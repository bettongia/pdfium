# Test Coverage: Reach 95%

**Status**: Investigated

**PR link**: _not yet submitted_

## Problem statement

`betto_pdfium` sits at **61.4 % line coverage** (1,100 / 1,792 tracked lines) as
of 2026-06-26. The project minimum is 90 %; the goal of this plan is to raise
coverage to **95 %** (≥ 1,703 / 1,792 lines). All work is confined to
`packages/betto_pdfium/test/`.

The primary driver of the gap is straightforward: four major public API methods
— `extractAnnotations()`, `getDocumentInfo()`, `renderPageToBytes()`, and
`getPageSize()` — have **zero** coverage in the `dart test` suite. Together
they account for hundreds of tracked lines in `pdfium_isolate.dart` and
`_document_native.dart`. Secondary gaps come from untested branches in value
types and error paths.

Coverage is measured with `make coverage`; `*/generated/*` is excluded from the
lcov report.

## Open questions

- [x] Does the coverage measurement environment guarantee the PDFium binary is
      present? The 95 % target is only reachable when Phase 2–4 integration tests
      actually run (they skip gracefully when the dylib is absent). `make
      coverage` does not run `make fetch_pdfium`, though the native-assets hook
      downloads the binary on any `dart test`. Confirm CI runs coverage with the
      binary available, or the headline figure will silently regress to ~69 %.

      _Confirmed._ The CI workflow (`.github/workflows/cicd.yml`) caches the
      binary at `.dart_tool/betto_pdfium` keyed on `PDFIUM_VERSION`. On a cache
      hit the binary is present before `make cicd` runs. On a cache miss the
      native-assets hook downloads it during the first `dart test` invocation
      inside `make cicd`. Either way the binary is available when coverage is
      measured. No action needed.

## Investigation

### Per-file baseline (2026-06-26)

| File | Lines | Covered | % |
|------|------:|--------:|--:|
| `lib/src/pdf_exception.dart` | 3 | 0 | **0 %** |
| `lib/src/rendering/pdf_page_size.dart` | 14 | 1 | **7 %** |
| `lib/src/document/pdfium_isolate.dart` | 928 | 440 | **47 %** |
| `lib/src/document/isolate_messages.dart` | 66 | 44 | **67 %** |
| `lib/src/document/pdf_document.dart` | 27 | 20 | **74 %** |
| `lib/src/document/_document_native.dart` | 219 | 166 | **76 %** |
| `lib/src/document/pdf_types.dart` | 497 | 392 | **79 %** |
| `lib/src/document/pdf_date_parser.dart` | 38 | 37 | **97 %** |
| **Total** | **1,792** | **1,100** | **61 %** |

### Root cause: untested API methods

Grepping `packages/betto_pdfium/test/` confirms four public `PdfDocument`
methods have zero calls in the `dart test` suite:

| Method | Handler in `pdfium_isolate.dart` |
|--------|----------------------------------|
| `extractAnnotations()` | `_handleExtractPageAnnotations` (line ~663) |
| `getDocumentInfo()` | `_handleGetDocumentInfo` (line ~314) |
| `renderPageToBytes()` | `_handleRenderPage` (line ~1580+) |
| `getPageSize()` | `_handleGetPageSize` (line ~1488+) |

Note: `extractAnnotations()` is exercised by the `integration_test_app` Flutter
suite, but that suite does not contribute to `dart test` coverage. The
annotation extraction implementation is fully complete (types, isolate handler,
fixtures); it just needs a companion test file in `packages/betto_pdfium/test/`.

### `pdfium_isolate.dart` gap detail

492 uncovered lines (out of 928 tracked). The main clusters:

- Lines ~314–400 — `_handleGetDocumentInfo` (never called)
- Lines ~663–760 — `_handleExtractPageAnnotations` dispatch and per-page loop
  (never called)
- Lines ~1371–1485 — `_withPopup` helper (called only when a PDF has
  popup-linked annotations; fixtures `popup_*.pdf` exist but no test loads them)
- Lines ~1580–1720 — `_handleRenderPage` (never called)
- Lines ~1870+ — `_handleGetPageSize` (never called)
- Scattered error/guard paths throughout (invalid token, null page pointer, etc.)

`_defaultDylibPathOrNull()` (line ~2824) is also uncovered because all tests
inject an explicit `dylibPath` via `nativeDylibPath()` — the auto-detect path
is never exercised.

### `_document_native.dart` gap detail (53 uncovered lines)

The uncovered lines fall into two categories:

1. **Untested API methods**: `extractAnnotations` (line ~230), stream tear-down
   when `close()` is called mid-stream (~line 320), `renderPageToBytes` (~361),
   `getPageSize` (~376), `getDocumentInfo` (~462).
2. **Error paths**: `fromBytes` loading-failure guard (~lines 65–67, 92), and
   the `_closed` guard in several methods (~lines 121–127, 141, 184–185, 202).

### `pdf_types.dart` gap detail (105 uncovered lines)

| Lines | Missing coverage |
|-------|-----------------|
| 65, 70–71 | `_listEqual` — length-mismatch branch and element-mismatch branch |
| 154–164 | `PdfMetadata.toString()` |
| 259, 261 | `PdfTextExtractorConfig.toString()` |
| 354–356 | `PdfColor.toString()` |
| 399–400 | `PdfRect.hashCode` and `toString()` |
| 444 | `PdfQuadPoints` equality non-identical branch |
| 463–476 | `PdfPopupAnnotation` equality and `hashCode` |
| 595–624 | `PdfFreeTextAnnotation` equality branches and `hashCode` |
| 680–746 | `PdfMarkupAnnotation` equality branches, `hashCode`, `toString()` |
| 1149–1152 | `PdfUnknownAnnotation.toString()` |
| 1162, 1176–1179 | `PdfPageAnnotations.toString()` |
| 1821, 1842–1849 | `PdfDocumentInfo` constructor and `toString()` |

### Smaller gaps

- **`pdf_exception.dart`** (3 lines, 0 % covered): `PdfiumException`
  constructor and `toString()` are never instantiated in tests.
- **`pdf_page_size.dart`** (13 uncovered of 14): Only the constructor's opening
  brace is covered. `aspectRatio`, `sizeForDpi()`, `toString()`, `==`, and
  `hashCode` are all untested.
- **`isolate_messages.dart`** (22 uncovered lines): Message type factory/
  constructor branches that are only reached by error paths or by the untested
  API handlers above.

## Implementation plan

### Phase 1 — Unit tests for pure-Dart value types (no native binary)

Target gain: ~120 lines. These tests have no dependency on the PDFium dylib and
can run in CI without the binary.

- [ ] **New file `test/pdf_exception_test.dart`**
  - Construct `PdfiumException("some message")`.
  - Verify `toString()` → `'PdfiumException: some message'`.
  - Construct `PdfExtractionException(PdfError.invalidDocument)` (already in
    `pdf_types.dart`) and verify its `toString()`.
  - Verify `PdfError` enum values (`invalidDocument`, `passwordRequired`).

- [ ] **New file `test/pdf_page_size_test.dart`**
  - `aspectRatio` — A4 page (595 × 842 pt) → ~0.707; zero-height page → 1.0.
  - `sizeForDpi` — A4 at 150 DPI → ~1239 × 1754 px; non-positive DPI → (0.0, 0.0).
  - `toString()` output contains widthPt and heightPt.
  - Equality: same values → equal; differing width/height → unequal.
  - `hashCode` consistent with equality.

- [ ] **Expand `test/pdf_types_test.dart`** to cover the gaps listed above:
  - `_listEqual` helper — exercise length-mismatch and element-mismatch branches
    via any list-carrying annotation type (e.g. `PdfInkAnnotation.strokes`).
  - `PdfMetadata.toString()` — construct a fully-populated instance and call
    `toString()`.
  - `PdfTextExtractorConfig.toString()`.
  - `PdfColor.toString()`.
  - `PdfRect.hashCode` and `toString()`.
  - `PdfQuadPoints` equality non-identical branch.
  - `PdfPopupAnnotation` equality (`==`) and `hashCode`.
  - `PdfFreeTextAnnotation` equality and `hashCode`.
  - `PdfMarkupAnnotation` equality, `hashCode`, `toString()` — use each
    markup subtype (highlight, underline, squiggly, strikeout).
  - `PdfUnknownAnnotation.toString()`.
  - `PdfPageAnnotations.toString()`.
  - `PdfDocumentInfo` constructor (with non-null `permanentId`/`changingId`)
    and `toString()`.

- [ ] **New file `test/isolate_messages_test.dart`**
  - Instantiate the message types that correspond to the four untested API
    methods: `PdfiumExtractPageAnnotationsCommand`,
    `PdfiumGetDocumentInfoCommand`, `PdfiumRenderPageCommand`,
    `PdfiumGetPageSizeCommand`.
  - Instantiate their matching `Response` types (both success and failure
    variants) and verify field access.
  - This exercises the 22 uncovered factory/constructor branches without
    requiring the native binary.

### Phase 2 — Integration tests for untested API methods

