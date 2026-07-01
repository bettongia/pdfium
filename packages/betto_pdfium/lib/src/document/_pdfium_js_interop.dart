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

// dart:js_interop declarations for the PDFium Emscripten WASM module.
//
// bblanchon/pdfium-binaries ships pdfium.js as a non-MODULARIZE Emscripten
// build (verified against chromium/7906). The module is exposed as a global
// window.Module object that is populated when the script auto-runs on load.
// All FPDF_* C functions are accessible as Module["_FPDF_*"]. Memory
// management helpers (malloc, free) and heap typed arrays (HEAPU8, HEAPF32,
// HEAPF64, HEAP32) are also present.
//
// Loading pattern:
//   1. Set window.Module = { onRuntimeInitialized: callback } BEFORE injecting
//      the <script> tag. Emscripten merges the pre-configured object.
//   2. Inject <script src="assets/pdfium/pdfium.js">.
//   3. Await onRuntimeInitialized — fires when WASM instantiation completes.
//   4. Access the full module via window.Module.
//
// Verified facts (bblanchon chromium/7906):
//   - Global object pattern; not MODULARIZE=1.
//   - Module["_FPDF_*"] exports present (251+ functions).
//   - Module["_malloc"], Module["_free"] present.
//   - Module["HEAPU8"], Module["HEAP32"], Module["HEAPF32"] present.
//   - No Asyncify — all C functions are synchronous.
//   - pdfium.js loads pdfium.wasm via locateFile("pdfium.wasm").

import 'dart:js_interop';

/// Extension type wrapping the global `window.Module` Emscripten object.
///
/// Only the subset of the Module API used by `_document_web.dart` is declared
/// here. Functions are organised by Phase 2 PR group.
extension type PdfiumModule._(JSObject _) implements JSObject {
  // --- Memory management ---

  /// Allocates [size] bytes on the WASM heap.
  ///
  /// Returns the WASM address of the allocated block, or 0 on failure.
  /// The caller is responsible for calling [free] when done.
  @JS('_malloc')
  external int malloc(int size);

  /// Frees a block previously allocated by [malloc].
  @JS('_free')
  external void free(int ptr);

  // --- Heap typed arrays (views into WASM linear memory) ---

  /// Unsigned 8-bit view of the entire WASM linear memory.
  ///
  /// Used to copy raw bytes into and out of WASM heap buffers. Re-fetch after
  /// any [malloc] call that may have grown WASM memory.
  @JS('HEAPU8')
  external JSUint8Array get heapu8;

  /// Signed 32-bit view of the WASM linear memory.
  ///
  /// Used to read int/uint struct fields. Access at `HEAP32[byteAddr >> 2]`.
  @JS('HEAP32')
  external JSInt32Array get heap32;

  /// 32-bit float view of the WASM linear memory.
  ///
  /// Used to read FS_FLOAT/float struct fields. Access at `HEAPF32[addr >> 2]`.
  @JS('HEAPF32')
  external JSFloat32Array get heapf32;

  /// 64-bit float view of the WASM linear memory.
  ///
  /// Used to read double* output parameters (e.g. FPDFText_GetRect).
  /// Access at `HEAPF64[byteAddr >> 3]`.
  @JS('HEAPF64')
  external JSFloat64Array get heapf64;

  // --- PDFium library lifecycle ---

  /// One-time process-level PDFium initialisation.
  ///
  /// Call once after the module is loaded. Pass 0 for the default config
  /// (equivalent to `FPDF_InitLibraryWithConfig(nullptr)` in C).
  @JS('_FPDF_InitLibraryWithConfig')
  external void fpdfInitLibraryWithConfig(int config);

  // --- Document lifecycle ---

  /// Loads a PDF document from a buffer already in WASM heap memory.
  ///
  /// [data] is the WASM heap address of the PDF byte buffer.
  /// [size] is the byte length of the buffer.
  /// [password] is 0 for unencrypted documents.
  ///
  /// Returns a non-zero FPDF_DOCUMENT handle on success, or 0 on failure.
  /// Call [fpdfGetLastError] on failure to retrieve the error code.
  ///
  /// The buffer at [data] must remain allocated until [fpdfCloseDocument] is
  /// called — PDFium does not copy the buffer.
  @JS('_FPDF_LoadMemDocument64')
  external int fpdfLoadMemDocument64(int data, int size, int password);

