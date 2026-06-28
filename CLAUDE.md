# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## General

Work is planned using specifications in the `docs/plans` directory. When working
on plans make sure you review `docs/plans/README.md` for guidance. When asked to
plan something do not commence implementation until explicitly told to do so.

The `docs/roadmap` directory tracks future work items and their priority. Review
it when working on the codebase as current work may intersect with the roadmap.

Plans live in `docs/plans/`. When the planned work is complete, move the plan to
`docs/plans/completed/`.

Quality assurance is critical. Maintain a minimum of 90% test coverage at all
times. Run all tests successfully before considering a task complete. Coverage is
measured with `make coverage`; the `*/generated/*` path (auto-generated FFI
bindings) is excluded from the lcov report by the Makefile's `--remove` step.

Every new feature or bug fix must ship with tests covering the added/changed code
paths before the task is considered done. Check coverage after each
implementation step — catching a gap early is cheaper than backfilling it later.
Consider edge cases and failure scenarios; not just happy-path tests.

All public classes, methods, and properties must have doc comments. Include
examples in doc comments where they help another developer.

All code files must have a license header. The template is `@header_template.txt`
— wrap it in the comment syntax appropriate to the language, and replace
`{{.Year}}` with the current year.

## Repository Layout

This is a monorepo. The root `Makefile` is a compositor that includes
per-package `.mk` fragments. Run all `make` commands from the repo root.

```
Makefile                       # Root compositor — includes per-package .mk files
site.mk                        # Documentation site targets
packages/
  betto_pdfium/                # Pure Dart PDFium wrapper package
    betto_pdfium.mk            # Per-package Makefile fragment
    hook/
      build.dart               # Native-assets hook: downloads PDFium binary at build time
    lib/
      betto_pdfium.dart        # Public library entry point
      src/
        document/
          pdf_document.dart    # PdfDocument public API (conditional import façade)
          _document_native.dart  # dart:ffi backend (macOS, Linux)
          _document_web.dart   # WASM backend (pending)
          _document_stub.dart  # Throws UnsupportedError on unrecognised platforms
          pdfium_isolate.dart  # Process-wide PDFium isolate singleton
          isolate_messages.dart  # Message types for isolate round-trips
          pdf_types.dart       # Public data types (PdfMetadata, PdfPageText, etc.)
          pdf_date_parser.dart # PDF date string parser
        rendering/
          pdf_page_size.dart   # PdfPageSize — page dimensions in points
        pdf_exception.dart     # PdfExtractionException, PdfiumException, PdfError
        pdfium_version.dart    # pdfiumVersion + bblanchonBuild constants — must match version_pdfium.json
        generated/
          pdfium_bindings.dart # Auto-generated FFI bindings (committed; regenerate
                               # with make ffi_bindings)
    version_pdfium.json        # Hook + mobile manifest: SHA, URLs, SHA-256 digests
    test/                      # dart test suite
    example/                   # Usage examples
    bin/                       # CLI entry points
    integration_test_app/      # Flutter app for iOS/Android on-device integration tests
      lib/main.dart            # Minimal Flutter scaffold
      integration_test/
        pdfium_test.dart       # Full mobile test suite (mirrors dart test suite)
      assets/                  # PDF fixtures (populated by make sync_fixtures)
      scripts/
        fetch_mobile_binaries.sh  # Downloads Android .so from release (iOS handled by SPM)
      ios/
      android/
        src/main/jniLibs/      # gitignored; .so files populated by fetch_mobile_binaries.sh
    third_party/pdfium/        # gitignored; populated by make fetch_pdfium
      public/                  # PDFium public headers for FFI binding generation
    third_party/pdfium_bin/    # gitignored; populated by make fetch_pdfium
      macos_arm64/
        libpdfium.dylib        # macOS arm64 binary loaded by Dart FFI
      linux_x64/
        libpdfium.so           # Linux x86_64 binary loaded by Dart FFI
      linux_arm64/
        libpdfium.so           # Linux arm64 binary loaded by Dart FFI
      VERSION                  # Installed bblanchon build number (e.g. "7906")
  betto_pdfium_ios/            # Flutter iOS companion plugin
    betto_pdfium_ios.mk        # Per-package Makefile fragment
    ios/betto_pdfium_ios/
      Package.swift            # SPM package: PdfiumIos → pdfium_binary (dynamic xcframework)
      Sources/
        PdfiumIos/             # Swift Flutter plugin stub (BettoPdfiumIosPlugin)
    pubspec.yaml               # Flutter plugin pubspec (iOS platform only)
docs/
  plans/                       # Implementation plans (see plans/README.md)
  roadmap/                     # Version roadmap files (vX_YY.md format)
  spec/                        # Full specification (Pandoc Markdown)
```

