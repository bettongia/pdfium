// Copyright 2026 The Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Web backend for PdfDocument — dart:js_interop / PDFium WASM implementation.
//
// Selected by the conditional import in pdf_document.dart when
// dart.library.js_interop is present (Flutter web / dart2wasm).
//
// Runtime notes:
//   - PDFium WASM runs synchronously on the browser main thread (v1). All
//     FPDF_* calls block until they complete. For large documents, individual
//     operations may freeze the tab briefly; display a loading indicator.
//   - Streaming methods (extractPlainText, extractAnnotations, etc.) yield
//     between pages via Future.delayed(Duration.zero). This reduces jank
//     between pages but does NOT unblock the main thread during a single
//     long PDFium call within a page.
//   - A Web Worker offload path is deferred to a future roadmap item.
//
// Distribution:
//   - pdfium.js + pdfium.wasm must be placed at web/assets/pdfium/ in the
//     consumer's Flutter app. Run `make fetch_wasm_assets` to download them.
//   - The module is loaded from assets/pdfium/pdfium.js (relative to the app
//     origin). Both files must be co-located; pdfium.js locates pdfium.wasm
//     relative to itself.

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../pdf_exception.dart';
import '../rendering/pdf_page_size.dart';
import '_bitmap_utils.dart';
import '_pdfium_js_interop.dart';
import 'pdf_date_parser.dart';
import 'pdf_types.dart';

/// Web implementation of [PdfDocument] using the PDFium WASM module.
///
/// The PDFium WASM module is loaded once per page lifetime (static singleton)
/// and shared across all [PdfDocumentImpl] instances. The module is
/// initialised on the first [fromBytes] call and held for the page lifetime.
///
/// All PDFium handles are stored as integers (WASM heap addresses). There is
/// no Isolate boundary — WASM runs on the browser main thread.
///
/// Use [fromBytes] to load a document. Always call [close] when done.
/// A [Finalizer] is registered as a safety net against forgotten [close]
/// calls, but explicit [close] is preferred.
class PdfDocumentImpl {
  PdfDocumentImpl._(this._token) {
    final rec = _registry[_token];
    if (rec != null) {
      _finalizer.attach(this, rec, detach: this);
    }
  }

  final int _token;
  bool _closed = false;

  // ---------------------------------------------------------------------------
  // Static module singleton + document registry
  // ---------------------------------------------------------------------------

  // The PDFium Emscripten module. Loaded once on the first fromBytes() call.
  static PdfiumModule? _module;

  // Monotonically increasing token counter. Never reset within a page lifetime.
  static int _nextToken = 1;

  // Per-document WASM heap pointers.
  //   docPtr  — the FPDF_DOCUMENT handle (WASM address of the PDFium object).
  //   bufPtr  — the WASM heap address of the raw PDF bytes buffer. PDFium does
  //             not copy the buffer; it must remain allocated until
  //             fpdfCloseDocument. Freed alongside the document on close().
  static final Map<int, ({int docPtr, int bufPtr})> _registry = {};

  // Safety-net Finalizer: if a PdfDocumentImpl is GC'd without close() being
  // called, this callback frees the WASM heap buffers. The module reference is
  // captured at callback time because the document object may be gone.
  // coverage:ignore-start
  // Finalizer callbacks are non-deterministic and cannot be reliably triggered
  // in a test suite.
  static final Finalizer<({int docPtr, int bufPtr})> _finalizer =
      Finalizer<({int docPtr, int bufPtr})>((rec) {
        final m = _module;
        if (m == null) return;
        m.fpdfCloseDocument(rec.docPtr);
        m.free(rec.bufPtr);
      });
  // coverage:ignore-end

  // ---------------------------------------------------------------------------
  // Module loading
  // ---------------------------------------------------------------------------

  static Future<PdfiumModule> _getModule() async {
    return _module ??= await _loadModule();
  }

  /// Loads pdfium.js and initialises the PDFium WASM module.
  ///
  /// The bblanchon pdfium.js uses a non-MODULARIZE Emscripten build. The
  /// module is exposed as window.Module. By setting window.Module to a config
  /// object with an `onRuntimeInitialized` callback BEFORE injecting the
  /// script, Emscripten merges the config and fires the callback when WASM
  /// instantiation completes.
  static Future<PdfiumModule> _loadModule() async {
    final completer = Completer<void>();

    // Pre-configure window.Module so Emscripten fires our callback.
    final config = JSObject();
    config.setProperty(
      'onRuntimeInitialized'.toJS,
      (() {
        if (!completer.isCompleted) completer.complete();
      }).toJS,
    );
    web.window.setProperty('Module'.toJS, config);

    // Inject pdfium.js as a <script> tag. The script auto-runs on load.
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src = 'assets/pdfium/pdfium.js';
    web.document.head!.appendChild(script);

    // Wait for WASM instantiation with a timeout so a missing or failed
    // pdfium.js fails fast rather than hanging the caller indefinitely.
    try {
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw PdfiumException(
          'PDFium WASM module failed to initialise within 30 seconds. '
          'Ensure pdfium.js and pdfium.wasm are present at '
          'assets/pdfium/ relative to the app origin '
          '(run `make fetch_wasm_assets` and copy the files to web/assets/pdfium/).',
        ),
      );
    } catch (e) {
      // Re-throw PdfiumException directly; wrap unexpected errors.
      if (e is PdfiumException) rethrow;
      throw PdfiumException('PDFium WASM module failed to initialise: $e');
    }

    // Retrieve the now-populated window.Module and initialise PDFium.
    final module = web.window.getProperty<PdfiumModule>('Module'.toJS);
    module.fpdfInitLibraryWithConfig(0);

