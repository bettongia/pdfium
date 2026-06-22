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

// Typed message protocol for the PdfiumIsolate.
//
// All communication with the PDFium isolate uses this sealed class hierarchy.
// Each message carries a [SendPort] for the response so that concurrent
// requests can be tracked and matched independently.
//
// Future plans (text extraction, annotations, rendering) extend this protocol
// by adding new [PdfiumCommand] subtypes without coupling their public APIs
// to this file.

import 'dart:isolate';
import 'dart:typed_data';

import 'pdf_types.dart';
import '../rendering/pdf_page_size.dart';

/// Base class for all commands sent to the [PdfiumIsolate].
///
/// Each command carries a [replyPort] — the [SendPort] on which the isolate
/// sends the [PdfiumResponse] for this specific request.
sealed class PdfiumCommand {
  /// Creates a command with the given [replyPort].
  const PdfiumCommand(this.replyPort);

  /// The port on which the isolate must send the response for this command.
  final SendPort replyPort;
}

/// Initialise the PDFium library within the isolate.
///
/// This is the first message sent after the isolate starts. The isolate
/// responds with a [PdfiumInitResponse] carrying the [SendPort] for
/// subsequent commands.
class PdfiumInitCommand extends PdfiumCommand {
  /// Creates an init command.
  const PdfiumInitCommand(super.replyPort, this.dylibPath);

  /// The filesystem path to the PDFium dynamic library.
  final String dylibPath;
}

/// Load a PDF document from raw bytes.
///
/// The isolate calls `FPDF_LoadMemDocument64()` and returns a document token
/// (an opaque integer handle) that the caller uses in subsequent commands.
class PdfiumLoadDocumentCommand extends PdfiumCommand {
  /// Creates a load-document command.
  const PdfiumLoadDocumentCommand(super.replyPort, this.bytes);

  /// The raw PDF bytes to load.
  final Uint8List bytes;
}

/// Read the Info dictionary metadata for an open document.
///
/// The isolate reads all eight standard Info dictionary fields using
/// `FPDF_GetMetaText()` and returns a [PdfiumGetMetadataResponse].
class PdfiumGetMetadataCommand extends PdfiumCommand {
  /// Creates a get-metadata command for the document identified by [token].
  const PdfiumGetMetadataCommand(super.replyPort, this.token);

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;
}

/// Read document-level properties (version and file identifiers).
///
/// The isolate calls `FPDF_GetFileVersion()` and `FPDF_GetFileIdentifier()`
/// in a single round-trip and returns a [PdfiumGetDocumentInfoResponse].
class PdfiumGetDocumentInfoCommand extends PdfiumCommand {
  /// Creates a get-document-info command for the document identified by [token].
  const PdfiumGetDocumentInfoCommand(super.replyPort, this.token);

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;
}

/// Close a previously loaded document and release its native handle.
///
/// The isolate calls `FPDF_CloseDocument()` and responds with a
/// [PdfiumCloseDocumentResponse].
class PdfiumCloseDocumentCommand extends PdfiumCommand {
  /// Creates a close-document command for the document identified by [token].
  const PdfiumCloseDocumentCommand(super.replyPort, this.token);

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;
}

/// Get the total number of pages in an open document.
///
/// The isolate calls `FPDF_GetPageCount()` and responds with a
/// [PdfiumGetPageCountResponse].
class PdfiumGetPageCountCommand extends PdfiumCommand {
  /// Creates a get-page-count command for the document identified by [token].
  const PdfiumGetPageCountCommand(super.replyPort, this.token);

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;
}

/// Extract plain text from a single page of an open document.
///
/// The isolate loads the page, loads the text page, extracts all text, then
/// closes both handles in a single round-trip. The response is a
/// [PdfiumExtractPageTextResponse] carrying the result.
///
/// [PdfiumExtractPageTextResponse.hasTextLayer] is true whenever PDFium
/// extracts at least one character from the page — the only reliable signal
/// that a text layer exists.
class PdfiumExtractPageTextCommand extends PdfiumCommand {
  /// Creates an extract-page-text command.
  const PdfiumExtractPageTextCommand(
    super.replyPort,
    this.token,
    this.pageIndex,
  );

  /// The opaque document token.
  final int token;

  /// Zero-based index of the page to extract text from.
  final int pageIndex;
}