  /// Closes [doc] and releases PDFium's internal page/object handles.
  ///
  /// The caller must [free] the WASM heap buffer separately after this call.
  @JS('_FPDF_CloseDocument')
  external void fpdfCloseDocument(int doc);

  /// Returns the PDFium error code from the most recent failed operation.
  ///
  /// Error codes (fpdfview.h):
  ///   0 = FPDF_ERR_SUCCESS, 1 = FPDF_ERR_UNKNOWN, 2 = FPDF_ERR_FILE,
  ///   3 = FPDF_ERR_FORMAT, 4 = FPDF_ERR_PASSWORD, 5 = FPDF_ERR_SECURITY.
  @JS('_FPDF_GetLastError')
  external int fpdfGetLastError();

  // --- Page count ---

  /// Returns the total number of pages in [doc].
  @JS('_FPDF_GetPageCount')
  external int fpdfGetPageCount(int doc);

  // --- Metadata (PR 2b) ---

  /// Copies a metadata field into a UTF-16LE buffer.
  ///
  /// [doc] is the document handle. [tag] is the WASM heap address of the
  /// null-terminated ASCII Info dictionary key (e.g. "Title"). [buffer] is a
  /// WASM heap address to write into; [bufLen] is the buffer length in bytes.
  /// Returns the required buffer length (including the null terminator pair).
  /// Pass [buffer]=0 and [bufLen]=0 for the first call to obtain the length.
  @JS('_FPDF_GetMetaText')
  external int fpdfGetMetaText(int doc, int tag, int buffer, int bufLen);

  /// Retrieves the file version of [doc] into [fileVersion].
  ///
  /// [fileVersion] is a WASM heap address (int32) where the version is
  /// written (e.g. 17 for PDF 1.7). Returns 1 on success, 0 on failure.
  @JS('_FPDF_GetFileVersion')
  external int fpdfGetFileVersion(int doc, int fileVersion);

  /// Copies a file identifier into a byte buffer.
  ///
  /// [idType] is 0 for the permanent ID, 1 for the changing ID. [buffer] is
  /// a WASM heap address; [bufLen] is its length. Returns the required length.
  @JS('_FPDF_GetFileIdentifier')
  external int fpdfGetFileIdentifier(
    int doc,
    int idType,
    int buffer,
    int bufLen,
  );

  // --- Page geometry (PR 2b) ---

  /// Loads page [pageIndex] from [doc].
  ///
  /// Returns a non-zero FPDF_PAGE handle, or 0 on failure. The caller must
  /// call [fpdfClosePage] when done.
  @JS('_FPDF_LoadPage')
  external int fpdfLoadPage(int doc, int pageIndex);

  /// Closes a page handle returned by [fpdfLoadPage].
  @JS('_FPDF_ClosePage')
  external void fpdfClosePage(int page);

  /// Returns the page width in PDF points.
  @JS('_FPDF_GetPageWidthF')
  external double fpdfGetPageWidthF(int page);

  /// Returns the page height in PDF points.
  @JS('_FPDF_GetPageHeightF')
  external double fpdfGetPageHeightF(int page);

  // --- Text extraction (PR 2b / PR 2c) ---

  /// Opens a text page for text extraction.
  ///
  /// Returns a non-zero FPDF_TEXTPAGE handle or 0 on failure. Caller must
  /// call [fpdfTextClosePage] when done.
  @JS('_FPDFText_LoadPage')
  external int fpdfTextLoadPage(int page);

  /// Closes a text page handle.
  @JS('_FPDFText_ClosePage')
  external void fpdfTextClosePage(int textPage);

  /// Returns the number of characters on [textPage].
  @JS('_FPDFText_CountChars')
  external int fpdfTextCountChars(int textPage);

  /// Returns non-zero when character [index] on [textPage] has a broken
  /// Unicode mapping (i.e. the glyph cannot be reliably decoded to Unicode).
  @JS('_FPDFText_HasUnicodeMapError')
  external int fpdfTextHasUnicodeMapError(int textPage, int index);

