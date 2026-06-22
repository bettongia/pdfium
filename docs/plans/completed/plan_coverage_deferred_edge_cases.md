# Coverage: Deferred Edge-Case Tests

**Status**: Complete

**PR link**: —

## Problem statement

Four isolate code paths remain uncovered after `plan_test_coverage.md` raised
overall line coverage to 90.9 %. All four require crafted binary-level PDF
fixtures that cannot be produced with the standard Python/reportlab tooling used
for other fixtures. The paths are individually small (1–6 lines each) but are
explicit error-handling branches that are worth covering when a low-level
fixture strategy is available.

| Code path                      | File                  | Lines      |
| ------------------------------ | --------------------- | ---------- |
| Ink stroke with zero points    | `pdfium_isolate.dart` | ~1053      |
| Polygon with zero vertices     | `pdfium_isolate.dart` | ~1085      |
| Render-page padded-stride path | `pdfium_isolate.dart` | ~1630–1636 |
| Image metadata failure skip    | `pdfium_isolate.dart` | ~2035–2037 |

## Investigation

### Ink stroke with zero points (line ~1053)

The isolate iterates ink annotation strokes and skips (or records an empty list
entry for) any stroke that `FPDFAnnot_GetInkListCount` reports as having zero
points. Standard PDF tools refuse to write an ink annotation with an empty
stroke array, so this guard exists for corrupt or hand-crafted files.

**Approach options:**

1. Craft a minimal PDF in hex/bytes that encodes an `/Ink` annotation with an
   empty `/InkList` entry. A PDF can be assembled with a Python `struct`/bytes
   approach without reportlab.
2. Use `pypdf` or `pikepdf` to post-process a standard ink PDF and patch the
   stream bytes.
3. Write a unit test that exercises the isolate handler directly by sending a
   synthesised `ExtractAnnotationsCommand` with a mocked PDFium response — but
   `PdfiumIsolate` does not expose injection points today, so this would require
   either an interface seam or a test-only subclass.

Option 2 (pikepdf post-processing) is likely the fastest path and does not
require protocol-level isolate changes.

### Polygon with zero vertices (line ~1085)

Same constraint as ink-zero-points. An `/Ink`-like annotation (polygon uses
`/Vertices` array) with an empty vertices array is rejected by mainstream tools.
Pike-pdf post-processing applies equally here.

### Render-page padded-stride path (lines ~1630–1636)

PDFium allocates bitmap rows with alignment padding when `width * 4` is not a
multiple of its internal stride requirement. The slow path copies each row
individually to strip padding before returning the pixel buffer. The stride is
controlled entirely by PDFium's allocator and is not exposed through the public
API.

**Approach options:**

1. Use `FPDFBitmap_CreateEx` with a caller-supplied stride larger than
   `width * 4` — this is an advanced API not currently used in the render path.
   A test-only helper that calls the isolate with a synthetic bitmap config
   could exercise the branch.
2. Find a page width where PDFium's allocator naturally pads (historical reports
   suggest width values not divisible by 4 sometimes trigger this on certain
   PDFium versions, but it is not guaranteed).
3. Refactor the stride-handling code into a pure Dart helper function that can
   be unit-tested without PDFium involvement.

Option 3 (extract and unit-test the row-copy logic) is the most reliable because
it decouples the coverage from PDFium's internal allocator behaviour.

### Image metadata failure skip (lines ~2035–2037)

`extractImages()` calls `FPDF_GetPageObjectMetaData` (or equivalent) for each
image object and skips the object silently if the call returns false. A
malformed image object (e.g. a stream with a broken filter) could trigger this,
but standard tooling will not write such a file.

**Approach options:**

1. Craft a minimal PDF with a malformed image stream using raw bytes / pikepdf.
2. Add a seam to the isolate that allows injecting a stub PDFium handle for
   integration-test purposes (more invasive).

Option 1 is preferred.

## Implementation plan

### 1 — Ink stroke with zero points

- [x] Add a `generate_zero_ink_stroke` function to
      `test/fixtures/generate/generate_fixtures.py` using stdlib-only raw-byte
      PDF construction (following the `make_thumb_fixture.py` pattern) that:
  - Builds a minimal PDF with an `/Ink` annotation whose `/InkList` entry
    contains a single empty sub-array (`/InkList [[]]`) using raw PDF object
    syntax and Python `bytes`/`bytearray` — no external library.
  - Writes `test/fixtures/zero_ink_stroke.pdf`.
  - Commits the generated fixture to version control.