/// Get the intrinsic size of a single page of an open document.
///
/// The isolate calls `FPDF_GetPageWidthF()` and `FPDF_GetPageHeightF()` and
/// returns a [PdfiumGetPageSizeResponse] containing a [PdfPageSize].
class PdfiumGetPageSizeCommand extends PdfiumCommand {
  /// Creates a get-page-size command.
  const PdfiumGetPageSizeCommand(super.replyPort, this.token, this.pageIndex);

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;

  /// Zero-based index of the page whose size is requested.
  final int pageIndex;
}

/// Render a single page of an open document to a BGRA pixel buffer.
///
/// The isolate allocates a bitmap of [pixelWidth] × [pixelHeight] pixels,
/// fills it with [backgroundColor] (in `0xAARRGGBB` format), calls
/// `FPDF_RenderPageBitmap()` with the given [renderFlags], copies the
/// resulting BGRA bytes into a [Uint8List], then destroys the bitmap handle
/// and closes the page handle.
///
/// Render flags are the raw PDFium integer flags (e.g. `FPDF_ANNOT`,
/// `FPDF_LCD_TEXT`). The public [PdfDocument.renderPage] method converts
/// [PdfRenderOptions] fields to these flags before dispatching this command.
class PdfiumRenderPageCommand extends PdfiumCommand {
  /// Creates a render-page command.
  const PdfiumRenderPageCommand(
    super.replyPort,
    this.token,
    this.pageIndex,
    this.pixelWidth,
    this.pixelHeight,
    this.renderFlags,
    this.backgroundColor,
  );

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;

  /// Zero-based index of the page to render.
  final int pageIndex;

  /// Width of the output bitmap in pixels.
  final int pixelWidth;

  /// Height of the output bitmap in pixels.
  final int pixelHeight;

  /// PDFium render flags (e.g. `FPDF_ANNOT`, `FPDF_LCD_TEXT`).
  final int renderFlags;

  /// Background colour in `0xAARRGGBB` format, used to fill the bitmap before
  /// rendering. Opaque white is `0xFFFFFFFF`.
  final int backgroundColor;
}

/// Retrieve the complete bookmark/outline tree for an open document.
///
/// The isolate walks the bookmark tree using `FPDFBookmark_GetFirstChild`,
/// `FPDFBookmark_GetNextSibling`, and `FPDFBookmark_GetAction` / destination
/// resolution, building a `List<PdfTocEntry>` in a single recursive pass.
///
/// Documents without any bookmarks produce an empty list — not an error.
///
/// The recursive [PdfTocEntry] tree is deep-copied across the isolate
/// boundary by Dart's message-passing mechanism (Dart serialises arbitrary
/// Dart objects by value when they are sent across isolate boundaries). This
/// is acceptable for the bounded sizes of typical PDF bookmark trees (hundreds
/// to low thousands of entries at most).
class PdfiumGetTocCommand extends PdfiumCommand {
  /// Creates a get-TOC command for the document identified by [token].
  const PdfiumGetTocCommand(super.replyPort, this.token);

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;
}

/// Extract all annotations from a single page of an open document.
///
/// The isolate opens the page, iterates all annotations via
/// `FPDFPage_GetAnnotCount()` / `FPDFPage_GetAnnot()`, extracts all fields,
/// closes each annotation handle and the page handle, then sends a
/// [PdfiumExtractPageAnnotationsResponse].
///
/// Pages with no annotations produce a response with an empty [annotations]
/// list — not an error.
class PdfiumExtractPageAnnotationsCommand extends PdfiumCommand {
  /// Creates an extract-page-annotations command.
  const PdfiumExtractPageAnnotationsCommand(
    super.replyPort,
    this.token,
    this.pageIndex,
  );

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;

  /// Zero-based index of the page whose annotations are to be extracted.
  final int pageIndex;
}

/// Extract all image objects from a single page of an open document.
///
/// The isolate opens the page, iterates all page objects via
/// `FPDFPage_CountObjects()` / `FPDFPage_GetObject()`, filters for objects
/// of type `FPDF_PAGEOBJ_IMAGE`, extracts metadata and (optionally) renders
/// the bitmap for each, then closes the page handle and sends a
/// [PdfiumExtractPageImagesResponse].
///
/// Pages with no image objects produce a response with an empty [images] list
/// — not an error.
///
/// When [includeBitmap] is `false` (the default), the bitmap is not rendered;
/// [PdfImage.bgra], [PdfImage.bitmapWidth], and [PdfImage.bitmapHeight] will
/// be `null` in every [PdfImage] in the response.
class PdfiumExtractPageImagesCommand extends PdfiumCommand {
  /// Creates an extract-page-images command.
  const PdfiumExtractPageImagesCommand(
    super.replyPort,
    this.token,
    this.pageIndex, {
    this.includeBitmap = false,
  });

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;

