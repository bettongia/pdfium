# Layout-Aware Text Reordering

**Status**: Open

**PR link**: —

## Problem statement

PDFium's native text extraction order (`FPDFText_GetText()`) follows the order
characters appear in the PDF content stream, which does not always match visual
reading order. In multi-column documents, all text from column 1 typically
precedes all text from column 2, but the content stream may interleave lines
from both columns. RTL (right-to-left) text in Arabic and Hebrew documents
presents a similar challenge.

For the primary use case of building a search index, approximate ordering is
often acceptable. However, for uses where reading order matters (document
summarisation, citation extraction, accessibility tooling), PDFium's native
ordering will produce incorrect output.

This plan covers layout-aware reordering of extracted text characters into
correct visual reading order, as a v2 enhancement to the text extraction API
established in `plan_text_extraction.md`.

**Prerequisite**: `plan_text_extraction.md` must be Complete before this plan
begins implementation.

**Web Worker dependency**: the v1 text extraction plan partially mitigates
main-thread WASM blocking via `Future.delayed(Duration.zero)` between pages, but
full remediation requires moving WASM execution to a Web Worker. That work is
coupled to this plan because the per-character `FPDFText_GetCharBox()` loop makes
Web Worker execution essential. The Web Worker implementation must be included in
this plan's scope. See `docs/spec/text_extraction.md` — Limitations section.

## Open questions

- [ ] **API shape**: Should reordering be opt-in via a parameter on
  `extractPage()` (e.g. `reorderColumns: true`), or should a separate extractor
  subclass / decorator be provided? Opt-in parameter is simpler; a separate class
  allows the reordering logic to be tested and evolved independently.
- [ ] **Column detection algorithm**: x-coordinate proximity clustering is the
  simplest approach but is sensitive to the clustering threshold. Are there
  established algorithms used by other open-source PDF tools (e.g. pdfminer,
  MuPDF's `fz_stext`) that are worth adopting or adapting?
- [ ] **RTL detection granularity**: Should RTL be detected per-character (using
  Unicode bidi category), per-line, or per-column? Per-character is most accurate
  but also most complex.
- [ ] **Tables**: Table cells in multi-column layout are a known failure case for
  x-midpoint-based column sorting. Should tables be detected and handled
  separately, or is the v2 scope limited to prose columns?
- [ ] **Rotated text**: Text at non-zero rotation angles (common in headers,
  watermarks, and some labels) will confuse a y-sorted line model. What is the
  intended behaviour?
- [ ] **Performance**: `FPDFText_GetCharBox()` is called once per character.
  For a dense page this may be thousands of calls. Is this acceptable, or should
  the algorithm batch character box queries?

## Investigation

### PDFium API surface

Character bounding boxes are available via `FPDFText_GetCharBox()`:

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV FPDFText_GetCharBox(
    FPDF_TEXTPAGE text_page,
    int index,
    double* left,
    double* right,
    double* bottom,
    double* top);
```

This is already included in the FFI bindings generated for the text extraction
plan, so no new bindings are needed.

Unicode bidi category is not exposed by PDFium; it must be computed in Dart from
the character code point. The `characters` package or a hand-rolled bidi
lookup table can be used.

### Proposed algorithm (to be validated during investigation)

1. For each character on the page, fetch its bounding box via
   `FPDFText_GetCharBox()`.
2. Cluster characters into lines by y-coordinate proximity (characters whose
   vertical midpoints are within ~half a line-height of each other belong to the
   same line).
3. Cluster lines into columns by x-coordinate proximity (lines whose horizontal
   midpoints are within a threshold of each other belong to the same column).
4. Detect the dominant bidi direction of each column from the Unicode bidi
   categories of its characters.
5. Sort columns: LTR documents sort columns left-to-right by x-midpoint; RTL
   documents sort right-to-left.
6. Within each column, sort lines top-to-bottom (PDF y-axis is inverted).
7. Within each line, sort characters by x-coordinate (left-to-right for LTR,
   right-to-left for RTL).
8. Concatenate the resulting character sequence to produce the reordered string.

### Known hard cases

| Document type | Challenge |
|---------------|-----------|
| Multi-column with footnotes | Footnotes span the full width below the columns; they must not be treated as a third column |
| Tables | Cell boundaries do not correspond to column boundaries; row-major vs column-major ordering is ambiguous |
| Rotated text | y-sort assumptions break for text at non-zero angles |
| Mixed LTR/RTL paragraphs | A single column may contain both directions |
| Justified text with large word gaps | Proximity threshold may split a single line into multiple "columns" |

## Implementation plan

_To be filled in after open questions are resolved and the algorithm is
validated._

## Summary

_To be completed after implementation._
