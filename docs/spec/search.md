# Text Search

## Overview

The search API allows a caller to locate all occurrences of a query string
within a PDF document. It works on all native platforms (iOS, Android, macOS,
Windows, Linux) where `dart:ffi` is available. Results are streamed
page-by-page so callers can react to early matches without waiting for a full
document scan.

The feature is exposed as a pure-Dart method on `PdfDocument` — it has no
dependency on `dart:ui` or Flutter and is available from
`pdfart_core.dart`.

## Public API

### `PdfSearchFlag`

An enum controlling search matching behaviour. Values are combined in a `Set`:

| Value | PDFium constant | Meaning |
|-------|----------------|---------|
| `matchCase` | `FPDF_MATCHCASE` (0x01) | Case-sensitive match. |
| `matchWholeWord` | `FPDF_MATCHWHOLEWORD` (0x02) | Whole-word match only. |
| `consecutive` | `FPDF_CONSECUTIVE` (0x04) | Allow overlapping matches. |

### `PdfSearchMatch`

Immutable result for a single search match.

| Property | Type | Description |
|----------|------|-------------|
| `pageIndex` | `int` | Zero-based page index. |
| `charIndex` | `int` | Zero-based character index of the first matched character on this page. |
| `charCount` | `int` | Number of matched characters. |
| `rects` | `List<PdfRect>` | Bounding rectangles in PDF user-space (origin bottom-left, points). One rect per visual line fragment. |

### `PdfDocument.search`

```dart
Stream<PdfSearchMatch> search(
  String query, {
  Set<PdfSearchFlag> flags = const {},
  int? pageIndex,
})
```

Searches the document for `query` and streams all matches in ascending page
order.

| Parameter | Description |
|-----------|-------------|
| `query` | The text to search for. An empty string produces an empty stream immediately. |
| `flags` | Controls case-sensitivity, whole-word matching, and overlapping. Defaults to case-insensitive, non-whole-word, non-overlapping. |
| `pageIndex` | When set, restricts the search to that single page. Throws `RangeError` if out of range. |

## Coordinate system

`PdfSearchMatch.rects` are in **PDF user space**: origin at the bottom-left of
the page, units in points (1 point = 1/72 inch). This is consistent with the
coordinate system used by `PdfRect` and page-size values throughout this
library.

Callers that need screen coordinates must transform them using
`FPDF_PageToDevice()` / `FPDF_DeviceToPage()` from the PDFium bindings, or
apply a simple y-axis flip when the device origin is top-left.

A note on multi-column layout: PDFium returns text in content-stream order,
not visual reading order. A match that spans a line-wrapping point on a
multi-column page may produce bounding rectangles that appear on different
visual columns. This is a known v1 limitation consistent with the text
extraction behaviour.

## Stream lifecycle

The `search()` stream follows the same lifecycle as `extractPlainText()`:

- Cancelling the subscription immediately stops further processing. Page-level
  PDFium handles (`FPDF_TEXTPAGE`, `FPDF_SCHHANDLE`) are released inside the
  isolate after each per-page round-trip completes, so there are no handle
  leaks on cancellation.
- `PdfDocument.close()` terminates any active stream. The stream stops
  emitting events and the subscription is silently cancelled. Callers do not
  need to cancel streams manually before calling `close()`.
- Each isolate round-trip handles one page: loads the text page, runs the full
  find loop for that page, closes all handles, and returns the matches as a
  list. This mirrors `extractPlainText()` and `extractAnnotations()`.

## Behaviour by scenario

| Scenario | Behaviour |
|----------|-----------|
| Empty query string | Returns an empty stream immediately without any PDFium calls. |
| Query not found on page | `FPDFText_FindNext` returns 0; the page produces no matches and the stream moves to the next page. |
| Page has no text layer | `FPDFText_LoadPage` returns null; the page produces no matches. Not an error. |
| Multi-line match | Multiple rects from `FPDFText_GetRect`; all included in `PdfSearchMatch.rects`. |
| `close()` called during active stream | `_closed` flag is checked before each isolate round-trip and before yielding each match; stream terminates promptly. |
| Scanned (image-only) PDF | All pages have no text layer; stream completes empty. |
| `pageIndex` out of range | Throws `RangeError` before any PDFium calls are made. |
| Overlapping matches | Only produced when `PdfSearchFlag.consecutive` is set. |
| Very long query string | UTF-16LE encoding handles any Dart string; no length limit in the PDFium API. |

## Platform notes

| Platform | Status |
|----------|--------|
| iOS, Android, macOS, Windows, Linux | Fully supported via `dart:ffi` + `PdfiumIsolate`. |
| Web | Throws `UnsupportedError` (PDFium WASM implementation pending). |
| Stub (other) | Throws `UnsupportedError`. |

## Implementation notes

### Isolate protocol

The search is implemented as a new `PdfiumSearchPageCommand` message type in
the `PdfiumIsolate` protocol. Each invocation of the command handles exactly
one page (matching the per-page model used by `PdfiumExtractPageTextCommand`
and `PdfiumExtractPageAnnotationsCommand`).

The `query` string is encoded inside the isolate as a null-terminated UTF-16LE
buffer (`FPDF_WIDESTRING = Pointer<UnsignedShort>`) before being passed to
`FPDFText_FindStart`. Dart strings are natively UTF-16, so the encoding is a
direct code-unit copy followed by a null terminator — no surrogates are
decoded or re-encoded.

### Handle lifecycle (inside the isolate)

For each `PdfiumSearchPageCommand`:

1. `FPDF_LoadPage` — may fail (bad page index or corrupt page); returns error
   on failure.
2. `FPDFText_LoadPage` — may return null (no text layer); returns empty
   matches, not an error.
3. UTF-16LE buffer allocation.
4. `FPDFText_FindStart` — starts the search; may return null; returns empty
   matches if null.
5. Loop: `FPDFText_FindNext` → `FPDFText_GetSchResultIndex` /
   `FPDFText_GetSchCount` → `FPDFText_CountRects` / `FPDFText_GetRect`.
6. `FPDFText_FindClose` — always called in a `finally` block.
7. `calloc.free` — frees the UTF-16LE buffer (always in a `finally` block).
8. `FPDFText_ClosePage` — always called in a `finally` block.
9. `FPDF_ClosePage` — always called in a `finally` block.

The nested `try/finally` structure ensures no handle is leaked even when an
exception occurs mid-loop.