  /// Zero-based index of the page whose images are to be extracted.
  final int pageIndex;

  /// When true, the rendered BGRA bitmap is fetched for each image object.
  ///
  /// Setting this to `true` calls `FPDFImageObj_GetRenderedBitmap` for every
  /// image on the page, which is significantly more expensive than metadata-
  /// only extraction. For selective on-demand bitmap fetches, prefer sending
  /// individual [PdfiumRenderImageCommand] requests.
  final bool includeBitmap;
}

/// Search for text on a single page of an open document.
///
/// The isolate loads the page's text layer via `FPDFText_LoadPage`, then
/// calls `FPDFText_FindStart` with the provided [query] (encoded as UTF-16LE)
/// and [flags] bitmask. It iterates `FPDFText_FindNext` to collect all
/// matches, calling `FPDFText_GetSchResultIndex`, `FPDFText_GetSchCount`,
/// `FPDFText_CountRects`, and `FPDFText_GetRect` for each. All handles are
/// closed in a `try/finally` block. The response is a
/// [PdfiumSearchPageResponse].
///
/// The [flags] field is a PDFium bitmask built from [PdfSearchFlag] values:
/// - `0x01` = `FPDF_MATCHCASE`
/// - `0x02` = `FPDF_MATCHWHOLEWORD`
/// - `0x04` = `FPDF_CONSECUTIVE`
///
/// An empty [query] string must be rejected by the caller before dispatching
/// this command; the isolate does not guard against it.
///
/// Pages with no text layer produce a response with an empty matches list —
/// not an error.
class PdfiumSearchPageCommand extends PdfiumCommand {
  /// Creates a search-page command.
  const PdfiumSearchPageCommand(
    super.replyPort,
    this.token,
    this.pageIndex,
    this.query,
    this.flags,
  );

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;

  /// Zero-based index of the page to search.
  final int pageIndex;

  /// The search query string (must be non-empty; the caller is responsible for
  /// guarding against empty queries).
  final String query;

  /// PDFium search flags bitmask (`FPDF_MATCHCASE | FPDF_MATCHWHOLEWORD |
  /// FPDF_CONSECUTIVE`).
  final int flags;
}

/// Fetch the rendered BGRA bitmap for a single image object on a page.
///
/// The isolate opens the page, retrieves the object at [objectIndex] via
/// `FPDFPage_GetObject`, verifies that its type is `FPDF_PAGEOBJ_IMAGE`,
/// calls `FPDFImageObj_GetRenderedBitmap`, copies the BGRA bytes, destroys
/// the bitmap handle, and closes the page handle. Sends a
/// [PdfiumRenderImageResponse].
///
/// The response carries `bitmap: null` when the object at [objectIndex] is
/// not an image object, or when `FPDFImageObj_GetRenderedBitmap` returns null
/// (e.g. a mask-only object).
///
/// The caller is responsible for range-checking [objectIndex] before
/// dispatching this command. If the object index is out of range for the page,
/// `FPDFPage_GetObject` returns null, and the response will carry
/// `bitmap: null`.
class PdfiumRenderImageCommand extends PdfiumCommand {
  /// Creates a render-image command.
  const PdfiumRenderImageCommand(
    super.replyPort,
    this.token,
    this.pageIndex,
    this.objectIndex,
  );

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;

  /// Zero-based index of the page containing the image.
  final int pageIndex;

  /// Zero-based index of the page object to render (as returned by
  /// `FPDFPage_GetObject`). Must be an image-type object.
  final int objectIndex;
}

/// Retrieve the embedded thumbnail bitmap for a single page of an open document.
///
/// The isolate opens the page via `FPDF_LoadPage`, calls
/// `FPDFPage_GetThumbnailAsBitmap`, and—if a bitmap is returned—reads its
/// pixel data into a [Uint8List] in BGRA format before destroying both the
/// bitmap and page handles. Sends a [PdfiumGetPageThumbnailResponse].
///
/// When the page has no embedded thumbnail, `FPDFPage_GetThumbnailAsBitmap`
/// returns `nullptr`. The isolate treats this as a success with a `null` pixel
/// buffer (not an error), so the caller can decide whether to fall back to
/// rendering.
///
/// The [token] is the opaque document token from a prior
/// [PdfiumLoadDocumentCommand]. The [pageIndex] is zero-based.
class PdfiumGetPageThumbnailCommand extends PdfiumCommand {
  /// Creates a get-page-thumbnail command.
  const PdfiumGetPageThumbnailCommand(
    super.replyPort,
    this.token,
    this.pageIndex,
  );

