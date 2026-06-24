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

/// Public PdfDocument interface with conditional platform import.
///
/// The platform split is entirely hidden behind this file. Callers import only
/// pdf_document.dart and receive the correct backend automatically:
///
///   dart.library.ffi     → _document_native.dart (iOS, Android, macOS, Windows, Linux)
///   dart.library.js_interop → _document_web.dart (web / WASM)
///   (fallback)           → _document_stub.dart   (throws UnsupportedError)
library;

import 'dart:typed_data';

import '_document_stub.dart'
    if (dart.library.ffi) '_document_native.dart'
    if (dart.library.js_interop) '_document_web.dart';

import 'pdf_types.dart';
import '../rendering/pdf_page_size.dart';

export 'pdf_types.dart';
export '../rendering/pdf_page_size.dart';

/// A loaded PDF document.
///
/// [PdfDocument] is the top-level Dart abstraction for a PDF file. It mirrors
/// the PDFium model: [PdfiumBindings.FPDF_LoadMemDocument64] returns a single document handle
/// used for all subsequent operations. [PdfDocument] is the Dart owner of that
/// handle and exposes document-level capabilities as async methods.
///
/// ## Loading
///
/// Use [fromBytes] to load a document from raw PDF bytes:
///
/// ```dart
/// final bytes = await File('document.pdf').readAsBytes();
/// final doc = await PdfDocument.fromBytes(bytes);
/// ```
///
/// ## Error handling
///
/// [fromBytes] throws [PdfExtractionException] when the document cannot be
/// loaded. Inspect [PdfExtractionException.error] to distinguish between
/// [PdfError.passwordRequired] and [PdfError.invalidDocument] so callers
/// can give users an actionable message.
///
/// ## Resource management
///
/// Always call [close] when the document is no longer needed to release the
/// native PDFium handle:
///
/// ```dart
/// final doc = await PdfDocument.fromBytes(bytes);
/// try {
///   final meta = await doc.getMetadata();
///   // use meta…
/// } finally {
///   await doc.close();
/// }
/// ```
///
/// A [Finalizer] is registered internally as a safety net in case [close] is
/// forgotten, but explicit disposal is strongly preferred.
///
/// ## Platform support
///
/// The public API is identical on all platforms. The backend differs:
///
/// | Platform              | Backend                   |
/// | --------------------- | ------------------------- |
/// | iOS, Android, macOS,  | dart:ffi + PdfiumIsolate  |
/// | Windows, Linux        |                           |
/// | Web                   | PDFium WASM (pending)     |
///
/// On native platforms all PDFium calls run on a dedicated [Isolate] so the
/// caller's isolate (typically the UI isolate) is never blocked. On web,
/// PDFium runs synchronously on the main thread in v1 — a Web Worker path is
/// deferred to `plan_layout_aware_reordering.md`.
///
/// ## Future capabilities
///
/// [PdfDocument] is designed to be the foundation for future capabilities:
/// text extraction (`document.openTextExtractor()`), annotation access, and
/// page rendering. This plan establishes the class and its metadata surface;
/// future plans add capabilities without breaking the existing API.
class PdfDocument {
  PdfDocument._(this._impl);

  final PdfDocumentImpl _impl;

  /// Loads a PDF document from raw [bytes].
  ///
  /// Returns a [PdfDocument] on success.
  ///
  /// Throws [PdfExtractionException] with:
  /// - [PdfError.passwordRequired] if the document is password-protected.
  /// - [PdfError.invalidDocument] if the bytes are corrupt or not a valid PDF.
  ///
  /// The optional [dylibPath] overrides the default PDFium dynamic library
  /// location. It is intended for testing only.
  static Future<PdfDocument> fromBytes(
    Uint8List bytes, {
    String? dylibPath,
  }) async {
    final impl = await PdfDocumentImpl.fromBytes(bytes, dylibPath: dylibPath);
    return PdfDocument._(impl);
  }