## Commands

`make` is preferred over calling `dart` directly. Always run from the **repo
root** — the root Makefile delegates to per-package fragments. This is a
**pure Dart** package — never use `flutter` commands for `betto_pdfium`.

```bash
make test          # Run tests (dart test — hook downloads binary automatically)
make analyze       # dart analyze (betto_pdfium) + flutter analyze (betto_pdfium_ios)
make format        # dart format
make coverage      # dart test --coverage + genhtml (outputs to site/coverage/)
make pre_commit    # format_check + analyze + analyze_ios + license_check + test
make cicd          # format_check + analyze + analyze_ios + license_check + test + doc_site
make license_add   # Add license headers to source files (via addlicense)
make clean         # Remove site/, dist/, coverage/, *.log
```

To run a single test file directly:

```bash
dart test packages/betto_pdfium/test/pdf_types_test.dart
```

### PDFium binary commands

Pre-built PDFium binaries are sourced from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries).
No local C++ toolchain is required.

```bash
make fetch_pdfium              # Download binary + headers matching BBLANCHON_BUILD
make check_pdfium_version      # Verify installed binary and headers match BBLANCHON_BUILD
make ffi_bindings              # Regenerate Dart FFI bindings from third_party/pdfium/public/
make update_pdfium_manifest    # Download bblanchon tarballs, compute SHA-256s, rewrite
                               # version_pdfium.json + pdfium_version.dart + Package.swift
make repack_ios_xcframework    # Build pdfium.xcframework from bblanchon iOS tarballs and
                               # upload to bettongia/pdfium GitHub Release
```

**Developer setup:**

1. Run `make test` — the native-assets hook downloads the platform binary into
   `.dart_tool/betto_pdfium/` automatically before the first test run.
2. (Optional) To work with PDFium headers (e.g. to regenerate FFI bindings):
   run `make fetch_pdfium`.

**Binary and headers layout:**

```
packages/betto_pdfium/third_party/pdfium_bin/   ← gitignored; populated by make fetch_pdfium
  macos_arm64/
    libpdfium.dylib           ← loaded by Dart FFI on macOS arm64
  linux_x64/
    libpdfium.so              ← loaded by Dart FFI on Linux x86_64
  linux_arm64/
    libpdfium.so              ← loaded by Dart FFI on Linux arm64
  VERSION                     ← installed bblanchon build number (e.g. "7906")
packages/betto_pdfium/third_party/pdfium/       ← gitignored; populated by make fetch_pdfium
  public/                     ← PDFium public headers (extracted from the bblanchon tarball)
```

**Bumping the bblanchon version (single-commit workflow):**

1. Update `BBLANCHON_BUILD` with the new build number.
2. `make repack_ios_xcframework` — repacks bblanchon iOS tarballs into a
   `pdfium.xcframework` and uploads it to a new `bettongia/pdfium` release.
3. `make update_pdfium_manifest` — downloads bblanchon tarballs, computes
   SHA-256s, rewrites `version_pdfium.json`, `lib/src/pdfium_version.dart`,
   and `Package.swift`.
4. `make fetch_pdfium` to install the new binary and headers locally.
5. `make ffi_bindings` if the PDFium public API changed.
6. Commit all changed files.

See `docs/spec/01_binary_distribution.md` for the full distribution contract
and `docs/spec/11_releasing.md` for the detailed version-bump workflow.

**FFI bindings:** The generated file `lib/src/generated/pdfium_bindings.dart`
is committed so that developers can build and run Dart code without the build
pipeline. Regenerate with `make ffi_bindings` whenever PDFium headers change.

### Mobile integration test app

`packages/betto_pdfium/integration_test_app/` is a Flutter app that runs the
`betto_pdfium` test suite on a connected iOS or Android device/simulator. It
uses `flutter test integration_test/` and loads PDF fixtures from the Flutter
asset bundle rather than the filesystem.

iOS support is provided by `packages/betto_pdfium_ios/` — a minimal Flutter
plugin. The PDFium xcframework is declared as a **URL-based SPM binary target**
in `betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift`; SPM downloads and
caches it automatically during `flutter pub get` — no manual binary fetch is
required for iOS. Flutter auto-discovers the plugin via the integration test
app's path dependency and wires it into `FlutterGeneratedPluginSwiftPackage`
automatically; no manual Xcode steps are required.

**One-time global setup:**
```bash
flutter config --enable-swift-package-manager
```

**Per-clone setup (Android only — iOS xcframework is fetched by SPM):**
```bash
make fetch_mobile_binaries
```

