# Text Search

**Status**: Complete

**PR link**: TBD

## Problem statement

`PdfDocument` has no way to search for text within a document. Users need to be
able to pass a query string and receive back the set of matching locations — one
record per match, identifying the page, the character range within that page,
and the bounding rectangles so callers can highlight or navigate to results.

This is a pure-Dart feature (no Flutter dependency) and must be exposed through
`lib/pdfart_core.dart`.

The roadmap item is in [docs/roadmap/0_03_1.md](../roadmap/0_03_1.md).

---

## Open questions

- [x] Should search return results as a `Stream` (lazy, per-page) or a `Future<List>` (eager, all pages)?
- [x] Should bounding rectangles be in PDF coordinates (points, origin bottom-left) or normalised device coordinates?
- [x] Should `bin/pdfinfo.dart` be extended with a `--search` flag?

---

## Investigation

### PDFium search API

All required bindings are already generated in
[lib/src/generated/pdfium_bindings.dart](../../lib/src/generated/pdfium_bindings.dart).
No `ffigen` re-run is needed.

The PDFium search workflow (per page):

1. `FPDFText_LoadPage(doc, pageIndex)` → `FPDF_TEXTPAGE`
2. `FPDFText_FindStart(textPage, findwhat, flags, startIndex)` → `FPDF_SCHHANDLE`
3. Loop: `FPDFText_FindNext(handle)` returns non-zero while a match exists
   - `FPDFText_GetSchResultIndex(handle)` → start character index
   - `FPDFText_GetSchCount(handle)` → character count of match
   - `FPDFText_CountRects(textPage, startIndex, count)` → number of bounding rects
   - Loop: `FPDFText_GetRect(textPage, rectIndex, left, top, right, bottom)` → one rect per visual line fragment
4. `FPDFText_FindClose(handle)` — must always be called
5. `FPDFText_ClosePage(textPage)` — must always be called

Relevant flags in `fpdf_text.h`:

| Flag | Value | Meaning |
|---|---|---|
| `FPDF_MATCHCASE` | `0x00000001` | Case-sensitive match |
| `FPDF_MATCHWHOLEWORD` | `0x00000002` | Whole-word match only |
| `FPDF_CONSECUTIVE` | `0x00000004` | Allow overlapping matches |

A match on a line that wraps across two visual rows will produce **two** rects
from `FPDFText_GetRect`. Callers should treat the rects list as "all fragments
that make up this match".

### Bounding rectangle coordinate system

`FPDFText_GetRect` returns coordinates in **PDF user space** (points, origin
bottom-left). This is consistent with how page sizes are reported by
`FPDF_GetPageWidthF` / `FPDF_GetPageHeightF`. The caller is responsible for
any coordinate transformation needed for display (e.g. flip the y-axis for
Flutter). We should expose raw PDF coordinates and document this clearly —
it mirrors the approach taken for page sizes throughout the library.

### Proposed public Dart API

```dart
// lib/src/document/pdf_types.dart

/// Search flags for [PdfDocument.search].
enum PdfSearchFlag {
  matchCase,
  matchWholeWord,
  consecutive,
}

/// A single match returned by [PdfDocument.search].
class PdfSearchMatch {
  const PdfSearchMatch({
    required this.pageIndex,
    required this.charIndex,
    required this.charCount,
    required this.rects,
  });

  /// Zero-based index of the page on which this match was found.
  final int pageIndex;

  /// Zero-based character index of the first matched character on this page.
  final int charIndex;

  /// Number of matched characters.
  final int charCount;

  /// Bounding rectangles in PDF user-space (origin bottom-left, points).
  /// A multi-line match produces one rect per visual line fragment.
  /// Uses the existing [PdfRect] type — same coordinate space as page sizes.
  final List<PdfRect> rects;
}
```

```dart
// lib/src/document/_document_native.dart (and abstract interface)

/// Search the document for [query] and return all matches as a stream.
///
/// Results are yielded page-by-page in ascending page order. An empty stream
/// means no matches were found.
///
/// [flags] controls case-sensitivity, whole-word matching, and overlapping
/// matches. Defaults to case-insensitive, non-whole-word.
///
/// [pageIndex] restricts the search to a single page. Omit to search all pages.
///
/// Bounding rectangles are in PDF user-space (origin bottom-left, units in
/// points).
Stream<PdfSearchMatch> search(
  String query, {
  Set<PdfSearchFlag> flags = const {},
  int? pageIndex,
});
```

A `Stream` is preferred over `Future<List>` for the same reasons as
`extractPlainText`: the document may have hundreds of pages, and streaming
lets the caller get results incrementally without waiting for the full scan.

### Isolate message additions

Following the existing pattern, two new message types are required in
[lib/src/document/isolate_messages.dart](../../lib/src/document/isolate_messages.dart):

**`PdfiumSearchPageCommand`**
- Fields: `replyPort`, `token` (doc), `pageIndex`, `query` (String), `flags` (int bitmask)
- The isolate executes the entire find loop for one page and returns all matches.
- Keeping it per-page mirrors `PdfiumExtractPageTextCommand` and avoids
  holding multiple `FPDF_SCHHANDLE`s open across round-trips.

