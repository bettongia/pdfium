# betto_pdfium

## 0.1.0-dev.5

## 0.1.0-dev.4

### Fixed

- **Native library resolution in a Pub workspace.** When `dart test` runs from a
  workspace _member_ package, the native-assets pipeline stages the bundled
  PDFium library to the _workspace root_ `.dart_tool/lib/`, not the package's
  own. The runtime loader previously probed only the current directory, so a
  PDFium call issued from a spawned isolate (which cannot see the test runner's
  `LD_LIBRARY_PATH`) failed to load the library with
  `cannot open shared object file`. The loader now walks up from the working
  directory, probing each ancestor's `.dart_tool/lib/`, covering both the
  single-package and workspace layouts on Linux, macOS, and Windows. This
  surfaced under Dart 3.13 in the `kmdb` workspace's PDF vault indexing.

### Toolchain

- **Dart 3.13 support.** SDK constraint raised to `^3.13.0`. Verified end-to-end
  against the Dart 3.13 native-assets pipeline: the prebuilt-binary build hook,
  library loading, and the full native API surface (text/annotation/image
  extraction, rendering, and search) pass on macOS, Linux (x64 and arm64), and
  Windows.
- **lcov 2.x build compatibility.** Coverage `lcov`/`genhtml` invocations now
  pass `--ignore-errors empty`, so the line-only tracefiles Dart emits no longer
  fail the build under lcov 2.0 (shipped on current Ubuntu runners).
- Regenerated the web `pdfium_worker.js` with the Dart 3.13 toolchain.

## 0.1.0-dev.3 - 2026-07-03

### Platform support

- **Windows x86_64** — pre-built `pdfium.dll` (bblanchon/pdfium-binaries) is now
  downloaded automatically by the native-assets hook, matching the existing
  macOS/Linux workflow. No native toolchain required.
- **Web (WASM)** — `PdfDocument` is now fully implemented on Flutter web and
  `dart2wasm` via `dart:js_interop`, covering the complete API surface
  (metadata, text/annotation/image extraction, rendering, search, table of
  contents, thumbnails). Run `make fetch_wasm_assets` to place the PDFium WASM +
  JS + Worker artifacts in your app's `web/assets/pdfium/` directory; see the
  package README for setup.
- **Web (WASM) — Web Worker offload** — PDFium calls on web now run inside a
  dedicated Web Worker instead of the browser main thread, so large document
  operations no longer block the UI. `dart:isolate` is not supported on web, so
  this uses a hand-rolled `Worker` + `postMessage` protocol mirroring the native
  `PdfiumIsolate` architecture's shape. `make fetch_wasm_assets` now also copies
  the checked-in `pdfium_worker.js` artifact alongside `pdfium.wasm`/`pdfium.js`
  — no other consumer-facing change. See the README's "Web (WASM)" section,
  including the "Adopting the Web Worker backend" migration guide, and
  `spec/02_pdfium_isolate.md`'s "Web Worker concurrency model" section.

## 0.1.0-dev.2 — 2026-06-30

Version bump — no API changes. Minor fix to publication config

## 0.1.0-dev.1 — 2026-06-29

First developer preview. All core PDF operations are implemented and tested
(96.1 % line coverage). API is subject to change before 1.0.

### Platform support

Pre-built PDFium binaries (bblanchon/pdfium-binaries chromium/7906) are shipped
for:

- macOS arm64
- Linux x86_64 and arm64
- iOS arm64 (xcframework via SPM)
- Android arm64 and x86_64

The binary is downloaded automatically by the native-assets hook on the first
`dart test` or `dart run` — no manual setup needed on desktop. Windows and WASM
are not yet supported.

### Document loading

- `PdfDocument.fromBytes(Uint8List)` — loads a PDF from raw bytes into a
  background isolate so the calling isolate is never blocked.
- `PdfExtractionException` — thrown when loading fails; `exception.error`
  distinguishes `PdfError.passwordRequired` from `PdfError.invalidDocument`.
- `PdfDocument.close()` — releases the native PDFium handle; safe to call more
  than once. A `Finalizer` is registered as a fallback but explicit disposal is
  preferred. After `close()`, all methods throw `StateError`.