    return module;
  }

  // ---------------------------------------------------------------------------
  // Public API — document lifecycle
  // ---------------------------------------------------------------------------

  /// Loads a PDF document from raw [bytes].
  ///
  /// Allocates a WASM heap buffer, copies [bytes] into it, and calls
  /// `FPDF_LoadMemDocument64`. The buffer is kept alive until [close].
  ///
  /// [dylibPath] is accepted for API compatibility with the native backend but
  /// is ignored on web — the WASM module is loaded from a fixed URL.
  ///
  /// Throws [PdfExtractionException] if the document is invalid or
  /// password-protected.
  static Future<PdfDocumentImpl> fromBytes(
    Uint8List bytes, {
    String? dylibPath,
  }) async {
    final module = await _getModule();

    // Allocate WASM heap buffer for the PDF bytes.
    final bufPtr = module.malloc(bytes.length);
    if (bufPtr == 0) {
      throw PdfiumException(
        'WASM _malloc(${bytes.length}) returned null — out of WASM heap memory.',
      );
    }

    // Copy Dart bytes into WASM heap via HEAPU8.set(src, offset).
    // bytes.toJS produces a JSUint8Array wrapping the same underlying data.
    module.heapu8.callMethod('set'.toJS, bytes.toJS, bufPtr.toJS);

    // Load the PDF document. PDFium does not copy the buffer — bufPtr must
    // remain allocated until fpdfCloseDocument.
    final docPtr = module.fpdfLoadMemDocument64(bufPtr, bytes.length, 0);
    if (docPtr == 0) {
      module.free(bufPtr);
      final errCode = module.fpdfGetLastError();
      final error = errCode == 4
          ? PdfError.passwordRequired
          : PdfError.invalidDocument;
      throw PdfExtractionException(error);
    }

    final token = _nextToken++;
    _registry[token] = (docPtr: docPtr, bufPtr: bufPtr);

    return PdfDocumentImpl._(token);
  }

  /// Releases the PDFium document handle and frees the WASM heap buffer.
  ///
  /// Calling [close] multiple times is safe (subsequent calls are no-ops).
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final rec = _registry.remove(_token);
    if (rec == null) return;
    _finalizer.detach(this);
    final m = _module!;
    m.fpdfCloseDocument(rec.docPtr);
    m.free(rec.bufPtr);
  }

  /// Returns the total number of pages in this document.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<int> get pageCount async {
    _checkNotClosed();
    final rec = _registry[_token]!;
    return _module!.fpdfGetPageCount(rec.docPtr);
  }

  // ---------------------------------------------------------------------------
  // PR 2b — metadata, document info, page size, text extractability
  // ---------------------------------------------------------------------------

  /// Returns the Info dictionary metadata for this document.
  ///
  /// Reads the eight standard Info dictionary fields (Title, Author, Subject,
  /// Keywords, Creator, Producer, CreationDate, ModDate). Fields not present
  /// in the document are null. Date fields are parsed via [PdfDateParser].
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfMetadata> getMetadata() async {
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    return PdfMetadata(
      title: _readMetaTextField(module, docPtr, 'Title'),
      author: _readMetaTextField(module, docPtr, 'Author'),
      subject: _readMetaTextField(module, docPtr, 'Subject'),
      keywords: _readMetaTextField(module, docPtr, 'Keywords'),
      creator: _readMetaTextField(module, docPtr, 'Creator'),
      producer: _readMetaTextField(module, docPtr, 'Producer'),
      creationDate: PdfDateParser.parse(
        _readMetaTextField(module, docPtr, 'CreationDate'),
      ),
      modDate: PdfDateParser.parse(
        _readMetaTextField(module, docPtr, 'ModDate'),
      ),
    );
  }

  /// Returns file-level information for this document.
  ///
  /// Retrieves the PDF file version (e.g. 17 for PDF 1.7) and the permanent
  /// and changing file identifiers. Fields are null when not present.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfDocumentInfo> getDocumentInfo() async {
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    // Read file version via int32 output pointer.
    final versionPtr = module.malloc(4);
    int? fileVersion;
    try {
      final ok = module.fpdfGetFileVersion(docPtr, versionPtr);
      if (ok != 0) {
        fileVersion = module.heap32.toDart[versionPtr >> 2];
      }
    } finally {
      module.free(versionPtr);
    }

    return PdfDocumentInfo(
      fileVersion: fileVersion,
      permanentId: _readFileIdentifier(module, docPtr, 0),
      changingId: _readFileIdentifier(module, docPtr, 1),
    );
  }

  /// Returns the intrinsic size of [pageIndex] in PDF points (1 pt = 1/72 in).
  ///
  /// Throws [StateError] if [close] has already been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Future<PdfPageSize> getPageSize(int pageIndex) async {
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    final count = module.fpdfGetPageCount(docPtr);
    if (pageIndex < 0 || pageIndex >= count) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }

    final pagePtr = module.fpdfLoadPage(docPtr, pageIndex);
    if (pagePtr == 0) throw PdfExtractionException(PdfError.invalidDocument);
    try {
      return PdfPageSize(
        widthPt: module.fpdfGetPageWidthF(pagePtr),
        heightPt: module.fpdfGetPageHeightF(pagePtr),
      );
    } finally {
      module.fpdfClosePage(pagePtr);
    }
  }

  /// Returns true when the document has a text layer on most pages.
  ///
  /// Runs [extractPlainText] to completion and counts pages where
  /// [PdfPageText.hasTextLayer] is false. Returns false when the proportion
  /// of scanned pages meets or exceeds [config.scannedPageRatio].
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<bool> isPlainTextExtractable({
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) async {
    var totalPages = 0;
    var noTextLayerPages = 0;

    await for (final page in extractPlainText(config: config)) {
      totalPages++;
      if (!page.hasTextLayer) noTextLayerPages++;
    }

    if (totalPages == 0) return false;

    final scannedRatio = noTextLayerPages / totalPages;
    return scannedRatio < config.scannedPageRatio;
  }

  // ---------------------------------------------------------------------------
  // PR 2c — text extraction and annotation extraction
  // ---------------------------------------------------------------------------

  /// Streams [PdfPageText] for each page, or a single page when [pageIndex]
  /// is specified.
  ///
  /// Yields between pages via `Future.delayed(Duration.zero)` to reduce main-
  /// thread jank. Each page's PDFium call is still synchronous.
  ///
  /// Throws [StateError] if [close] has already been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Stream<PdfPageText> extractPlainText({
    int? pageIndex,
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) {
    return _extractPlainTextImpl(pageIndex: pageIndex);
  }

  Stream<PdfPageText> _extractPlainTextImpl({int? pageIndex}) async* {
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    final count = module.fpdfGetPageCount(docPtr);
    if (pageIndex != null && (pageIndex < 0 || pageIndex >= count)) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }
    final indices = pageIndex != null
        ? [pageIndex]
        : List.generate(count, (i) => i);

    for (final idx in indices) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;

      yield _extractPageText(module, docPtr, idx);
    }
  }

  /// Streams [PdfPageAnnotations] for each page, or a single page when
  /// [pageIndex] is specified.
  ///
  /// Throws [StateError] if [close] has already been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Stream<PdfPageAnnotations> extractAnnotations({int? pageIndex}) {
    return _extractAnnotationsImpl(pageIndex: pageIndex);
  }

  Stream<PdfPageAnnotations> _extractAnnotationsImpl({int? pageIndex}) async* {
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    final count = module.fpdfGetPageCount(docPtr);
    if (pageIndex != null && (pageIndex < 0 || pageIndex >= count)) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }
    final indices = pageIndex != null
        ? [pageIndex]
        : List.generate(count, (i) => i);

    for (final idx in indices) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;

      yield PdfPageAnnotations(
        pageIndex: idx,
        annotations: _extractPageAnnotations(module, docPtr, idx),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PR 2d — rendering and thumbnails
  // ---------------------------------------------------------------------------

  /// Renders page [pageIndex] to a BGRA pixel buffer.
  ///
  /// Returns a record with [pixels] (compact BGRA bytes), [pixelWidth], and
  /// [pixelHeight]. Uses `FPDFBitmap_Create` (BGRA, alpha=1).
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [PdfiumException] if a native PDFium call fails.
  Future<({Uint8List pixels, int pixelWidth, int pixelHeight})>
  renderPageToBytes(
    int pageIndex,
    int pixelWidth,
    int pixelHeight, {
    bool renderAnnotations = true,
    bool lcdText = false,
    int backgroundColor = 0xFFFFFFFF,
  }) async {
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    final count = module.fpdfGetPageCount(docPtr);
    if (pageIndex < 0 || pageIndex >= count) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }

    final pagePtr = module.fpdfLoadPage(docPtr, pageIndex);
    if (pagePtr == 0) {
      throw PdfiumException('FPDF_LoadPage returned null for page $pageIndex.');
    }

    try {
      // hasAlpha=1 → BGRA format.
      final bitmap = module.fpdfBitmapCreate(pixelWidth, pixelHeight, 1);
      if (bitmap == 0) {
        throw PdfiumException(
          'FPDFBitmap_Create returned null for '
          '${pixelWidth}x$pixelHeight (possible out-of-memory).',
        );
      }

      try {
        // FPDF_ANNOT = 0x01, FPDF_LCD_TEXT = 0x02.
        var flags = 0;
        if (renderAnnotations) flags |= 0x01;
        if (lcdText) flags |= 0x02;

        module.fpdfBitmapFillRect(
          bitmap,
          0,
          0,
          pixelWidth,
          pixelHeight,
          backgroundColor,
        );
        module.fpdfRenderPageBitmap(
          bitmap,
          pagePtr,
          0,
          0,
          pixelWidth,
          pixelHeight,
          0,
          flags,
        );

        final bufPtr = module.fpdfBitmapGetBuffer(bitmap);
        final stride = module.fpdfBitmapGetStride(bitmap);
        final byteCount = stride * pixelHeight;
        final rawBytes = Uint8List.fromList(
          module.heapu8.toDart.sublist(bufPtr, bufPtr + byteCount),
        );
        final pixels = stripBitmapStride(
          rawBytes,
          pixelWidth,
          pixelHeight,
          stride,
        );

        return (
          pixels: pixels,
          pixelWidth: pixelWidth,
          pixelHeight: pixelHeight,
        );
      } finally {
        module.fpdfBitmapDestroy(bitmap);
      }
    } finally {
      module.fpdfClosePage(pagePtr);
    }
  }

  /// Returns the thumbnail for page [pageIndex].
  ///
  /// Tries the embedded /Thumb stream first. If absent and [generateIfAbsent]
  /// is true (default), renders the page scaled to [maxDimension] pixels on
  /// the longest edge and returns a [PdfThumbnailSource.rendered] thumbnail.
  ///
  /// Returns null when no embedded thumbnail exists and [generateIfAbsent] is
  /// false.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [ArgumentError] if [maxDimension] ≤ 0.
  Future<PdfThumbnail?> getThumbnail(
    int pageIndex, {
    bool generateIfAbsent = true,
    int maxDimension = 256,
  }) async {
    if (maxDimension <= 0) {
      throw ArgumentError.value(
        maxDimension,
        'maxDimension',
        'maxDimension must be greater than 0',
      );
    }
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    final count = module.fpdfGetPageCount(docPtr);
    if (pageIndex < 0 || pageIndex >= count) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }

    final pagePtr = module.fpdfLoadPage(docPtr, pageIndex);
    if (pagePtr == 0) {
      throw PdfiumException('FPDF_LoadPage returned null for page $pageIndex.');
    }

    try {
      final bitmap = module.fpdfGetPageThumbnailAsBitmap(pagePtr);

      if (bitmap != 0) {
        try {
          final result = _readThumbnailBitmap(module, bitmap, pageIndex);
          if (result != null) return result;
        } finally {
          module.fpdfBitmapDestroy(bitmap);
        }
      }
    } finally {
      module.fpdfClosePage(pagePtr);
    }

    if (!generateIfAbsent) return null;

    // Fallback: render the page at a scaled size.
    _checkNotClosed();
    final size = await getPageSize(pageIndex);
    _checkNotClosed();

    final double scale;
    if (size.widthPt >= size.heightPt) {
      scale = maxDimension / size.widthPt;
    } else {
      scale = maxDimension / size.heightPt;
    }
    final pw = (size.widthPt * scale).round().clamp(1, maxDimension);
    final ph = (size.heightPt * scale).round().clamp(1, maxDimension);

    final rendered = await renderPageToBytes(pageIndex, pw, ph);
    return PdfThumbnail(
      bgra: rendered.pixels,
      width: rendered.pixelWidth,
      height: rendered.pixelHeight,
      source: PdfThumbnailSource.rendered,
    );
  }

  // ---------------------------------------------------------------------------
  // PR 2e — images, search, table of contents
  // ---------------------------------------------------------------------------

  /// Streams [PdfPageImages] for each page, or a single page when [pageIndex]
  /// is specified.
  ///
  /// When [includeBitmap] is false (default), [PdfImage.bgra] is null.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Stream<PdfPageImages> extractImages({
    int? pageIndex,
    bool includeBitmap = false,
  }) {
    return _extractImagesImpl(
      pageIndex: pageIndex,
      includeBitmap: includeBitmap,
    );
  }

  Stream<PdfPageImages> _extractImagesImpl({
    int? pageIndex,
    required bool includeBitmap,
  }) async* {
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    final count = module.fpdfGetPageCount(docPtr);
    if (pageIndex != null && (pageIndex < 0 || pageIndex >= count)) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }
    final indices = pageIndex != null
        ? [pageIndex]
        : List.generate(count, (i) => i);

    for (final idx in indices) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;

      yield PdfPageImages(
        pageIndex: idx,
        images: _extractPageImages(module, docPtr, idx, includeBitmap),
      );
    }
  }

  /// Returns the BGRA bitmap for image object [objectIndex] on page
  /// [pageIndex], or null when the object has no renderable bitmap.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range or [objectIndex] is
  /// negative.
  Future<PdfImageBitmap?> renderImage(int pageIndex, int objectIndex) async {
    _checkNotClosed();
    if (objectIndex < 0) {
      throw RangeError.value(objectIndex, 'objectIndex');
    }
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    final count = module.fpdfGetPageCount(docPtr);
    if (pageIndex < 0 || pageIndex >= count) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }

    final pagePtr = module.fpdfLoadPage(docPtr, pageIndex);
    if (pagePtr == 0) throw PdfExtractionException(PdfError.invalidDocument);

    try {
      final objPtr = module.fpdfPageGetObject(pagePtr, objectIndex);
      if (objPtr == 0) return null;

      final objType = module.fpdfPageObjGetType(objPtr);
      if (objType != 3) return null; // FPDF_PAGEOBJ_IMAGE = 3

      return _renderImageBitmap(module, docPtr, pagePtr, objPtr);
    } finally {
      module.fpdfClosePage(pagePtr);
    }
  }

  /// Streams [PdfSearchMatch] for all matches of [query] across the document,
  /// or across a single [pageIndex] when specified.
  ///
  /// An empty [query] yields nothing. [flags] controls case sensitivity and
  /// word-boundary matching.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Stream<PdfSearchMatch> search(
    String query, {
    Set<PdfSearchFlag> flags = const {},
    int? pageIndex,
  }) {
    return _searchImpl(query, flags: flags, pageIndex: pageIndex);
  }

  Stream<PdfSearchMatch> _searchImpl(
    String query, {
    required Set<PdfSearchFlag> flags,
    int? pageIndex,
  }) async* {
    if (query.isEmpty) return;
    _checkNotClosed();

    var flagsMask = 0;
    if (flags.contains(PdfSearchFlag.matchCase)) flagsMask |= 0x01;
    if (flags.contains(PdfSearchFlag.matchWholeWord)) flagsMask |= 0x02;
    if (flags.contains(PdfSearchFlag.consecutive)) flagsMask |= 0x04;

    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;
    final count = module.fpdfGetPageCount(docPtr);
    if (pageIndex != null && (pageIndex < 0 || pageIndex >= count)) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }
    final indices = pageIndex != null
        ? [pageIndex]
        : List.generate(count, (i) => i);

    for (final idx in indices) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;

      final matches = _searchPage(module, docPtr, idx, query, flagsMask);
      for (final match in matches) {
        if (_closed) return;
        yield match;
      }
    }
  }

  /// Returns the complete Table of Contents (bookmark/outline tree).
  ///
  /// Returns an empty list when the document has no bookmarks.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<List<PdfTocEntry>> get tableOfContents async {
    _checkNotClosed();
    final module = _module!;
    final docPtr = _registry[_token]!.docPtr;

    final visited = <int>{};
    return _walkBookmarkTree(module, docPtr, 0, visited);
  }

  // ---------------------------------------------------------------------------
  // Private helpers — module-level operations
  // ---------------------------------------------------------------------------

  void _checkNotClosed() {
    if (_closed) {
      throw StateError('PdfDocument has already been closed.');
    }
  }
}

