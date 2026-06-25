# Page Rendering

## Overview

The page rendering API allows a caller to rasterise a PDF page into a
`dart:ui Image` for display in a Flutter widget tree. Rendering runs on the
shared `PdfiumIsolate` so the UI thread is never blocked. The API is available
on native platforms (iOS, Android, macOS, Windows, Linux) that can load the
PDFium dylib. On web and stub platforms the method throws `UnsupportedError`.

The primary use case is the `PdfPageView` Flutter widget, which wraps the
rendering API in a fit-to-width stateful widget suitable for inclusion in a
document viewer. Direct use of `getPageSize()` and `renderPage()` is also
supported for callers that need raw pixel buffers (e.g. thumbnail generation,
print preview).

## Public API

### `PdfPageSize`

An immutable value type representing the intrinsic size of a PDF page.

| Property / Method | Type | Description |
|-------------------|------|-------------|
| `widthPt` | `double` | Page width in PDF user units (points, 1 pt = 1/72 inch). |
| `heightPt` | `double` | Page height in PDF user units (points). |
| `aspectRatio` | `double` | `widthPt / heightPt`. Returns `1.0` on malformed pages where `heightPt` is zero. |
| `sizeForDpi(double dpi)` | `Size` | Returns pixel dimensions at the given DPI. Computed as `widthPt * dpi / 72` × `heightPt * dpi / 72`. Returns `Size.zero` when `dpi ≤ 0`. |

PDF user units are storage-level measurements, not tied to any screen or
rendering resolution. `sizeForDpi(72)` returns a `Size` numerically equal to
the point dimensions; `sizeForDpi(150)` returns the pixel dimensions needed
for 150 DPI rendering.

### `PdfRenderOptions`

Options controlling how `PdfDocument.renderPage()` rasterises the page.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `renderAnnotations` | `bool` | `true` | When true, maps to the PDFium `FPDF_ANNOT` flag — annotations (highlights, ink, stamps, etc.) are drawn on top of the page content. |
| `lcdText` | `bool` | `false` | When true, maps to `FPDF_LCD_TEXT` — sub-pixel text rendering. Produces sharper text on LCD screens but may cause colour fringing on non-LCD surfaces. |
| `backgroundColor` | `Color` | `Color(0xFFFFFFFF)` | Opaque white. The bitmap is filled with this colour before rendering, eliminating garbage pixels on transparent areas. |

The `backgroundColor` field uses `dart:ui Color` for Flutter interoperability;
the rendering pipeline converts it to PDFium's `0xAARRGGBB` integer format
internally.

**Note on zoom and scale:** `PdfRenderOptions` intentionally has no `scale`
field. The caller controls output resolution via the `pixelWidth` and
`pixelHeight` arguments on `renderPage()`. Zoom/scale as a *widget-level*
concern — including pinch-to-zoom, keyboard zoom, and accessibility scaling —
is deferred to a future plan and must be treated as an accessibility
requirement in that plan (keyboard zoom, `MediaQuery.disableAnimations`
gating, pinch-to-zoom with `ScaleGestureDetector`).

### Rendering methods on `PdfDocument`

| Method | Description |
|--------|-------------|
| `getPageSize(int pageIndex)` | `Future<PdfPageSize>` — returns the intrinsic size of the given page. |
| `renderPage(int pageIndex, int pixelWidth, int pixelHeight, {PdfRenderOptions options})` | `Future<ui.Image>` — rasterises the page at the given pixel dimensions. |

#### `getPageSize(int pageIndex)`

Returns the intrinsic size of the page at `pageIndex` (0-based).

**Throws:**
- `RangeError` if `pageIndex` is outside `[0, pageCount)`. Use `RangeError.checkValidIndex` semantics.
- `StateError` if `close()` has already been called.

#### `renderPage(int pageIndex, int pixelWidth, int pixelHeight, {PdfRenderOptions options = const PdfRenderOptions()})`

Rasterises the page at `pageIndex` into a `dart:ui Image` of exactly
`pixelWidth × pixelHeight` pixels. All PDFium calls run inside `PdfiumIsolate`;
only the `Uint8List` pixel buffer crosses the isolate boundary.

