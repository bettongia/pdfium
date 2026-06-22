# Raise Test Coverage to ≥ 90 %

**Status**: Complete

**PR link**: —

## Problem statement

Excluding the auto-generated `pdfium_bindings.dart`, the library sits at **70 %**
line coverage — well below the project's 90 % minimum. Two files account for
nearly all of the gap:

| File | Current | Uncovered lines |
| ---- | ------- | --------------- |
| `lib/src/document/pdfium_isolate.dart` | 68.5 % | 247 |
| `lib/src/document/pdf_types.dart` | 54.0 % | 216 |
| `lib/src/document/isolate_messages.dart` | 78.2 % | 12 |
| `lib/src/document/_document_native.dart` | 88.6 % | 19 |
| Other files | ≥ 92 % | ≤ 5 each |

The generated bindings file (`lib/src/generated/pdfium_bindings.dart`) is
excluded from all measurements in this plan — it exposes the full PDFium
surface, most of which the library does not exercise, and it is regenerated
automatically. The `make coverage` / lcov pipeline should be updated to exclude
it permanently.

## Investigation

### `pdf_types.dart` — 54 %, 216 uncovered lines

Every concrete `PdfAnnotation` subtype implements `==`, `hashCode`, and
`toString()`. The existing annotation tests exercise *extraction* (round-trips
through the isolate) but do not test the value-type semantics of the returned
objects. The uncovered lines fall into three clusters:

1. **`==` / `hashCode` / `toString()` on annotation subtypes** — affects
   `PdfFreeTextAnnotation`, `PdfShapeAnnotation`, `PdfLineAnnotation`,
   `PdfInkAnnotation`, `PdfPolygonAnnotation`, `PdfLinkAnnotation`,
   `PdfStampAnnotation`, `PdfUnknownAnnotation` (lines 601–670, 775–866,
   921–997, 1023–1098, 1128–1146).
2. **`==` / `hashCode` on `PdfPageText`** — lines 226–228 (the multi-field
   equality chain; `hashCode` at 232 is covered but the `==` body is not
   fully exercised).
3. **`==` / `hashCode` / `toString()` on image types** — `PdfImageMetadata`,
   `PdfImage`, `PdfImageBitmap`, `PdfPageImages` (lines 1385–1395, plus the
   surrounding image-type cluster).

These are all pure-Dart unit tests — no PDFium binary required. A new
`test/pdf_types_test.dart` (or additions to the existing type tests) can
cover them with simple in-process construction and assertion.

### `pdfium_isolate.dart` — 68.5 %, 247 uncovered lines

The uncovered lines split into four themes:

1. **Popup IRT matching** (lines 750–795) — the second annotation pass that
   links `POPUP` annotations back to their parent via `FPDFAnnot_GetLinkedAnnot`.
   No existing test fixture carries a popup annotation with a valid IRT link.
   A fixture PDF with a text annotation that has an associated popup would
   trigger this path.

2. **`_withPopup` switch** (lines 1364–1473) — the helper that clones every
   concrete annotation subtype with a `popup` field set. This is only reached
   when the IRT path succeeds, so it is blocked by the same gap as (1). Fixing
   (1) will unblock most of (2).

3. **Error / edge-case paths in isolate handlers** — scattered single lines
   such as:
   - Isolate init failure (`PdfiumInitFailedResponse`, line 98)
   - `FPDFPage_LoadPage` returning null in the render-page handler (line 204–205)
   - `FPDFBitmap_CreateEx` null guard in the render-page handler (line 312–313)
   - Padded-stride slow path in the render-page handler (lines 1630–1636)
   - Ink stroke with zero points (line 1053)
   - Polygon with zero vertices (line 1085)
   - `_resolveXyzScrollPosition` null paths (lines 1906–1912)
   - `_readActionUri` empty-URI guard (line 1952)
   - Image metadata failure skip (lines 2035–2037)
   - `GetRenderedBitmap` null guard in the render-image handler