  /// Returns non-zero when character [index] on [textPage] is a soft hyphen
  /// (U+00AD) at a line-break position that should be stripped.
  @JS('_FPDFText_IsHyphen')
  external int fpdfTextIsHyphen(int textPage, int index);

  /// Extracts UTF-16LE text from [textPage] into a WASM heap buffer.
  ///
  /// [startIndex] is the first character index. [count] is the number of
  /// characters to extract. [result] is a WASM heap address for the output
  /// UTF-16LE buffer (must hold at least [count]+1 unsigned short slots).
  /// Returns the number of code units written, including the null terminator.
  @JS('_FPDFText_GetText')
  external int fpdfTextGetText(
    int textPage,
    int startIndex,
    int count,
    int result,
  );

  /// Extracts UTF-16LE text within an axis-aligned bounding box on [textPage].
  ///
  /// The bounding box [left]/[top]/[right]/[bottom] is in PDF user space
  /// (bottom-left origin). [buffer] is a WASM heap address for the output
  /// UTF-16LE buffer (unsigned shorts); [bufLen] is the number of code units
  /// (not bytes) the buffer can hold. Returns the number of chars written.
  /// Pass [buffer]=0 and [bufLen]=0 to obtain the required char count.
  @JS('_FPDFText_GetBoundedText')
  external int fpdfTextGetBoundedText(
    int textPage,
    double left,
    double top,
    double right,
    double bottom,
    int buffer,
    int bufLen,
  );

  // --- Search (PR 2e) ---

  /// Starts a text search on [textPage] for [query].
  ///
  /// [query] is a WASM heap address of a null-terminated UTF-16LE string.
  /// [flags] is a bitmask: FPDF_MATCHCASE=0x01, FPDF_MATCHWHOLEWORD=0x02,
  /// FPDF_CONSECUTIVE=0x04. [startIndex] is the starting character position.
  /// Returns a non-zero search handle on success, or 0 on failure.
  @JS('_FPDFText_FindStart')
  external int fpdfTextFindStart(
    int textPage,
    int query,
    int flags,
    int startIndex,
  );

  /// Advances the search handle to the next match.
  ///
  /// Returns non-zero if a match was found.
  @JS('_FPDFText_FindNext')
  external int fpdfTextFindNext(int searchHandle);

  /// Returns the start character index of the current search match.
  @JS('_FPDFText_GetSchResultIndex')
  external int fpdfTextGetSchResultIndex(int searchHandle);

  /// Returns the character count of the current search match.
  @JS('_FPDFText_GetSchCount')
  external int fpdfTextGetSchCount(int searchHandle);

  /// Closes a search handle returned by [fpdfTextFindStart].
  @JS('_FPDFText_FindClose')
  external void fpdfTextFindClose(int searchHandle);

  /// Returns the number of bounding rectangles for [count] characters starting
  /// at [startIndex] on [textPage].
  @JS('_FPDFText_CountRects')
  external int fpdfTextCountRects(int textPage, int startIndex, int count);

  /// Writes the bounding rectangle for rect [rectIndex] on [textPage] into
  /// four WASM heap double addresses: [left], [top], [right], [bottom].
  ///
  /// Each output address must hold 8 bytes (double). Read via HEAPF64.
  @JS('_FPDFText_GetRect')
  external int fpdfTextGetRect(
    int textPage,
    int rectIndex,
    int left,
    int top,
    int right,
    int bottom,
  );

  // --- Rendering (PR 2d) ---

  /// Creates an FPDF_BITMAP of the given dimensions.
  ///
  /// [alpha] = 0 for BGRx, 1 for BGRA. Returns 0 on failure. PDFium
  /// internally allocates and owns the pixel buffer; free with
  /// [fpdfBitmapDestroy].
  @JS('_FPDFBitmap_Create')
  external int fpdfBitmapCreate(int width, int height, int alpha);

  /// Fills a rectangle in [bitmap] with [color] (0xAARRGGBB packed ARGB).
  @JS('_FPDFBitmap_FillRect')
  external void fpdfBitmapFillRect(
    int bitmap,
    int left,
    int top,
    int width,
    int height,
    int color,
  );

  /// Returns the WASM heap address of the first scan line of [bitmap].
  @JS('_FPDFBitmap_GetBuffer')
  external int fpdfBitmapGetBuffer(int bitmap);

