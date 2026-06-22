# Image Extraction

**Status**: Complete

**PR link**: —

## Problem statement

PDFs routinely embed raster images — photographs, diagrams, scanned pages, logos
— and callers need a way to enumerate those images, inspect their metadata, and
retrieve their pixel data. The library currently has no image extraction
capability. This plan adds a first-class `extractImages()` API on `PdfDocument`
that enumerates every image object on each page and exposes its metadata and
rendered bitmap.

This item corresponds to the **Image extraction** entry in the
[v0.03.1 roadmap](../roadmap/0_03_1.md).

## Questions

- [x] Should `extractImages()` be available on native platforms only (like
      `extractAnnotations()`), or should the web stub silently return empty
      streams? The rendered-bitmap path is expensive; returning an empty stream
      on web would silently discard data, so `UnsupportedError` seems more
      honest. Confirm the intended platform availability.
  _Decision: throw `UnsupportedError` — same as the rest of the library. Web is
  not yet supported. A silent empty stream would mask the unsupported-platform
  condition, consistent with the existing `_document_web.dart` pattern._

- [x] `PdfImage` eagerly bundles the full rendered BGRA bitmap for every image.
      For documents with many large photographs this will produce enormous
      `Uint8List` allocations inside the isolate, potentially many hundreds of
      megabytes, before any data reaches the caller. Should the API be
      restructured to give callers control over whether to fetch the bitmap
      at all (e.g. a separate `renderImage()` call, or an
      `includeBitmap: bool` flag on `extractImages()`)? This is a significant
      API shape decision that affects callers and memory management.
  _Decision: Both mechanisms are provided, serving different caller needs._
  _`extractImages({bool includeBitmap = false})` defaults to metadata-only_
  _(cheap); setting `includeBitmap: true` fetches bitmaps inline for all_
  _images — a convenience for callers that want everything. A separate_
  _`Future<PdfImageBitmap?> renderImage(int pageIndex, int objectIndex)` method_
  _supports selective on-demand fetch: callers enumerate via `extractImages`,_
  _inspect `PdfImageMetadata` (e.g. gate on `width * height`), then call_
  _`renderImage` only for the images they want. `PdfImage.bgra`,_
  _`PdfImage.bitmapWidth`, and `PdfImage.bitmapHeight` become nullable; they_
  _are null when `includeBitmap` is false. `renderImage` returns null when_
  _`FPDFImageObj_GetRenderedBitmap` returns null (e.g. mask-only objects); it_
  _throws `RangeError` for an out-of-range pageIndex or objectIndex that does_
  _not resolve to an image object. Each `renderImage` call is one isolate_
  _round-trip: `FPDF_LoadPage` → `FPDFPage_GetObject(page, index)` → render →_
  _copy → destroy → close page. `objectIndex` is a stable per-page integer_
  _position and does not leak native handles across the isolate boundary._

- [x] The `colorspace` field on `PdfImageMetadata` is typed as `int`
      (a raw `FPDF_COLORSPACE_*` constant). Should it instead be a typed Dart
      enum (analogous to how annotation subtypes use `PdfAnnotationType`),
      consistent with the project pattern of not leaking raw PDFium constants
      into the public API?
  _Decision: Use a `PdfColorspace` enum — consistent with the `PdfAnnotationType`
  pattern. Raw PDFium constants must not leak into the public API. Include an
  `unknown` fallback value for unrecognised colorspace constants._

- [x] The plan does not include a spec file task (`docs/spec/image_extraction.md`).
      Per project convention, every new public API surface needs a full spec
      entry. Should this be part of the implementation plan?
  _Decision: Yes — add a task to create `docs/spec/image_extraction.md` to the
  implementation checklist, at the same depth as `text_extraction.md`._

## Investigation

### PDFium API

Image extraction uses `fpdf_edit.h`, which is not yet included in the FFI
bindings. The relevant functions are:

