# Image Extraction

## Overview

The image extraction API allows a caller to enumerate every raster image object
embedded in a PDF document, inspect each image's metadata (dimensions, DPI,
colourspace, compression filters), and retrieve its rendered BGRA pixel data.
Extraction is available on all native platforms (iOS, Android, macOS, Windows,
Linux) via PDFium FFI. On web the API throws `UnsupportedError` — consistent
with the rest of the library — because PDFium WASM support for image rendering
is not yet available.

The primary use cases are:

- Extracting embedded photographs or diagrams for display or storage.
- Inspecting image metadata (DPI, colourspace) for quality assurance.
- Detecting scanned pages by examining image dimensions relative to page size.

## Public API

### `PdfColorspace`

Typed enumeration of PDF colourspace values, mapped from the PDFium
`FPDF_COLORSPACE_*` constants. Raw integer constants are not exposed in the
public API.

| Value | Description |
|-------|-------------|
| `unknown` | Unrecognised or absent colourspace. |
| `deviceGray` | DeviceGray (monochrome). |
| `deviceRgb` | DeviceRGB. |
| `deviceCmyk` | DeviceCMYK. |
| `calGray` | CIE-calibrated monochrome. |
| `calRgb` | CIE-calibrated RGB. |
| `lab` | CIE L\*a\*b\*. |
| `iccBased` | ICC profile-based colourspace. |
| `separation` | Separation (spot colour). |
| `deviceN` | DeviceN (multi-component spot). |
| `indexed` | Indexed (palette). |
| `pattern` | Pattern. |

### `PdfImageMetadata`

Immutable value type carrying the intrinsic properties of an image as stored in
the PDF.

| Property | Type | Description |
|----------|------|-------------|
| `width` | `int` | Source pixel width (before any page transformation). |
| `height` | `int` | Source pixel height. |
| `horizontalDpi` | `double` | Horizontal resolution in dots per inch. |
| `verticalDpi` | `double` | Vertical resolution in dots per inch. |
| `bitsPerPixel` | `int` | Bit depth per pixel (e.g. 1 for masks, 8 for greyscale, 24 for RGB). |
| `colorspace` | `PdfColorspace` | Colourspace of the image data. |
| `markedContentId` | `int` | Marked-content identifier (links to the PDF structure tree for alt-text lookup); `-1` when absent. |

`PdfImageMetadata` implements `==` and `hashCode` based on all fields, and
provides a `toString()` for debugging.

### `PdfImage`

Immutable value type representing a single image object on a PDF page.

| Property | Type | Description |
|----------|------|-------------|
| `pageIndex` | `int` | 0-based page index. |
| `objectIndex` | `int` | 0-based position of this object in the page's object list. Stable within a `PdfDocument` session; use with `PdfDocument.renderImage`. |
| `metadata` | `PdfImageMetadata` | Intrinsic image properties. |
| `bounds` | `PdfRect` | Axis-aligned bounding box in PDF user-space (origin bottom-left). |
| `filters` | `List<String>` | Compression filter names in order (e.g. `['DCTDecode']`). Empty when no filter is present. |
| `bgra` | `Uint8List?` | Rendered BGRA pixel bytes. `null` unless `extractImages` was called with `includeBitmap: true`. |
| `bitmapWidth` | `int?` | Rendered pixel width. May differ from `metadata.width` after page-level transforms. `null` when `bgra` is null. |
| `bitmapHeight` | `int?` | Rendered pixel height. `null` when `bgra` is null. |

Equality is based on all fields **except** `bgra` (pixel data is excluded from
comparison to keep equality fast and allocation-free). `hashCode` and
`toString()` follow the same convention.

**Image masks:** Image objects with `metadata.bitsPerPixel == 1` are stencil
masks. They appear in the `extractImages` output and are not suppressed
automatically. Callers can identify them via `metadata.bitsPerPixel`. Note
that `FPDFImageObj_GetRenderedBitmap` composites the mask when rendering the
owning image; the mask object itself may return `null` from `renderImage`.

### `PdfImageBitmap`

Immutable value type returned by `PdfDocument.renderImage`. All fields are
non-nullable.

| Property | Type | Description |
|----------|------|-------------|
| `bgra` | `Uint8List` | Rendered BGRA pixel bytes. Length equals `width * height * 4`. |
| `width` | `int` | Rendered pixel width. |
| `height` | `int` | Rendered pixel height. |

Equality and `hashCode` are based on `width` and `height` only (pixel data
excluded for performance). `toString()` includes all three fields.

### `PdfPageImages`

Immutable container for the image objects on a single page.

| Property | Type | Description |
|----------|------|-------------|
| `pageIndex` | `int` | 0-based page index. |
| `images` | `List<PdfImage>` | Image objects found on this page, in page-object-list order. Empty when the page has no image objects. |

### Image extraction methods on `PdfDocument`

| Member | Description |
|--------|-------------|
| `extractImages({int? pageIndex, bool includeBitmap = false})` | `Stream<PdfPageImages>` — yields one `PdfPageImages` per page. All pages are yielded when `pageIndex` is null; exactly one page when specified. When `includeBitmap` is false (the default) the `bgra`, `bitmapWidth`, and `bitmapHeight` fields on each `PdfImage` are null. |
| `renderImage(int pageIndex, int objectIndex)` | `Future<PdfImageBitmap?>` — fetches the rendered bitmap for a specific image object on demand. Returns `null` when the object has no renderable bitmap (e.g. stencil mask objects). Throws `RangeError` for an out-of-range `pageIndex` or for an `objectIndex` that does not identify an image object. Throws `StateError` if the document has been closed. |

