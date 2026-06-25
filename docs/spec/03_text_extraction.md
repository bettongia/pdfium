# Text Extraction

## Overview

The text extraction API allows a caller to extract plain Unicode text from a PDF
document. It works across all supported platforms — iOS, Android, macOS, Windows,
Linux, and web — without requiring platform-specific code from the caller. The
primary use case is feeding extracted text into a search index.

## Public API

### `PdfTextExtractorConfig`

Configuration for the heuristics used to classify documents.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `scannedPageRatio` | `double` | `0.5` | Fraction of pages that must have no text layer for `isPlainTextExtractable()` to return false. |

A single image or figure page in an otherwise text-based document will not trigger
`isPlainTextExtractable()` returning false at the default ratio of 0.5.

### `PdfDocument.fromBytes(Uint8List bytes)`

Static factory. Accepts raw PDF bytes and returns a `PdfDocument`. Throws
`PdfExtractionException(PdfError.invalidDocument)` if the document is corrupt or
not a valid PDF, or `PdfExtractionException(PdfError.passwordRequired)` if the
document is password-protected.

### Text extraction methods on `PdfDocument`

| Member | Description |
|--------|-------------|
| `pageCount` | `Future<int>` — total number of pages. |
| `extractPlainText({int? pageIndex, PdfTextExtractorConfig config})` | `Stream<PdfPageText>` — yields all pages when `pageIndex` is null, or exactly one page when specified. |
| `isPlainTextExtractable({PdfTextExtractorConfig config})` | `Future<bool>` — returns false when the proportion of pages without a text layer meets or exceeds `scannedPageRatio`. |
| `close()` | Release all resources. Safe to call more than once. Terminates any active `extractPlainText()` stream. |

### `PdfPageText`

Immutable result for a single page.

| Property | Type | Description |
|----------|------|-------------|
| `pageIndex` | `int` | 0-based page index. |
| `text` | `String` | Extracted Unicode text in PDFium's native extraction order. |
| `hasTextLayer` | `bool` | True when PDFium extracted at least one character from the page. |
| `hasUnicodeErrors` | `bool` | True when one or more characters had no Unicode mapping. |

### Stream lifecycle

Cancelling the `extractPlainText()` subscription immediately releases all
page-level native/WASM resources. `PdfDocument.close()` terminates any active
`extractPlainText()` stream and releases its page-level handles before closing
the document handle. Callers do not need to cancel streams manually before
calling `close()`.

## Behaviour by scenario

| Scenario | Behaviour |
|----------|-----------|
| Scanned page | `hasTextLayer` false, `text` empty, no exception. `isPlainTextExtractable()` returns false when ratio exceeded. |
| Unmapped character | Silently omitted by PDFium; `hasUnicodeErrors` true on that page. |
| Soft hyphen | Detected and stripped; adjacent word fragments are joined. |
| Multi-column text | Native PDFium extraction order (see [Limitations](#limitations)). |
| RTL text | Native PDFium extraction order (see [Limitations](#limitations)). |
| Password-protected PDF | `PdfExtractionException(PdfError.passwordRequired)`. |
| Corrupt / non-PDF bytes | `PdfExtractionException(PdfError.invalidDocument)`. |
| Page index out of range | `RangeError`. |

## Platform notes

On native platforms (iOS, Android, macOS, Windows, Linux) all PDFium calls run on
a dedicated `PdfiumIsolate` — a process-wide singleton that owns the PDFium library
handle and serialises all FFI calls. The caller's isolate (typically the UI isolate)
is never blocked. On web, PDFium is compiled to WebAssembly and runs on the
browser's main thread (v1 limitation; see below).

## Limitations

### Web: main-thread blocking

**Status: partially mitigated in v1; full remediation deferred.**

WASM execution is synchronous on the browser's main thread. The `async` keyword
on Dart methods does not offload WASM work to another thread. The `extractPlainText()`
stream yields to the event loop between pages via `Future.delayed(Duration.zero)`,
allowing the browser to process input and paint between page extractions. However,
a single dense page can still produce a blocking WASM call of non-trivial duration.

**Caller guidance for v1:** prefer `extractPlainText(pageIndex: n)` over the
all-pages stream when processing large documents on web, and consider displaying
progress UI between calls.

**Remediation path:** full remediation requires moving WASM execution to a
[Web Worker](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API),
communicating with the main thread via message passing — the browser equivalent
of the native isolate model. This is deferred to the layout-aware reordering
implementation (`plan_layout_aware_reordering.md`), where the per-character
`FPDFText_GetCharBox()` loop makes Web Worker execution essential regardless.
Both features should be implemented together to avoid revisiting the web
architecture twice.

### Text extraction order

**Status: v1 limitation; remediation planned.**

Text is returned in PDFium's native content-stream order, which does not always
match visual reading order. Multi-column documents and RTL text (Arabic, Hebrew)
are most affected. For search indexing this is generally acceptable; for use cases
requiring correct reading order, see `plan_layout_aware_reordering.md`.

### Scanned PDFs

No OCR capability. Pages without a text layer return an empty string with
`hasTextLayer: false`. External OCR must be applied before extraction if text
content is required.

### Password-protected PDFs

Not supported in v1. Password-protected documents surface as
`PdfError.passwordRequired`, which is distinct from `PdfError.invalidDocument`
(used for corrupt or non-PDF bytes) so callers can give users a meaningful
error message.
