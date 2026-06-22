# betto_pdfium

A pure Dart package wrapping the
[PDFium](https://pdfium.googlesource.com/pdfium/) C++ library for PDF rendering,
text extraction, and annotation support via Dart FFI.

## Features

- PDF metadata extraction (Info dictionary and XMP)
- Full-text extraction with support for scanned PDFs, multi-column, and RTL
  layouts
- Full-text search with match coordinates for overlay highlights
- Annotation extraction (sticky notes, highlights)
- Page thumbnail generation
- Table of contents (bookmark tree) extraction

## Building PDFium

PDFium must be compiled from source before any integration tests or Dart FFI
code can run. The build is managed via `make` targets that operate entirely
within the project's `.build/` directory — no system-wide changes are required.

> **Note:** The `.build/` workspace directory and `third_party/pdfium_bin/`
> directory are gitignored. Every developer must build the library locally (or
> fetch it from the CI pipeline — see
> `docs/plans/plan_pdfium_build_pipeline.md`).

### Prerequisites

- macOS with Xcode installed (not just Command Line Tools):
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  xcodebuild -version   # must show Xcode, not CLT only
  ```
- Python 3.8 or later (`python3 --version`)
- Git

### Step 1 — Bootstrap the workspace

Run once. Downloads `depot_tools`, configures a `gclient` workspace, and runs
`gclient sync` to download the full PDFium source tree and clang toolchain
(approximately 2–5 GB; takes 20–40 minutes on first run).

```bash
make setup
```

> **Side-effect note:** `gclient` writes a small authentication cache to
> `~/.config/gclient`. All other files (source tree, clang toolchain) stay under
> `.build/`.

### Step 2 — Build

Compiles `libpdfium.dylib` for macOS arm64 and stages it to
`third_party/pdfium_bin/macos_arm64/`. A full build takes 10–30 minutes;
incremental rebuilds are fast.

```bash
make build_pdfium_macos
```

The binary layout produced here is:

```
third_party/pdfium_bin/
  macos_arm64/
    libpdfium.dylib     ← loaded by Dart FFI at runtime
  VERSION               ← PDFium commit SHA and build date
```

This layout is the canonical contract shared with the standalone build pipeline
(`plan_pdfium_build_pipeline.md`). Any change to it must be coordinated across
both plans.

### Resetting the workspace

To start completely fresh (for example, after a failed `gclient sync`):

```bash
make clean_build   # removes .build/ entirely
make setup         # re-bootstrap
```

### Regenerating FFI bindings

If the PDFium public headers change, regenerate the Dart FFI bindings with:

```bash
make ffi_bindings
```

The generated file (`lib/src/generated/pdfium_bindings.dart`) is committed so
developers without the C++ toolchain can still build and edit Dart code.

## Getting started

1. Build the PDFium library (see above).
2. Run `make test` to validate the smoke test passes.

## Usage

```dart
import 'package:betto_pdf/pdfart.dart';
```

### Metadata extraction

Load a PDF and read its Info dictionary metadata:

```dart
import 'dart:io';
import 'package:betto_pdf/pdfart.dart';

final bytes = await File('document.pdf').readAsBytes();

try {
  final doc = await PdfDocument.fromBytes(bytes);
  try {
    final meta = await doc.getMetadata();
    print('Title: ${meta.title}');
    print('Author: ${meta.author}');
    print('Created: ${meta.creationDate?.value?.toIso8601String()}');

    final info = await doc.getDocumentInfo();
    print('PDF version: ${info.fileVersion}');
  } finally {
    await doc.close();
  }
} on PdfExtractionException catch (e) {
  if (e.error == PdfError.passwordRequired) {
    print('This PDF is password-protected.');
  } else {
    print('Could not open PDF: ${e.error}');
  }
}
```

### Text extraction

Extract plain Unicode text from a PDF, page by page:

```dart
import 'dart:io';
import 'package:betto_pdf/pdfart.dart';

final bytes = await File('document.pdf').readAsBytes();

final doc = await PdfDocument.fromBytes(bytes);
try {
  // Check whether the document has a usable text layer before extracting.
  final extractable = await doc.isPlainTextExtractable();
  if (!extractable) {
    print('Document appears to be scanned — no text layer.');
    return;
  }

  // Stream pages one at a time. Cancel the subscription at any point to stop.
  await for (final page in doc.extractPlainText()) {
    if (page.hasTextLayer) {
      print('--- Page ${page.pageIndex} ---');
      print(page.text);
    } else {
      print('Page ${page.pageIndex}: no text layer (image/scanned)');
    }
    if (page.hasUnicodeErrors) {
      print('  (warning: some characters had no Unicode mapping)');
    }
  }

  // Extract a single page by index:
  final firstPage = await doc.extractPlainText(pageIndex: 0).first;
  print('Page 0 has ${firstPage.text.length} characters.');
} finally {
  await doc.close();
}
```

### Developer CLI

Inspect a real-world PDF file at the command line:

```bash
dart run bin/pdfinfo.dart path/to/document.pdf
```

Prints all Info dictionary fields, document version, and file identifiers.

Full API documentation: run `dart doc` or see the `docs/spec/` directory.

## Additional information

- Implementation plans: `docs/plans/`
- Version roadmap: `docs/roadmap/`
- Full specification: `docs/spec/`
- Contributing: `CONTRIBUTING.md`
