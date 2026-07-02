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
//
// Structural note (Phase 1 of the Web Worker offload plan):
//   All PDFium call/marshalling logic previously inlined in this file's
//   instance methods has been extracted to `_pdfium_wasm_engine.dart` as
//   worker-reusable, module-parameterised functions. The instance methods
//   below are now thin callers of that engine — this file owns only the
//   static module/registry singleton, the public PdfDocumentImpl API shape,
//   and Finalizer-based cleanup. This split is what lets the engine module be
//   called identically from a future Worker (Phase 2/3) and from direct,
//   coverage-preserving tests (Phase 4) that bypass the Worker entirely.

import 'dart:async';
import 'dart:typed_data';

import '../rendering/pdf_page_size.dart';
import '_pdfium_js_interop.dart';
import '_pdfium_wasm_engine.dart';
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
        engineCloseDocument(m, rec.docPtr, rec.bufPtr);
      });
  // coverage:ignore-end

  // ---------------------------------------------------------------------------
  // Module loading
  // ---------------------------------------------------------------------------

  static Future<PdfiumModule> _getModule() async {
    return _module ??= await loadPdfiumModule();
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
    final rec = engineLoadDocument(module, bytes);

    final token = _nextToken++;
    _registry[token] = rec;

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
    engineCloseDocument(_module!, rec.docPtr, rec.bufPtr);
  }

  /// Returns the total number of pages in this document.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<int> get pageCount async {
    _checkNotClosed();
    final rec = _registry[_token]!;
    return enginePageCount(_module!, rec.docPtr);
  }

  // ---------------------------------------------------------------------------
  // Metadata, document info, page size, text extractability
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
    return engineGetMetadata(_module!, _registry[_token]!.docPtr);
  }

  /// Returns file-level information for this document.
  ///
  /// Retrieves the PDF file version (e.g. 17 for PDF 1.7) and the permanent
  /// and changing file identifiers. Fields are null when not present.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfDocumentInfo> getDocumentInfo() async {
    _checkNotClosed();
    return engineGetDocumentInfo(_module!, _registry[_token]!.docPtr);
  }

  /// Returns the intrinsic size of [pageIndex] in PDF points (1 pt = 1/72 in).
  ///
  /// Throws [StateError] if [close] has already been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Future<PdfPageSize> getPageSize(int pageIndex) async {
    _checkNotClosed();
    return engineGetPageSize(_module!, _registry[_token]!.docPtr, pageIndex);
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
  // Text extraction and annotation extraction
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

    final indices = engineResolvePageIndices(module, docPtr, pageIndex);

    for (final idx in indices) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;

      yield engineExtractPageText(module, docPtr, idx);
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

    final indices = engineResolvePageIndices(module, docPtr, pageIndex);

    for (final idx in indices) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;

      yield PdfPageAnnotations(
        pageIndex: idx,
        annotations: engineExtractPageAnnotations(module, docPtr, idx),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Rendering and thumbnails
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
    return engineRenderPageToBytes(
      _module!,
      _registry[_token]!.docPtr,
      pageIndex,
      pixelWidth,
      pixelHeight,
      renderAnnotations: renderAnnotations,
      lcdText: lcdText,
      backgroundColor: backgroundColor,
    );
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
    _checkNotClosed();
    return engineGetThumbnail(
      _module!,
      _registry[_token]!.docPtr,
      pageIndex,
      generateIfAbsent: generateIfAbsent,
      maxDimension: maxDimension,
    );
  }

  // ---------------------------------------------------------------------------
  // Images, search, table of contents
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

    final indices = engineResolvePageIndices(module, docPtr, pageIndex);

    for (final idx in indices) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;

      yield PdfPageImages(
        pageIndex: idx,
        images: engineExtractPageImages(module, docPtr, idx, includeBitmap),
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
    return engineRenderImage(
      _module!,
      _registry[_token]!.docPtr,
      pageIndex,
      objectIndex,
    );
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
    final indices = engineResolvePageIndices(module, docPtr, pageIndex);

    for (final idx in indices) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;

      final matches = engineSearchPage(module, docPtr, idx, query, flagsMask);
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
    return engineTableOfContents(_module!, _registry[_token]!.docPtr);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _checkNotClosed() {
    if (_closed) {
      throw StateError('PdfDocument has already been closed.');
    }
  }
}