  /// Returns the stride (bytes per scan line, including padding) of [bitmap].
  @JS('_FPDFBitmap_GetStride')
  external int fpdfBitmapGetStride(int bitmap);

  /// Returns the width in pixels of [bitmap].
  @JS('_FPDFBitmap_GetWidth')
  external int fpdfBitmapGetWidth(int bitmap);

  /// Returns the height in pixels of [bitmap].
  @JS('_FPDFBitmap_GetHeight')
  external int fpdfBitmapGetHeight(int bitmap);

  /// Returns the pixel format of [bitmap].
  ///
  /// Values: 0=unknown, 1=gray, 2=BGR, 3=BGRx, 4=BGRA.
  @JS('_FPDFBitmap_GetFormat')
  external int fpdfBitmapGetFormat(int bitmap);

  /// Destroys [bitmap] and releases its memory.
  @JS('_FPDFBitmap_Destroy')
  external void fpdfBitmapDestroy(int bitmap);

  /// Renders [page] into [bitmap] with the given transform and flags.
  ///
  /// [flags]: FPDF_ANNOT = 0x01, FPDF_LCD_TEXT = 0x02.
  @JS('_FPDF_RenderPageBitmap')
  external void fpdfRenderPageBitmap(
    int bitmap,
    int page,
    int startX,
    int startY,
    int sizeX,
    int sizeY,
    int rotate,
    int flags,
  );

  // --- Thumbnail (PR 2d) ---

  /// Returns the FPDF_BITMAP for the embedded /Thumb stream of [page], or 0.
  ///
  /// The caller must destroy the returned bitmap with [fpdfBitmapDestroy].
  @JS('_FPDFPage_GetThumbnailAsBitmap')
  external int fpdfGetPageThumbnailAsBitmap(int page);

  // --- Annotations (PR 2c) ---

  /// Returns the number of annotations on [page].
  @JS('_FPDFPage_GetAnnotCount')
  external int fpdfPageGetAnnotCount(int page);

  /// Returns the annotation at [index] on [page].
  ///
  /// Caller must call [fpdfPageCloseAnnot] when done.
  @JS('_FPDFPage_GetAnnot')
  external int fpdfPageGetAnnot(int page, int index);

  /// Closes an annotation handle.
  @JS('_FPDFPage_CloseAnnot')
  external void fpdfPageCloseAnnot(int annot);

  /// Returns the zero-based index of [annot] in the [page] annotation list.
  ///
  /// Returns -1 if [annot] is not found on [page].
  @JS('_FPDFPage_GetAnnotIndex')
  external int fpdfPageGetAnnotIndex(int page, int annot);

  /// Returns the subtype of [annot] as an integer (FPDF_ANNOT_* constant).
  @JS('_FPDFAnnot_GetSubtype')
  external int fpdfAnnotGetSubtype(int annot);

  /// Returns the flags bitmask of [annot], or 0 on failure.
  @JS('_FPDFAnnot_GetFlags')
  external int fpdfAnnotGetFlags(int annot);

  /// Copies the string value of [key] in [annot]'s dictionary into a
  /// UTF-16LE buffer.
  ///
  /// [key] is a WASM heap address of a null-terminated ASCII string.
  /// [buffer] is a WASM heap address; [bufLen] is its byte length.
  /// Returns the required buffer length. Pass [buffer]=0 / [bufLen]=0 first.
  @JS('_FPDFAnnot_GetStringValue')
  external int fpdfAnnotGetStringValue(
    int annot,
    int key,
    int buffer,
    int bufLen,
  );

  /// Returns the colour of [annot] as ARGB components.
  ///
  /// [colorType] is 0 for the main colour, 1 for interior colour.
  /// [r], [g], [b], [a] are WASM heap addresses of uint32 output values.
  /// Returns non-zero on success.
  @JS('_FPDFAnnot_GetColor')
  external int fpdfAnnotGetColor(
    int annot,
    int colorType,
    int r,
    int g,
    int b,
    int a,
  );