  /// The opaque document token returned by a prior [PdfiumLoadDocumentCommand].
  final int token;

  /// Zero-based index of the page whose embedded thumbnail is requested.
  final int pageIndex;
}

// ---------------------------------------------------------------------------
// Responses
// ---------------------------------------------------------------------------

/// Base class for all responses sent from the [PdfiumIsolate].
sealed class PdfiumResponse {
  /// Creates a response.
  const PdfiumResponse();
}

/// Sent by the isolate after it has started and initialised PDFium.
///
/// The [commandPort] is used for all subsequent commands.
class PdfiumInitResponse extends PdfiumResponse {
  /// Creates an init response.
  const PdfiumInitResponse(this.commandPort);

  /// The [SendPort] on which the isolate accepts subsequent [PdfiumCommand]s.
  final SendPort commandPort;
}

/// Sent by the isolate when PDFium library initialisation fails.
///
/// This occurs when the dynamic library cannot be loaded (e.g. the path is
/// wrong or the binary is missing). The [message] field contains the
/// underlying error description.
class PdfiumInitFailedResponse extends PdfiumResponse {
  /// Creates a failure response with the given error [message].
  const PdfiumInitFailedResponse(this.message);

  /// A human-readable description of why initialisation failed.
  final String message;
}

/// Sent when a [PdfiumLoadDocumentCommand] succeeds.
class PdfiumLoadDocumentResponse extends PdfiumResponse {
  /// Creates a successful load response with the given document [token].
  const PdfiumLoadDocumentResponse.success(this.token) : error = null;

  /// Creates a failed load response with the given [error].
  const PdfiumLoadDocumentResponse.failure(this.error) : token = null;

  /// The opaque document token, or `null` on failure.
  final int? token;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether the document was loaded successfully.
  bool get isSuccess => token != null;
}

/// Sent when a [PdfiumGetMetadataCommand] completes.
class PdfiumGetMetadataResponse extends PdfiumResponse {
  /// Creates a successful metadata response.
  const PdfiumGetMetadataResponse.success(this.metadata) : error = null;

  /// Creates a failed metadata response.
  const PdfiumGetMetadataResponse.failure(this.error) : metadata = null;

  /// The extracted metadata, or `null` on failure.
  final PdfMetadata? metadata;

  /// The error that occurred, or `null` on success.
  final PdfError? error;
}

/// Sent when a [PdfiumGetDocumentInfoCommand] completes.
class PdfiumGetDocumentInfoResponse extends PdfiumResponse {
  /// Creates a successful document-info response.
  const PdfiumGetDocumentInfoResponse.success(this.info) : error = null;

  /// Creates a failed document-info response.
  const PdfiumGetDocumentInfoResponse.failure(this.error) : info = null;

  /// The document info, or `null` on failure.
  final PdfDocumentInfo? info;

  /// The error that occurred, or `null` on success.
  final PdfError? error;
}

/// Sent when a [PdfiumCloseDocumentCommand] completes.
class PdfiumCloseDocumentResponse extends PdfiumResponse {
  /// Creates a close-document response.
  const PdfiumCloseDocumentResponse();
}

/// Sent when a [PdfiumGetPageCountCommand] completes.
class PdfiumGetPageCountResponse extends PdfiumResponse {
  /// Creates a successful page-count response.
  const PdfiumGetPageCountResponse.success(this.pageCount) : error = null;

  /// Creates a failed page-count response.
  const PdfiumGetPageCountResponse.failure(this.error) : pageCount = null;

  /// The total number of pages, or `null` on failure.
  final int? pageCount;

  /// The error that occurred, or `null` on success.
  final PdfError? error;
}

/// Sent when a [PdfiumExtractPageAnnotationsCommand] completes.
class PdfiumExtractPageAnnotationsResponse extends PdfiumResponse {
  /// Creates a successful annotation-extraction response.
  const PdfiumExtractPageAnnotationsResponse.success({
    required this.pageIndex,
    required List<PdfAnnotation> this._annotations,
  }) : error = null;