**`PdfiumSearchPageResponse`** (success / failure)
- Success carries `List<PdfSearchMatch>` (may be empty).
- Failure carries an error message string.

### Dispatch in `pdfium_isolate.dart`

Add a new `else if (message is PdfiumSearchPageCommand)` branch in the message
handler loop at line 89 of
[lib/src/document/pdfium_isolate.dart](../../lib/src/document/pdfium_isolate.dart).
The handler allocates a `FPDF_WIDESTRING` on the native heap for the query,
calls `FPDFText_FindStart`, iterates `FPDFText_FindNext`, collects all matches,
calls `FPDFText_FindClose` and `FPDFText_ClosePage` unconditionally (in a
`try/finally`), then sends the response.

`FPDF_WIDESTRING` requires a UTF-16LE-encoded null-terminated C string.
The existing TOC implementation at line ~1680 of `pdfium_isolate.dart` already
shows the pattern for `FPDF_WIDESTRING` allocation using `calloc` and
`Pointer<Uint16>`. Reuse that helper.

### Stub and web implementations

[lib/src/document/_document_stub.dart](../../lib/src/document/_document_stub.dart)
and [lib/src/document/_document_web.dart](../../lib/src/document/_document_web.dart)
need `search()` added. Both should throw `UnsupportedError` (not
`UnimplementedError`), consistent with how other platform-unsupported methods
are handled there.

### `bin/pdfinfo.dart`

The CLI should gain a `--search <query>` flag that prints page number, character
index, and bounding rects. This is low-complexity and fits within the same PR.

### Edge cases and failure scenarios

| Scenario | Handling |
|---|---|
| Empty query string | Return empty stream immediately (guard before any PDFium call) |
| Query not found on page | `FPDFText_FindNext` returns 0 immediately; emit nothing for that page |
| Page has no text layer | `FPDFText_LoadPage` returns null; emit nothing and continue |
| Multi-line match | Multiple rects from `FPDFText_GetRect`; all included in `PdfSearchMatch.rects` |
| `close()` called during active stream | Follow the existing `extractPlainText` cancellation pattern |
| Search on a scanned (image-only) PDF | All pages will have no text layer; stream completes empty |
| Very long query string | UTF-16 encoding still works; no length limit in PDFium API |
| Overlapping matches | Only produced when `PdfSearchFlag.consecutive` is set |
| Out-of-range `pageIndex` | Throw `RangeError`, consistent with `extractPlainText` and `extractAnnotations` |

### Test strategy

- Unit tests with a real PDF (use existing test assets from `test/`).
- Golden-path: single match, multiple matches across pages, case-insensitive.
- Edge cases: no matches, empty query, single-page restriction, whole-word flag, out-of-range `pageIndex`.
- `close()` interleaved with active search stream.
- CLI flag output format.

---

## Implementation plan

- [x] Add `PdfSearchFlag` and `PdfSearchMatch` to `pdf_types.dart` (use existing `PdfRect` for bounding rectangles)
- [x] Add `search()` abstract method to the `PdfDocument` interface / abstract class
- [x] Add `PdfiumSearchPageCommand` and `PdfiumSearchPageResponse` to `isolate_messages.dart`
- [x] Implement the isolate handler in `pdfium_isolate.dart`
- [x] Implement `search()` in `_document_native.dart`
- [x] Add `search()` stub to `_document_stub.dart` and `_document_web.dart`
- [x] Add `--search` flag to `bin/pdfinfo.dart`
- [x] Write `docs/spec/search.md` (public API, streaming lifecycle, edge-case behaviour, platform notes)
- [x] Write tests (golden-path + edge cases)
- [x] Update doc comments and ensure 90%+ coverage
- [x] Run `make pre_commit` (format + analyze + license check)
- [x] Update roadmap: mark Search item with plan link

---

## Questions

- [x] Should `PdfSearchRect` be replaced with the existing `PdfRect` type?
  Yes — `PdfSearchRect` removed; `PdfSearchMatch.rects` uses `List<PdfRect>`.

- [x] Should a spec entry for the search API be added to `docs/spec/`?
  Yes — `docs/spec/search.md` task added to the implementation plan checklist.

- [x] Should the isolate response type follow the existing `.success`/`.failure`
  named constructor pattern?
  Yes — `PdfiumSearchPageResponse` will use a single class with `.success(…)`
  and `.failure(…)` named constructors, consistent with all other response types.

---

## Reviews

### Review 1: 2026-05-20

_Reviewed: 2026-05-20_

**Problem Statement Assessment**

The problem is real and well-scoped. `PdfDocument` having no search capability
is a meaningful gap, and the PDFium API (`fpdf_text.h`) has the surface required
to implement it cleanly. The roadmap entry in `docs/roadmap/0_03_1.md` confirms
this is planned work. The decision to expose search through `pdfart_core.dart`
(no Flutter dependency) is correct and consistent with the library's architectural
split.