// =============================================================================
// Module-level helper functions (private)
//
// These functions receive a PdfiumModule explicitly and perform synchronous
// WASM heap operations. They mirror the isolate-level helpers in
// pdfium_isolate.dart but use WASM int handles instead of FFI pointers.
// =============================================================================

// ---------------------------------------------------------------------------
// Memory helpers
// ---------------------------------------------------------------------------

/// Allocates a null-terminated UTF-8 string in the WASM heap.
///
/// The caller must call `module.free(ptr)` when done.
int _allocUtf8(PdfiumModule module, String s) {
  final encoded = utf8.encode(s);
  final ptr = module.malloc(encoded.length + 1);
  final bytes = Uint8List(encoded.length + 1);
  for (var i = 0; i < encoded.length; i++) {
    bytes[i] = encoded[i];
  }
  bytes[encoded.length] = 0; // null terminator
  // Re-fetch HEAPU8 after malloc (memory may have grown).
  module.heapu8.callMethod('set'.toJS, bytes.toJS, ptr.toJS);
  return ptr;
}

/// Decodes UTF-16LE bytes from the WASM heap into a Dart [String].
///
/// [bufPtr] is the WASM byte address of the first code unit. [byteLen] is the
/// number of bytes to decode (NOT including any null terminator).
String _readUtf16Le(PdfiumModule module, int bufPtr, int byteLen) {
  final u8 = module.heapu8.toDart;
  final codeUnits = <int>[];
  for (var i = 0; i < byteLen; i += 2) {
    codeUnits.add(u8[bufPtr + i] | (u8[bufPtr + i + 1] << 8));
  }
  return String.fromCharCodes(codeUnits);
}

/// Reads a float32 from WASM HEAPF32 at byte address [byteAddr].
double _readF32(PdfiumModule module, int byteAddr) =>
    module.heapf32.toDart[byteAddr >> 2];

