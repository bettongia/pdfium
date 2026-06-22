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

```
lib/
  betto_pdfium.dart           # Public library entry point
  src/
    document/
      pdf_document.dart        # PdfDocument public API (conditional import façade)
      _document_native.dart    # dart:ffi backend (iOS, Android, macOS, Linux)
      _document_web.dart       # WASM backend (pending)
      _document_stub.dart      # Throws UnsupportedError on unrecognised platforms
      pdfium_isolate.dart      # Process-wide PDFium isolate singleton
      isolate_messages.dart    # Message types for isolate round-trips
      pdf_types.dart           # Public data types (PdfMetadata, PdfPageText, etc.)
      pdf_date_parser.dart     # PDF date string parser
    rendering/
      pdf_page_size.dart       # PdfPageSize — page dimensions in points
    pdf_exception.dart         # PdfExtractionException, PdfiumException, PdfError
    generated/
      pdfium_bindings.dart     # Auto-generated FFI bindings (committed; regenerate
                               # with make ffi_bindings)
test/                          # dart test suite
example/                       # Usage examples
bin/                           # CLI entry points
third_party/pdfium/            # PDFium public headers only (git subtree)
  public/                      # Headers used for FFI binding generation
third_party/pdfium_bin/        # gitignored; pre-built PDFium binaries
  macos_arm64/
    libpdfium.dylib            # macOS arm64 binary loaded by Dart FFI
  VERSION                      # PDFium commit SHA + build date (ISO-8601 UTC)
.build/                        # gitignored; depot_tools + source (make setup)
docs/
  plans/                       # Implementation plans (see plans/README.md)
  roadmap/                     # Version roadmap files (vX_YY.md format)
  spec/                        # Full specification (Pandoc Markdown)
```

## Commands

`make` is preferred over calling `dart` directly. This is a **pure Dart**
package — never use `flutter` commands.

```bash
make test          # Run tests (dart test)
make analyze       # dart analyze
make format        # dart format
make coverage      # dart test --coverage + genhtml (outputs to site/coverage/)
make pre_commit    # format_check + analyze + license_check + test
make cicd          # Full CI pipeline: clean + default
make license_add   # Add license headers to source files (via addlicense)
make clean         # Remove site/, dist/, coverage/, *.log
```

To run a single test file directly:

```bash
dart test test/pdf_types_test.dart
```

### PDFium build commands

PDFium must be built from source (or fetched via `make fetch_pdfium`) before
integration tests that load the native library can run. All build artefacts are
confined to `.build/` (gitignored) and the staged binary goes to
`third_party/pdfium_bin/` (also gitignored).

```bash
make setup              # Bootstrap depot_tools + gclient sync (run once; 20–40 min)
make build_pdfium_macos # Compile libpdfium.dylib and stage to third_party/pdfium_bin/
make ffi_bindings       # Regenerate Dart FFI bindings from third_party/pdfium/public/
make clean_build        # Remove .build/ entirely to start fresh
```

**Local build workflow:**

1. Run `make setup` once to download depot_tools and the PDFium source tree.
2. Run `make build_pdfium_macos` to compile and stage the binary.
3. Run `make test` — the smoke test in `test/pdfium_smoke_test.dart` exercises
   the library load/init/destroy round-trip.

**Binary layout (canonical contract):**

```
third_party/pdfium_bin/       ← gitignored; populated by make build_pdfium_macos
  macos_arm64/
    libpdfium.dylib           ← loaded by Dart FFI
  VERSION                     ← PDFium commit SHA + build date (ISO-8601 UTC)
```

**Versioning convention:** The `VERSION` file contains two lines:

```
pdfium_commit=<git SHA>
build_date=<YYYY-MM-DDTHH:MM:SSZ>
```

**Codesigning note:** Locally-built dylibs are never assigned the
`com.apple.quarantine` xattr, so Gatekeeper does not apply and `dlopen()` loads
them without ad-hoc signing. Ad-hoc signing is handled by the fetch pipeline
(see `plan_pdfium_build_pipeline.md`).

**Side-effect note:** `gclient` writes a small authentication cache to
`~/.config/gclient`. Everything else stays under `.build/`.

**FFI bindings:** The generated file `lib/src/generated/pdfium_bindings.dart`
is committed so that developers without the C++ toolchain can still build and
run Dart code. Regenerate with `make ffi_bindings` whenever PDFium headers
change. PDFium headers are added incrementally as feature plans are
implemented.

## Architecture

`betto_pdfium` is a **pure Dart** package that wraps the
[PDFium](https://pdfium.googlesource.com/pdfium/) C++ library via Dart FFI.
There is no dependency on `dart:ui` or `package:flutter`. The package can be
used in CLI tools, server-side Dart, and any non-Flutter context.

### Platform split

`PdfDocument` in `lib/src/document/pdf_document.dart` is a thin façade over a
conditional import:

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
`Isolate` — `PdfiumIsolate` in `lib/src/document/pdfium_isolate.dart`.

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