**Rendering pipeline (inside PdfiumIsolate):**
1. `FPDFBitmap_Create(pixelWidth, pixelHeight, hasAlpha=1)` — allocate a BGRA bitmap.
2. `FPDFBitmap_FillRect(bitmap, 0, 0, w, h, color)` — fill with `backgroundColor` (converted to `0xAARRGGBB`).
3. `FPDF_RenderPageBitmap(bitmap, page, 0, 0, w, h, 0, flags)` — rasterise. Flags are built from `renderAnnotations` and `lcdText`.
4. `FPDFBitmap_GetBuffer(bitmap)` — obtain raw pointer; copy `w × h × 4` bytes into a `Uint8List` **before** `FPDFBitmap_Destroy`.
5. `FPDFBitmap_Destroy(bitmap)` and `FPDF_ClosePage(page)` — release all native handles.

On the Flutter side the `Uint8List` is converted to a `dart:ui Image` via
`ImmutableBuffer.fromUint8List` → `ImageDescriptor.raw` →
`instantiateCodec` → `codec.getNextFrame()`. The BGRA pixel format maps to
`PixelFormat.bgra8888`.

**For sharp output on high-DPI displays,** multiply the widget's logical width
by `MediaQuery.devicePixelRatio` before passing `pixelWidth` to `renderPage`.
`PdfPageView` does this automatically.

**Throws:**
- `RangeError` if `pageIndex` is outside `[0, pageCount)`.
- `StateError` if `close()` has been called before or during the render. When `close()` is called while a render future is in flight, the future completes with `StateError` — consistent with the Dart convention for post-disposal access.
- `PdfiumException` if a PDFium native call fails unexpectedly (e.g. `FPDFBitmap_Create` returns null due to an out-of-memory condition).

The returned `ui.Image` is owned by the caller and must be disposed by calling
`ui.Image.dispose()` when no longer needed. `PdfPageView` disposes images
automatically.

### `getThumbnail(int pageIndex, {bool generateIfAbsent, int maxDimension})`

Returns a thumbnail image for the page at `pageIndex` (0-based).

#### Public API signature

```dart
Future<PdfThumbnail?> getThumbnail(
  int pageIndex, {
  bool generateIfAbsent = true,
  int maxDimension = 256,
})
```

`PdfThumbnail` carries `bgra` (compact BGRA pixel bytes), `width`, `height`,
and `source` (`PdfThumbnailSource.embedded` or `PdfThumbnailSource.rendered`).

#### Behaviour

1. **Embedded thumbnail present.** If the page has an embedded `/Thumb` stream,
   PDFium decodes it via `FPDFPage_GetThumbnailAsBitmap`. The bitmap is read,
   row padding is stripped, and the result is returned as a `PdfThumbnail` with
   `source: PdfThumbnailSource.embedded` at its native dimensions.
   `maxDimension` is ignored.

2. **No embedded thumbnail, `generateIfAbsent: true` (default).** The page is
   rendered via the existing `renderPageToBytes` pipeline. The render dimensions
   are computed by scaling the page's intrinsic PDF size (`getPageSize()`) so
   the longest edge equals `maxDimension` pixels, preserving aspect ratio and
   clamping the short edge to at minimum 1 pixel. The result is returned as a
   `PdfThumbnail` with `source: PdfThumbnailSource.rendered`.

3. **No embedded thumbnail, `generateIfAbsent: false`.** `null` is returned
   immediately without any render pass. Useful for callers that only want to
   surface natively-embedded previews.

#### `maxDimension` semantics

`maxDimension` is a **logical pixel budget** that applies only to the fallback
render path. Embedded thumbnails are returned at their native dimensions
regardless of `maxDimension`. On high-DPI displays, multiply `maxDimension` by
`MediaQuery.devicePixelRatio` before calling to obtain a retina-sharp fallback
render — this method cannot access `MediaQuery` as it lives in the pure-Dart
layer (`package:betto_pdfium/betto_pdfium.dart`).

#### Error contract

| Exception | Condition |
|-----------|-----------|
| `RangeError` | `pageIndex < 0` or `pageIndex >= pageCount`. |
| `ArgumentError` | `maxDimension ≤ 0`. |
| `StateError` | `close()` has been called before or during the call (including between the thumbnail round-trip and the fallback render pass). |
| `PdfiumException` | A PDFium native call fails unexpectedly (e.g. `FPDF_LoadPage` returns null, or a bitmap read error). |

Errors from the fallback `renderPageToBytes` call (`StateError`,
`PdfiumException`) are re-thrown directly — they are not wrapped.

#### Platform support