### Metadata and document info

- `getMetadata()` — returns `PdfMetadata` with `title`, `author`, `subject`,
  `keywords`, `creator`, `producer`, `creationDate`, and `modificationDate`. All
  fields are nullable; dates are `PdfDate` values with a parsed `DateTime?`.
- `getDocumentInfo()` — returns `PdfDocumentInfo` with `fileVersion` and the
  16-byte `permanentId` / `changingId` file identifiers.
- `pageCount` — total page count.

### Text extraction

- `extractPlainText({int? pageIndex})` — streams `PdfPageText` per page. Each
  result carries `text`, `hasTextLayer`, and `hasUnicodeErrors`.
- `isPlainTextExtractable()` — quick check that returns `false` when too many
  pages lack a text layer (configurable via
  `PdfTextExtractorConfig.scannedPageRatio`).
- Cancelling the stream or calling `close()` stops further processing
  immediately with no handle leaks.

### Page size and rendering

- `getPageSize(int pageIndex)` — returns `PdfPageSize` with `widthPt`,
  `heightPt`, `aspectRatio`, and `sizeForDpi(dpi)` for pixel conversion.
- `renderPageToBytes(pageIndex, pixelWidth, pixelHeight)` — renders a page to a
  raw BGRA pixel buffer; returns
  `({Uint8List pixels, int pixelWidth, int pixelHeight})`. Optional flags:
  `renderAnnotations`, `lcdText`, `backgroundColor` (ARGB packed int).

### Annotation extraction

- `extractAnnotations({int? pageIndex})` — streams `PdfPageAnnotations` per
  page; pages with no annotations yield an entry with an empty list so callers
  can track page coverage without gaps.
- Concrete annotation types: `PdfTextAnnotation`, `PdfMarkupAnnotation`
  (highlight, underline, squiggly, strikeout), `PdfFreeTextAnnotation`,
  `PdfInkAnnotation`, `PdfShapeAnnotation`, `PdfPopupAnnotation`,
  `PdfStampAnnotation`, `PdfUnknownAnnotation`.
- `PdfMarkupAnnotation` includes `quadPoints` for precise text-span geometry.
- Annotations with a linked popup carry a non-null `popup` field.

### Image extraction

- `extractImages({int? pageIndex, bool includeBitmap})` — streams
  `PdfPageImages` per page, each containing a list of `PdfImage` objects with
  bounding box and `PdfImageMetadata` (dimensions, colour space, bits per pixel,
  filter chain).
- `includeBitmap: false` (default) — metadata-only; no bitmap allocation.
- `includeBitmap: true` — populates `PdfImage.bgra` for every image on the page.
- `renderImage(pageIndex, objectIndex)` — fetches the BGRA bitmap for a single
  image object on demand; returns `null` for mask-only images.

### Search

- `search(String query, {Set<PdfSearchFlag> flags, int? pageIndex})` — streams
  `PdfSearchMatch` values with `pageIndex`, `charIndex`, and `rects` in PDF
  user-space (origin bottom-left).
- Search flags: `PdfSearchFlag.matchCase`, `PdfSearchFlag.matchWholeWord`,
  `PdfSearchFlag.consecutive`.

### Table of contents

- `tableOfContents` — returns the complete bookmark tree as `List<PdfTocEntry>`.
  Each entry has `title`, `pageIndex`, and `children` for nested entries.
  Returns an empty list when the document has no bookmarks.

### Thumbnails

- `getThumbnail(int pageIndex, {bool generateIfAbsent, int maxDimension})` —
  returns a `PdfThumbnail` with `bgra`, `width`, `height`, and `source`
  (`embedded` or `rendered`). When no embedded `/Thumb` stream is present, a
  fallback render is produced at the requested `maxDimension` (longest edge)
  unless `generateIfAbsent: false`.

### `pdfinfo` CLI tool

- `dart run bin/pdfinfo.dart` — a command-line tool for inspecting PDF metadata,
  document info, page count, table of contents, and plain-text extractability.