## Behaviour by scenario

| Scenario | Behaviour |
|----------|-----------|
| Page with no images | `PdfPageImages.images` is an empty list; no error or exception. |
| `extractImages(includeBitmap: false)` | `bgra`, `bitmapWidth`, `bitmapHeight` on every `PdfImage` are `null`. |
| `extractImages(includeBitmap: true)` | `bgra` is a `Uint8List` of length `bitmapWidth * bitmapHeight * 4`; all three fields are non-null for every image that has a renderable bitmap. |
| `renderImage` on a valid image | Returns `PdfImageBitmap` with `bgra.length == width * height * 4`. |
| `renderImage` on a stencil mask | Returns `null` (PDFium `GetRenderedBitmap` returns null for mask-only objects). |
| `renderImage` with out-of-range `pageIndex` | Throws `RangeError`. |
| `renderImage` with `objectIndex` not an image | Throws `RangeError`. |
| `renderImage` after `close()` | Throws `StateError`. |
| `extractImages` with out-of-range `pageIndex` | Stream emits an error event and terminates; no crash. |
| `FPDFImageObj_GetImageMetadata` returns false | Image object is skipped silently; a warning is logged in debug mode. |
| `FPDFPageObj_GetBounds` returns false | `bounds` is set to a zero `PdfRect`; image is still included in the output. |
| Multi-page document | `extractImages()` yields one `PdfPageImages` per page in ascending order. |
| `close()` during active stream | Stream terminates cleanly; all page-level native handles are released. |
| Web platform | Both `extractImages` and `renderImage` throw `UnsupportedError`. |
| Stub/unsupported platform | Both methods throw `UnsupportedError`. |
| Password-protected PDF | `PdfDocument.fromBytes` throws `PdfExtractionException(PdfError.passwordRequired)` before image extraction is attempted. |
| Corrupt / non-PDF bytes | `PdfDocument.fromBytes` throws `PdfExtractionException(PdfError.invalidDocument)`. |

## Stream lifecycle

Cancelling the `extractImages()` subscription immediately releases all
page-level native resources for the current page. `PdfDocument.close()`
terminates any active `extractImages()` stream and releases all its handles
before closing the document handle. Callers do not need to cancel the stream
manually before calling `close()`.

The `renderImage()` future is a single isolate round-trip:

1. `FPDF_LoadPage` — open the page handle.
2. `FPDFPage_GetObject(page, objectIndex)` — O(1) index access.
3. Verify object type is `FPDF_PAGEOBJ_IMAGE`.
4. `FPDFImageObj_GetRenderedBitmap` — composite the image with transforms and mask.
5. Copy BGRA bytes into a `Uint8List`, accounting for stride padding.
6. `FPDFBitmap_Destroy` and `FPDF_ClosePage` — release native handles.
7. Return `PdfImageBitmap` (or `null`).

No native handle crosses the isolate boundary; `objectIndex` is a plain integer.

## Platform notes

On native platforms (iOS, Android, macOS, Windows, Linux) all PDFium calls run
on the `PdfiumIsolate` — a process-wide singleton isolate that owns the PDFium
library handle and serialises all FFI calls. The caller's isolate (typically the
UI isolate) is never blocked.

On web, both `extractImages` and `renderImage` throw `UnsupportedError`. Web
support requires PDFium compiled to WebAssembly with `fpdf_edit.h` exports, and
is deferred to a future release.

## Coordinate system

`PdfImage.bounds` is an axis-aligned bounding box in PDF user-space. PDF origin
is bottom-left; Flutter/screen origin is top-left. Use `FPDF_PageToDevice` /
`FPDF_DeviceToPage` for coordinate conversion when mapping bounds to screen
coordinates. See `PdfRect` for the field definitions (`left`, `bottom`, `right`,
`top`).

The rendered bitmap dimensions (`bitmapWidth`, `bitmapHeight`) reflect the
composited size after the page-level transform is applied and may differ from
the intrinsic `metadata.width` / `metadata.height`.

## Limitations

### Inline images

Inline images (PDF operator `BI … ID … EI`) are surfaced by PDFium as regular
`FPDF_PAGEOBJ_IMAGE` objects with the same type constant. No special handling is
required; they appear in the `extractImages` output alongside stream-based images.

### Raw and decoded byte access

`FPDFImageObj_GetImageDataRaw` (compressed bytes) and
`FPDFImageObj_GetImageDataDecoded` (uncompressed bytes) are not exposed in v1.
Only the composited rendered bitmap is available. Raw access is deferred to a
follow-on plan.

### ICC profile data

`FPDFImageObj_GetIccProfileDataDecoded` is not exposed in v1. The
`markedContentId` field on `PdfImageMetadata` allows callers to look up ICC
profile data via the structure tree (`fpdf_structtree.h`) independently; that
path is also out of scope here.

### Image mask objects

Stencil mask objects (`bitsPerPixel == 1`) appear in the output and are not
filtered automatically. `renderImage` may return `null` for these objects
because PDFium's `GetRenderedBitmap` returns null for mask-only objects. Callers
should gate rendering on `metadata.bitsPerPixel > 1` when masks are not wanted.

### Memory usage with `includeBitmap: true`

A full-resolution photograph at 300 DPI on an A4 page can produce a BGRA bitmap
of around 70–100 MB. Calling `extractImages(includeBitmap: true)` on a
document with many such pages will allocate one `Uint8List` per image inside the
isolate before streaming results to the caller. For large documents, prefer
`extractImages(includeBitmap: false)` combined with selective `renderImage`
calls gated on `metadata.width * metadata.height`.