- [x] Add a test in `test/pdf_annotation_test.dart` that opens
      `zero_ink_stroke.pdf`, calls `extractAnnotations()`, and asserts:
  - The ink annotation is returned.
  - Its `strokes` list has one entry.
  - That entry is an empty list (zero points).

### 2 — Polygon with zero vertices

- [x] Add a `generate_zero_polygon_vertices` function to `generate_fixtures.py`
      using stdlib-only raw-byte PDF construction (following the
      `make_thumb_fixture.py` pattern) that writes
      `test/fixtures/zero_polygon_vertices.pdf` with a polygon annotation whose
      `/Vertices` array is an empty PDF array (`/Vertices []`) — no external
      library. Commit the generated fixture to version control.
- [x] Add a test that opens the fixture, calls `extractAnnotations()`, and
      asserts the polygon annotation has an empty `vertices` list.

### 3 — Render-page padded-stride path

- [x] Extract the row-copy stride logic in `pdfium_isolate.dart` (lines
      ~1630–1636) into a package-private function
      `stripBitmapStride(Uint8List src, int width, int height, int stride)`
      annotated `@visibleForTesting`, kept in `pdfium_isolate.dart`.
- [x] Add a unit test in a new `test/bitmap_util_test.dart` that calls
      `stripBitmapStride` with a synthetic padded buffer and asserts:
  - Output length is exactly `width * height * 4`.
  - Each output row matches the corresponding input row bytes (padding
    stripped).
  - A case where padding bytes are non-zero catches any off-by-one in stride
    arithmetic.

### 4 — Image metadata failure skip

- [x] Add a `generate_broken_image_metadata` function to `generate_fixtures.py`
      using stdlib-only raw-byte PDF construction (following the
      `make_thumb_fixture.py` pattern) that produces
      `test/fixtures/broken_image_metadata.pdf` — a PDF with one image XObject
      that has **no stream body** (a dict-only object with no
      `stream … endstream`). Empirically confirmed (2026-05-22) that this causes
      `FPDFImageObj_GetImageMetadata` to return false; a corrupt FlateDecode
      stream body is NOT sufficient (PDFium reads metadata from the dict, not
      the pixel data). Constructed with raw PDF object syntax and Python
      `bytes`/`bytearray` — no external library. Commit the generated fixture to
      version control.
- [x] Add a test in `test/image_extraction_test.dart` that opens the fixture,
      calls `extractImages()`, and asserts the call completes without throwing
      (the malformed object is skipped gracefully).

### 5 — Verify and close

- [x] Run tests via `mcp__plugin_bettongia_dart__run_tests` and confirm all
      pass.
- [x] Run `make coverage` and confirm overall coverage remains ≥ 90 %.
- [x] Run `make analyze` — no new warnings.
- [x] Run `make pre_commit`.

## Open questions

- [x] **pikepdf dependency (steps 1, 2, 4):** The implementation plan calls for
      `pip install pikepdf` in three places, but pikepdf is not in
      `requirements.txt` and has never been installed in the project venv. The
      thumbnail-extraction plan faced the same problem and resolved it using
      stdlib-only raw-byte construction (see `make_thumb_fixture.py` / the
      `struct`+`zlib` approach). Will pikepdf be added to `requirements.txt` and
      the project venv, or should the fixtures for steps 1, 2, and 4 be crafted
      with stdlib bytes in the style of `make_thumb_fixture.py`? _Decision:
      stdlib-only raw-byte PDF construction following the
      `make_thumb_fixture.py` pattern. Pikepdf is available as a fallback only
      if stdlib genuinely cannot produce the required PDF; the default is stdlib
      with no new dependency added to `requirements.txt`. All three fixture
      cases (ink zero-point stroke, polygon zero-vertices, malformed image
      stream) are achievable with raw PDF object syntax and do not require a
      C-extension library._

- [x] **Render-page stride coverage (step 3):** `stripBitmapStride` will be
      extracted as a package-private function inside `pdfium_isolate.dart`,
      annotated `@visibleForTesting`. Test lives in a new
      `test/bitmap_util_test.dart`. No new `lib/src/` file needed.