Target gain: ~300 lines. These tests require the native binary; skip gracefully
when unavailable (same pattern as `image_extraction_test.dart`).

**Note**: all four API methods have complete implementations and test fixtures
already present. This phase is purely adding the missing test files.

- [ ] **New file `test/annotation_extraction_test.dart`**

  Mirror the structure of `image_extraction_test.dart`.

  Fixture files available in `test/fixtures/`:

  | Fixture | Expected content |
  |---------|-----------------|
  | `no_annotations.pdf` | 0 annotations on all pages |
  | `annotated_text.pdf` | Text annotations (`PdfTextAnnotation`) |
  | `annotated_shapes.pdf` | Shape annotations (`PdfShapeAnnotation`) |
  | `annotated_ink.pdf` | Ink annotations (`PdfInkAnnotation`) |
  | `annotated_extra.pdf` | Additional annotation types |
  | `popup_annotation.pdf` | Text annotation with a linked popup |
  | `popup_freetext.pdf` | FreeText annotation with a linked popup |
  | `popup_multi.pdf` | Multiple popup-linked annotations |
  | `zero_ink_stroke.pdf` | Ink annotation with a zero-point stroke |
  | `zero_polygon_vertices.pdf` | Polygon annotation with empty vertices |

  Cover:
  - `no_annotations.pdf` → stream yields one `PdfPageAnnotations` per page,
    each with an empty `annotations` list.
  - `annotated_text.pdf` → first page contains a `PdfTextAnnotation`; verify
    `contents`, `rect`, `color`, `flags`.
  - `popup_annotation.pdf` → annotation has a non-null `popup` field (exercises
    `_withPopup` for `PdfTextAnnotation`).
  - `popup_freetext.pdf` → `PdfFreeTextAnnotation` with a non-null `popup`
    (exercises `_withPopup` for `PdfFreeTextAnnotation`).
  - `popup_multi.pdf` → multiple annotations have popups.
  - `annotated_shapes.pdf` → `PdfShapeAnnotation` with expected `subtype`.
  - `annotated_ink.pdf` → `PdfInkAnnotation` with non-empty `strokes`.
  - `zero_ink_stroke.pdf` → ink annotation with a zero-point stroke is returned
    with an empty `strokes` entry (guard at isolate line ~1053).
  - `zero_polygon_vertices.pdf` → polygon with empty vertices (guard at ~1085).
  - Out-of-range `pageIndex` → throws `RangeError`.
  - `extractAnnotations` after `close()` → throws `StateError`.
  - `close()` during active stream → terminates cleanly.
  - Single `pageIndex` argument returns only that page.

  Reference `.annot.json` files exist for the basic fixtures; cross-check
  annotation counts and types against those.

- [ ] **New file `test/rendering_test.dart`** (covers `renderPageToBytes` and `getPageSize`)

  - `getPageSize(0)` on `01_basic.pdf` → returns a `PdfPageSize` with positive
    `widthPt` / `heightPt` (typical A4: ~595 × 842).
  - `getPageSize` on a multi-page PDF → each page may differ; verify at least
    pages 0 and 1.
  - Out-of-range page index → throws `RangeError`.
  - `renderPageToBytes(0, 100, 100)` → returns a record
    `({Uint8List pixels, int pixelWidth, int pixelHeight})`; verify
    `result.pixels.length == 100 * 100 * 4` (BGRA) and `result.pixelWidth == 100`.
  - `result.pixels` is not all-zero for a text page.
  - `renderPageToBytes` out-of-range page index → throws `RangeError`.
  - Non-positive width or height → throws `RangeError`.
  - `getPageSize` / `renderPageToBytes` after `close()` → throws `StateError`.

- [ ] **Expand `test/pdfinfo_test.dart`** to cover `getDocumentInfo()`

  The `pdfinfo` CLI already calls `getDocumentInfo()` via `--all`; confirm via
  a direct API test rather than CLI subprocess:
  - Call `getDocumentInfo()` on `full_metadata.pdf` → `fileVersion` is non-null
    and plausible (≥ 14 for PDF 1.4).
  - Call on `partial_metadata.pdf` → `permanentId` may be null; no exception.
  - Call on `no_metadata.pdf` → call succeeds; all fields may be null.
  - `toString()` on `PdfDocumentInfo` with non-null `permanentId` produces a
    hex string.
  - `getDocumentInfo()` after `close()` → throws `StateError`.

### Phase 3 — Error-path tests

Target gain: ~80 lines. These exercise the error-handling branches in
`_document_native.dart` and `pdfium_isolate.dart`.