  /// Writes the bounding rectangle of [annot] into [rect].
  ///
  /// [rect] is a WASM heap address for a 16-byte FS_RECTF struct
  /// (left, top, right, bottom as float32). Returns non-zero on success.
  @JS('_FPDFAnnot_GetRect')
  external int fpdfAnnotGetRect(int annot, int rect);

  /// Returns the ink stroke count of [annot] (FPDF_ANNOT_INK only).
  @JS('_FPDFAnnot_GetInkListCount')
  external int fpdfAnnotGetInkListCount(int annot);

  /// Writes up to [pointCount] ink points for stroke [pathIndex] of [annot].
  ///
  /// [points] is a WASM heap address for an array of FS_POINTF structs (8
  /// bytes each). Returns the actual number of points written.
  @JS('_FPDFAnnot_GetInkListPath')
  external int fpdfAnnotGetInkListPath(
    int annot,
    int pathIndex,
    int points,
    int pointCount,
  );

  /// Returns the count of quad-point sets in [annot] (markup annotations).
  @JS('_FPDFAnnot_CountAttachmentPoints')
  external int fpdfAnnotCountAttachmentPoints(int annot);

  /// Writes the quad-point set at [quadIndex] into [quadPoints].
  ///
  /// [quadPoints] is a WASM heap address for a 32-byte FS_QUADPOINTSF struct
  /// (x1,y1,x2,y2,x3,y3,x4,y4 as float32). Returns non-zero on success.
  @JS('_FPDFAnnot_GetAttachmentPoints')
  external int fpdfAnnotGetAttachmentPoints(
    int annot,
    int quadIndex,
    int quadPoints,
  );

  /// Writes the start and end points of a line [annot] into two FS_POINTF
  /// structs at WASM heap addresses [start] and [end] (8 bytes each).
  ///
  /// Returns non-zero on success.
  @JS('_FPDFAnnot_GetLine')
  external int fpdfAnnotGetLine(int annot, int start, int end);

  /// Returns the count of polygon/polyline vertices in [annot].
  ///
  /// [buffer] = 0, [length] = 0 for the count-only call.
  @JS('_FPDFAnnot_GetVertices')
  external int fpdfAnnotGetVertices(int annot, int buffer, int length);

  /// Returns the link handle from [annot] (FPDF_ANNOT_LINK only), or 0.
  @JS('_FPDFAnnot_GetLink')
  external int fpdfAnnotGetLink(int annot);

  /// Returns the annotation linked via [key] to [annot], or 0.
  ///
  /// [key] is a WASM heap address of a null-terminated ASCII string (e.g.
  /// "IRT" for In-Reply-To). The returned annotation must be closed with
  /// [fpdfPageCloseAnnot].
  @JS('_FPDFAnnot_GetLinkedAnnot')
  external int fpdfAnnotGetLinkedAnnot(int annot, int key);

  // --- Link actions (PR 2c) ---

  /// Returns the action associated with [link], or 0 if none.
  @JS('_FPDFLink_GetAction')
  external int fpdfLinkGetAction(int link);

  // --- Action helpers (PR 2c / PR 2e) ---

  /// Returns the action type of [action] (PDFACTION_* constant).
  ///
  /// Values: 0=unsupported, 1=goto, 2=remotegoto, 3=uri, 4=launch, 5=embedded.
  @JS('_FPDFAction_GetType')
  external int fpdfActionGetType(int action);

  /// Returns the destination associated with [action], or 0.
  @JS('_FPDFAction_GetDest')
  external int fpdfActionGetDest(int doc, int action);

  /// Copies the URI string of a URI [action] into a byte buffer.
  ///
  /// [buffer] is a WASM heap address; [bufLen] is its byte length.
  /// Returns the required buffer length (including null terminator).
  @JS('_FPDFAction_GetURIPath')
  external int fpdfActionGetURIPath(
    int doc,
    int action,
    int buffer,
    int bufLen,
  );

  // --- Bookmarks / TOC (PR 2e) ---

  /// Returns the first child of [bookmark], or 0 if none.
  ///
  /// Pass 0 for [bookmark] to get the first top-level bookmark.
  @JS('_FPDFBookmark_GetFirstChild')
  external int fpdfBookmarkGetFirstChild(int doc, int bookmark);