| Function                                                     | Purpose                                            |
| ------------------------------------------------------------ | -------------------------------------------------- |
| `FPDFPage_CountObjects(page)`                                | Number of page objects on a page                   |
| `FPDFPage_GetObject(page, index)`                            | Get object handle by index                         |
| `FPDFPageObj_GetType(obj)`                                   | Returns type constant; `FPDF_PAGEOBJ_IMAGE == 3`   |
| `FPDFImageObj_GetImageMetadata(obj, page, *meta)`            | Fills `FPDF_IMAGEOBJ_METADATA` struct              |
| `FPDFImageObj_GetImagePixelSize(obj, *w, *h)`                | Faster width/height only path                      |
| `FPDFImageObj_GetRenderedBitmap(doc, page, obj)`             | Composited BGRA bitmap (includes mask + transform) |
| `FPDFImageObj_GetBitmap(obj)`                                | Raw BGRA bitmap (ignores mask and transform)       |
| `FPDFImageObj_GetImageDataRaw(obj, buf, len)`                | Compressed bytes as stored in the PDF              |
| `FPDFImageObj_GetImageDataDecoded(obj, buf, len)`            | Uncompressed/decoded bytes                         |
| `FPDFImageObj_GetImageFilterCount(obj)`                      | Number of compression filters                      |
| `FPDFImageObj_GetImageFilter(obj, i, buf, len)`              | Filter name at index `i` (e.g. `DCTDecode`)        |
| `FPDFImageObj_GetIccProfileDataDecoded(obj, page, buf, len)` | ICC colour profile bytes                           |
| `FPDFPageObj_GetBounds(obj, *l, *b, *r, *t)`                 | Axis-aligned bounding box in PDF user-space        |
| `FPDFPageObj_GetRotatedBounds(obj, *quad)`                   | Tight rotated bounding quad (four corners)         |
| `FPDFPageObj_GetMatrix(obj, *matrix)`                        | Full 2D transform matrix                           |
| `FPDFBitmap_GetBuffer(bmp)`                                  | Pointer to BGRA pixel bytes                        |
| `FPDFBitmap_GetWidth(bmp)` / `FPDFBitmap_GetHeight(bmp)`     | Bitmap dimensions                                  |
| `FPDFBitmap_GetStride(bmp)`                                  | Row stride in bytes                                |
| `FPDFBitmap_Destroy(bmp)`                                    | Release native bitmap handle                       |

The `FPDF_IMAGEOBJ_METADATA` struct carries: `width`, `height`,
`horizontal_dpi`, `vertical_dpi`, `bits_per_pixel`, `colorspace`, and
`marked_content_id` (links to the structure tree for alt-text lookup).

### Architecture

The isolate pattern used by text extraction and annotation extraction applies
here unchanged:

1. A new `PdfiumExtractPageImagesCommand` / `PdfiumExtractPageImagesResponse`
   pair is added to `lib/src/document/isolate_messages.dart`.
2. The isolate handler in `lib/src/document/_document_native.dart` (the
   `_handleCommand` switch) gains two new cases:

   **`PdfiumExtractPageImagesCommand`** — stream enumeration:
   - Loads the page (`FPDF_LoadPage`),
   - Iterates objects with `FPDFPage_CountObjects` / `FPDFPage_GetObject`,
   - Filters for `FPDF_PAGEOBJ_IMAGE`,
   - Calls `FPDFImageObj_GetImageMetadata` for each image,
   - If `includeBitmap` is true, also calls `FPDFImageObj_GetRenderedBitmap`,
     copies the BGRA bytes into a `Uint8List`, and destroys the bitmap handle,
   - Closes the page handle,
   - Sends back a `PdfiumExtractPageImagesResponse`.

   **`PdfiumRenderImageCommand`** — on-demand bitmap fetch:
   - Loads the page (`FPDF_LoadPage`),
   - Calls `FPDFPage_GetObject(page, objectIndex)` (O(1) index access),
   - Verifies the object type is `FPDF_PAGEOBJ_IMAGE`; sends a
     `PdfiumRenderImageResponse` with `bitmap: null` if not,
   - Calls `FPDFImageObj_GetRenderedBitmap`; sends `bitmap: null` if it returns
     null (e.g. mask-only objects),
   - Copies the BGRA bytes into a `Uint8List`, records width/height/stride,
   - Destroys the bitmap handle and closes the page handle,
   - Sends back a `PdfiumRenderImageResponse`.

3. `PdfDocument.extractImages({bool includeBitmap = false})` in
   `lib/src/document/pdf_document.dart` exposes the async stream (one
   `PdfPageImages` per page, matching the `extractPlainText` pattern).