/// Reads a float64 from WASM HEAPF64 at byte address [byteAddr].
double _readF64(PdfiumModule module, int byteAddr) =>
    module.heapf64.toDart[byteAddr >> 3];

/// Reads a signed int32 from WASM HEAP32 at byte address [byteAddr].
int _readI32(PdfiumModule module, int byteAddr) =>
    module.heap32.toDart[byteAddr >> 2];

/// Reads a uint32 from WASM HEAP32 at byte address [byteAddr].
int _readU32(PdfiumModule module, int byteAddr) =>
    module.heap32.toDart[byteAddr >> 2] & 0xFFFFFFFF;

// ---------------------------------------------------------------------------
// PDF metadata helpers
// ---------------------------------------------------------------------------

/// Reads one Info dictionary field as a string, or null if absent.
String? _readMetaTextField(PdfiumModule module, int docPtr, String tag) {
  final tagPtr = _allocUtf8(module, tag);
  try {
    final reqLen = module.fpdfGetMetaText(docPtr, tagPtr, 0, 0);
    // <= 2 means empty: only the UTF-16LE null terminator pair.
    if (reqLen <= 2) return null;

    final bufPtr = module.malloc(reqLen);
    try {
      module.fpdfGetMetaText(docPtr, tagPtr, bufPtr, reqLen);
      // Decode reqLen - 2 bytes (exclude null terminator pair).
      final s = _readUtf16Le(module, bufPtr, reqLen - 2);
      return s.isEmpty ? null : s;
    } finally {
      module.free(bufPtr);
    }
  } finally {
    module.free(tagPtr);
  }
}

/// Reads a file identifier (permanent or changing) as raw bytes.
Uint8List? _readFileIdentifier(PdfiumModule module, int docPtr, int idType) {
  final reqLen = module.fpdfGetFileIdentifier(docPtr, idType, 0, 0);
  if (reqLen == 0) return null;

  final bufPtr = module.malloc(reqLen);
  try {
    module.fpdfGetFileIdentifier(docPtr, idType, bufPtr, reqLen);
    return Uint8List.fromList(
      module.heapu8.toDart.sublist(bufPtr, bufPtr + reqLen),
    );
  } finally {
    module.free(bufPtr);
  }
}

// ---------------------------------------------------------------------------
// Text extraction
// ---------------------------------------------------------------------------

/// Extracts all text from a single page.
PdfPageText _extractPageText(PdfiumModule module, int docPtr, int pageIndex) {
  final pagePtr = module.fpdfLoadPage(docPtr, pageIndex);
  if (pagePtr == 0) {
    // coverage:ignore-start
    return PdfPageText(
      pageIndex: pageIndex,
      text: '',
      hasUnicodeErrors: false,
      hasTextLayer: false,
    );
    // coverage:ignore-end
  }

  try {
    final textPagePtr = module.fpdfTextLoadPage(pagePtr);
    if (textPagePtr == 0) {
      // coverage:ignore-start
      return PdfPageText(
        pageIndex: pageIndex,
        text: '',
        hasUnicodeErrors: false,
        hasTextLayer: false,
      );
      // coverage:ignore-end
    }

    try {
      final charCount = module.fpdfTextCountChars(textPagePtr);

      var hasUnicodeErrors = false;
      final softHyphenIndices = <int>{};

      for (var i = 0; i < charCount; i++) {
        if (module.fpdfTextHasUnicodeMapError(textPagePtr, i) != 0) {
          hasUnicodeErrors = true;
        }
        if (module.fpdfTextIsHyphen(textPagePtr, i) != 0) {
          softHyphenIndices.add(i);
        }
      }

      final String extractedText;
      if (charCount <= 0) {
        extractedText = '';
      } else {
        // Buffer: (charCount + 1) code units × 2 bytes each.
        final bufPtr = module.malloc((charCount + 1) * 2);
        try {
          final written = module.fpdfTextGetText(
            textPagePtr,
            0,
            charCount,
            bufPtr,
          );
          if (written <= 0) {
            extractedText = '';
          } else {
            // written includes the null terminator; decode (written-1) chars.
            extractedText = _readUtf16Le(module, bufPtr, (written - 1) * 2);
          }
        } finally {
          module.free(bufPtr);
        }
      }

      final processedText = softHyphenIndices.isEmpty
          ? extractedText
          : _stripSoftHyphens(extractedText, softHyphenIndices);

      return PdfPageText(
        pageIndex: pageIndex,
        text: processedText,
        hasUnicodeErrors: hasUnicodeErrors,
        hasTextLayer: charCount > 0,
      );
    } finally {
      module.fpdfTextClosePage(textPagePtr);
    }
  } finally {
    module.fpdfClosePage(pagePtr);
  }
}

/// Strips soft hyphens at line-break positions and joins the surrounding word
/// fragments. Mirrors `_stripSoftHyphens` in pdfium_isolate.dart.
String _stripSoftHyphens(String text, Set<int> softHyphenIndices) {
  final buffer = StringBuffer();
  var skipNextWhitespace = false;

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];

    if (skipNextWhitespace && (ch == '\n' || ch == '\r' || ch == ' ')) {
      skipNextWhitespace = false;
      continue;
    }
    skipNextWhitespace = false;

    if (softHyphenIndices.contains(i)) {
      skipNextWhitespace = true;
      continue;
    }

    buffer.write(ch);
  }

  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Annotation extraction
// ---------------------------------------------------------------------------

/// Extracts all annotations from a single page.
List<PdfAnnotation> _extractPageAnnotations(
  PdfiumModule module,
  int docPtr,
  int pageIndex,
) {
  final pagePtr = module.fpdfLoadPage(docPtr, pageIndex);
  if (pagePtr == 0) return const []; // coverage:ignore-line

  try {
    final annotCount = module.fpdfPageGetAnnotCount(pagePtr);

    // First pass: extract non-POPUP annotations; stash POPUP handles.
    final extracted = List<PdfAnnotation?>.filled(annotCount, null);
    final popupHandlesByIndex = <int, int>{}; // annotIndex → WASM handle

    for (var i = 0; i < annotCount; i++) {
      final annotPtr = module.fpdfPageGetAnnot(pagePtr, i);
      if (annotPtr == 0) continue;

      final subtypeInt = module.fpdfAnnotGetSubtype(annotPtr);

      if (subtypeInt == 16) {
        // FPDF_ANNOT_POPUP = 16 — defer to second pass; do NOT close.
        popupHandlesByIndex[i] = annotPtr;
        continue;
      }

      try {
        final contents = _readAnnotStringValue(module, annotPtr, 'Contents');
        final author = _readAnnotStringValue(module, annotPtr, 'T');
        final modDateStr = _readAnnotStringValue(module, annotPtr, 'M');
        final flags = module.fpdfAnnotGetFlags(annotPtr);
        final rect = _readAnnotRect(module, annotPtr);
        final color = _readAnnotColor(module, annotPtr, 0);

        extracted[i] = _buildAnnotation(
          module: module,
          annotPtr: annotPtr,
          subtypeInt: subtypeInt,
          pageIndex: pageIndex,
          contents: contents,
          author: author,
          rect: rect,
          color: color,
          modifiedDate: PdfDateParser.parse(modDateStr),
          flags: flags,
          docPtr: docPtr,
          pagePtr: pagePtr,
        );
      } finally {
        module.fpdfPageCloseAnnot(annotPtr);
      }
    }

    // Second pass: link POPUP annotations to their parents via IRT key.
    final irtKeyPtr = _allocUtf8(module, 'IRT');
    try {
      for (final entry in popupHandlesByIndex.entries) {
        final popupPtr = entry.value;
        try {
          final parentPtr = module.fpdfAnnotGetLinkedAnnot(popupPtr, irtKeyPtr);

          if (parentPtr != 0) {
            try {
              final parentIndex = module.fpdfPageGetAnnotIndex(
                pagePtr,
                parentPtr,
              );

              if (parentIndex >= 0 &&
                  parentIndex < annotCount &&
                  extracted[parentIndex] != null) {
                final popupRect = _readAnnotRect(module, popupPtr);
                final popupFlags = module.fpdfAnnotGetFlags(popupPtr);
                final popupData = PdfPopupAnnotation(
                  rect: popupRect,
                  flags: popupFlags,
                );
                extracted[parentIndex] = _withPopup(
                  extracted[parentIndex]!,
                  popupData,
                );
              }
            } finally {
              module.fpdfPageCloseAnnot(parentPtr);
            }
          }
        } finally {
          module.fpdfPageCloseAnnot(popupPtr);
        }
      }
    } finally {
      module.free(irtKeyPtr);
    }

    return extracted.where((a) => a != null).cast<PdfAnnotation>().toList();
  } finally {
    module.fpdfClosePage(pagePtr);
  }
}