4. **`_document_native.dart` / `isolate_messages.dart` scattered lines** —
   mostly error-response branches (invalid-document token, null-page load) in
   the metadata, render, annotation, ToC, and image handlers. These can be
   tested by sending commands with a closed or invalid document.

### Coverage exclusion for generated bindings

`make coverage` currently runs `genhtml` over the raw `lcov.info`. The
`Makefile` (or a `.lcovrc`) should add a `--remove` step to strip
`*/generated/*` before reporting, so the headline number reflects real library
code.

## Implementation plan

### 1 — Exclude generated bindings from coverage reporting

- [x] Add an lcov `--remove` step to `Makefile` (`coverage` target) that strips
      `*/generated/*` from `coverage/lcov.info` before running `genhtml`.
      Document the exclusion in a comment.

### 2 — Pure-Dart value-type tests (`pdf_types_test.dart`)

No PDFium binary needed; all construction is in-process.

- [x] For each annotation subtype listed below, write tests that verify:
  - `==` returns `true` for two equal instances
  - `==` returns `false` when each field differs
  - `hashCode` is equal for equal instances
  - `toString()` returns a non-empty string containing the type name
  - Subtypes covered: `PdfFreeTextAnnotation`, `PdfShapeAnnotation`,
    `PdfLineAnnotation`, `PdfInkAnnotation`, `PdfPolygonAnnotation`,
    `PdfLinkAnnotation`, `PdfStampAnnotation`, `PdfUnknownAnnotation`
- [x] Write equality and `hashCode` tests for `PdfPageText` covering the
      full `==` branch (all fields differ path)
- [x] Write equality / `hashCode` / `toString()` tests for the image value
      types: `PdfImageMetadata`, `PdfImage` (both with and without bitmap
      fields), `PdfImageBitmap`, `PdfPageImages`

### 3 — Popup annotation fixture and tests

- [x] Add a test PDF fixture (`test/fixtures/popup_annotation.pdf`) that
      contains a text annotation with an associated popup annotation (IRT link).
      Update `test/fixtures/generate/generate_fixtures.py` with the generator
      for this fixture.
- [x] Extend `test/pdf_annotation_test.dart` with a test that opens
      `popup_annotation.pdf`, calls `extractAnnotations()`, and asserts:
  - The returned `PdfTextAnnotation` has a non-null `popup` field
  - `popup.rect` is non-zero
  - `popup.flags` is a non-negative integer
  - `_withPopup` is exercised for at least the `PdfTextAnnotation` arm

### 4 — Isolate error-path and edge-case tests

These require the PDFium binary (integration tests).

- [ ] **Ink stroke with zero points** — add a fixture PDF that contains an ink
      annotation with an empty stroke, or mock the isolate response; verify the
      annotation is still returned with an empty stroke list entry.
      (Deferred: requires an unusual PDF that mainstream tools reject; coverage
      of this code path is not achievable without a crafted binary-level fixture.)
- [ ] **Polygon with zero vertices** — similar: fixture or mock; verify an
      empty `vertices` list is returned.
      (Deferred: same constraint as ink-zero-points above.)
- [ ] **Render-page padded-stride path** — test `renderPage()` with a render
      width that produces a stride wider than `width * 4`; verify the returned
      pixel buffer has exactly `width * height * 4` bytes. (This requires
      control over render dimensions; a single-pixel or very-narrow page width
      may reproduce the condition, or a direct isolate unit test.)
      (Deferred: stride is controlled by PDFium; not reproducible via public API.)
- [x] **`_resolveXyzScrollPosition` null paths** — added `fit_toc.pdf` fixture
      with FIT-view bookmarks; `toc_extraction_test.dart` asserts
      `scrollPosition` is `null` for those entries.
- [x] **`_readActionUri` empty URI** — added `empty_uri_link.pdf` fixture with a
      link whose URI action has an empty string; `pdf_annotation_test.dart`
      asserts `uri` is `null`.
- [ ] **Image metadata failure** — test that `extractImages()` skips (does not
      crash on) an image object whose metadata call returns false. (This may
      require a crafted PDF or a mock.)
      (Deferred: requires a crafted PDF that is difficult to create portably.)
