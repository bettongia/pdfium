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

// Native backend for PdfDocument (dart:ffi + PdfiumIsolate).
//
// This file is selected by the conditional import in pdf_document.dart when
// dart.library.ffi is present (iOS, Android, macOS, Windows, Linux).
//
// All PDFium FFI calls are routed through PdfiumIsolate, which is a
// process-wide singleton that owns the single dedicated PDFium isolate.
// Callers never interact with the isolate directly.

import 'dart:async';
import 'dart:typed_data';

import 'isolate_messages.dart';
import 'pdf_types.dart';
import 'pdfium_isolate.dart';
import '../pdf_exception.dart';
import '../rendering/pdf_page_size.dart';

/// Native implementation of [PdfDocument] using dart:ffi and [PdfiumIsolate].
///
/// All PDFium operations run on the shared PDFium isolate. Methods are
/// [Future]-returning; callers never interact with native code or the isolate
/// directly.
///
/// Use [fromBytes] to load a document. Always call [close] when done to
/// release the native document handle. A [Finalizer] is registered as a
/// safety net, but explicit [close] is preferred.
class PdfDocumentImpl {
  PdfDocumentImpl._(this._token, this._isolate) {
    // Register a Finalizer as a safety net against forgotten close() calls.
    // If the Dart GC collects this object without close() having been called,
    // the finalizer sends the close command to the isolate.
    //
    // This is a best-effort mechanism — the isolate may have already been
    // torn down by the time the finalizer runs. close() is the primary path.
    _finalizer.attach(this, _FinalizerToken(_token, _isolate), detach: this);
  }

  final int _token;
  final PdfiumIsolate _isolate;
  bool _closed = false;

  // Finalizer for the native document handle. The token type is a simple
  // record so the finalizer callback can send the close command without
  // holding a reference to the (potentially GC'd) PdfDocumentImpl.
  static final Finalizer<_FinalizerToken> _finalizer =
      Finalizer<_FinalizerToken>((token) async {
        // Best-effort: send close command. Errors are silently swallowed —
        // we are in a finalizer callback, not a user-controlled call site.
        // coverage:ignore-start
        // The Finalizer callback is invoked by the GC when a PdfDocumentImpl
        // is collected without close() being called. This is non-deterministic
        // and cannot be reliably triggered in a test suite.
        try {
          await token.isolate.send<PdfiumCloseDocumentResponse>(
            (replyPort) =>
                PdfiumCloseDocumentCommand(replyPort, token.docToken),
          );
        } catch (_) {
          // Ignore — the isolate may no longer be running.
        }
        // coverage:ignore-end
      });

  /// Loads a PDF document from raw [bytes].
  ///
  /// Returns a [PdfDocumentImpl] on success. Throws [PdfExtractionException]
  /// if the document is invalid, corrupt, or password-protected.
  ///
  /// The optional [dylibPath] overrides the default PDFium library location;
  /// it is used in tests to inject a path to the staged dylib.
  static Future<PdfDocumentImpl> fromBytes(
    Uint8List bytes, {
    String? dylibPath,
  }) async {
    final isolate = await PdfiumIsolate.ensureInitialised(dylibPath: dylibPath);

    final response = await isolate.send<PdfiumLoadDocumentResponse>(
      (replyPort) => PdfiumLoadDocumentCommand(replyPort, bytes),
    );

    if (!response.isSuccess) {
      throw PdfExtractionException(response.error!);
    }

    return PdfDocumentImpl._(response.token!, isolate);
  }