  /// Creates a failed annotation-extraction response.
  const PdfiumExtractPageAnnotationsResponse.failure(this.error, this.pageIndex)
    : _annotations = null;

  final List<PdfAnnotation>? _annotations;

  /// The zero-based page index this response corresponds to.
  final int pageIndex;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether this response represents a successful extraction.
  bool get isSuccess => error == null;

  /// The list of extracted annotations. Only valid when [isSuccess] is true.
  List<PdfAnnotation> get annotations => _annotations!;
}

/// Sent when a [PdfiumGetPageSizeCommand] completes.
class PdfiumGetPageSizeResponse extends PdfiumResponse {
  /// Creates a successful page-size response.
  const PdfiumGetPageSizeResponse.success(this.pageSize) : error = null;

  /// Creates a failed page-size response.
  const PdfiumGetPageSizeResponse.failure(this.error) : pageSize = null;

  /// The page size, or `null` on failure.
  final PdfPageSize? pageSize;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether the response represents a successful operation.
  bool get isSuccess => error == null;
}

/// Sent when a [PdfiumRenderPageCommand] completes.
class PdfiumRenderPageResponse extends PdfiumResponse {
  /// Creates a successful render response carrying the BGRA [_pixels] buffer
  /// and the actual rendered [pixelWidth] × [pixelHeight] dimensions.
  const PdfiumRenderPageResponse.success({
    required Uint8List this._pixels,
    required this.pixelWidth,
    required this.pixelHeight,
  }) : _errorMessage = null;

  /// Creates a failed render response with a descriptive [errorMessage].
  const PdfiumRenderPageResponse.failure(this._errorMessage)
    : _pixels = null,
      pixelWidth = 0,
      pixelHeight = 0;

  final Uint8List? _pixels;
  final String? _errorMessage;

  /// The width of the rendered bitmap in pixels. Only valid when [isSuccess].
  final int pixelWidth;

  /// The height of the rendered bitmap in pixels. Only valid when [isSuccess].
  final int pixelHeight;

  /// Whether the render succeeded.
  bool get isSuccess => _errorMessage == null;

  /// The BGRA pixel buffer. Only valid when [isSuccess] is `true`.
  Uint8List get pixels => _pixels!;

  /// The error message describing why rendering failed. Only valid when
  /// [isSuccess] is `false`.
  String get errorMessage => _errorMessage!;
}

/// Sent when a [PdfiumGetTocCommand] completes.
class PdfiumGetTocResponse extends PdfiumResponse {
  /// Creates a successful TOC response with the given [entries] tree.
  const PdfiumGetTocResponse.success(this.entries) : error = null;

  /// Creates a failed TOC response.
  const PdfiumGetTocResponse.failure(this.error) : entries = null;

  /// The root-level TOC entries, or `null` on failure.
  ///
  /// An empty list is a valid success — the document simply has no bookmarks.
  final List<PdfTocEntry>? entries;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether this response represents a successful extraction.
  bool get isSuccess => error == null;
}

/// Sent when a [PdfiumExtractPageImagesCommand] completes.
class PdfiumExtractPageImagesResponse extends PdfiumResponse {
  /// Creates a successful image-extraction response.
  const PdfiumExtractPageImagesResponse.success({
    required this.pageIndex,
    required List<PdfImage> this._images,
  }) : error = null;

  /// Creates a failed image-extraction response.
  const PdfiumExtractPageImagesResponse.failure(this.error, this.pageIndex)
    : _images = null;

  final List<PdfImage>? _images;

  /// The zero-based page index this response corresponds to.
  final int pageIndex;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether this response represents a successful extraction.
  bool get isSuccess => error == null;

  /// The list of extracted images. Only valid when [isSuccess] is true.
  List<PdfImage> get images => _images!;
}

/// Sent when a [PdfiumRenderImageCommand] completes.
class PdfiumRenderImageResponse extends PdfiumResponse {
  /// Creates a successful render response carrying the [bitmap].
  ///
  /// [bitmap] is `null` when the object at the requested index is not an
  /// image type or when `FPDFImageObj_GetRenderedBitmap` returned null.
  const PdfiumRenderImageResponse.success(this.bitmap) : error = null;

  /// Creates a failed render response.
  const PdfiumRenderImageResponse.failure(this.error) : bitmap = null;