- [x] **`GetRenderedBitmap` null** — `renderImage(0, 9999)` returns null for an
      out-of-range object index (covers the null-bitmap guard in the handler);
      test exists in `image_extraction_test.dart`.
- [x] **Invalid-document error paths** — `extractImages` throws `StateError`
      after `close()` added to `image_extraction_test.dart`; existing tests
      already cover `getMetadata`, `renderPage`, `extractAnnotations`,
      `tableOfContents`, and `renderImage` post-close paths.

### 5 — Verify and close

- [x] Run `make coverage` (with the updated exclusion) and confirm ≥ 90 %
      Coverage achieved: **90.9 %** (1522/1675 lines). New fixture PDFs and
      companion tests cover the remaining `_withPopup()` switch arms and extra
      annotation subtypes (squiggly, strikeout, stamp, free-text, polygon, and
      all popup-linked annotation types).
- [x] Run `make analyze` — no new warnings
- [x] Run `dart format .` — no issues

## Reviews

### Review 1: 2026-05-20

The gap is real — 70 % (excluding generated code) against a 90 % bar is a
meaningful shortfall. The root causes are well-understood:

- Value-type methods (`==`, `hashCode`, `toString()`) on annotation and image
  types are exercised by extraction tests but not by dedicated equality/identity
  tests. This is a systematic omission across every concrete subtype.
- The popup IRT path is a structural gap: no fixture triggers it, so both the
  isolate second-pass and the `_withPopup` helper are dark.
- Isolate error paths are individually small but collectively add up.

The plan addresses all three root causes with proportionate effort. The
pure-Dart value-type tests (step 2) carry no PDFium dependency and can be
written quickly; they alone should recover roughly 10–12 percentage points.
The popup fixture (step 3) and isolate edge cases (step 4) address the
remainder.

No open questions. The plan is ready for implementation.

## Summary

Coverage raised from **70 %** to **90.9 %** (1522/1675 lines), clearing the
project's 90 % minimum. All 468 tests pass; `dart analyze` and `dart format`
report zero issues.

Key changes:

1. **Makefile** — `coverage` target now strips `*/generated/*` from the lcov
   data before generating the HTML report, so the generated FFI bindings file
   is excluded from all coverage measurements.

2. **`test/pdf_types_test.dart`** (new, 149 tests) — pure-Dart unit tests for
   `==`, `hashCode`, and `toString()` on every annotation subtype and image
   value type. No native binary required. Raised `pdf_types.dart` from 54 % to
   98 %.

3. **Popup fixtures** — three new fixture PDFs exercise the IRT-linking path in
   the isolate and the `_withPopup()` switch:
   - `popup_annotation.pdf` (sticky note + popup) — covers `PdfTextAnnotation`
     arm.
   - `popup_freetext.pdf` (free-text annotation + popup) — covers
     `PdfFreeTextAnnotation` arm.
   - `popup_multi.pdf` (7 annotation types each with a linked popup) — covers
     `PdfMarkupAnnotation`, `PdfShapeAnnotation`, `PdfLineAnnotation`,
     `PdfInkAnnotation`, `PdfPolygonAnnotation`, `PdfStampAnnotation`, and
     `PdfUnknownAnnotation` arms.

4. **Extra annotation-type fixtures**:
   - `annotated_extra.pdf` — squiggly, strikeout, stamp, free-text, and polygon
     annotations; covers the corresponding `_annotationTypeFromInt` and
     `_buildAnnotation` branches.
   - `fit_toc.pdf` — FIT-view bookmarks; covers the
     `_resolveXyzScrollPosition` null path.
   - `empty_uri_link.pdf` — link with empty URI action; covers the
     `_readLinkUri` empty-string guard.

5. **`test/image_extraction_test.dart`** — added `extractImages` post-`close()`
   `StateError` test; `renderImage(0, 9999)` null-bitmap guard already covered.

Remaining deferred items (documented in step 4): ink stroke with zero points,
polygon with zero vertices, render-page padded-stride path, and image metadata
failure — all require crafted binary-level PDFs not achievable with standard
Python tooling.