| Platform | Supported | Notes |
|----------|-----------|-------|
| macOS, iOS, Android, Windows, Linux | Yes | Via dart:ffi + PdfiumIsolate. |
| Web | No | Throws `UnsupportedError`. Both the embedded path (FFI) and fallback path are unavailable. |
| Stub | No | Throws `UnsupportedError`. |

### `PdfiumException`

A general-purpose exception for unexpected PDFium native failures.

| Property | Type | Description |
|----------|------|-------------|
| `message` | `String` | A descriptive message identifying the failed PDFium call and any available context. |

`PdfiumException` is thrown only for unexpected native failures (e.g. bitmap
allocation failure). Logical errors (out-of-range index, closed document) use
standard Dart exception types (`RangeError`, `StateError`).

### `PdfPageView`

A stateful Flutter widget that renders a single page of a `PdfDocument`
fit-to-width.

```dart
PdfPageView(
  document: doc,
  pageIndex: 0,
  options: PdfRenderOptions(renderAnnotations: false),
  semanticLabel: 'Research paper – page 1',
)
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `document` | `PdfDocument` | yes | The document to render. |
| `pageIndex` | `int` | yes | The zero-based page index to display. |
| `options` | `PdfRenderOptions` | no | Render options. Defaults to `PdfRenderOptions()`. |
| `semanticLabel` | `String?` | no | Accessibility label for the rendered canvas (e.g. the document title). Falls back to `"PDF page N"`. |

**Layout:** Uses `LayoutBuilder` to obtain the available logical width. The
widget renders at the full available width and derives the height from the
page's aspect ratio. The logical width is multiplied by
`MediaQuery.devicePixelRatio` when computing `pixelWidth` and `pixelHeight`
for the `renderPage()` call, producing sharp output on retina displays.

**Loading state:** A `CircularProgressIndicator` is shown while the render is
in flight. The spinner is suppressed when `MediaQuery.disableAnimations` is
true, consistent with accessibility preferences that reduce motion.

**Caching:** The last successfully rendered `ui.Image` is cached. A re-render
is triggered only when `pageIndex` changes, `document` changes, or the
available logical width changes by more than 2 pixels.

**In-flight cancellation:** If `pageIndex` (or `document`) changes while a
render is in flight, the in-flight result is silently discarded via a
generation counter. The new page's render starts immediately.

**Error handling:** `RangeError`, `StateError`, and `PdfiumException` from
`renderPage()` are caught and displayed as a centred error message. The widget
does not rethrow; the error persists until `pageIndex` or `document` changes.

**Accessibility:** All three states (loading, rendered, error) expose a
`Semantics` label. The rendered canvas is tagged as an image (`isImage: true`).
Provide a meaningful `semanticLabel` (e.g. the document file name or title)
for best screen-reader experience.

**Resource management:** Each `ui.Image` is disposed when replaced by a new
render or when the widget is disposed. The `PdfDocument` is owned by the
caller; `PdfPageView` never calls `close()` on it.

### `PdfViewerController`

A `ChangeNotifier` that holds all view-level state for a single open PDF: the
current page, zoom mode, annotation toggle, and active search matches.

```dart
final controller = PdfViewerController();

// Navigate to a page:
controller.setPage(2, pageCount: doc.pageCount);

// Change zoom mode:
controller.setZoom(ZoomMode.fitPage);

// Step zoom by 10 % relative to the current visual scale:
controller.setZoom(ZoomMode.custom, factor: controller.effectiveZoomFactor + 0.1);

// Toggle annotations:
controller.renderAnnotations = !controller.renderAnnotations;

// Apply search results from PdfSearchView:
controller.setSearchMatches(matches);
controller.clearSearch();