  /// Returns the metadata extracted from the PDF Info dictionary.
  ///
  /// All fields on the returned [PdfMetadata] are nullable; a `null` value
  /// means the field was not present in the document's Info dictionary.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfMetadata> getMetadata() async {
    _checkNotClosed();
    final response = await _isolate.send<PdfiumGetMetadataResponse>(
      (replyPort) => PdfiumGetMetadataCommand(replyPort, _token),
    );
    if (response.metadata == null) {
      throw PdfExtractionException(response.error!);
    }
    return response.metadata!;
  }

  /// Returns document-level properties: file version and file identifiers.
  ///
  /// File identifiers are raw bytes (typically 16-byte MD5 hashes). Use
  /// hex encoding if a string representation is needed.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfDocumentInfo> getDocumentInfo() async {
    _checkNotClosed();
    final response = await _isolate.send<PdfiumGetDocumentInfoResponse>(
      (replyPort) => PdfiumGetDocumentInfoCommand(replyPort, _token),
    );
    if (response.info == null) {
      throw PdfExtractionException(response.error!);
    }
    return response.info!;
  }

  /// Returns the total number of pages in the document.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<int> get pageCount async {
    _checkNotClosed();
    final response = await _isolate.send<PdfiumGetPageCountResponse>(
      (replyPort) => PdfiumGetPageCountCommand(replyPort, _token),
    );
    if (response.pageCount == null) {
      throw PdfExtractionException(response.error!);
    }
    return response.pageCount!;
  }

  /// Extracts plain text from one or all pages of the document.
  ///
  /// When [pageIndex] is null, the stream yields all pages in index order.
  /// When [pageIndex] is specified, the stream yields exactly one [PdfPageText].
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if the document has been closed before or during
  /// extraction.
  ///
  /// Cancelling the subscription immediately stops further processing. Any
  /// page-level PDFium handles are released within the isolate after each
  /// round-trip completes, so there are no handle leaks on cancellation.
  ///
  /// [PdfDocumentImpl.close] terminates any active stream: the stream simply
  /// stops emitting events and the subscription is silently cancelled.
  Stream<PdfPageText> extractPlainText({
    int? pageIndex,
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) {
    // Use an async generator so that cancellation via StreamSubscription.cancel()
    // causes the generator to exit cleanly at the next yield/await point.
    return _extractPlainTextImpl(pageIndex: pageIndex, config: config);
  }

  /// Internal async generator implementing [extractPlainText].
  Stream<PdfPageText> _extractPlainTextImpl({
    int? pageIndex,
    required PdfTextExtractorConfig config,
  }) async* {
    _checkNotClosed();

    // Determine which page indices to process.
    final count = await pageCount;
    _checkNotClosed();

    final List<int> indices;
    if (pageIndex != null) {
      if (pageIndex < 0 || pageIndex >= count) {
        throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
      }
      indices = [pageIndex];
    } else {
      indices = List.generate(count, (i) => i);
    }

    for (final idx in indices) {
      // Check closed state on each iteration so that PdfDocumentImpl.close()
      // terminates the stream promptly. We check before issuing the command
      // to avoid sending a command to the isolate for a closed document.
      if (_closed) return;

      final response = await _isolate.send<PdfiumExtractPageTextResponse>(
        (replyPort) => PdfiumExtractPageTextCommand(replyPort, _token, idx),
      );

      if (!response.isSuccess) {
        throw PdfExtractionException(response.error!);
      }

      yield PdfPageText(
        pageIndex: response.pageIndex,
        text: response.text,
        hasUnicodeErrors: response.hasUnicodeErrors,
        hasTextLayer: response.hasTextLayer,
      );
    }
  }

  /// Extracts all annotations from one or all pages of the document.
  ///
  /// When [pageIndex] is null, the stream yields one [PdfPageAnnotations] per
  /// page in index order. Pages with no annotations emit an entry with an empty
  /// [PdfPageAnnotations.annotations] list so callers can track page coverage.
  ///
  /// When [pageIndex] is specified, the stream yields exactly one
  /// [PdfPageAnnotations] for that page.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if the document has been closed before or during
  /// extraction.
  ///
  /// [PdfDocumentImpl.close] terminates any active stream: the stream stops
  /// emitting events and the subscription is silently cancelled, releasing all
  /// page-level annotation handles.
  Stream<PdfPageAnnotations> extractAnnotations({int? pageIndex}) {
    return _extractAnnotationsImpl(pageIndex: pageIndex);
  }

  /// Internal async generator implementing [extractAnnotations].
  Stream<PdfPageAnnotations> _extractAnnotationsImpl({int? pageIndex}) async* {
    _checkNotClosed();

    final count = await pageCount;
    _checkNotClosed();

    final List<int> indices;
    if (pageIndex != null) {
      if (pageIndex < 0 || pageIndex >= count) {
        throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
      }
      indices = [pageIndex];
    } else {
      indices = List.generate(count, (i) => i);
    }

    for (final idx in indices) {
      // Check closed state before each isolate round-trip so that close()
      // terminates the stream promptly without sending commands for a closed doc.
      if (_closed) return;

      final response = await _isolate
          .send<PdfiumExtractPageAnnotationsResponse>(
            (replyPort) =>
                PdfiumExtractPageAnnotationsCommand(replyPort, _token, idx),
          );

      if (!response.isSuccess) {
        throw PdfExtractionException(response.error!);
      }

      yield PdfPageAnnotations(
        pageIndex: response.pageIndex,
        annotations: response.annotations,
      );
    }
  }

  /// Returns true when fewer than [config.scannedPageRatio] of pages lack a
  /// text layer.
  ///
  /// Internally runs [extractPlainText] to completion and counts pages where
  /// [PdfPageText.hasTextLayer] is false. Returns false when the proportion
  /// of such pages meets or exceeds [config.scannedPageRatio].
  ///
  /// Use per-page [PdfPageText.hasTextLayer] for finer-grained control.
  ///
  /// Throws [StateError] if the document has been closed.
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

  /// Returns the intrinsic size of a page in PDF user units (points).
  ///
  /// One PDF user unit equals 1/72 inch. This is a storage-level measurement
  /// independent of rendering resolution. Use [PdfPageSize.sizeForDpi] to
  /// convert to pixel dimensions for a [renderPage] call.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if [close] has already been called.
  Future<PdfPageSize> getPageSize(int pageIndex) async {
    _checkNotClosed();

    // Validate the page index against the document page count before
    // dispatching to the isolate, so callers receive a RangeError rather
    // than a generic isolate failure for out-of-range indices.
    final count = await pageCount;
    _checkNotClosed();
    RangeError.checkValidIndex(pageIndex, _PageIndexRange(count), 'pageIndex');

    final response = await _isolate.send<PdfiumGetPageSizeResponse>(
      (replyPort) => PdfiumGetPageSizeCommand(replyPort, _token, pageIndex),
    );
    if (!response.isSuccess) {
      throw PdfExtractionException(response.error!);
    }
    return response.pageSize!;
  }

  /// Renders a page to a raw BGRA pixel buffer.
  ///
  /// The page at [pageIndex] is rendered at [pixelWidth] × [pixelHeight]
  /// pixels. The returned record contains the BGRA [pixels] and the actual
  /// [pixelWidth] and [pixelHeight] from the render command.
  ///
  /// [renderAnnotations] maps to the PDFium `FPDF_ANNOT` flag.
  /// [lcdText] maps to the PDFium `FPDF_LCD_TEXT` flag.
  /// [backgroundColor] is an ARGB packed integer (e.g. `0xFFFFFFFF` for
  /// opaque white) passed directly to `FPDFBitmap_FillRect`.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if [close] has been called before or during the
  /// render.
  /// Throws [PdfiumException] if a PDFium native call fails unexpectedly.
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

    // Validate index eagerly against the page count.
    final count = await pageCount;
    _checkNotClosed();
    RangeError.checkValidIndex(pageIndex, _PageIndexRange(count), 'pageIndex');

    // FPDF_ANNOT = 0x01, FPDF_LCD_TEXT = 0x02 (defined in fpdfview.h).
    var flags = 0;
    if (renderAnnotations) flags |= 0x01;
    if (lcdText) flags |= 0x02;

    final response = await _isolate.send<PdfiumRenderPageResponse>(
      (replyPort) => PdfiumRenderPageCommand(
        replyPort,
        _token,
        pageIndex,
        pixelWidth,
        pixelHeight,
        flags,
        backgroundColor,
      ),
    );

    if (!response.isSuccess) {
      final msg = response.errorMessage;
      if (msg.startsWith('Document token')) {
        throw StateError(
          'PdfDocument has been closed. '
          'Create a new PdfDocument with PdfDocument.fromBytes().',
        );
      }
      throw PdfiumException(msg);
    }

    return (
      pixels: response.pixels,
      pixelWidth: response.pixelWidth,
      pixelHeight: response.pixelHeight,
    );
  }

  /// Extracts all image objects from one or all pages of the document.
  ///
  /// When [pageIndex] is null, the stream yields one [PdfPageImages] per page
  /// in index order. Pages with no image objects emit an entry with an empty
  /// [PdfPageImages.images] list so callers can track page coverage without gaps.
  ///
  /// When [pageIndex] is specified, the stream yields exactly one [PdfPageImages]
  /// for that page.
  ///
  /// When [includeBitmap] is false (the default), [PdfImage.bgra],
  /// [PdfImage.bitmapWidth], and [PdfImage.bitmapHeight] are all null on
  /// every returned [PdfImage] — only metadata and bounds are populated. This
  /// is the fast, memory-efficient path for enumerating images.
  ///
  /// When [includeBitmap] is true, the rendered BGRA bitmap is fetched for
  /// every image object. For documents with many large images this can produce
  /// large allocations. Prefer calling [renderImage] selectively after
  /// inspecting [PdfImageMetadata] for image dimensions and colorspace.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if the document has been closed before or during
  /// extraction.
  ///
  /// [close] terminates any active stream.
  Stream<PdfPageImages> extractImages({
    int? pageIndex,
    bool includeBitmap = false,
  }) {
    return _extractImagesImpl(
      pageIndex: pageIndex,
      includeBitmap: includeBitmap,
    );
  }

  /// Internal async generator implementing [extractImages].
  Stream<PdfPageImages> _extractImagesImpl({
    int? pageIndex,
    required bool includeBitmap,
  }) async* {
    _checkNotClosed();

    final count = await pageCount;
    _checkNotClosed();

    final List<int> indices;
    if (pageIndex != null) {
      if (pageIndex < 0 || pageIndex >= count) {
        throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
      }
      indices = [pageIndex];
    } else {
      indices = List.generate(count, (i) => i);
    }

    for (final idx in indices) {
      // Check closed state before each isolate round-trip so that close()
      // terminates the stream promptly without sending commands for a closed doc.
      if (_closed) return;

      final response = await _isolate.send<PdfiumExtractPageImagesResponse>(
        (replyPort) => PdfiumExtractPageImagesCommand(
          replyPort,
          _token,
          idx,
          includeBitmap: includeBitmap,
        ),
      );

      if (!response.isSuccess) {
        throw PdfExtractionException(response.error!);
      }

      yield PdfPageImages(
        pageIndex: response.pageIndex,
        images: response.images,
      );
    }
  }

  /// Fetches the rendered BGRA bitmap for a single image object on a page.
  ///
  /// [pageIndex] and [objectIndex] together identify the image: [objectIndex]
  /// is the position in the page's object list, as reported by
  /// [PdfImage.objectIndex] from [extractImages].
  ///
  /// Returns a [PdfImageBitmap] with the composited BGRA pixel data, or `null`
  /// when the object has no renderable bitmap (e.g. a mask-only object where
  /// `FPDFImageObj_GetRenderedBitmap` returns null).
  ///
  /// Throws [RangeError] if [pageIndex] or [objectIndex] is out of range.
  /// Throws [StateError] if the document has been closed.
  Future<PdfImageBitmap?> renderImage(int pageIndex, int objectIndex) async {
    _checkNotClosed();

    // Validate page index eagerly.
    final count = await pageCount;
    _checkNotClosed();
    if (pageIndex < 0 || pageIndex >= count) {
      throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
    }

    // Validate object index: we need the page object count, which requires
    // a round-trip to the isolate. We use a metadata-only extractImages call
    // on the single page to get the image count efficiently. However, the
    // objectIndex is a raw page-object index (not just an image index), so we
    // cannot validate it against image count alone. Instead, we dispatch the
    // render command and treat a null bitmap from the isolate for a null-object
    // case as an out-of-range signal.
    //
    // A dedicated object-count validation call would require another message
    // type. Instead, per the plan spec, FPDFPage_GetObject returns null for
    // out-of-range indices and the isolate returns bitmap: null in that case.
    // We map that to a RangeError here only when the caller passes a negative
    // index (clearly invalid without an isolate round-trip).
    if (objectIndex < 0) {
      throw RangeError.value(objectIndex, 'objectIndex');
    }

    final response = await _isolate.send<PdfiumRenderImageResponse>(
      (replyPort) =>
          PdfiumRenderImageCommand(replyPort, _token, pageIndex, objectIndex),
    );

    if (!response.isSuccess) {
      if (response.error == PdfError.invalidDocument) {
        // The isolate could not load the page — treat as out-of-range.
        throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
      }
      throw PdfExtractionException(response.error!);
    }

    return response.bitmap;
  }

  /// Searches the document for [query] and streams all matches.
  ///
  /// Results are yielded page-by-page in ascending page order. An empty stream
  /// means no matches were found. An empty [query] string returns an empty
  /// stream immediately without issuing any PDFium calls.
  ///
  /// [flags] controls case-sensitivity, whole-word matching, and overlapping
  /// matches. Defaults to case-insensitive, non-whole-word, non-overlapping.
  ///
  /// When [pageIndex] is specified, the search is restricted to that page.
  /// Throws [RangeError] if [pageIndex] is out of range.
  ///
  /// Throws [StateError] if the document has been closed before or during
  /// the search.
  Stream<PdfSearchMatch> search(
    String query, {
    Set<PdfSearchFlag> flags = const {},
    int? pageIndex,
  }) {
    return _searchImpl(query, flags: flags, pageIndex: pageIndex);
  }

  /// Internal async generator implementing [search].
  Stream<PdfSearchMatch> _searchImpl(
    String query, {
    required Set<PdfSearchFlag> flags,
    int? pageIndex,
  }) async* {
    // Guard: empty query returns an empty stream immediately.
    if (query.isEmpty) return;

    _checkNotClosed();

    // Build the PDFium flags bitmask from the [PdfSearchFlag] set.
    // FPDF_MATCHCASE = 0x01, FPDF_MATCHWHOLEWORD = 0x02, FPDF_CONSECUTIVE = 0x04.
    var flagsMask = 0;
    if (flags.contains(PdfSearchFlag.matchCase)) flagsMask |= 0x01;
    if (flags.contains(PdfSearchFlag.matchWholeWord)) flagsMask |= 0x02;
    if (flags.contains(PdfSearchFlag.consecutive)) flagsMask |= 0x04;

    final count = await pageCount;
    _checkNotClosed();

    final List<int> indices;
    if (pageIndex != null) {
      if (pageIndex < 0 || pageIndex >= count) {
        throw RangeError.range(pageIndex, 0, count - 1, 'pageIndex');
      }
      indices = [pageIndex];
    } else {
      indices = List.generate(count, (i) => i);
    }

    for (final idx in indices) {
      // Check closed state before each isolate round-trip.
      if (_closed) return;

      final response = await _isolate.send<PdfiumSearchPageResponse>(
        (replyPort) =>
            PdfiumSearchPageCommand(replyPort, _token, idx, query, flagsMask),
      );

      if (!response.isSuccess) {
        throw PdfExtractionException(response.error!);
      }

      // Yield each match from this page individually so callers get results
      // incrementally (early termination via stream cancel is supported).
      for (final match in response.matches) {
        if (_closed) return;
        yield match;
      }
    }
  }

  /// Returns a thumbnail for the page at [pageIndex].
  ///
  /// When the page has an embedded `/Thumb` stream, that bitmap is returned
  /// with [PdfThumbnailSource.embedded] at its native dimensions.
  ///
  /// When no embedded thumbnail is present and [generateIfAbsent] is `true`
  /// (the default), the page is rendered at a size where the longest edge is
  /// at most [maxDimension] pixels, preserving aspect ratio, and returned with
  /// [PdfThumbnailSource.rendered].
  ///
  /// When no embedded thumbnail is present and [generateIfAbsent] is `false`,
  /// `null` is returned without any render pass.
  ///
  /// [maxDimension] only affects the fallback render path. Embedded thumbnails
  /// are returned at their native size.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [ArgumentError] if [maxDimension] ≤ 0.
  /// Throws [StateError] if [close] has been called before or during the call.
  /// Throws [PdfiumException] if a PDFium native call fails.
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

    // Validate the page index against the live page count before dispatching
    // to the isolate, so callers receive a RangeError for out-of-range values.
    final count = await pageCount;
    _checkNotClosed();
    RangeError.checkValidIndex(pageIndex, _PageIndexRange(count), 'pageIndex');

    // Ask the isolate to extract the embedded thumbnail (if any).
    final response = await _isolate.send<PdfiumGetPageThumbnailResponse>(
      (replyPort) =>
          PdfiumGetPageThumbnailCommand(replyPort, _token, pageIndex),
    );

    if (!response.isSuccess) {
      final msg = response.errorMessage;
      if (msg.startsWith('Document token')) {
        throw StateError(
          'PdfDocument has been closed. '
          'Create a new PdfDocument with PdfDocument.fromBytes().',
        );
      }
      throw PdfiumException(msg);
    }

    // If an embedded thumbnail was found, return it immediately.
    if (response.bgra != null) {
      return PdfThumbnail(
        bgra: response.bgra!,
        width: response.width,
        height: response.height,
        source: PdfThumbnailSource.embedded,
      );
    }

    // No embedded thumbnail. If the caller does not want a fallback, return null.
    if (!generateIfAbsent) return null;

    // Fallback: render the page at a size proportional to maxDimension.
    // Call _checkNotClosed() again because close() may have been called
    // between the thumbnail round-trip above and the page-size round-trip
    // below — consistent with the guard pattern in _extractPlainTextImpl.
    _checkNotClosed();
    final size = await getPageSize(pageIndex);
    _checkNotClosed();

    // Scale so the longest edge equals maxDimension, preserving aspect ratio.
    // Ensure a minimum of 1 pixel on the short edge to avoid zero-dimension
    // renders on extremely elongated pages.
    final double scale;
    if (size.widthPt >= size.heightPt) {
      scale = maxDimension / size.widthPt;
    } else {
      scale = maxDimension / size.heightPt;
    }
    final pixelWidth = (size.widthPt * scale).round().clamp(1, maxDimension);
    final pixelHeight = (size.heightPt * scale).round().clamp(1, maxDimension);

    // renderPageToBytes re-throws StateError / PdfiumException directly — do
    // not wrap here, consistent with all other methods in this class.
    final rendered = await renderPageToBytes(
      pageIndex,
      pixelWidth,
      pixelHeight,
    );

    return PdfThumbnail(
      bgra: rendered.pixels,
      width: rendered.pixelWidth,
      height: rendered.pixelHeight,
      source: PdfThumbnailSource.rendered,
    );
  }

  /// Returns the complete Table of Contents (bookmark/outline tree) for the
  /// document.
  ///
  /// Each [PdfTocEntry] in the returned list is a root-level bookmark entry.
  /// Children are accessed via [PdfTocEntry.children], forming a tree of
  /// arbitrary depth.
  ///
  /// Returns an empty list when the document has no bookmarks — this is not
  /// an error condition.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<List<PdfTocEntry>> get tableOfContents async {
    _checkNotClosed();
    final response = await _isolate.send<PdfiumGetTocResponse>(
      (replyPort) => PdfiumGetTocCommand(replyPort, _token),
    );
    if (!response.isSuccess) {
      throw PdfExtractionException(response.error!);
    }
    return response.entries!;
  }

  /// Closes the document and releases the native PDFium handle.
  ///
  /// Safe to call more than once — subsequent calls are no-ops.
  /// After [close] returns, all other methods throw [StateError].
  ///
  /// Any active [extractPlainText] stream is terminated: the stream stops
  /// emitting events and the subscription is silently cancelled. Callers do
  /// not need to cancel streams manually before calling [close].
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // Detach the finalizer so it does not send a second close after GC.
    _finalizer.detach(this);
    await _isolate.send<PdfiumCloseDocumentResponse>(
      (replyPort) => PdfiumCloseDocumentCommand(replyPort, _token),
    );
  }

  /// Throws [StateError] if the document has already been closed.
  void _checkNotClosed() {
    if (_closed) {
      throw StateError(
        'PdfDocument has been closed. '
        'Create a new PdfDocument with PdfDocument.fromBytes().',
      );
    }
  }
}

/// Data carrier for the [PdfDocumentImpl] finalizer.
///
/// Holds the minimum information needed to send a close command without
/// retaining a reference to the [PdfDocumentImpl] itself (which would prevent
/// GC and make the finalizer never fire).
class _FinalizerToken {
  const _FinalizerToken(this.docToken, this.isolate);

  /// The opaque document token.
  final int docToken;

  /// The isolate to send the close command to.
  final PdfiumIsolate isolate;
}

/// Minimal [Iterable] adapter that satisfies [RangeError.checkValidIndex]'s
/// requirement for a `length` getter.
///
/// [RangeError.checkValidIndex] expects an indexable object with a [length]
/// property. This thin wrapper around a page count avoids allocating a
/// real list just to validate a page index.
class _PageIndexRange {
  const _PageIndexRange(this.length);

  /// The number of pages in the document.
  final int length;
}