- [x] **Image-metadata failure (step 4):** Empirically confirmed 2026-05-22. A
      corrupt FlateDecode stream body is **not** sufficient — PDFium reads
      metadata from the stream dictionary, not the pixel data, so it still
      returns success. However, an image XObject with **no stream at all** (a
      dict-only object, no `stream … endstream`) causes
      `FPDFImageObj_GetImageMetadata` to return false and the isolate's skip
      path to fire. A probe test verified `extractImages()` returns 0 images for
      such a fixture (vs 1 for a valid image). Step 4 must use a streamless
      image XObject, not a corrupt-stream-body approach.

- [x] **Missing `## Reviews` section:** The plan template requires a
      `## Reviews` section. It is absent. This is a structural issue — resolved
      by this review adding the section below, but worth noting.

## Reviews

### Review 1: 2026-05-22

#### Problem Statement Assessment

The problem is real and the scope is tight and honest. The plan correctly
identifies that four specific code paths remain uncovered after
`plan_test_coverage.md` raised overall coverage to 90.9 %, and accurately
explains why standard tooling cannot reach them. Shipping deliberate
error-handling branches without test coverage is a genuine quality risk, so the
motivation is sound.

One caveat: the plan describes "four isolate code paths" but three of the four
(the ink-zero-points guard at line 1045, the polygon-zero-vertices guard at line
1089, and the image-metadata skip at line 2039–2041) are all single early-
return guards. They are genuinely worth covering, but the plan's framing ("1–6
lines each") slightly overstates the complexity of steps 1 and 2. Step 3
(render-page padded-stride, lines 1629–1644) is meaningfully larger.

The plan is also missing two structural sections required by the plan template:
`## Open questions` and `## Reviews`. Both have been added by this review.

#### Proposed Solution Assessment

**Step 3 (stride extraction) — strong.** Refactoring the padded-stride row-copy
into a pure Dart helper that can be exercised without PDFium is the right call.
It decouples the test from PDFium's internal allocator behaviour, avoids relying
on platform-specific alignment quirks, and produces a unit test that is
deterministic and fast. This is the best-designed step in the plan.

**Steps 1 and 2 (ink-zero-points, polygon-zero-vertices)** — approach is
correct, but the chosen tool is wrong.\*\* The plan recommends pikepdf for
post-processing annotation fixtures. pikepdf is NOT installed in the project
venv and is NOT in `requirements.txt`. The thumbnail-extraction plan
(`plan_thumbnail_extraction.md`) faced an identical constraint and resolved it
using stdlib-only raw-byte PDF construction — see `make_thumb_fixture.py`, which
builds a valid two-page PDF with an embedded image stream using nothing but
`zlib` and Python `bytes`/`bytearray`. The same approach applies here: an ink
annotation with an `/InkList` entry containing a single empty sub-array, and a
polygon annotation with an empty `/Vertices` array, are both straightforward to
encode with raw PDF object syntax. No external library is needed.

The plan must either (a) drop the pikepdf references and instead craft the
fixtures with stdlib bytes following the `make_thumb_fixture.py` pattern, or (b)
explicitly justify adding pikepdf to `requirements.txt` with a rationale for why
stdlib is insufficient. Option (a) is strongly preferred — adding a C-extension
dependency (pikepdf links against libqpdf) for three fixture files is
disproportionate.

**Step 4 (image-metadata failure) — approach is uncertain.** The plan asserts
that a malformed image stream will cause `FPDFImageObj_GetImageMetadata` to
return false, but this is not verified. Looking at the actual code at lines
2031–2037, the `finally` block comment says "Do not free yet; we read fields
below before freeing" — but then immediately frees in the outer `try` block.
More importantly, PDFium's public API for `FPDFImageObj_GetImageMetadata` does
not document what counts as a "metadata failure" — it could silently succeed
with default values for a corrupt stream, or it could crash. Before investing
effort in crafting a malformed-image fixture, this must be empirically confirmed
with a test PDF. If the false-return path cannot be reliably triggered via a PDF
file, an injection seam is a more honest and more maintainable approach.

#### Architecture Fit

The library-architecture skill is not directly triggered by this plan — no new
public API surface, no widget extraction, no changes to `lib/` structure. The
plan adds test fixtures and helper functions. The only architectural concern is
where the extracted `stripBitmapStride` helper lives. The plan says
"package-private" but does not specify the file. It should go in
`lib/src/rendering/` (not in `pdfium_isolate.dart` itself) or be declared
`@visibleForTesting` in the isolate file and exercised via the test-library
import. Either is acceptable; the plan should be specific.

