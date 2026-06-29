---
title: Technical Specification
subtitle: betto_pdfium
toc-title: "Contents"
...

- **Package:** `betto_pdfium`
- **Version:** 0.1.0-dev.2
- **Dart SDK:** ≥ 3.12.0

# Overview

`betto_pdfium` is a pure-Dart package that wraps the
[PDFium](https://pdfium.googlesource.com/pdfium/) C++ library via Dart FFI. The
spec describes the public API, internal architecture, platform behaviour, and
edge-case handling for each feature area.

## Sections

### [PDFium Isolate Architecture](pdfium_isolate.md)

Internal architecture reference for contributors adding new features. Covers the
`PdfiumIsolate` singleton, the typed command/response message protocol, the
response class convention (`.success`/`.failure` named constructors), document
tokens, memory management patterns, and UTF-16LE string handling.

### [Metadata Extraction](metadata_extraction.md)

API for reading the standard PDF Info dictionary fields (`title`, `author`,
`subject`, `keywords`, `creator`, `producer`, and both date fields) and
document-level properties (file version, file identifiers). Works across all
supported platforms.

### [Text Extraction](text_extraction.md)

Streaming plain-text extraction from a PDF's text layer via
`extractPlainText()`. Covers the `PdfPageText` result type, the
`isPlainTextExtractable()` heuristic, scanned-PDF and Unicode-error handling,
and the v1 limitation on multi-column / RTL reading order.

### [Annotation Extraction](annotation_extraction.md)

Streaming API for reading all PDF annotations from a document — highlights,
sticky notes, underlines, ink drawings, shapes, links, and more — as a typed
`PdfAnnotation` hierarchy. Native platforms only; covers the popup-inlining
approach, the two-pass algorithm, and the `fpdf_annot.h` Experimental API
caveat.

### [Table of Contents Extraction](toc_extraction.md)

Single `Future`-returning API for retrieving the bookmark/outline tree embedded
in a PDF. Describes destination resolution (page, XYZ anchor, URI), cycle
detection for malformed PDFs, and the deliberate omission of zoom values from
`XYZ` destinations.

### [Page Rendering](rendering.md)

API for rasterising a PDF page into a `dart:ui Image` via `renderPage()`, plus
the `PdfPageView` Flutter widget that wraps it. Covers `PdfRenderOptions`, the
BGRA rendering pipeline inside the isolate, high-DPI scaling, caching behaviour,
and in-flight cancellation.

### [Testing](10_testing.md)

How to run the Dart test suite, measure coverage, and execute mobile integration
tests on iOS simulators and Android emulators. Covers the
`betto_pdfium_ios` companion plugin's role in iOS testing and the
`integration_test_app/` Flutter app.

### [Releasing](11_releasing.md)

Release process for publishing `betto_pdfium` and `betto_pdfium_ios` to
pub.dev. Covers lock-step versioning, the required publish order (`betto_pdfium`
first), dry-run validation, and the rationale for keeping both packages at the
same version.