  /// The rendered bitmap, or `null` if the object is not a renderable image.
  final PdfImageBitmap? bitmap;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether this response represents a successful (non-error) operation.
  ///
  /// Note: a successful response may still carry a `null` [bitmap] when the
  /// object has no renderable bitmap (mask-only etc.). A `false` value here
  /// indicates a hard error such as an invalid document token.
  bool get isSuccess => error == null;
}

/// Sent when a [PdfiumSearchPageCommand] completes.
class PdfiumSearchPageResponse extends PdfiumResponse {
  /// Creates a successful search response with the [_matches] found on the page.
  ///
  /// An empty [_matches] list means no matches were found on this page — that
  /// is a normal, non-error result.
  const PdfiumSearchPageResponse.success({
    required this.pageIndex,
    required List<PdfSearchMatch> this._matches,
  }) : error = null;

  /// Creates a failed search response.
  const PdfiumSearchPageResponse.failure(this.error, this.pageIndex)
    : _matches = null;

  final List<PdfSearchMatch>? _matches;

  /// The zero-based page index this response corresponds to.
  final int pageIndex;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether this response represents a successful search.
  bool get isSuccess => error == null;

  /// The list of matches found on this page. Only valid when [isSuccess] is
  /// `true`. May be empty when no matches were found.
  List<PdfSearchMatch> get matches => _matches!;
}

/// Sent when a [PdfiumGetPageThumbnailCommand] completes.
///
/// On success, [bgra] is either:
/// - A non-null [Uint8List] containing the compact BGRA pixel bytes of the
///   embedded thumbnail (`length == width * height * 4`, row-padding stripped).
/// - `null`, indicating the page has no embedded thumbnail — this is a normal
///   result, not an error.
///
/// On failure (e.g. invalid document token or `FPDF_LoadPage` returning null),
/// [isSuccess] is `false` and [errorMessage] describes the problem.
class PdfiumGetPageThumbnailResponse extends PdfiumResponse {
  /// Creates a successful response where the page has an embedded thumbnail.
  ///
  /// [_bgra] must have length `[width] * [height] * 4`. Pass `null` for [_bgra]
  /// (with [width] and [height] of 0) when the page has no embedded thumbnail.
  const PdfiumGetPageThumbnailResponse.success({
    required this._bgra,
    required this.width,
    required this.height,
  }) : _errorMessage = null;

  /// Creates a failed response with a descriptive [errorMessage].
  const PdfiumGetPageThumbnailResponse.failure(this._errorMessage)
    : _bgra = null,
      width = 0,
      height = 0;

  final Uint8List? _bgra;
  final String? _errorMessage;

  /// The pixel width of the embedded thumbnail. Zero when [bgra] is `null`.
  final int width;

  /// The pixel height of the embedded thumbnail. Zero when [bgra] is `null`.
  final int height;

  /// Whether the operation succeeded (even if no thumbnail was found).
  bool get isSuccess => _errorMessage == null;

  /// The BGRA pixel buffer of the embedded thumbnail, or `null` when:
  /// - The page has no embedded thumbnail (normal result).
  ///
  /// Only valid when [isSuccess] is `true`.
  Uint8List? get bgra => _bgra;

  /// The error message. Only valid when [isSuccess] is `false`.
  String get errorMessage => _errorMessage!;
}

/// Sent when a [PdfiumExtractPageTextCommand] completes.
class PdfiumExtractPageTextResponse extends PdfiumResponse {
  /// Creates a successful text-extraction response.
  const PdfiumExtractPageTextResponse.success({
    required this.pageIndex,
    required String this._text,
    required bool this._hasUnicodeErrors,
    required bool this._hasTextLayer,
  }) : error = null;

  /// Creates a failed text-extraction response.
  const PdfiumExtractPageTextResponse.failure(this.error, this.pageIndex)
    : _text = null,
      _hasUnicodeErrors = null,
      _hasTextLayer = null;

  final String? _text;
  final bool? _hasUnicodeErrors;
  final bool? _hasTextLayer;

  /// The zero-based page index this response corresponds to.
  final int pageIndex;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether this response represents a successful extraction.
  bool get isSuccess => error == null;

  /// The extracted text. Only valid when [isSuccess] is true.
  String get text => _text!;

  /// Whether any characters had broken Unicode mappings. Only valid when
  /// [isSuccess] is true.
  bool get hasUnicodeErrors => _hasUnicodeErrors!;

  /// Whether this page has a meaningful text layer. Only valid when
  /// [isSuccess] is true.
  bool get hasTextLayer => _hasTextLayer!;
}