  /// Returns the metadata extracted from the PDF Info dictionary.
  ///
  /// All fields on [PdfMetadata] are nullable. A `null` field means the
  /// corresponding entry was not present in the document's Info dictionary —
  /// this is distinct from a field that is present but empty.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfMetadata> getMetadata() => _impl.getMetadata();

  /// Returns document-level properties: PDF file version and file identifiers.
  ///
  /// File identifiers ([PdfDocumentInfo.permanentId] and
  /// [PdfDocumentInfo.changingId]) are raw bytes, typically 16-byte MD5
  /// hashes. Hex-encode them if a string representation is needed:
  ///
  /// ```dart
  /// final info = await doc.getDocumentInfo();
  /// final hex = info.permanentId
  ///     ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
  ///     .join();
  /// ```
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfDocumentInfo> getDocumentInfo() => _impl.getDocumentInfo();

  /// The total number of pages in the document.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<int> get pageCount => _impl.pageCount;

  /// Extracts plain text from one or all pages of the document.
  ///
  /// When [pageIndex] is `null`, the stream yields all pages in index order.
  /// When [pageIndex] is specified, the stream yields exactly one [PdfPageText].
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if the document has been closed before or during
  /// extraction.
  ///
  /// Cancelling the stream subscription immediately stops further processing.
  /// Page-level PDFium handles are released after each round-trip, so there
  /// are no handle leaks on cancellation.
  ///
  /// [close] terminates any active stream: the stream stops emitting events
  /// and the subscription is silently cancelled.
  ///
  /// Example — extract all pages and print each one:
  ///
  /// ```dart
  /// await for (final page in doc.extractPlainText()) {
  ///   if (page.hasTextLayer) {
  ///     print('Page ${page.pageIndex}: ${page.text}');
  ///   } else {
  ///     print('Page ${page.pageIndex}: no text layer (scanned page)');
  ///   }
  /// }
  /// ```
  Stream<PdfPageText> extractPlainText({
    int? pageIndex,
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) => _impl.extractPlainText(pageIndex: pageIndex, config: config);

  /// Extracts all annotations from one or all pages of the document.
  ///
  /// When [pageIndex] is `null`, the stream yields one [PdfPageAnnotations] per
  /// page in index order. Pages with no annotations emit an entry with an empty
  /// [PdfPageAnnotations.annotations] list, so callers can track page coverage
  /// without gaps.
  ///
  /// When [pageIndex] is specified, the stream yields exactly one
  /// [PdfPageAnnotations] for that page.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if the document has been closed before or during
  /// extraction.
  ///
  /// [close] terminates any active stream: the stream stops emitting events and
  /// all page-level annotation handles are released. Callers do not need to
  /// cancel streams manually before calling [close].
  ///
  /// **Note:** This method does not accept a page range — only a single optional
  /// page index. Range-based extraction is a known limitation to revisit in a
  /// future plan.
  ///
  /// **Platform support:** Native (dart:ffi) only. Stubs on unsupported
  /// platforms throw [UnsupportedError] immediately.
  ///
  /// Example — collect all highlights from every page:
  ///
  /// ```dart
  /// await for (final page in doc.extractAnnotations()) {
  ///   for (final annot in page.annotations) {
  ///     if (annot case PdfMarkupAnnotation(:final subtype, :final quadPoints)
  ///         when subtype == PdfAnnotationType.highlight) {
  ///       print('Highlight on page ${page.pageIndex}: $quadPoints');
  ///     }
  ///   }
  /// }
  /// ```
  Stream<PdfPageAnnotations> extractAnnotations({int? pageIndex}) =>
      _impl.extractAnnotations(pageIndex: pageIndex);

  /// Returns `true` when fewer than [config.scannedPageRatio] of pages lack a
  /// text layer (i.e. the document is suitable for plain-text extraction).
  ///
  /// Internally runs [extractPlainText] to completion and counts pages where
  /// [PdfPageText.hasTextLayer] is `false`. Returns `false` when the proportion
  /// of such pages meets or exceeds [config.scannedPageRatio].
  ///
  /// Use per-page [PdfPageText.hasTextLayer] for finer-grained control.
  ///
  /// Throws [StateError] if the document has been closed.
  Future<bool> isPlainTextExtractable({
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) => _impl.isPlainTextExtractable(config: config);

  /// Returns the intrinsic size of a page in PDF user units (points).
  ///
  /// One PDF user unit equals 1/72 inch. This is a storage-level measurement
  /// independent of rendering resolution. Use [PdfPageSize.sizeForDpi] to
  /// convert to pixel dimensions for a [renderPageToBytes] call.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if [close] has already been called.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final size = await doc.getPageSize(0);
  /// final px = size.sizeForDpi(150);
  /// final result = await doc.renderPageToBytes(0, px.width.round(), px.height.round());
  /// ```
  Future<PdfPageSize> getPageSize(int pageIndex) =>
      _impl.getPageSize(pageIndex);

  /// Renders a page to a raw BGRA pixel buffer.
  ///
  /// The page at [pageIndex] is rendered at [pixelWidth] × [pixelHeight]
  /// pixels. The returned record exposes [pixels] (BGRA bytes),
  /// [pixelWidth], and [pixelHeight].
  ///
  /// For Flutter apps, decode the returned BGRA bytes into a `dart:ui` [Image]
  /// via `decodeImageFromPixels`.
  ///
  /// [renderAnnotations] maps to the PDFium `FPDF_ANNOT` flag (default true).
  /// [lcdText] maps to `FPDF_LCD_TEXT` (default false).
  /// [backgroundColor] is an ARGB packed integer; default `0xFFFFFFFF`
  /// (opaque white).
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if [close] has been called before or during render.
  /// Throws [PdfiumException] if a PDFium native call fails.
  Future<({Uint8List pixels, int pixelWidth, int pixelHeight})>
  renderPageToBytes(
    int pageIndex,
    int pixelWidth,
    int pixelHeight, {
    bool renderAnnotations = true,
    bool lcdText = false,
    int backgroundColor = 0xFFFFFFFF,
  }) => _impl.renderPageToBytes(
    pageIndex,
    pixelWidth,
    pixelHeight,
    renderAnnotations: renderAnnotations,
    lcdText: lcdText,
    backgroundColor: backgroundColor,
  );

  /// Extracts all image objects from one or all pages of the document.
  ///
  /// When [pageIndex] is `null`, the stream yields one [PdfPageImages] per
  /// page in index order. Pages with no image objects emit an entry with an
  /// empty [PdfPageImages.images] list so callers can track page coverage
  /// without gaps.
  ///
  /// When [pageIndex] is specified, the stream yields exactly one
  /// [PdfPageImages] for that page.
  ///
  /// ## Bitmap mode
  ///
  /// When [includeBitmap] is `false` (the default), [PdfImage.bgra],
  /// [PdfImage.bitmapWidth], and [PdfImage.bitmapHeight] are `null` on every
  /// returned [PdfImage]. Only metadata ([PdfImage.metadata]) and the
  /// bounding box ([PdfImage.bounds]) are populated. This is the cheap,
  /// memory-efficient path for enumerating images.
  ///
  /// When [includeBitmap] is `true`, the rendered BGRA bitmap is fetched for
  /// every image object on each page. For documents with many large photographs
  /// this can produce very large allocations. Prefer calling [renderImage]
  /// selectively after inspecting [PdfImageMetadata] for image dimensions and
  /// colorspace.
  ///
  /// ## Image masks
  ///
  /// Image mask objects (`metadata.bitsPerPixel == 1`) are included in the
  /// output and are not suppressed automatically. Callers can identify them
  /// via `image.metadata.bitsPerPixel == 1`.
  ///
  /// ## Error handling
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if the document has been closed before or during
  /// extraction.
  ///
  /// [close] terminates any active stream: the stream stops emitting events
  /// and the subscription is silently cancelled. Callers do not need to cancel
  /// streams manually before calling [close].
  ///
  /// **Platform support:** Native (dart:ffi) only. Stubs on unsupported
  /// platforms throw [UnsupportedError] immediately.
  ///
  /// Example — collect all JPEG images from a document:
  ///
  /// ```dart
  /// await for (final page in doc.extractImages()) {
  ///   for (final img in page.images) {
  ///     if (img.filters.contains('DCTDecode')) {
  ///       final bitmap = await doc.renderImage(img.pageIndex, img.objectIndex);
  ///       // use bitmap…
  ///     }
  ///   }
  /// }
  /// ```
  Stream<PdfPageImages> extractImages({
    int? pageIndex,
    bool includeBitmap = false,
  }) => _impl.extractImages(pageIndex: pageIndex, includeBitmap: includeBitmap);

  /// Fetches the rendered BGRA bitmap for a single image object on a page.
  ///
  /// [pageIndex] is the zero-based page index. [objectIndex] is the position
  /// of the image object in the page's object list, as reported by
  /// [PdfImage.objectIndex] from [extractImages].
  ///
  /// Returns a [PdfImageBitmap] containing the composited BGRA pixel data,
  /// or `null` when the object has no renderable bitmap (e.g. a mask-only
  /// image where `FPDFImageObj_GetRenderedBitmap` returns null).
  ///
  /// Each call is one isolate round-trip. For bulk extraction of many images
  /// from the same page, prefer calling [extractImages] with
  /// `includeBitmap: true` instead.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range for the document.
  /// Throws [RangeError] if [objectIndex] is negative, or if [objectIndex]
  /// is out of range for the page (the object does not exist).
  /// Throws [StateError] if the document has been closed.
  ///
  /// **Platform support:** Native (dart:ffi) only. Stubs on unsupported
  /// platforms throw [UnsupportedError].
  ///
  /// Example — render only large images:
  ///
  /// ```dart
  /// await for (final page in doc.extractImages()) {
  ///   for (final img in page.images) {
  ///     if (img.metadata.width > 500 && img.metadata.height > 500) {
  ///       final bitmap = await doc.renderImage(img.pageIndex, img.objectIndex);
  ///       if (bitmap != null) {
  ///         // process bitmap.bgra…
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  Future<PdfImageBitmap?> renderImage(int pageIndex, int objectIndex) =>
      _impl.renderImage(pageIndex, objectIndex);

  /// Searches the document for [query] and streams all matches.
  ///
  /// Results are yielded page-by-page in ascending page order. An empty stream
  /// means no matches were found. An empty [query] string returns an empty
  /// stream immediately without invoking any PDFium calls.
  ///
  /// [flags] controls case-sensitivity, whole-word matching, and overlapping
  /// matches. Defaults to case-insensitive, non-whole-word, non-overlapping.
  ///
  /// When [pageIndex] is specified, the search is restricted to that single
  /// page. Omit it to search all pages. Throws [RangeError] if [pageIndex] is
  /// out of range for the document.
  ///
  /// Bounding rectangles in each [PdfSearchMatch] are in **PDF user-space**
  /// (origin bottom-left, units in points). Callers that need screen-space
  /// coordinates must apply `FPDF_PageToDevice()` themselves.
  ///
  /// Cancelling the stream subscription immediately stops further processing.
  /// Page-level PDFium handles are released inside the isolate after each
  /// round-trip, so there are no handle leaks on cancellation.
  ///
  /// [close] terminates any active stream: the stream stops emitting events
  /// and the subscription is silently cancelled.
  ///
  /// Throws [StateError] if the document has been closed before or during
  /// the search.
  ///
  /// **Platform support:** Native (dart:ffi) only. Stubs on unsupported
  /// platforms throw [UnsupportedError] immediately.
  ///
  /// Example — search for a term and print each match location:
  ///
  /// ```dart
  /// await for (final match in doc.search('example')) {
  ///   print('Match on page ${match.pageIndex + 1}: '
  ///       'char ${match.charIndex}, '
  ///       '${match.rects.length} rect(s)');
  /// }
  /// ```
  Stream<PdfSearchMatch> search(
    String query, {
    Set<PdfSearchFlag> flags = const {},
    int? pageIndex,
  }) => _impl.search(query, flags: flags, pageIndex: pageIndex);

  /// Returns the complete Table of Contents (bookmark/outline tree) for the
  /// document.
  ///
  /// Each [PdfTocEntry] in the returned list is a root-level bookmark entry.
  /// [PdfTocEntry.children] provides nested sub-entries at arbitrary depth.
  ///
  /// Returns an empty list when the document has no bookmarks — this is not
  /// an error condition.
  ///
  /// Throws [StateError] if [close] has already been called.
  ///
  /// **Platform support:** Native (dart:ffi) only. Stubs on unsupported
  /// platforms throw [UnsupportedError] immediately.
  ///
  /// Example — print all top-level bookmark titles and their page numbers:
  ///
  /// ```dart
  /// final toc = await doc.tableOfContents;
  /// for (final entry in toc) {
  ///   final page = entry.pageIndex != null ? 'page ${entry.pageIndex! + 1}' : '(no target)';
  ///   print('${entry.title} → $page');
  /// }
  /// ```
  Future<List<PdfTocEntry>> get tableOfContents => _impl.tableOfContents;

  /// Returns a thumbnail image for the page at [pageIndex].
  ///
  /// When the page contains an embedded `/Thumb` stream, that bitmap is decoded
  /// and returned at its native dimensions with
  /// [PdfThumbnailSource.embedded]. Not all PDFs contain embedded thumbnails —
  /// modern tools such as `pdflatex` typically do not produce them.
  ///
  /// When no embedded thumbnail is present and [generateIfAbsent] is `true`
  /// (the default), the page is rendered at a size proportional to
  /// [maxDimension] (longest edge ≤ [maxDimension] pixels, aspect ratio
  /// preserved) and returned with [PdfThumbnailSource.rendered].
  ///
  /// When no embedded thumbnail is present and [generateIfAbsent] is `false`,
  /// `null` is returned without any render pass. This is useful for callers
  /// that only wish to surface natively-embedded previews.
  ///
  /// [maxDimension] is a **logical pixel budget** — it applies only to the
  /// fallback render path and is ignored for embedded thumbnails. On high-DPI
  /// displays (e.g. Retina), multiply [maxDimension] by
  /// `MediaQuery.of(context).devicePixelRatio` before calling to obtain a
  /// full-resolution fallback render. This method lives in the pure-Dart layer
  /// and cannot access `MediaQuery` itself.
  ///
  /// ## Error contract
  ///
  /// Throws [RangeError] if [pageIndex] is out of range for the document.
  /// Throws [ArgumentError] if [maxDimension] ≤ 0.
  /// Throws [StateError] if [close] has been called before or during the call.
  /// Throws [PdfiumException] if a PDFium native call fails unexpectedly.
  ///
  /// **Platform support:** Native (dart:ffi) only. Stubs on unsupported
  /// platforms throw [UnsupportedError] immediately.
  ///
  /// Example — display a thumbnail in a Flutter widget:
  ///
  /// ```dart
  /// final dpr = MediaQuery.of(context).devicePixelRatio;
  /// final thumb = await doc.getThumbnail(0, maxDimension: (256 * dpr).round());
  /// if (thumb != null) {
  ///   // thumb.bgra is BGRA bytes; thumb.width × thumb.height is the size.
  /// }
  /// ```
  Future<PdfThumbnail?> getThumbnail(
    int pageIndex, {
    bool generateIfAbsent = true,
    int maxDimension = 256,
  }) => _impl.getThumbnail(
    pageIndex,
    generateIfAbsent: generateIfAbsent,
    maxDimension: maxDimension,
  );

  /// Closes the document and releases the native PDFium handle.
  ///
  /// Safe to call more than once — subsequent calls are no-ops. After [close]
  /// returns, all other methods throw [StateError].
  ///
  /// Any active [extractPlainText] stream is terminated: the stream stops
  /// emitting events and the subscription is silently cancelled. Callers do
  /// not need to cancel streams manually before calling [close].
  Future<void> close() => _impl.close();
}