- [ ] **New file `test/error_handling_test.dart`**

  - `PdfDocument.fromBytes(corrupt)` → throws `PdfExtractionException`.
    Fixture: `corrupt.pdf`. Confirm the exact `PdfError` value against the
    fixture when writing the test; based on the isolate implementation
    (`_handleLoadDocument` maps `FPDF_ERR_PASSWORD = 4` → `passwordRequired`,
    all others → `invalidDocument`) the expected value is
    `PdfError.invalidDocument`, but verify rather than assume.
  - `PdfDocument.fromBytes(password)` → throws `PdfExtractionException`.
    Fixture: `password.pdf`. Expected `error == PdfError.passwordRequired`
    per the same mapping; confirm before asserting.
  - _Note:_ the `integration_test_app` error-handling tests mistakenly assert
    `PdfiumException` for these fixtures; the native implementation actually
    throws `PdfExtractionException`. The `integration_test_app` tests need a
    separate fix (out of scope here).
  - `close()` is idempotent — calling it twice does not throw.
  - All stream-returning methods (`extractPlainText`, `extractAnnotations`,
    `extractImages`) throw `StateError` immediately when called on a closed
    document.
  - All `Future`-returning methods (`getMetadata`, `getDocumentInfo`,
    `pageCount`, `getPageSize`, `getThumbnail`, `tableOfContents`) throw
    `StateError` when called on a closed document.

  Error guards for the `_closed` flag in `_document_native.dart` (lines
  ~121–127, 141, 184–185, 202) will be covered by the closed-document tests
  scattered throughout phases 2 and 3; consolidate remaining gaps here.

### Phase 4 — Isolate infrastructure and remaining gaps

Target gain: ~30 lines. Lower priority; depends on Phases 1–3 first.

- [ ] **Init-failure path**

  Test that `PdfiumIsolate.ensureInitialised()` raises `StateError` when given a
  non-existent dylib path. This covers the `PdfiumInitFailedResponse` branch
  (~lines 2776–2782). Use a temporary path that does not exist.

- [ ] **`pdf_date_parser.dart` final line**

  One line (line 38) is uncovered — likely the edge case where the input is
  empty or `null`. Add a test in `pdf_date_parser_test.dart` for that branch.

### Coverage checkpoints

Run `make coverage` after each phase and confirm progress:

| After phase | Expected cumulative coverage |
|-------------|------------------------------|
| Phase 1 | ≥ 69 % |
| Phase 2 | ≥ 87 % |
| Phase 3 | ≥ 92 % |
| Phase 4 | ≥ 95 % (use HTML report after Phase 3 to fill any remaining gap) |

If coverage after Phase 3 falls short of 92 %, use the HTML report in
`site/coverage/` to identify remaining uncovered lines before starting Phase 4.

## Reviews

### Review 1: 2026-06-26

**Problem Statement Assessment**

The problem is real and well worth solving. The package is at 61.4 % line
coverage against a 90 % project minimum — that is a hard policy breach, not a
nice-to-have. The diagnosis is also correct and I verified it independently:
grepping `test/` for `extractAnnotations`, `getDocumentInfo`,
`renderPageToBytes`, and `getPageSize` returns zero matches, so all four public
methods genuinely have no `dart test` coverage. The framing is honest: the
implementations and fixtures already exist; this is a test-authoring exercise,
not a feature build. That is exactly the right scope for a coverage plan.

One framing nuance worth stating plainly: the gap is partly an artefact of the
coverage *measurement boundary*. `extractAnnotations()` is exercised by the
`integration_test_app` Flutter suite (the plan acknowledges this), but that
suite does not feed the `dart test` lcov report. So some of these "untested"
methods are not untested in absolute terms — they are untested *by the suite
that the coverage gate reads*. The plan handles this correctly by adding native
`dart test` coverage, but it is worth being clear that we are closing a
measurement gap as much as a real-confidence gap for annotations.

**Proposed Solution Assessment**

Strong. The phased structure is sensible and correctly ordered by dependency
and risk:

- Phase 1 (pure-Dart value types) front-loads the binary-free wins. I confirmed
  every referenced type exists: `PdfiumException` (`pdf_exception.dart:36`),
  `PdfPageSize` (`pdf_page_size.dart:33`), `PdfDocumentInfo`
  (`pdf_types.dart:1819`), and all the annotation subtypes. The
  `pdf_page_size.dart` targets (`aspectRatio`, `sizeForDpi`, `toString`, `==`,
  `hashCode`) all map to real, currently-uncovered members, including the two
  guard branches (`heightPt > 0` and `dpi <= 0`) that the plan's specific test
  values are chosen to hit. Good.