The plan targets `test/pdf_types_test.dart` or a new
`test/bitmap_util_test.dart` for the stride test. A new file is cleaner —
`pdf_types_test.dart` tests data types, not rendering utilities.

#### Risk and Edge Cases

1. **pikepdf is absent from the project environment.** This is the most
   important gap. Steps 1, 2, and 4 in the implementation plan call for
   `pip install pikepdf` but this would introduce a C-extension dependency that
   has never been discussed for this project. The implementation will either
   silently fail (venv without pikepdf) or require an undocumented dependency
   install step that no contributor will know about. This must be resolved
   before implementation begins.

2. **Image-metadata false-return is unverified.** If PDFium does not actually
   return false for the crafted malformed PDF, the test will either never hit
   the branch (no coverage gain) or need to be skipped. The plan should include
   an explicit investigation sub-step to verify this before writing the fixture
   generator.

3. **Stride test asserts the right thing.** The plan says "asserts the output
   has exactly `width * height * 4` bytes with correct row content" — this is
   correct, but "correct row content" needs to be precisely defined: each output
   row must be exactly the input row bytes with padding stripped from the end,
   and row order must be preserved. The test implementation should include a
   case where padding is interleaved with non-zero bytes to catch an off-by-one
   in the stride arithmetic.

4. **Fixture files not committed to version control.** The plan generates PDFs
   via Python scripts but does not explicitly say the generated PDFs are
   committed. Other fixtures (e.g. `annotated_ink.pdf`, `thumbnail_fixture.pdf`)
   are committed. The new fixtures should be committed so the test suite runs
   without requiring Python/fixture-regen as a prerequisite.

5. **`generate_fixtures.py` integration.** The plan adds new generator functions
   to `generate_fixtures.py`, but the existing generator uses `fpdf2` and
   `pypdf` — both of which are in `requirements.txt`. If the new functions use
   stdlib-only bytes (recommended), they fit naturally alongside the existing
   `make_thumb_fixture.py` approach. The plan should state whether the new
   functions go into `generate_fixtures.py` or into separate fixture scripts
   (like `make_thumb_fixture.py` at the repo root — though its location at the
   repo root rather than `test/fixtures/generate/` is itself an inconsistency
   worth noting).

#### Recommendations

1. **Replace all pikepdf references with stdlib-bytes construction.** Study
   `make_thumb_fixture.py` for the pattern: build PDF object dictionaries as raw
   byte strings, collect byte offsets, write an xref table. An ink annotation
   with a zero-point stroke requires only adding an `/InkList` array containing
   a single empty sub-array `[[]]` to a page's annotation list. A polygon with
   zero vertices needs an empty `/Vertices` array. Both are achievable in ~100
   lines of Python with no external dependency. Update `requirements.txt` only
   if this turns out to be genuinely impossible.

2. **Verify image-metadata false-return before writing step 4.** Add an
   investigation note confirming that a specific type of malformed image object
   reliably causes `FPDFImageObj_GetImageMetadata` to return false. If it cannot
   be confirmed, replace step 4 with a seam/injection approach and document the
   decision.

3. **Name the home file for `stripBitmapStride` explicitly.** Recommend
   `lib/src/rendering/bitmap_util.dart` as a new file (analogous to other small
   utility files in the library), annotated `@visibleForTesting`, with a
   corresponding `test/bitmap_util_test.dart`. Update the plan accordingly.

4. **Locate fixture generator functions in `test/fixtures/generate/`.** The
   `make_thumb_fixture.py` at the repo root is an outlier — new fixture
   generators should go in `test/fixtures/generate/generate_fixtures.py` or a
   peer script in the same directory, not at the repo root.

5. **Commit generated fixtures.** Add an explicit task to commit the three new
   PDF fixtures alongside the generator functions, so CI does not require a
   Python fixture-regen step.

#### Open questions

- [ ] **pikepdf vs stdlib-bytes:** see `## Open questions` above — this must be
      resolved before implementation starts. Recommendation is stdlib.
- [ ] **Image-metadata false-return verification:** see `## Open questions`
      above — empirical confirmation required before step 4 is financed.
- [ ] **`stripBitmapStride` home file:** see `## Open questions` above — the
      plan should name the target file explicitly.