  /// Returns the next sibling of [bookmark], or 0 if none.
  @JS('_FPDFBookmark_GetNextSibling')
  external int fpdfBookmarkGetNextSibling(int doc, int bookmark);

  /// Copies the title of [bookmark] into a UTF-16LE buffer.
  ///
  /// [buffer] is a WASM heap address; [bufLen] is its byte length.
  /// Returns the required length. Pass [buffer]=0 / [bufLen]=0 for the first
  /// call.
  @JS('_FPDFBookmark_GetTitle')
  external int fpdfBookmarkGetTitle(int bookmark, int buffer, int bufLen);

  /// Returns the destination associated with [bookmark], or 0 if none.
  @JS('_FPDFBookmark_GetDest')
  external int fpdfBookmarkGetDest(int doc, int bookmark);

  /// Returns the action associated with [bookmark], or 0 if none.
  @JS('_FPDFBookmark_GetAction')
  external int fpdfBookmarkGetAction(int bookmark);

  /// Returns the page index for a destination, or -1 if unknown.
  @JS('_FPDFDest_GetDestPageIndex')
  external int fpdfDestGetDestPageIndex(int doc, int dest);

  /// Writes the XYZ location for a destination into out-parameters.
  ///
  /// All output pointers are WASM heap addresses:
  ///   [hasXVal], [hasYVal], [hasZoomVal] — each a 4-byte FPDF_BOOL (int32).
  ///   [x], [y], [zoom] — each a 4-byte FS_FLOAT (float32).
  ///
  /// Returns non-zero when successful (PDFDEST_VIEW_XYZ).
  @JS('_FPDFDest_GetLocationInPage')
  external int fpdfDestGetLocationInPage(
    int dest,
    int hasXVal,
    int hasYVal,
    int hasZoomVal,
    int x,
    int y,
    int zoom,
  );

  // --- Images (PR 2e) ---

  /// Returns the number of objects on [page].
  @JS('_FPDFPage_CountObjects')
  external int fpdfPageCountObjects(int page);

  /// Returns the object at [index] on [page], or 0.
  @JS('_FPDFPage_GetObject')
  external int fpdfPageGetObject(int page, int index);

  /// Returns the type of [pageObj] (FPDF_PAGEOBJ_* constant).
  ///
  /// FPDF_PAGEOBJ_IMAGE = 3.
  @JS('_FPDFPageObj_GetType')
  external int fpdfPageObjGetType(int pageObj);

  /// Fills the [metadata] struct (28-byte FPDF_IMAGEOBJ_METADATA) for
  /// [imageObj]. [page] is the page that owns the object. Returns 1 on
  /// success.
  @JS('_FPDFImageObj_GetImageMetadata')
  external int fpdfImageObjGetImageMetadata(
    int imageObj,
    int page,
    int metadata,
  );

  /// Returns an FPDF_BITMAP of the composited image in [imageObj], or 0.
  ///
  /// [doc] and [page] provide context for compositing. The caller must
  /// destroy the returned bitmap with [fpdfBitmapDestroy].
  @JS('_FPDFImageObj_GetRenderedBitmap')
  external int fpdfImageObjGetRenderedBitmap(int doc, int page, int imageObj);

  /// Returns the count of compression filters on [imageObj].
  @JS('_FPDFImageObj_GetImageFilterCount')
  external int fpdfImageObjGetImageFilterCount(int imageObj);

  /// Copies filter name [index] for [imageObj] into a byte buffer.
  ///
  /// [buffer] is a WASM heap address; [bufLen] is its byte length (including
  /// the null terminator). Returns the required length. Pass [buffer]=0 /
  /// [bufLen]=0 for the first call.
  @JS('_FPDFImageObj_GetImageFilter')
  external int fpdfImageObjGetImageFilter(
    int imageObj,
    int index,
    int buffer,
    int bufLen,
  );

  /// Writes the axis-aligned bounding box of [pageObj] into four float32
  /// output addresses: [left], [bottom], [right], [top].
  ///
  /// Each address must hold 4 bytes (float32). Read via HEAPF32.
  /// Returns non-zero on success.
  @JS('_FPDFPageObj_GetBounds')
  external int fpdfPageObjGetBounds(
    int pageObj,
    int left,
    int bottom,
    int right,
    int top,
  );
}