- Phase 2/3 reuse the established `image_extraction_test.dart` pattern
  (`nativeDylibPath()` + graceful skip), which is the right call — it keeps the
  new tests consistent with the suite and CI-safe.
- I verified all 15 fixture PDFs referenced across the plan exist in
  `test/fixtures/`, plus `data/01_basic.pdf`. No missing-fixture surprises.

Two factual defects in the plan that will mislead the implementer:

1. **`renderPageToBytes` return type is wrong in Phase 2.** The plan says it
   "returns a `Uint8List` with length `100 * 100 * 4`". The actual signature
   (`pdf_document.dart:275`) returns a record
   `({Uint8List pixels, int pixelWidth, int pixelHeight})`. The length assertion
   must target `result.pixels.length`, and the "not all-zero" check likewise.
   The positional call form `renderPageToBytes(0, 100, 100)` is correct.

2. **Error-type assumptions in Phase 3 are unverified.** The plan asserts
   `corrupt.pdf` yields `PdfError.invalidDocument` and `password.pdf` yields
   `PdfError.passwordRequired`. Both enum members exist (`pdf_types.dart:38–43`)
   and the mapping is plausible, but the plan does not cite where the isolate
   performs that classification. The implementer should treat the exact
   `PdfError` value as something to *confirm against the fixture*, not assume —
   PDFium's load-error codes do not map one-to-one to these two buckets, and a
   merely-corrupt file can surface as a generic load failure.

**Architecture Fit**

Excellent. This is a test-only plan — all work confined to
`packages/betto_pdfium/test/` — so it touches no `lib/` structure, no storage,
no public API surface, and no layer boundaries. The library-architecture skill
is not engaged: there is no Flutter UI, no barrel change, and the pure-Dart core
is unaffected. Likewise the design and inclusivity skills do not apply (no UI).
No spec or roadmap update is required; raising coverage does not change the
distribution contract or public behaviour. I checked `docs/spec/` is unaffected.

**Risk & Edge Cases**

- **Coverage-environment dependency (the open question).** This is the one real
  risk to the headline goal. `make coverage` runs a single combined
  `dart test`; Phases 2–4 skip when the dylib is absent. If coverage is ever
  measured without the binary, the number collapses to roughly the Phase-1
  figure (~69 %) and the gate passes/fails on environment, not code. The plan's
  own checkpoint table implicitly assumes the binary is present at every phase.
  This needs an explicit confirmation rather than an assumption.
- **`_defaultDylibPathOrNull()` test (Phase 4) is inherently environment-coupled
  and order-fragile.** It depends on `PdfiumIsolate` *not* having been
  initialised with an explicit path earlier in the same process. Because the
  isolate is a process-wide singleton (per CLAUDE.md, "never spawn a second
  isolate"), a test that calls `ensureInitialised()` with no override may either
  race with or be poisoned by earlier tests that injected a path. This single
  uncovered helper is low value (one method) and high flakiness risk. If it
  costs more than a trivial amount of effort, drop it and absorb the ~few lines
  elsewhere — 95 % has headroom.
- **Init-failure path (Phase 4)** similarly mutates global isolate state by
  attempting a bad init. Verify it does not leave the singleton in a broken
  state that breaks subsequent tests in the same run. Run the full suite, not
  just the new file, to confirm.
- **Checkpoint percentages are estimates.** The per-phase targets (69/87/92/95)
  are reasonable but unproven; the plan already includes the right fallback
  (inspect the HTML report after Phase 3). Good.

**Recommendations**

Proceed — this is a sound, well-investigated plan that fixes a genuine policy
breach with appropriately scoped, low-risk work. Before moving back to
`Investigated`, address:

1. Resolve the open question about the coverage environment (does CI run
   coverage with the binary present?). This is the only item that gates the
   plan's stated goal.
2. Correct the `renderPageToBytes` return-type description in Phase 2 to the
   record form.
3. Soften the Phase 3 error-code assertions to "confirm the `PdfError` value
   against the fixture" rather than asserting a specific value up front.
4. Consider demoting or dropping the `_defaultDylibPathOrNull()` test (Phase 4)
   given its singleton-ordering fragility versus its one-line payoff.

None of these are structural; the plan is close to ready.

**Open questions**

- [ ] See the plan-level open question on coverage-environment binary
      availability. This is the one item blocking a return to `Investigated`.
- [ ] Fix the `renderPageToBytes` return-type description (record, not bare
      `Uint8List`) before implementation — tracked here so it is not lost.
- [ ] Confirm the exact `PdfError` mapping for `corrupt.pdf` and `password.pdf`
      rather than assuming it.

## Summary

_To be completed after implementation._