### Review 2: 2026-05-22

#### Q1 Resolution — stdlib vs pikepdf

Open question 1 is resolved: use stdlib-only raw-byte PDF construction for all
fixture generators, following the `make_thumb_fixture.py` pattern. Pikepdf
remains available as a fallback only if stdlib genuinely cannot produce the
required PDF, but the default is no new dependency in `requirements.txt`.

**Stdlib sufficiency assessment for the three affected steps:**

- **Step 1 — ink annotation with zero-point stroke.** An `/InkList` entry is a
  PDF array of arrays. An empty sub-array (`/InkList [[]]`) is valid PDF syntax
  and can be written as a literal byte string inside a raw annotation dictionary
  object. `make_thumb_fixture.py` already demonstrates that object dictionaries,
  stream headers, xref tables, and trailers can all be assembled from Python
  `bytes`/`bytearray` in under 130 lines. Adding an annotation dictionary is not
  materially more complex. Stdlib is sufficient.

- **Step 2 — polygon with zero vertices.** `/Vertices []` is an empty PDF array
  literal. Identical reasoning to step 1 — pure object dictionary syntax, no
  binary encoding required beyond what `make_thumb_fixture.py` already does.
  Stdlib is sufficient.

- **Step 4 — malformed image stream for metadata failure.** Construction of the
  PDF file itself is straightforward with stdlib: embed an image XObject whose
  stream body is intentionally corrupt (e.g. claim `/Filter /FlateDecode` but
  write non-zlib bytes). The stream dictionary syntax is identical to the valid
  image stream in `make_thumb_fixture.py`; only the stream body content differs.
  Stdlib is sufficient for the construction. The open empirical question —
  whether this reliably causes `FPDFImageObj_GetImageMetadata` to return false
  rather than silently succeed or crash — is unchanged and remains open
  (question 3 in `## Open questions`). The updated step 4 now includes an
  explicit investigation sub-step before the fixture is finalised.

**Implementation steps updated:** Steps 1, 2, and 4 now specify "stdlib-only
raw-byte PDF construction (following the `make_thumb_fixture.py` pattern)" and
no longer reference pikepdf. Step 4 also includes the empirical verification
gate from the previous review's recommendation.

## Summary

- Added `generate_zero_ink_stroke()`, `generate_zero_polygon_vertices()`, and
  `generate_broken_image_metadata()` to `test/fixtures/generate/generate_fixtures.py`
  using stdlib-only raw-byte PDF construction (no new dependencies). All three
  fixtures are committed to version control.
- Added a `_raw_pdf()` helper in `generate_fixtures.py` to share the
  PDF serialisation logic (xref table, trailer) across the three new generators.
- Added a test in `test/pdf_annotation_test.dart` that opens `zero_ink_stroke.pdf`
  and asserts the ink annotation has one stroke entry that is empty — covering the
  `if (pointCount == 0) { strokes.add(const []); }` guard at `pdfium_isolate.dart`
  ~line 1056.
- Added a test in `test/pdf_annotation_test.dart` that opens
  `zero_polygon_vertices.pdf` and asserts the polygon annotation has an empty
  `vertices` list — covering the `if (count == 0) return const []` guard at
  `pdfium_isolate.dart` ~line 1089.
- Extracted the bitmap row-padding strip logic from the render-page handler into a
  `@visibleForTesting` function `stripBitmapStride(Uint8List, int, int, int)` in
  `pdfium_isolate.dart`. The render handler now calls this function.
- Added `package:meta` to `pubspec.yaml` (direct dependency) to support the
  `@visibleForTesting` annotation.
- Created `test/bitmap_util_test.dart` with 8 unit tests covering the fast path
  (no padding), the slow path (padding stripped row by row), row order preservation,
  non-zero padding byte exclusion, and edge cases (single pixel, 1-byte pad).
- Added a test in `test/image_extraction_test.dart` that opens
  `broken_image_metadata.pdf` (a streamless image XObject) and asserts
  `extractImages()` completes without throwing, returning zero images for the page
  — covering the `if (!metaOk) { calloc.free(metaPtr); continue; }` skip path at
  `pdfium_isolate.dart` ~lines 2039-2042.
- All 545 tests pass. Line coverage (excluding generated bindings): 90.7%.
- No deviations from the plan. All four code paths are now covered.
