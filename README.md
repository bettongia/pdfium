# betto_pdfium

A monorepo for `betto_pdfium` — a pure Dart package wrapping the
[PDFium](https://pdfium.googlesource.com/pdfium/) C++ library for PDF rendering,
text extraction, search, annotations, and thumbnails via Dart FFI (native) and
`dart:js_interop` (web) — plus its Flutter companion plugin for iOS.

No local C++ toolchain is required. Pre-built PDFium binaries are sourced from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries) and
downloaded automatically.

## Platform support

| Platform       | Status                  |
| -------------- | ----------------------- |
| macOS arm64    | Supported               |
| Linux x86_64   | Supported               |
| Linux arm64    | Supported               |
| Windows x86_64 | Supported               |
| iOS arm64      | Supported (xcframework) |
| Android arm64  | Supported               |
| Android x86_64 | Supported               |
| Web (WASM)     | Supported (Web Worker)  |

## Packages

```
packages/
  betto_pdfium/       # Pure Dart PDFium wrapper — the main package
  betto_pdfium_ios/   # Flutter iOS companion plugin (delivers the PDFium
                       # xcframework via Swift Package Manager)
```

`betto_pdfium` has no dependency on `dart:ui` or `package:flutter` and works in
CLI tools, server-side Dart, and Flutter apps alike. `betto_pdfium_ios` is only
needed by Flutter apps targeting iOS.

See [`packages/betto_pdfium/README.md`](packages/betto_pdfium/README.md) for the
full API guide (metadata, text/image/annotation extraction, rendering, search,
table of contents, thumbnails), web (WASM) setup, and mobile setup.

The [`betto_pdf_widgets`](https://pub.dev/packages/betto_pdf_widgets) package
provides Flutter widgets that use the `betto_pdfium package` for displaying PDF
documents. The codebase includes a PDF viewer application as the example
implementation.

## Getting started

All commands are run from the **repo root** via the root `Makefile`, which
composes per-package `.mk` fragments. This is a pure Dart package — never use
`flutter` commands for `betto_pdfium` itself.

```bash
make test          # dart test — the native-assets hook downloads the
                    # platform PDFium binary automatically on first run
make analyze        # dart analyze (betto_pdfium) + flutter analyze (betto_pdfium_ios)
make format          # dart format
make coverage        # dart test --coverage + genhtml (site/coverage/)
make web_test        # dart test -p chrome (requires Chrome)
make pre_commit      # format_check + analyze + analyze_ios + license_check + test
```

Quick usage example:

```dart
import 'dart:io';
import 'package:betto_pdfium/betto_pdfium.dart';

final bytes = await File('document.pdf').readAsBytes();
final doc = await PdfDocument.fromBytes(bytes);
try {
  final meta = await doc.getMetadata();
  print(meta.title);
} finally {
  await doc.close();
}
```

## Library development

Working on `betto_pdfium` itself (regenerating FFI bindings, bumping the PDFium
version, running mobile/web tests) requires a few extra `make` targets:

```bash
make fetch_pdfium              # Download PDFium binary + headers for the
                                # current BBLANCHON_BUILD (only needed for
                                # FFI binding regeneration — make test works
                                # without it)
make check_pdfium_version      # Verify installed binary/headers match BBLANCHON_BUILD
make ffi_bindings               # Regenerate Dart FFI bindings from PDFium headers
make fetch_wasm_assets          # Download PDFium WASM + JS + Worker assets for web
make fetch_mobile_binaries       # Download Android .so (iOS xcframework is fetched by SPM)
make ios_test                    # Run the mobile integration suite on iOS
make android_test                # Run the mobile integration suite on Android
```

**Bumping the PDFium version** is a documented multi-step workflow — see
[`packages/betto_pdfium/README.md`](packages/betto_pdfium/README.md) and
`CLAUDE.md`'s "Bumping the bblanchon version" section for the full single-commit
workflow, and
[`docs/spec/01_binary_distribution.md`](docs/spec/01_binary_distribution.md) for
the underlying distribution contract.

## Developer CLI

Inspect a real-world PDF file at the command line:

```bash
cd packages/betto_pdfium
dart run bin/pdfinfo.dart path/to/document.pdf
```

Prints all Info dictionary fields, document version, and file identifiers. See
[`packages/betto_pdfium/example/`](packages/betto_pdfium/example/) for further
usage examples.

## Additional information

- Full package API guide:
  [`packages/betto_pdfium/README.md`](packages/betto_pdfium/README.md)
- Implementation plans: `docs/plans/`
- Version roadmap: `docs/roadmap/`
- Full specification: `docs/spec/`
- Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md)