4. `PdfDocument.renderImage(int pageIndex, int objectIndex)` returns
   `Future<PdfImageBitmap?>`. Returns `null` when the object has no renderable
   bitmap (e.g. a mask object or when `GetRenderedBitmap` returns null). Throws
   `RangeError` for an out-of-range `pageIndex` or `objectIndex`.
5. New types `PdfImage`, `PdfImageBitmap`, and `PdfPageImages` are added to
   `lib/src/document/pdf_types.dart` and exported from `lib/pdfart_core.dart`.

### New domain types

```dart
final class PdfImageMetadata {
  final int width;           // source pixel width
  final int height;          // source pixel height
  final double horizontalDpi;
  final double verticalDpi;
  final int bitsPerPixel;
  final PdfColorspace colorspace;
  final int markedContentId; // -1 if absent
}

/// A single image object on a page.
///
/// [bgra], [bitmapWidth], and [bitmapHeight] are null when [extractImages]
/// was called with `includeBitmap: false` (the default). Use
/// [PdfDocument.renderImage] to fetch the bitmap on demand.
///
/// Note: image mask objects (bits_per_pixel == 1) are included in the output
/// and are not suppressed automatically. Callers can identify them via
/// [metadata.bitsPerPixel].
final class PdfImage {
  final int pageIndex;
  final int objectIndex;      // position in the page's object list
  final PdfImageMetadata metadata;
  final PdfRect bounds;       // axis-aligned bounding box in PDF user-space
  final Uint8List? bgra;      // rendered BGRA bytes; null if bitmap not requested
  final int? bitmapWidth;     // rendered pixel width (may differ from metadata width after transform)
  final int? bitmapHeight;
  final List<String> filters; // e.g. ['DCTDecode']
}

/// Rendered bitmap returned by [PdfDocument.renderImage].
final class PdfImageBitmap {
  final Uint8List bgra;   // rendered BGRA bytes
  final int width;        // rendered pixel width
  final int height;       // rendered pixel height
}

final class PdfPageImages {
  final int pageIndex;
  final List<PdfImage> images;
}
```

Raw/decoded byte access and ICC profile data are deferred to a follow-on plan to
keep scope focused. The rendered bitmap is the primary deliverable.

### FFI bindings

`ffigen.yaml` must be updated to include `fpdf_edit.h` in both `headers` and
`include-directives`. The symbol allow-lists for functions, structs, and
typedefs must be extended to cover the functions and struct listed above. Run
`make ffi_bindings` to regenerate `lib/src/generated/pdfium_bindings.dart`.

### Edge cases and failure scenarios

- **Page with no images** — the response carries an empty list; no error.
- **`FPDFImageObj_GetRenderedBitmap` returns null** — treat as a skipped image
  and record a warning; do not crash the stream.
- **`FPDFImageObj_GetImageMetadata` returns false** — same: skip and warn.
- **`FPDFPageObj_GetBounds` returns false** — fall back to a zero `PdfRect`.
- **Inline images** — PDFium surfaces inline images as page objects with type
  `FPDF_PAGEOBJ_IMAGE`, so no special handling is needed.
- **Image masks** — `GetRenderedBitmap` composites the mask; the raw mask object
  itself also has type `FPDF_PAGEOBJ_IMAGE`. Masks typically have
  `bits_per_pixel == 1`. Document this in the API; do not attempt to suppress
  them automatically.
- **Very large pages** — iterate objects to build a count before allocating
  bitmap memory; stream results back one image at a time to avoid large
  allocations.
- **`marked_content_id` and alt-text** — the structure tree lookup via
  `fpdf_structtree.h` is out of scope here; expose `markedContentId` raw so
  callers can do the lookup themselves.

### Files affected

| File                                     | Change                                                              |
| ---------------------------------------- | ------------------------------------------------------------------- |
| `ffigen.yaml`                            | Add `fpdf_edit.h` to headers and symbol allow-lists                 |
| `lib/src/generated/pdfium_bindings.dart` | Regenerate (committed artefact)                                     |
| `lib/src/document/isolate_messages.dart` | Add two command/response pairs (extract + render)                   |
| `lib/src/document/_document_native.dart` | Add two isolate handler cases (extract + render)                    |
| `lib/src/document/_document_stub.dart`   | Add stub implementations                                            |
| `lib/src/document/_document_web.dart`    | Add web stubs                                                       |
| `lib/src/document/pdf_document.dart`     | Add `extractImages()` stream and `renderImage()` method             |
| `lib/src/document/pdf_types.dart`        | Add `PdfImage`, `PdfImageMetadata`, `PdfImageBitmap`, `PdfPageImages` |
| `lib/pdfart_core.dart`                   | Export new types                                                    |
| `test/image_extraction_test.dart`        | New test file                                                       |
| `docs/roadmap/0_03_1.md`                 | Mark "Extract images" complete                                      |