**Makefile targets:**
```bash
make sync_fixtures           # Copy test/fixtures/ + test/data/ into assets/ (run before mobile tests)
make fetch_mobile_binaries   # Download Android .so from GitHub Release (iOS handled by SPM)
make ios_test                # sync_fixtures + flutter pub get (SPM fetches xcframework) + flutter test
make android_test            # sync_fixtures + fetch_mobile_binaries + flutter test on Android emulator
make emulator_ios_create     # Create the ios-emulator simulator (one-time)
make emulator_android_create # Create the android AVD (one-time)
make emulators_stop          # Stop all running emulators
```

Environment variables (set in your shell or `~/.zshrc`):
- `EMULATOR_IOS` — iOS simulator name (default: `ios-emulator`)
- `EMULATOR_IOS_DEVICE` — simulator device type (default: `iPhone 17`)
- `EMULATOR_IOS_RUNTIME` — simulator runtime (default: `iOS26.5`)
- `EMULATOR_ANDROID` — Android AVD name (default: `android-emulator`)
- `ADB_BINARY_PATH` — path to `adb` (default: `~/Library/Android/sdk/platform-tools`)

**Running tests manually (from `integration_test_app/`):**
```bash
flutter test integration_test/ -d <device-id>
```

## Architecture

`betto_pdfium` is a **pure Dart** package that wraps the
[PDFium](https://pdfium.googlesource.com/pdfium/) C++ library via Dart FFI.
There is no dependency on `dart:ui` or `package:flutter`. The package can be
used in CLI tools, server-side Dart, and any non-Flutter context.

### Platform split

`PdfDocument` in `packages/betto_pdfium/lib/src/document/pdf_document.dart` is
a thin façade over a conditional import:

| Condition               | Backend                 |
| ----------------------- | ----------------------- |
| `dart.library.ffi`      | `_document_native.dart` |
| `dart.library.js_interop` | `_document_web.dart`  |
| (fallback)              | `_document_stub.dart`   |

Callers import only `pdf_document.dart` and receive the correct backend
automatically. Flutter and `dart:ui` imports must never appear in any of these
files.

### PDFium isolate

PDFium is not thread-safe. All PDFium calls run on a single dedicated
`Isolate` — `PdfiumIsolate` in
`packages/betto_pdfium/lib/src/document/pdfium_isolate.dart`.

- **Singleton:** `PdfiumIsolate` is lazily spawned on the first
  `PdfDocument.fromBytes()` call and held for the process lifetime.
- **Never spawn a second isolate** or call `FPDF_InitLibraryWithConfig()` again
  — doing so is a correctness bug.
- All `PdfDocument` instances share the same isolate.

### Memory management

Every PDFium handle (`FPDF_DOCUMENT`, `FPDF_PAGE`, `FPDF_TEXTPAGE`, etc.) has a
matching `Close`/`Destroy` call. Dart's GC will not invoke these. Use
`Finalizer` or a RAII-style wrapper to prevent leaks. Page-level handles are
closed inside the isolate after each round-trip.

### Rendering output

Page rendering (`renderPageToBytes`) returns raw BGRA bytes (`Uint8List`), not
a `dart:ui` `Image`. Callers decode the buffer themselves. This keeps the
rendering surface usable outside Flutter.

### Coordinate system

PDF origin is bottom-left; screen origin is top-left. Use `FPDF_PageToDevice()`
/ `FPDF_DeviceToPage()` for coordinate conversions.

### Current public API surface

All capabilities are on `PdfDocument`:

| Method / property          | Description                              |
| -------------------------- | ---------------------------------------- |
| `fromBytes()`              | Load a document from raw PDF bytes       |
| `getMetadata()`            | Info dictionary (title, author, …)       |
| `getDocumentInfo()`        | File version, permanent/changing IDs     |
| `pageCount`                | Total page count                         |
| `extractPlainText()`       | Streaming text extraction per page       |
| `extractAnnotations()`     | Streaming annotation extraction          |
| `extractImages()`          | Streaming image object extraction        |
| `renderImage()`            | BGRA bitmap for a single image object    |
| `search()`                 | Full-text search; yields match rects     |
| `tableOfContents`          | Bookmark / outline tree                  |
| `getThumbnail()`           | Embedded thumbnail or rendered fallback  |
| `getPageSize()`            | Page dimensions in PDF points            |
| `renderPageToBytes()`      | Renders a page to a BGRA byte buffer     |
| `close()`                  | Releases the native PDFium handle        |

## Documentation

Full specification is in `docs/spec/` (Pandoc Markdown). The built HTML lives
in `site/` and is generated via `make site`. API docs are generated to
`api-docs/` via `dart doc`.