// Always dispose when the document is closed:
controller.dispose();
```

| Property / Method | Type | Description |
|---|---|---|
| `currentPage` | `int` | Zero-based index of the currently displayed page. Read-only; set via `setPage`. |
| `zoomMode` | `ZoomMode` | Current zoom mode: `fitPage`, `fitWidth`, or `custom`. |
| `zoomFactor` | `double` | Scale factor used when `zoomMode == ZoomMode.custom`. Relative to the available viewport width. |
| `effectiveZoomFactor` | `double` | The actual rendered scale as a fraction of viewport width, updated by `PdfPageViewer` after each render. Use this as the base when stepping zoom. |
| `renderAnnotations` | `bool` | Whether annotations are drawn on the page. Maps to `FPDF_ANNOT`. Default `true`. |
| `activeSearchMatches` | `List<PdfSearchMatch>` | Matches currently displayed as overlays by `PdfPageViewer`. |
| `searchQuery` | `String` | Last query typed in `PdfSearchView`; persists across tab switches. |
| `searchCompleted` | `bool` | Whether the last search stream completed. |
| `searchPageTexts` | `Map<int, String>` | Per-page extracted text cache populated by `PdfSearchView`. |
| `setPage(int, {int pageCount})` | `void` | Clamps to `[0, pageCount − 1]` and notifies. No-op when `pageCount ≤ 0`. |
| `nextPage({int pageCount})` | `void` | Advances one page; no-op at last page. |
| `previousPage()` | `void` | Moves back one page; no-op at page 0. |
| `setZoom(ZoomMode, {double factor})` | `void` | Sets mode and optional custom factor; notifies. |
| `setSearchMatches(List<PdfSearchMatch>)` | `void` | Replaces active matches; notifies so `PdfPageViewer` repaints overlays. |
| `clearSearch()` | `void` | Clears matches and resets all search persistence fields; notifies. |

**Ownership:** One controller per open document. The controller does not own the
`PdfDocument` handle; that is owned by the caller.

### `PdfPageViewer`

A stateful Flutter widget that renders a single PDF page with support for three
zoom modes and search-match overlays.

```dart
PdfPageViewer(
  document: doc,
  pageCount: pageCount,
  controller: controller,
  semanticLabel: 'Annual report, page 1',
)
```

| Property | Type | Required | Description |
|---|---|---|---|
| `document` | `PdfDocument` | yes | The document to render. |
| `pageCount` | `int` | yes | Total pages; used to validate page indices. |
| `controller` | `PdfViewerController` | yes | Drives zoom, page, annotations, and search overlays. |
| `semanticLabel` | `String?` | no | Accessibility label for the page canvas. |

**Zoom modes:**

| Mode | Canvas width | Scrolling |
|---|---|---|
| `fitPage` | `min(widthBudget, heightBudget × aspectRatio)` with 24 dp border | None |
| `fitWidth` | Full available width | Vertical via `SingleChildScrollView` |
| `custom` | `availableWidth × controller.zoomFactor` | Pan via `InteractiveViewer` |

After each successful render, `PdfPageViewer` writes
`renderLogicalWidth / logicalWidth` into `controller.effectiveZoomFactor` so the
toolbar zoom buttons can step from the actual visual scale.

**Search overlays:** For each `PdfSearchMatch` on the current page,
`PdfPageViewer` draws a translucent amber rectangle (50 % opacity) over the
match's bounding box. Coordinates are converted from PDF user space (bottom-left
origin) to Flutter screen space (top-left origin):

```
flutterX = pdfRect.left / pageWidthPt * widgetWidth
flutterY = (pageHeightPt − pdfRect.top) / pageHeightPt * widgetHeight
rectW    = (pdfRect.right − pdfRect.left) / pageWidthPt * widgetWidth
rectH    = (pdfRect.top − pdfRect.bottom) / pageHeightPt * widgetHeight
```

**In-flight cancellation:** A generation counter discards stale results when the
page, zoom, or document changes during an async render.

**Resource management:** `PdfPageViewer` disposes each `ui.Image` when it is
replaced or when the widget is disposed. It never calls `close()` on the
document.

## Platform support

| Platform | Rendering | Notes |
|----------|-----------|-------|
| macOS, iOS, Android, Windows, Linux | Supported | Via dart:ffi + PDFium dylib. |
| Web | Unsupported | Throws `UnsupportedError`. Web rendering is deferred to a future plan. |
| Stub | Unsupported | Throws `UnsupportedError`. |

## Coordinate system

PDF origin is bottom-left; Flutter/screen origin is top-left. For this phase
(display only, no hit-testing) the coordinate flip is invisible — PDFium
renders the page into the bitmap with the correct orientation. Hit-testing via
`FPDF_PageToDevice()` / `FPDF_DeviceToPage()` is deferred to a future
zoom/selection plan.

## Memory considerations

Each rendered page allocates `pixelWidth × pixelHeight × 4` bytes. A typical
A4 page at 150 DPI on a retina display (≈ 1440 × 1800 px) uses ~10 MB.
`PdfPageView` holds exactly one `ui.Image` per instance; with N open tabs
there are N live images. No LRU cache is used in this phase.