/// Reads a UTF-16LE annotation string dictionary value via the two-call
/// buffer pattern.
String? _readAnnotStringValue(PdfiumModule module, int annotPtr, String key) {
  final keyPtr = _allocUtf8(module, key);
  try {
    final reqLen = module.fpdfAnnotGetStringValue(annotPtr, keyPtr, 0, 0);
    // <= 2: absent or empty (null terminator only).
    if (reqLen <= 2) return null;

    final bufPtr = module.malloc(reqLen);
    try {
      module.fpdfAnnotGetStringValue(annotPtr, keyPtr, bufPtr, reqLen);
      final s = _readUtf16Le(module, bufPtr, reqLen - 2);
      return s.isEmpty ? null : s;
    } finally {
      module.free(bufPtr);
    }
  } finally {
    module.free(keyPtr);
  }
}

/// Reads the FS_RECTF bounding rectangle of [annotPtr].
PdfRect? _readAnnotRect(PdfiumModule module, int annotPtr) {
  // FS_RECTF: 4 × float32 = 16 bytes (left, top, right, bottom).
  final rectPtr = module.malloc(16);
  try {
    final ok = module.fpdfAnnotGetRect(annotPtr, rectPtr);
    if (ok == 0) return null;
    return PdfRect(
      left: _readF32(module, rectPtr),
      top: _readF32(module, rectPtr + 4),
      right: _readF32(module, rectPtr + 8),
      bottom: _readF32(module, rectPtr + 12),
    );
  } finally {
    module.free(rectPtr);
  }
}

/// Reads an RGBA colour from [annotPtr].
///
/// [colorType]: 0 = main colour, 1 = interior colour.
PdfColor? _readAnnotColor(PdfiumModule module, int annotPtr, int colorType) {
  // FPDFAnnot_GetColor writes 4 × uint32 (one per component) to separate
  // addresses. Allocate a contiguous block for efficiency.
  final block = module.malloc(16); // 4 × 4 bytes
  final rPtr = block;
  final gPtr = block + 4;
  final bPtr = block + 8;
  final aPtr = block + 12;
  try {
    final ok = module.fpdfAnnotGetColor(
      annotPtr,
      colorType,
      rPtr,
      gPtr,
      bPtr,
      aPtr,
    );
    if (ok == 0) return null;
    return PdfColor(
      r: _readU32(module, rPtr),
      g: _readU32(module, gPtr),
      b: _readU32(module, bPtr),
      a: _readU32(module, aPtr),
    );
  } finally {
    module.free(block);
  }
}

/// Reads quad-point attachment sets from [annotPtr].
List<PdfQuadPoints> _readAnnotQuadPoints(PdfiumModule module, int annotPtr) {
  final count = module.fpdfAnnotCountAttachmentPoints(annotPtr);
  if (count == 0) return const [];

  final result = <PdfQuadPoints>[];
  // FS_QUADPOINTSF: 8 × float32 = 32 bytes.
  final quadPtr = module.malloc(32);
  try {
    for (var i = 0; i < count; i++) {
      final ok = module.fpdfAnnotGetAttachmentPoints(annotPtr, i, quadPtr);
      if (ok == 0) continue;

      result.add(
        PdfQuadPoints(
          p1: PdfPoint(
            x: _readF32(module, quadPtr),
            y: _readF32(module, quadPtr + 4),
          ),
          p2: PdfPoint(
            x: _readF32(module, quadPtr + 8),
            y: _readF32(module, quadPtr + 12),
          ),
          p3: PdfPoint(
            x: _readF32(module, quadPtr + 16),
            y: _readF32(module, quadPtr + 20),
          ),
          p4: PdfPoint(
            x: _readF32(module, quadPtr + 24),
            y: _readF32(module, quadPtr + 28),
          ),
        ),
      );
    }
  } finally {
    module.free(quadPtr);
  }
  return result;
}

/// Extracts text covered by markup annotation quad-point regions.
String? _readMarkupMarkedText(
  PdfiumModule module,
  int pagePtr,
  List<PdfQuadPoints> quadPoints,
) {
  if (quadPoints.isEmpty) return null;

  final textPagePtr = module.fpdfTextLoadPage(pagePtr);
  if (textPagePtr == 0) return null;

  try {
    final segments = <String>[];
    for (final quad in quadPoints) {
      // Compute the axis-aligned bounding box of the four quad corners.
      var left = quad.p1.x;
      var right = quad.p1.x;
      var top = quad.p1.y;
      var bottom = quad.p1.y;
      for (final pt in [quad.p2, quad.p3, quad.p4]) {
        if (pt.x < left) left = pt.x;
        if (pt.x > right) right = pt.x;
        if (pt.y > top) top = pt.y;
        if (pt.y < bottom) bottom = pt.y;
      }

      // First call: get character count in the region.
      final count = module.fpdfTextGetBoundedText(
        textPagePtr,
        left,
        top,
        right,
        bottom,
        0,
        0,
      );
      if (count <= 0) continue;

      // Second call: fill the UTF-16LE buffer.
      final bufPtr = module.malloc(count * 2);
      try {
        final written = module.fpdfTextGetBoundedText(
          textPagePtr,
          left,
          top,
          right,
          bottom,
          bufPtr,
          count,
        );
        if (written <= 0) continue;
        segments.add(_readUtf16Le(module, bufPtr, written * 2));
      } finally {
        module.free(bufPtr);
      }
    }
    return segments.join(' ');
  } finally {
    module.fpdfTextClosePage(textPagePtr);
  }
}

/// Reads ink strokes from [annotPtr] (FPDF_ANNOT_INK only).
List<List<PdfPoint>> _readInkStrokes(PdfiumModule module, int annotPtr) {
  final strokeCount = module.fpdfAnnotGetInkListCount(annotPtr);
  if (strokeCount == 0) return const [];

  final strokes = <List<PdfPoint>>[];
  for (var strokeIdx = 0; strokeIdx < strokeCount; strokeIdx++) {
    final pointCount = module.fpdfAnnotGetInkListPath(
      annotPtr,
      strokeIdx,
      0,
      0,
    );
    if (pointCount == 0) {
      strokes.add(const []);
      continue;
    }

    // FS_POINTF: 2 × float32 = 8 bytes per point.
    final bufPtr = module.malloc(pointCount * 8);
    try {
      final written = module.fpdfAnnotGetInkListPath(
        annotPtr,
        strokeIdx,
        bufPtr,
        pointCount,
      );

      final points = <PdfPoint>[];
      for (var j = 0; j < written; j++) {
        points.add(
          PdfPoint(
            x: _readF32(module, bufPtr + j * 8),
            y: _readF32(module, bufPtr + j * 8 + 4),
          ),
        );
      }
      strokes.add(points);
    } finally {
      module.free(bufPtr);
    }
  }
  return strokes;
}

/// Reads polygon or polyline vertices from [annotPtr].
List<PdfPoint> _readAnnotVertices(PdfiumModule module, int annotPtr) {
  final count = module.fpdfAnnotGetVertices(annotPtr, 0, 0);
  if (count == 0) return const [];

  // FS_POINTF: 8 bytes per point.
  final bufPtr = module.malloc(count * 8);
  try {
    final written = module.fpdfAnnotGetVertices(annotPtr, bufPtr, count);
    final vertices = <PdfPoint>[];
    for (var i = 0; i < written; i++) {
      vertices.add(
        PdfPoint(
          x: _readF32(module, bufPtr + i * 8),
          y: _readF32(module, bufPtr + i * 8 + 4),
        ),
      );
    }
    return vertices;
  } finally {
    module.free(bufPtr);
  }
}