**Proposed Solution Assessment**

The per-page isolate command approach (`PdfiumSearchPageCommand`) is the right
call. It mirrors `PdfiumExtractPageTextCommand`, keeps the isolate message
protocol uniform, and avoids holding multiple `FPDF_SCHHANDLE`s open across
round-trips. The `Stream<PdfSearchMatch>` return type is well-motivated: lazy
per-page delivery lets callers get early results without waiting for a full scan,
consistent with `extractPlainText`.

The edge-case table is thorough and the `try/finally` requirement for
`FPDFText_FindClose` and `FPDFText_ClosePage` is correctly called out. The
`close()` interleaved with active stream scenario correctly points to the existing
`_closed` guard pattern used in `_extractPlainTextImpl` and
`_extractAnnotationsImpl`.

Three issues require resolution before this plan is implementation-ready:

1. **`PdfSearchRect` is a redundant type.** `PdfRect` already exists in
   `pdf_types.dart` with identical semantics — four `double` fields (`left`,
   `bottom`, `right`, `top`) in PDF user space, bottom-left origin. The plan's
   `PdfSearchRect` duplicates this exactly and also introduces a field-ordering
   inconsistency (its constructor lists `top` before `bottom`, opposite to
   `PdfRect`). `PdfSearchMatch.rects` should be typed as `List<PdfRect>` and
   `PdfSearchRect` should not be added. This is a clear fix, not a trade-off.

2. **No spec entry is planned.** The project convention requires a full spec
   document in `docs/spec/` for every new public API surface (see memory:
   `project_spec_coverage.md` and `docs/spec/text_extraction.md` as the
   reference depth). The implementation plan checklist has no "write
   `docs/spec/search.md`" task. A spec covering the public API, streaming
   lifecycle, edge-case behaviour table, and platform notes must be added to the
   checklist before this plan reaches `Investigated`.

3. **Response type naming diverges from the existing protocol convention.** The
   plan describes a `PdfiumSearchPageResponse` class as if it is a separate
   success/failure pair. Every current response type (`PdfiumExtractPageTextResponse`,
   `PdfiumGetTocResponse`, `PdfiumExtractPageAnnotationsResponse`, etc.) uses a
   single class with `.success(…)` and `.failure(…)` named constructors. The
   implementation must follow this pattern.

**Architecture Fit**

The approach integrates cleanly: new message types in `isolate_messages.dart`, a
new dispatch branch in `pdfium_isolate.dart`, and a new `search()` method on the
`PdfDocumentImpl` abstract class and the three platform implementations. The
`_document_stub.dart` and `_document_web.dart` stubs should throw
`UnsupportedError` (not `UnimplementedError`) to be consistent with how other
platform-unsupported methods are handled in this codebase. Verify this against
the existing stub before implementing.

The UTF-16LE `FPDF_WIDESTRING` allocation note is valuable — reusing the helper
already present in `pdfium_isolate.dart` for the TOC implementation is the
correct approach.

**Risk and Edge Cases**

The edge-case table is well-constructed. One additional scenario not listed:
what happens when `pageIndex` is provided but is out of range? The existing
`extractPlainText` and `extractAnnotations` implementations both throw
`RangeError`. The plan should state this expectation explicitly and include a
test for it.

The note that a multi-line match produces multiple rects is correct and already
covered. The warning that PDFium text extraction order is content-stream order
(not visual reading order) applies equally to search — a match that spans a
line-wrapping point on a multi-column page may produce surprising rects. This
is acceptable as a v1 limitation, consistent with the text extraction spec, but
worth a brief note in the spec.

**Recommendations**

1. Replace `PdfSearchRect` with `List<PdfRect>` in `PdfSearchMatch.rects`.
   Remove `PdfSearchRect` from the plan entirely.
2. Add a "Write `docs/spec/search.md`" task to the implementation plan checklist.
3. Confirm the response type will use the `.success`/`.failure` named constructor
   pattern and update the plan text to reflect this.
4. Add an out-of-range `pageIndex` test case to the test strategy.
5. Confirm that the stub implementations use `UnsupportedError`, not
   `UnimplementedError`.

Once the three questions above are resolved and the checklist updated, this plan
should be promoted to `Investigated`.

---

## Summary

Implementation complete. `PdfDocument.search(query, {flags, pageIndex})` streams
`PdfSearchMatch` results page-by-page using the PDFium `FPDFText_FindStart` /
`FPDFText_FindNext` API. New public types: `PdfSearchFlag` (enum) and
`PdfSearchMatch` (immutable result with `pageIndex`, `charIndex`, `charCount`,
and `rects: List<PdfRect>`).

The isolate protocol gained `PdfiumSearchPageCommand` and
`PdfiumSearchPageResponse` following the existing per-page command pattern.
`bin/pdfinfo.dart` gained `--search <query>` for plain-text and JSON output.
37 tests cover golden-path, edge cases (empty query, no matches, scanned PDFs,
out-of-range page index, close() interleaved with stream), CLI output, and value
type equality/hashCode/toString. Coverage: 90.7%.
