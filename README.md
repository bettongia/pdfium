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

## PDFium binary

Pre-built PDFium binaries are published as GitHub Releases from the
`pdfium-build` orphan branch. No local C++ toolchain is required.

### Package consumers

When you add `betto_pdfium` to your project, the native-assets hook
(`hook/build.dart`) downloads the correct platform binary automatically the
first time you run `dart build`, `dart run`, or `dart test`. No manual setup
is required.

### Library developers

Working on `betto_pdfium` itself (e.g. to regenerate FFI bindings after a
PDFium header change) requires the developer toolchain:

#### Prerequisites

- [`gh`](https://cli.github.com/) (GitHub CLI) — installed and authenticated.

#### Fetch binary and headers

```bash
make fetch_pdfium
```

Downloads the platform binary and public headers matching `PDFIUM_VERSION`,
verifies SHA256 checksums, and installs them into `third_party/pdfium_bin/` and
`third_party/pdfium/` (both gitignored). The command is idempotent — it does
nothing if the correct version is already installed.

Note: `make test` works without this step — the native-assets hook downloads
the binary into `.dart_tool/betto_pdfium/` automatically. `make fetch_pdfium`
is only needed to regenerate FFI bindings (`make ffi_bindings`).

#### Verify

```bash
make check_pdfium_version
```

Confirms the installed binary and headers match `PDFIUM_VERSION`.

### Bumping the PDFium version

This is a two-commit workflow — the SHA-256 digests in `version_pdfium.json`
are only known after CI has built and uploaded the binaries.

**Commit 1 — trigger the build:**

1. Update `PDFIUM_VERSION` with the new upstream commit SHA.
2. Commit and push to `main` — CI rebuilds all platform binaries, packages the
   public headers from the same commit, and publishes a new GitHub Release.

**Wait for CI to finish.**

**Commit 2 — update the hook manifest:**

3. `make update_pdfium_manifest` — reads `checksums.sha256` from the
   just-published release, rewrites `version_pdfium.json` and
   `lib/src/pdfium_version.dart`.
4. `make fetch_pdfium` to install the new binary and headers locally.
5. If the public API changed: `make ffi_bindings` to regenerate
   `lib/src/generated/pdfium_bindings.dart`.
6. Commit `version_pdfium.json`, `lib/src/pdfium_version.dart`, and any
   updated bindings.

See [`docs/spec/01_binary_distribution.md`](docs/spec/01_binary_distribution.md)
for the full distribution contract.

## Getting started

```bash
dart test   # hook downloads the binary automatically; all tests should pass
```

For library development (FFI binding regeneration, etc.):

1. Run `make fetch_pdfium` to install the PDFium binary and headers.
2. Run `make ffi_bindings` to regenerate FFI bindings if headers changed.
3. Run `make test` to validate the smoke test passes.

## Usage

```dart
import 'package:betto_pdfium/betto_pdfium.dart';
```

### Metadata extraction

Load a PDF and read its Info dictionary metadata:

```dart
import 'dart:io';
import 'package:betto_pdfium/betto_pdfium.dart';

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
import 'package:betto_pdfium/betto_pdfium.dart';

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