/// Reads the start and end points of a line annotation.
({PdfPoint? start, PdfPoint? end}) _readLineEndpoints(
  PdfiumModule module,
  int annotPtr,
) {
  // Two FS_POINTF structs: start at 0, end at 8. Total 16 bytes.
  final bufPtr = module.malloc(16);
  try {
    final ok = module.fpdfAnnotGetLine(annotPtr, bufPtr, bufPtr + 8);
    if (ok == 0) return (start: null, end: null);
    return (
      start: PdfPoint(
        x: _readF32(module, bufPtr),
        y: _readF32(module, bufPtr + 4),
      ),
      end: PdfPoint(
        x: _readF32(module, bufPtr + 8),
        y: _readF32(module, bufPtr + 12),
      ),
    );
  } finally {
    module.free(bufPtr);
  }
}

/// Reads the URI string from a LINK annotation, or null if unavailable.
String? _readLinkUri(PdfiumModule module, int docPtr, int annotPtr) {
  final link = module.fpdfAnnotGetLink(annotPtr);
  if (link == 0) return null;

  final action = module.fpdfLinkGetAction(link);
  if (action == 0) return null;

  // PDFACTION_URI = 3.
  final actionType = module.fpdfActionGetType(action);
  if (actionType != 3) return null;

  return _readActionUri(module, docPtr, action);
}

/// Reads a URI string from a PDFACTION_URI action.
// coverage:ignore-start
// Only reachable when a PDF has URI-type link or TOC actions — not in suite.
String? _readActionUri(PdfiumModule module, int docPtr, int action) {
  final reqLen = module.fpdfActionGetURIPath(docPtr, action, 0, 0);
  if (reqLen == 0) return null;

  final bufPtr = module.malloc(reqLen);
  try {
    module.fpdfActionGetURIPath(docPtr, action, bufPtr, reqLen);
    // ASCII null-terminated string; reqLen includes the null terminator.
    final u8 = module.heapu8.toDart;
    final uri = String.fromCharCodes(u8.sublist(bufPtr, bufPtr + reqLen - 1));
    return uri.isEmpty ? null : uri;
  } finally {
    module.free(bufPtr);
  }
}
// coverage:ignore-end

/// Maps a PDFium annotation subtype integer to [PdfAnnotationType].
PdfAnnotationType _annotationTypeFromInt(int subtype) => switch (subtype) {
  1 => PdfAnnotationType.text,
  2 => PdfAnnotationType.link,
  3 => PdfAnnotationType.freeText,
  4 => PdfAnnotationType.line,
  5 => PdfAnnotationType.square,
  6 => PdfAnnotationType.circle,
  7 => PdfAnnotationType.polygon,
  8 => PdfAnnotationType.polyline,
  9 => PdfAnnotationType.highlight,
  10 => PdfAnnotationType.underline,
  11 => PdfAnnotationType.squiggly,
  12 => PdfAnnotationType.strikeout,
  13 => PdfAnnotationType.stamp,
  15 => PdfAnnotationType.ink,
  16 => PdfAnnotationType.popup,
  _ => PdfAnnotationType.unknown,
};