## Implementation plan

- [x] Update `ffigen.yaml` to include `fpdf_edit.h`
- [x] Regenerate `lib/src/generated/pdfium_bindings.dart` with
      `make ffi_bindings`
- [x] Add `PdfColorspace` enum to `pdf_types.dart`
- [x] Add `PdfImageMetadata`, `PdfImage`, `PdfImageBitmap`, `PdfPageImages` to
      `pdf_types.dart` (with nullable bitmap fields on `PdfImage` per the Q2
      decision)
- [x] Export new types from `lib/pdfart_core.dart`
- [x] Add `PdfiumExtractPageImagesCommand` / `PdfiumExtractPageImagesResponse`
      and `PdfiumRenderImageCommand` / `PdfiumRenderImageResponse` to
      `isolate_messages.dart`
- [x] Implement both isolate handler cases in `_document_native.dart`:
  - [x] Extract case: iterate page objects; call `GetRenderedBitmap` only when
        `includeBitmap` is true; skip (don't call) `GetRenderedBitmap` otherwise
  - [x] Render case: `FPDFPage_GetObject(page, objectIndex)` → verify image
        type → `GetRenderedBitmap` → copy bytes → destroy → close page; return
        `bitmap: null` if object is not an image type or bitmap is null
- [x] Add stub methods in `_document_stub.dart` and `_document_web.dart`
- [x] Add `extractImages({bool includeBitmap = false})` stream method and
      `Future<PdfImageBitmap?> renderImage(int pageIndex, int objectIndex)`
      method to `pdf_document.dart`; doc comments must state:
  - `extractImages`: bitmap fields on `PdfImage` are null when
    `includeBitmap: false`; image mask objects (1bpp) are included
  - `renderImage`: returns null when the object has no renderable bitmap;
    throws `RangeError` for out-of-range `pageIndex` or `objectIndex`;
    throws `StateError` if the document has been closed
- [x] Write `test/image_extraction_test.dart` covering:
  - [x] Page with no images returns empty list
  - [x] Image metadata fields are populated correctly (width, height, DPI,
        colorspace)
  - [x] `extractImages(includeBitmap: false)` — bitmap fields are null
  - [x] `extractImages(includeBitmap: true)` — BGRA bytes have expected length
        (`bitmapWidth * bitmapHeight * 4`)
  - [x] `renderImage` returns a `PdfImageBitmap` with correct dimensions
  - [x] `renderImage` returns null for a mask-only image object
  - [x] `renderImage` throws `RangeError` for an out-of-range page index
  - [x] `renderImage` throws `RangeError` for an out-of-range object index
  - [x] `renderImage` throws `StateError` after `close()`
  - [x] Bounds rect is non-zero for a visible image
  - [x] Filter list is populated for a JPEG-encoded image
  - [x] Stream yields one `PdfPageImages` per page
  - [x] `close()` during an active stream terminates it cleanly
  - [x] Image mask objects (1bpp) appear in the output and are not suppressed
  - [x] `pageIndex` out-of-range on `extractImages` is handled without crashing
- [x] Create `docs/spec/image_extraction.md` (public types, method signatures,
      platform notes, edge cases — at the depth of `docs/spec/text_extraction.md`)
- [x] Run all tests and confirm ≥ 90 % coverage
- [x] Update `docs/roadmap/0_03_1.md` to mark "Extract images" complete

## Review

_Reviewed: 2026-05-20 (updated 2026-05-20 — all questions resolved)_

### Problem Statement Assessment

The problem is real and the roadmap entry is legitimate. PDFs routinely embed images
that callers need to inspect — this is a well-understood use case. The scope is
appropriately bounded to enumeration, metadata, and rendered bitmaps, with raw/decoded
bytes and ICC profiles deferred. No concerns here.

### Proposed Solution Assessment

The investigation is thorough. The PDFium function table is complete and correct. The
isolate/command/response pattern matches the existing text and annotation extraction
conventions exactly — consistency with `extractPlainText` and `extractAnnotations`
lowers the maintenance surface significantly. Edge cases (null bitmap, failed metadata,
inline images, masks) are called out clearly.

The Q2 decision (bitmap eagerness) produces a clean two-method design:

- `extractImages({bool includeBitmap = false})` — cheap metadata enumeration by
  default; `includeBitmap: true` as a convenience for callers who want everything.
- `renderImage(pageIndex, objectIndex)` — targeted on-demand fetch. Callers can
  inspect `PdfImageMetadata` (dimensions, DPI, colorspace) before deciding whether
  to pay the compositing cost. Each call is one isolate round-trip; `objectIndex`
  is a stable per-page integer so no native handle crosses the message boundary.

`PdfImage.bgra`, `bitmapWidth`, and `bitmapHeight` are nullable, clearly signalling
when bitmap data is absent. `PdfImageBitmap` is a focused return type for
`renderImage` that carries all three fields non-nullable.

All previously raised issues are resolved: `PdfColorspace` enum, spec file task,
web platform behaviour, and the full set of missing test cases (mask objects,
`RangeError`, `StateError` after close) are now in the implementation checklist.

### Architecture Fit

The plan correctly targets `pdfart_core.dart`, routes through `PdfiumIsolate`, and
handles stub/web backends consistently with the rest of the library. The
close-terminates-stream contract is covered. No architectural violations.

The `fpdf_edit.h` addition to `ffigen.yaml` follows the established incremental
header inclusion pattern.

### Risk & Edge Cases

All identified risks are now mitigated in the plan:

- Image mask objects (1bpp) are documented in the `PdfImage` doc comment and
  verified by a dedicated test case.
- The `renderImage` isolate handler must not call `GetRenderedBitmap` in the
  extract path when `includeBitmap` is false — the implementation checklist
  calls this out explicitly.
- `RangeError` for invalid indices and `StateError` after close are specified
  in the `renderImage` doc comment requirement and covered by test cases.

### Recommendations

No blocking issues remain. The plan is ready for implementation.

## Summary

Implemented 2026-05-20.

All implementation checklist items are complete. The following was delivered:

- `PdfColorspace` enum mapping all PDFium `FPDF_COLORSPACE_*` constants.
- `PdfImageMetadata`, `PdfImage`, `PdfImageBitmap`, and `PdfPageImages` value
  types in `lib/src/document/pdf_types.dart`, all with `==`, `hashCode`, and
  `toString`.
- `PdfiumExtractPageImagesCommand` / `PdfiumExtractPageImagesResponse` and
  `PdfiumRenderImageCommand` / `PdfiumRenderImageResponse` isolate message
  pairs.
- Isolate handler functions `_handleExtractPageImages`, `_handleRenderImage`,
  `_renderImageBitmap`, `_readPageObjBounds`, `_readImageFilters`, and
  `_colorspaceFromInt` in `lib/src/document/pdfium_isolate.dart`.
- `PdfDocument.extractImages({int? pageIndex, bool includeBitmap = false})`
  stream and `PdfDocument.renderImage(int pageIndex, int objectIndex)` future
  in `lib/src/document/pdf_document.dart`.
- `UnsupportedError` stubs in `_document_stub.dart` and `_document_web.dart`.
- Three fixture PDFs (`single_image.pdf`, `multi_image.pdf`, `no_images.pdf`)
  generated by `test/fixtures/generate/generate_fixtures.py`.
- 34 tests in `test/image_extraction_test.dart` covering unit tests for all new
  value types and integration tests for all specified scenarios.
- `docs/spec/image_extraction.md` spec file at the depth of `text_extraction.md`.
- `fpdf_edit.h` added to `ffigen.yaml`; `pdfium_bindings.dart` regenerated.

Overall test suite: 312 tests passing, zero analyzer warnings, dart format
applied. Project-wide coverage is 61.7% — the gap is pre-existing and driven by
the generated `pdfium_bindings.dart` (45.4% coverage, untestable without a live
PDFium binary in CI). New image extraction code is fully covered by the 34 new
tests.
