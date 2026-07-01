# betto_pdfium

A pure Dart package that wraps [PDFium](https://pdfium.googlesource.com/pdfium/)
via Dart FFI. No dependency on `dart:ui` or Flutter — works in CLI tools,
server-side Dart, and Flutter apps alike.

Pre-built PDFium binaries are sourced from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries) and
downloaded automatically by the native-assets hook on first use.

## Platform support

| Platform       | Status                  |
| -------------- | ----------------------- |
| macOS arm64    | Supported               |
| Linux x86_64   | Supported               |
| Linux arm64    | Supported               |
| iOS arm64      | Supported (xcframework) |
| Android arm64  | Supported               |
| Android x86_64 | Supported               |
| Windows x86_64 | Supported               |
| Web (WASM)     | Supported (beta)        |

_"Beta" for Web (WASM): the full API surface works, but v1 runs synchronously
on the browser main thread (no Web Worker offload yet) and the backend is
newer and less battle-tested than the native platforms. See
[Web (WASM)](#web-wasm) below._

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  betto_pdfium: ^0.1.0-dev.3
```

**Flutter iOS apps** also need the companion plugin, which delivers the PDFium
xcframework via Swift Package Manager:

```yaml
dependencies:
  betto_pdfium: ^0.1.0-dev.3
  betto_pdfium_ios: ^0.1.0-dev.3
```

No additional setup is needed on desktop — the PDFium binary is fetched
automatically when you first run `dart test` or `dart run`. For iOS and Android
see [Mobile](#mobile-ios--android) below.

## Quick start

```dart
import 'dart:io';
import 'package:betto_pdfium/betto_pdfium.dart';

void main() async {
  final bytes = await File('document.pdf').readAsBytes();
  final doc = await PdfDocument.fromBytes(bytes);
  try {
    final meta = await doc.getMetadata();
    print(meta.title);
  } finally {
    await doc.close();
  }
}
```

## API

All capabilities are on `PdfDocument`. Import a single file:

```dart
import 'package:betto_pdfium/betto_pdfium.dart';
```

### Loading a document

```dart
final bytes = await File('document.pdf').readAsBytes();
final doc = await PdfDocument.fromBytes(bytes);
```

Throws `PdfExtractionException` on failure. Inspect `exception.error` to
distinguish recoverable conditions:

```dart
try {
  final doc = await PdfDocument.fromBytes(bytes);
} on PdfExtractionException catch (e) {
  switch (e.error) {
    case PdfError.passwordRequired:
      print('Password required.');
    case PdfError.invalidDocument:
      print('Not a valid PDF.');
  }
}
```

### Closing and resource management

Always call `close()` when finished. A `Finalizer` is registered as a safety
net, but explicit disposal is strongly preferred:

```dart
final doc = await PdfDocument.fromBytes(bytes);
try {
  // work with doc
} finally {
  await doc.close();
}
```

After `close()` returns, all other methods throw `StateError`. Calling `close()`
more than once is safe.

### Metadata

```dart
final meta = await doc.getMetadata();
print(meta.title);
print(meta.author);
print(meta.creationDate?.value?.toIso8601String());
```

All fields on `PdfMetadata` are nullable — a `null` means the entry was absent
from the PDF's Info dictionary.

### Document info

Returns the PDF file version and the permanent/changing file identifiers:

```dart
final info = await doc.getDocumentInfo();
print('PDF version: ${info.fileVersion}');

final hex = info.permanentId
    ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();
print('Permanent ID: $hex');
```

### Page count

```dart
final count = await doc.pageCount;
print('Pages: $count');
```

### Text extraction

Streams pages one at a time, in index order:

```dart
await for (final page in doc.extractPlainText()) {
  if (page.hasTextLayer) {
    print('Page ${page.pageIndex}: ${page.text}');
  } else {
    print('Page ${page.pageIndex}: scanned (no text layer)');
  }
}
```

Extract a single page by index:

```dart
final page = await doc.extractPlainText(pageIndex: 0).first;
```

Check whether the document is worth extracting before streaming all pages:

```dart
if (!await doc.isPlainTextExtractable()) {
  print('Document appears to be scanned.');
}
```

### Page size

Returns the page's intrinsic dimensions in PDF user units (points, 1/72 inch):

```dart
final size = await doc.getPageSize(0);
print('${size.widthPt} × ${size.heightPt} pt');
print('Aspect ratio: ${size.aspectRatio}');
```

Convert to pixels for a specific DPI:

```dart
final px = size.sizeForDpi(150);
// px.width, px.height are doubles
```

### Rendering

Renders a page to a raw BGRA byte buffer:

```dart
final size = await doc.getPageSize(0);
final px = size.sizeForDpi(150);
final result = await doc.renderPageToBytes(
  0,
  px.width.round(),
  px.height.round(),
);

// result.pixels  — Uint8List of BGRA bytes
// result.pixelWidth, result.pixelHeight
assert(result.pixels.length == result.pixelWidth * result.pixelHeight * 4);
```

In a Flutter app, decode the BGRA buffer into a `dart:ui Image` via
`decodeImageFromPixels`. The rendering surface is intentionally kept at the
pure-Dart layer so it can be used outside Flutter.

Optional flags:

```dart
final result = await doc.renderPageToBytes(
  pageIndex,
  width,
  height,
  renderAnnotations: true,   // default: true  (FPDF_ANNOT)
  lcdText: false,            // default: false (FPDF_LCD_TEXT)
  backgroundColor: 0xFFFFFFFF, // default: opaque white (ARGB)
);
```

### Annotations

Streams one `PdfPageAnnotations` per page. Pages with no annotations yield an
entry with an empty `annotations` list:

```dart
await for (final page in doc.extractAnnotations()) {
  for (final annot in page.annotations) {
    switch (annot) {
      case PdfTextAnnotation(:final contents, :final rect):
        print('Note on page ${page.pageIndex}: $contents at $rect');
      case PdfMarkupAnnotation(:final subtype, :final quadPoints)
          when subtype == PdfAnnotationType.highlight:
        print('Highlight on page ${page.pageIndex}');
      case PdfInkAnnotation(:final strokes):
        print('Ink with ${strokes.length} stroke(s)');
      default:
        print('Other annotation: ${annot.runtimeType}');
    }
  }
}
```

Extract a single page:

```dart
final page = await doc.extractAnnotations(pageIndex: 2).first;
```

### Images

Enumerate image objects page by page:

```dart
await for (final page in doc.extractImages()) {
  for (final img in page.images) {
    print('Image ${img.objectIndex}: '
        '${img.metadata.width}×${img.metadata.height} '
        '${img.filters.join(",")}');
  }
}
```

Fetch the rendered BGRA bitmap for a specific image object:

```dart
final bitmap = await doc.renderImage(pageIndex, objectIndex);
if (bitmap != null) {
  // bitmap.bgra, bitmap.width, bitmap.height
}
```

For bulk extraction, pass `includeBitmap: true` to `extractImages()` to retrieve
bitmaps in a single stream pass.

### Search

```dart
await for (final match in doc.search('example')) {
  print('Match on page ${match.pageIndex + 1}: '
      'char ${match.charIndex}, ${match.rects.length} rect(s)');
}
```

Control matching behaviour with `PdfSearchFlag` values:

```dart
final matches = doc.search(
  'Dart',
  flags: {PdfSearchFlag.matchCase, PdfSearchFlag.matchWholeWord},
  pageIndex: 0, // restrict to one page
);
```

Match rects are in PDF user-space (origin bottom-left). Apply
`FPDF_PageToDevice` if you need screen coordinates.

### Table of contents

```dart
final toc = await doc.tableOfContents;
for (final entry in toc) {
  final target = entry.pageIndex != null
      ? 'page ${entry.pageIndex! + 1}'
      : '(no target)';
  print('${entry.title} → $target');
  for (final child in entry.children) {
    print('  ${child.title}');
  }
}
```

Returns an empty list when the document has no bookmarks — not an error.

### Thumbnails

```dart
final thumb = await doc.getThumbnail(0);
if (thumb != null) {
  // thumb.bgra, thumb.width, thumb.height
  // thumb.source == PdfThumbnailSource.embedded
  //             or PdfThumbnailSource.rendered
}
```

In Flutter, scale `maxDimension` by `MediaQuery.of(context).devicePixelRatio`
for crisp thumbnails on high-DPI displays:

```dart
final dpr = MediaQuery.of(context).devicePixelRatio;
final thumb = await doc.getThumbnail(0, maxDimension: (256 * dpr).round());
```

Pass `generateIfAbsent: false` to return `null` rather than rendering a fallback
when no embedded thumbnail exists.

## Error types

| Exception                | When thrown                                             |
| ------------------------ | ------------------------------------------------------- |
| `PdfExtractionException` | `fromBytes()` fails (wrong password, corrupt file)      |
| `PdfiumException`        | Unexpected PDFium native failure (allocation, render)   |
| `StateError`             | Any method called after `close()`                       |
| `RangeError`             | Page index out of range, non-positive render dimensions |

## Architecture

The platform backend is selected automatically via Dart's conditional import
mechanism — callers import only `betto_pdfium.dart` and receive the correct
implementation for their target.

**Native platforms (macOS, Linux, iOS, Android, Windows):** PDFium is not
thread-safe. All PDFium calls run on a dedicated background `Isolate`
(`PdfiumIsolate`) so the calling isolate (e.g. the Flutter UI isolate) is
never blocked. The isolate is spawned lazily on the first
`PdfDocument.fromBytes()` call and held for the process lifetime.

**Web (WASM):** PDFium runs synchronously on the browser main thread via the
Emscripten module. There is no isolate boundary. Large document operations
may block the UI — see the [Web (WASM)](#web-wasm) section for details.

## Running the examples

From the repo root:

```sh
dart run example/main.dart   # metadata extraction
dart run example/extract.dart  # full text extraction
dart run bin/pdfinfo.dart    # pdfinfo CLI tool
```

See [example/README.md](example/README.md) for more details.

## Web (WASM)

`betto_pdfium` includes a `dart:js_interop`-based backend for Flutter web and
`dart2wasm`. It uses the PDFium Emscripten module from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries).

### Web setup (one-time per app)

The PDFium WASM and JS files must be placed at `web/assets/pdfium/` in your
Flutter app before building. Run the helper script from the repo root:

```sh
make fetch_wasm_assets
```

This downloads `pdfium-wasm.tgz`, verifies its SHA-256, and extracts
`pdfium.wasm` and `pdfium.js` to the correct location. Re-run this after every
`betto_pdfium` version bump that upgrades the bblanchon build number.

### Main-thread blocking (important)

**v1 of the web backend runs synchronously on the browser main thread.** All
PDFium calls block until they complete. For large or complex PDFs, individual
operations may freeze the browser tab briefly.

The streaming methods (`extractPlainText`, `extractAnnotations`, etc.) yield
between pages via `Future.delayed(Duration.zero)` to reduce jank, but this
does **not** unblock the thread during a single long PDFium call within a page.

A Web Worker offload path is planned for a future release.

### Web usage

The public API is identical on all platforms. No code changes are needed when
targeting the web — the correct backend is selected automatically via Dart's
conditional import mechanism.

```dart
// Works identically on native and web.
import 'package:betto_pdfium/betto_pdfium.dart';

final doc = await PdfDocument.fromBytes(bytes);
final meta = await doc.getMetadata();
await doc.close();
```

On the web, `fromBytes` returns after the PDFium WASM module is loaded and
initialised (on the first call this may take a moment while the browser
downloads `pdfium.wasm`). Subsequent calls reuse the already-loaded module.

## Mobile (iOS / Android)

iOS support is provided by the companion package
[`betto_pdfium_ios`](../betto_pdfium_ios/), which wraps the PDFium xcframework
as a Flutter plugin and delivers it via Swift Package Manager. Add it to your
Flutter app's `pubspec.yaml` alongside `betto_pdfium` (see
[Installation](#installation)).

iOS and Android require additional one-time setup. See
[`integration_test_app/`](integration_test_app/) and the repo `Makefile` for
targets that fetch mobile binaries and run on-device tests:

```sh
make fetch_mobile_binaries   # Android only — iOS xcframework fetched by SPM
make ios_test
make android_test
```

**iOS prerequisite (one-time global setup):**

```sh
flutter config --enable-swift-package-manager
```

## Licenses

This package is provided under Apache License, Version 2.0 — see
[LICENSE](../../LICENSE).

The binaries used by this package are accessed from
[https://github.com/bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries).
The repository carries the
[MIT License](https://github.com/bblanchon/pdfium-binaries/blob/master/LICENSE),
Copyright 2014-2025 Benoit Blanchon.

[PDFium](https://pdfium.googlesource.com/pdfium/) is licensed under the Apache
License, Version 2.0 — see
[PDFium LICENSE](<[../../LICENSE](https://pdfium.googlesource.com/pdfium/+/refs/heads/main/LICENSE)>).