/// Constructs a [PdfAnnotation] subclass from the extracted fields.
PdfAnnotation _buildAnnotation({
  required PdfiumModule module,
  required int annotPtr,
  required int subtypeInt,
  required int pageIndex,
  required String? contents,
  required String? author,
  required PdfRect? rect,
  required PdfColor? color,
  required PdfDate? modifiedDate,
  required int flags,
  required int docPtr,
  required int pagePtr,
}) {
  // Markup subtypes: highlight, underline, squiggly, strikeout.
  if (subtypeInt == 9 ||
      subtypeInt == 10 ||
      subtypeInt == 11 ||
      subtypeInt == 12) {
    final subtype = _annotationTypeFromInt(subtypeInt);
    final quadPoints = _readAnnotQuadPoints(module, annotPtr);
    final markedText = _readMarkupMarkedText(module, pagePtr, quadPoints);
    return PdfMarkupAnnotation(
      pageIndex: pageIndex,
      subtype: subtype,
      quadPoints: quadPoints,
      markedText: markedText,
      contents: contents,
      author: author,
      rect: rect,
      color: color,
      modifiedDate: modifiedDate,
      flags: flags,
    );
  }

  // Shape subtypes: square (rectangle) and circle (ellipse).
  if (subtypeInt == 5 || subtypeInt == 6) {
    final subtype = _annotationTypeFromInt(subtypeInt);
    final interiorColor = _readAnnotColor(module, annotPtr, 1);
    return PdfShapeAnnotation(
      pageIndex: pageIndex,
      subtype: subtype,
      interiorColor: interiorColor,
      contents: contents,
      author: author,
      rect: rect,
      color: color,
      modifiedDate: modifiedDate,
      flags: flags,
    );
  }

  switch (subtypeInt) {
    case 1: // FPDF_ANNOT_TEXT
      return PdfTextAnnotation(
        pageIndex: pageIndex,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 2: // FPDF_ANNOT_LINK
      final uri = _readLinkUri(module, docPtr, annotPtr);
      return PdfLinkAnnotation(
        pageIndex: pageIndex,
        uri: uri,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 3: // FPDF_ANNOT_FREETEXT
      return PdfFreeTextAnnotation(
        pageIndex: pageIndex,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 4: // FPDF_ANNOT_LINE
      final (:start, :end) = _readLineEndpoints(module, annotPtr);
      final lineStart =
          start ?? PdfPoint(x: rect?.left ?? 0, y: rect?.bottom ?? 0);
      final lineEnd = end ?? PdfPoint(x: rect?.right ?? 0, y: rect?.top ?? 0);
      return PdfLineAnnotation(
        pageIndex: pageIndex,
        lineStart: lineStart,
        lineEnd: lineEnd,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 7: // FPDF_ANNOT_POLYGON
    case 8: // FPDF_ANNOT_POLYLINE
      final subtype = _annotationTypeFromInt(subtypeInt);
      final vertices = _readAnnotVertices(module, annotPtr);
      return PdfPolygonAnnotation(
        pageIndex: pageIndex,
        subtype: subtype,
        vertices: vertices,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 13: // FPDF_ANNOT_STAMP
      return PdfStampAnnotation(
        pageIndex: pageIndex,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 15: // FPDF_ANNOT_INK
      final strokes = _readInkStrokes(module, annotPtr);
      return PdfInkAnnotation(
        pageIndex: pageIndex,
        strokes: strokes,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    default:
      return PdfUnknownAnnotation(
        pageIndex: pageIndex,
        rawSubtype: subtypeInt,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );
  }
}

/// Returns a copy of [annotation] with [popup] set.
PdfAnnotation _withPopup(PdfAnnotation annotation, PdfPopupAnnotation popup) {
  return switch (annotation) {
    PdfTextAnnotation a => PdfTextAnnotation(
      pageIndex: a.pageIndex,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfFreeTextAnnotation a => PdfFreeTextAnnotation(
      pageIndex: a.pageIndex,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfMarkupAnnotation a => PdfMarkupAnnotation(
      pageIndex: a.pageIndex,
      subtype: a.subtype,
      quadPoints: a.quadPoints,
      markedText: a.markedText,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfShapeAnnotation a => PdfShapeAnnotation(
      pageIndex: a.pageIndex,
      subtype: a.subtype,
      interiorColor: a.interiorColor,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfLineAnnotation a => PdfLineAnnotation(
      pageIndex: a.pageIndex,
      lineStart: a.lineStart,
      lineEnd: a.lineEnd,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfInkAnnotation a => PdfInkAnnotation(
      pageIndex: a.pageIndex,
      strokes: a.strokes,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfPolygonAnnotation a => PdfPolygonAnnotation(
      pageIndex: a.pageIndex,
      subtype: a.subtype,
      vertices: a.vertices,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    // coverage:ignore-start
    PdfLinkAnnotation a => PdfLinkAnnotation(
      pageIndex: a.pageIndex,
      uri: a.uri,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfStampAnnotation a => PdfStampAnnotation(
      pageIndex: a.pageIndex,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfUnknownAnnotation a => PdfUnknownAnnotation(
      pageIndex: a.pageIndex,
      rawSubtype: a.rawSubtype,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    // coverage:ignore-end
  };
}

// ---------------------------------------------------------------------------
// Thumbnail
// ---------------------------------------------------------------------------

/// Decodes an FPDF_BITMAP into a [PdfThumbnail] or null on unsupported format.
PdfThumbnail? _readThumbnailBitmap(
  PdfiumModule module,
  int bitmap,
  int pageIndex,
) {
  final width = module.fpdfBitmapGetWidth(bitmap);
  final height = module.fpdfBitmapGetHeight(bitmap);
  final stride = module.fpdfBitmapGetStride(bitmap);
  final format = module.fpdfBitmapGetFormat(bitmap);
  final bufPtr = module.fpdfBitmapGetBuffer(bitmap);

  // format: 2=BGR (3 bytes/px), 3=BGRx (4 bytes/px), 4=BGRA (4 bytes/px).
  final int srcBytesPerPixel;
  switch (format) {
    case 4: // BGRA
      srcBytesPerPixel = 4;
      break;
    case 3: // BGRx — the x byte carries no information; replace with 0xFF.
      srcBytesPerPixel = 4;
      break;
    case 2: // BGR — expand to BGRA by appending 0xFF alpha.
      srcBytesPerPixel = 3;
      break;
    default:
      return null; // coverage:ignore-line
  }

  final bgra = Uint8List(width * height * 4);
  final u8 = module.heapu8.toDart;

  for (var row = 0; row < height; row++) {
    final srcRowBase = bufPtr + row * stride;
    final dstRowBase = row * width * 4;

    for (var col = 0; col < width; col++) {
      final srcOff = srcRowBase + col * srcBytesPerPixel;
      final dstOff = dstRowBase + col * 4;

      bgra[dstOff] = u8[srcOff]; // B
      bgra[dstOff + 1] = u8[srcOff + 1]; // G
      bgra[dstOff + 2] = u8[srcOff + 2]; // R
      bgra[dstOff + 3] = (format == 4) ? u8[srcOff + 3] : 0xFF; // A
    }
  }

  return PdfThumbnail(
    bgra: bgra,
    width: width,
    height: height,
    source: PdfThumbnailSource.embedded,
  );
}

// ---------------------------------------------------------------------------
// Image extraction
// ---------------------------------------------------------------------------

/// Extracts all image objects from a single page.
List<PdfImage> _extractPageImages(
  PdfiumModule module,
  int docPtr,
  int pageIndex,
  bool includeBitmap,
) {
  final pagePtr = module.fpdfLoadPage(docPtr, pageIndex);
  if (pagePtr == 0) return const []; // coverage:ignore-line

  try {
    final objectCount = module.fpdfPageCountObjects(pagePtr);
    final images = <PdfImage>[];

    for (var i = 0; i < objectCount; i++) {
      final objPtr = module.fpdfPageGetObject(pagePtr, i);
      if (objPtr == 0) continue;

      // FPDF_PAGEOBJ_IMAGE = 3.
      if (module.fpdfPageObjGetType(objPtr) != 3) continue;

      // FPDF_IMAGEOBJ_METADATA: 28-byte struct.
      // Offsets: width(0), height(4), hDpi(8), vDpi(12),
      //          bpp(16), colorspace(20), markedContentId(24).
      final metaPtr = module.malloc(28);
      final metaOk =
          module.fpdfImageObjGetImageMetadata(objPtr, pagePtr, metaPtr) != 0;

      if (!metaOk) {
        module.free(metaPtr);
        continue;
      }

      final metadata = PdfImageMetadata(
        width: _readU32(module, metaPtr),
        height: _readU32(module, metaPtr + 4),
        horizontalDpi: _readF32(module, metaPtr + 8),
        verticalDpi: _readF32(module, metaPtr + 12),
        bitsPerPixel: _readU32(module, metaPtr + 16),
        colorspace: _colorspaceFromInt(_readI32(module, metaPtr + 20)),
        markedContentId: _readU32(module, metaPtr + 24),
      );
      module.free(metaPtr);

      final bounds = _readPageObjBounds(module, objPtr);
      final filters = _readImageFilters(module, objPtr);

      PdfImageBitmap? bitmap;
      if (includeBitmap) {
        bitmap = _renderImageBitmap(module, docPtr, pagePtr, objPtr);
      }

      images.add(
        PdfImage(
          pageIndex: pageIndex,
          objectIndex: i,
          metadata: metadata,
          bounds: bounds,
          filters: filters,
          bgra: bitmap?.bgra,
          bitmapWidth: bitmap?.width,
          bitmapHeight: bitmap?.height,
        ),
      );
    }

    return images;
  } finally {
    module.fpdfClosePage(pagePtr);
  }
}

/// Reads the axis-aligned bounding box of a page object.
PdfRect _readPageObjBounds(PdfiumModule module, int objPtr) {
  // 4 × float32: left(0), bottom(4), right(8), top(12).
  final block = module.malloc(16);
  try {
    final ok = module.fpdfPageObjGetBounds(
      objPtr,
      block,
      block + 4,
      block + 8,
      block + 12,
    );
    if (ok == 0) return const PdfRect(left: 0, bottom: 0, right: 0, top: 0);
    return PdfRect(
      left: _readF32(module, block),
      bottom: _readF32(module, block + 4),
      right: _readF32(module, block + 8),
      top: _readF32(module, block + 12),
    );
  } finally {
    module.free(block);
  }
}

/// Reads compression filter names from an image object.
List<String> _readImageFilters(PdfiumModule module, int objPtr) {
  final count = module.fpdfImageObjGetImageFilterCount(objPtr);
  if (count <= 0) return const [];

  final filters = <String>[];
  for (var i = 0; i < count; i++) {
    final reqLen = module.fpdfImageObjGetImageFilter(objPtr, i, 0, 0);
    if (reqLen <= 0) continue;

    final bufPtr = module.malloc(reqLen);
    try {
      module.fpdfImageObjGetImageFilter(objPtr, i, bufPtr, reqLen);
      // ASCII null-terminated; reqLen includes the null terminator.
      final u8 = module.heapu8.toDart;
      final name = String.fromCharCodes(
        u8.sublist(bufPtr, bufPtr + reqLen - 1),
      );
      if (name.isNotEmpty) filters.add(name);
    } finally {
      module.free(bufPtr);
    }
  }
  return filters;
}

/// Renders an image object to a [PdfImageBitmap], or null if unavailable.
PdfImageBitmap? _renderImageBitmap(
  PdfiumModule module,
  int docPtr,
  int pagePtr,
  int objPtr,
) {
  final bitmap = module.fpdfImageObjGetRenderedBitmap(docPtr, pagePtr, objPtr);
  if (bitmap == 0) return null;

  try {
    final width = module.fpdfBitmapGetWidth(bitmap);
    final height = module.fpdfBitmapGetHeight(bitmap);
    final stride = module.fpdfBitmapGetStride(bitmap);

    if (width <= 0 || height <= 0) return null;

    final bufPtr = module.fpdfBitmapGetBuffer(bitmap);
    final byteCount = stride * height;
    final rawBytes = Uint8List.fromList(
      module.heapu8.toDart.sublist(bufPtr, bufPtr + byteCount),
    );
    final bgra = stripBitmapStride(rawBytes, width, height, stride);

    return PdfImageBitmap(bgra: bgra, width: width, height: height);
  } finally {
    module.fpdfBitmapDestroy(bitmap);
  }
}

/// Maps an FPDF_COLORSPACE integer to [PdfColorspace].
PdfColorspace _colorspaceFromInt(int value) => switch (value) {
  0 => PdfColorspace.unknown,
  1 => PdfColorspace.deviceGray,
  2 => PdfColorspace.deviceRgb,
  // coverage:ignore-start
  3 => PdfColorspace.deviceCmyk,
  4 => PdfColorspace.calGray,
  5 => PdfColorspace.calRgb,
  6 => PdfColorspace.lab,
  7 => PdfColorspace.iccBased,
  8 => PdfColorspace.separation,
  9 => PdfColorspace.deviceN,
  10 => PdfColorspace.indexed,
  11 => PdfColorspace.pattern,
  _ => PdfColorspace.unknown,
  // coverage:ignore-end
};

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

/// Searches for [query] on a single page and returns all matches.
List<PdfSearchMatch> _searchPage(
  PdfiumModule module,
  int docPtr,
  int pageIndex,
  String query,
  int flagsMask,
) {
  final pagePtr = module.fpdfLoadPage(docPtr, pageIndex);
  if (pagePtr == 0) return const []; // coverage:ignore-line

  try {
    final textPagePtr = module.fpdfTextLoadPage(pagePtr);
    if (textPagePtr == 0) return const []; // coverage:ignore-line

    try {
      // Allocate null-terminated UTF-16LE query string in WASM heap.
      // Each code unit is 2 bytes; add 2 bytes for the null terminator.
      final codeUnits = query.codeUnits;
      final queryBytes = module.malloc((codeUnits.length + 1) * 2);
      try {
        final u8 = module.heapu8.toDart;
        for (var i = 0; i < codeUnits.length; i++) {
          u8[queryBytes + i * 2] = codeUnits[i] & 0xFF;
          u8[queryBytes + i * 2 + 1] = (codeUnits[i] >> 8) & 0xFF;
        }
        u8[queryBytes + codeUnits.length * 2] = 0;
        u8[queryBytes + codeUnits.length * 2 + 1] = 0;

        final findHandle = module.fpdfTextFindStart(
          textPagePtr,
          queryBytes,
          flagsMask,
          0,
        );
        if (findHandle == 0) return const []; // coverage:ignore-line

        final matches = <PdfSearchMatch>[];
        try {
          while (module.fpdfTextFindNext(findHandle) != 0) {
            final charIndex = module.fpdfTextGetSchResultIndex(findHandle);
            final charCount = module.fpdfTextGetSchCount(findHandle);

            final rectCount = module.fpdfTextCountRects(
              textPagePtr,
              charIndex,
              charCount,
            );

            final rects = <PdfRect>[];
            // FPDFText_GetRect writes 4 × double (8 bytes each).
            final rectBuf = module.malloc(32);
            try {
              for (var r = 0; r < rectCount; r++) {
                module.fpdfTextGetRect(
                  textPagePtr,
                  r,
                  rectBuf,
                  rectBuf + 8,
                  rectBuf + 16,
                  rectBuf + 24,
                );
                rects.add(
                  PdfRect(
                    left: _readF64(module, rectBuf),
                    top: _readF64(module, rectBuf + 8),
                    right: _readF64(module, rectBuf + 16),
                    bottom: _readF64(module, rectBuf + 24),
                  ),
                );
              }
            } finally {
              module.free(rectBuf);
            }

            matches.add(
              PdfSearchMatch(
                pageIndex: pageIndex,
                charIndex: charIndex,
                charCount: charCount,
                rects: rects,
              ),
            );
          }
        } finally {
          module.fpdfTextFindClose(findHandle);
        }

        return matches;
      } finally {
        module.free(queryBytes);
      }
    } finally {
      module.fpdfTextClosePage(textPagePtr);
    }
  } finally {
    module.fpdfClosePage(pagePtr);
  }
}

// ---------------------------------------------------------------------------
// Table of contents (bookmarks)
// ---------------------------------------------------------------------------

/// Recursively walks the bookmark tree from [parentBookmark] (0 = root).
List<PdfTocEntry> _walkBookmarkTree(
  PdfiumModule module,
  int docPtr,
  int parentBookmark,
  Set<int> visited,
) {
  final entries = <PdfTocEntry>[];

  var bookmark = module.fpdfBookmarkGetFirstChild(docPtr, parentBookmark);

  while (bookmark != 0) {
    if (visited.contains(bookmark)) break; // cycle detection
    visited.add(bookmark);

    final title = _readBookmarkTitle(module, bookmark);
    final (:pageIndex, :uri, :scrollPosition) = _resolveBookmarkDestination(
      module,
      docPtr,
      bookmark,
    );

    final children = _walkBookmarkTree(module, docPtr, bookmark, visited);

    entries.add(
      PdfTocEntry(
        title: title,
        pageIndex: pageIndex,
        uri: uri,
        scrollPosition: scrollPosition,
        children: children,
      ),
    );

    bookmark = module.fpdfBookmarkGetNextSibling(docPtr, bookmark);
  }

  return entries;
}

/// Decodes the title of a bookmark as a UTF-16LE string.
String _readBookmarkTitle(PdfiumModule module, int bookmark) {
  final reqLen = module.fpdfBookmarkGetTitle(bookmark, 0, 0);
  if (reqLen <= 2) return ''; // absent or empty

  final bufPtr = module.malloc(reqLen);
  try {
    module.fpdfBookmarkGetTitle(bookmark, bufPtr, reqLen);
    // Decode reqLen - 2 bytes (exclude null terminator pair).
    return _readUtf16Le(module, bufPtr, reqLen - 2);
  } finally {
    module.free(bufPtr);
  }
}

/// Resolves a bookmark to a page index, URI, or null.
({int? pageIndex, String? uri, PdfPoint? scrollPosition})
_resolveBookmarkDestination(PdfiumModule module, int docPtr, int bookmark) {
  final action = module.fpdfBookmarkGetAction(bookmark);
  if (action != 0) {
    final actionType = module.fpdfActionGetType(action);

    if (actionType == 1) {
      // PDFACTION_GOTO
      final dest = module.fpdfActionGetDest(docPtr, action);
      if (dest != 0) {
        final pageIndex = _resolveDestPageIndex(module, docPtr, dest);
        final scrollPosition = _resolveXyzScrollPosition(module, dest);
        return (
          pageIndex: pageIndex,
          uri: null,
          scrollPosition: scrollPosition,
        );
      }
      return (pageIndex: null, uri: null, scrollPosition: null);
    }

    if (actionType == 3) {
      // PDFACTION_URI
      // coverage:ignore-start
      final uri = _readActionUri(module, docPtr, action);
      return (pageIndex: null, uri: uri, scrollPosition: null);
      // coverage:ignore-end
    }

    return (pageIndex: null, uri: null, scrollPosition: null);
  }

  final dest = module.fpdfBookmarkGetDest(docPtr, bookmark);
  if (dest != 0) {
    final pageIndex = _resolveDestPageIndex(module, docPtr, dest);
    final scrollPosition = _resolveXyzScrollPosition(module, dest);
    return (pageIndex: pageIndex, uri: null, scrollPosition: scrollPosition);
  }

  return (pageIndex: null, uri: null, scrollPosition: null);
}

/// Extracts the page index from a dest handle, or null if invalid.
int? _resolveDestPageIndex(PdfiumModule module, int docPtr, int dest) {
  final idx = module.fpdfDestGetDestPageIndex(docPtr, dest);
  return idx < 0 ? null : idx;
}

/// Extracts the XYZ scroll position from a dest handle, or null.
// coverage:ignore-start
// Requires a PDF with XYZ-type bookmark destinations — not in the test suite.
PdfPoint? _resolveXyzScrollPosition(PdfiumModule module, int dest) {
  // Allocate 6 × 4 bytes: 3 int32 (hasX, hasY, hasZoom) + 3 float32 (x,y,z).
  final block = module.malloc(24);
  final hasXPtr = block;
  final hasYPtr = block + 4;
  final hasZoomPtr = block + 8;
  final xPtr = block + 12;
  final yPtr = block + 16;
  final zoomPtr = block + 20;
  try {
    final ok = module.fpdfDestGetLocationInPage(
      dest,
      hasXPtr,
      hasYPtr,
      hasZoomPtr,
      xPtr,
      yPtr,
      zoomPtr,
    );
    if (ok == 0) return null;

    final hasX = _readI32(module, hasXPtr) != 0;
    final hasY = _readI32(module, hasYPtr) != 0;
    if (!hasX && !hasY) return null;

    return PdfPoint(
      x: hasX ? _readF32(module, xPtr).toDouble() : 0.0,
      y: hasY ? _readF32(module, yPtr).toDouble() : 0.0,
    );
  } finally {
    module.free(block);
  }
}

// coverage:ignore-end
