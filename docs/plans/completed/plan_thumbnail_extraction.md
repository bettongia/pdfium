# Thumbnail Extraction

**Status**: Complete

**PR link**: committed directly to main — `87952943f`

## Problem statement

PDFs may contain embedded per-page thumbnail images, typically small previews
created by the authoring application at save time. The library currently has no
way to access these thumbnails. This plan adds a `getThumbnail(pageIndex)` API
on `PdfDocument` that:

1. Returns the embedded thumbnail if one exists in the PDF.
2. Falls back to rendering the page at a small size when no embedded thumbnail
   is present, so callers always receive a usable preview image for display.

The fallback render path is for display only — nothing is written back to the
PDF.

This item corresponds to the **Thumbnail extraction** entry in the
[v0.03.1 roadmap](../roadmap/0_03_1.md).

## Open questions

- [ ] **Test fixture**: Embedded thumbnails are uncommon in modern PDFs (arXiv
      and pdflatex-generated files never contain them). A fixture PDF with an
      embedded thumbnail must be synthesised using `pikepdf`, which can write a
      `/Thumb` stream directly into a page dictionary. This gives full control
      over the known dimensions and pixel content, making test assertions
      deterministic. The fixture should be created as part of the implementation
      task and committed to `test/data/`.

## Investigation

### PDFium API

Thumbnail extraction is exposed through `fpdf_thumbnail.h`, which is marked
**Experimental API** throughout. Three functions are available:

| Function                                              | Purpose                                                        |
| ----------------------------------------------------- | -------------------------------------------------------------- |
| `FPDFPage_GetThumbnailAsBitmap(page)`                 | Returns `FPDF_BITMAP` ready to read; `nullptr` if no thumbnail |
| `FPDFPage_GetDecodedThumbnailData(page, buf, buflen)` | Returns decoded bytes; `0` if no thumbnail                     |
| `FPDFPage_GetRawThumbnailData(page, buf, buflen)`     | Returns raw/compressed bytes; `0` if no thumbnail              |

`FPDFPage_GetThumbnailAsBitmap` is the most convenient entry point: it returns
an `FPDF_BITMAP` handle that can be read with the same `FPDFBitmap_GetBuffer` /
`FPDFBitmap_GetWidth` / `FPDFBitmap_GetHeight` / `FPDFBitmap_GetStride` /
`FPDFBitmap_Destroy` sequence already used by `_handleRenderPage`. The decoded
and raw byte variants are deferred to a follow-on plan to keep scope focused.

The fallback render path reuses the existing `PdfiumRenderPageCommand` machinery
— no new PDFium functions are required beyond `fpdf_thumbnail.h`.

### FFI bindings

`fpdf_thumbnail.h` only needs to be added as an entry-point and
include-directive in `ffigen.yaml`. The existing function allow-list pattern
`FPDFPage_.*` already covers all three thumbnail functions — no pattern changes
are needed. Regenerate bindings with `make ffi_bindings`.

### Architecture

#### Embedded thumbnail path (isolate)

1. Add `PdfiumGetPageThumbnailCommand` / `PdfiumGetPageThumbnailResponse` to
   `isolate_messages.dart`. The command carries `token` and `pageIndex`; the
   response carries `Uint8List? bgra`, `int width`, `int height`, and an
   optional `String? errorMessage`.
2. Add `_handleGetPageThumbnail` in `pdfium_isolate.dart`:
   - Validate the document token.
   - Load the page with `FPDF_LoadPage`.
   - Call `FPDFPage_GetThumbnailAsBitmap(page)`.
   - If the returned bitmap is `nullptr`, send a success response with
     `bgra: null` (no embedded thumbnail; not an error).
   - Otherwise read `FPDFBitmap_GetBuffer`, `GetWidth`, `GetHeight`,
     `GetStride`, copy into a `Uint8List` (stripping row padding if stride
     differs from `width * 4`), destroy the bitmap, close the page, and send a
     success response with the pixel data.

#### Fallback render path (Dart layer)

The fallback is handled entirely in `_document_native.dart` — no new isolate
message is needed. After receiving a `null` response from
`PdfiumGetPageThumbnailCommand`, and when `generateIfAbsent` is `true`:

1. Call `getPageSize(pageIndex)` to retrieve the page's PDF dimensions.
2. Scale those dimensions so the longest edge equals `maxDimension`, preserving
   aspect ratio, rounding to whole pixels.
3. Call `renderPageToBytes(pageIndex, scaledWidth, scaledHeight)` using the
   existing render path.
4. Wrap the result in a `PdfThumbnail` with
   `source: PdfThumbnailSource.rendered`.

The scaling is pure Dart arithmetic; no additional PDFium calls are needed.

#### Public API

```dart
Future<PdfThumbnail?> getThumbnail(
  int pageIndex, {
  bool generateIfAbsent = true,
  int maxDimension = 256,
})
```

- When `generateIfAbsent` is `true` (the default), the method always returns a
  `PdfThumbnail` unless the page index is invalid or the document is closed.
- When `generateIfAbsent` is `false`, the method returns `null` for pages with
  no embedded thumbnail, which is useful for callers that only want to surface
  natively-embedded previews.
- `maxDimension` only applies to the fallback render path; embedded thumbnails
  are returned at their native size.

### New domain types

```dart
/// Whether a [PdfThumbnail] came from an embedded stream or was rendered.
enum PdfThumbnailSource {
  /// Decoded from an embedded `/Thumb` stream in the PDF page dictionary.
  embedded,

  /// Rendered from the page content at [PdfDocument.getThumbnail]'s
  /// [maxDimension] because no embedded thumbnail was present.
  rendered,
}

/// A thumbnail image for a PDF page.
///
/// Obtain via [PdfDocument.getThumbnail]. Pixel data is in BGRA format
/// (4 bytes per pixel, blue first). The [source] field indicates whether
/// the thumbnail was decoded from an embedded stream or synthesised by
/// rendering the page.
final class PdfThumbnail {
  const PdfThumbnail({
    required this.bgra,
    required this.width,
    required this.height,
    required this.source,
  });

  /// BGRA pixel bytes. Length is always [width] * [height] * 4.
  final Uint8List bgra;

  /// Width of the thumbnail in pixels.
  final int width;

  /// Height of the thumbnail in pixels.
  final int height;

  /// Whether this thumbnail was decoded from an embedded stream or rendered.
  final PdfThumbnailSource source;
}
```

### Experimental API note

All three `fpdf_thumbnail.h` functions are annotated `// Experimental API.` in
the PDFium headers. The Dart abstraction layer isolates callers from any future
signature change — `PdfThumbnail` and `PdfDocument.getThumbnail` form the stable
surface.

### Edge cases and failure scenarios

| Scenario                                                    | Behaviour                                                             |
| ----------------------------------------------------------- | --------------------------------------------------------------------- |
| Page has no embedded thumbnail, `generateIfAbsent: true`    | Fall back to rendering; return `PdfThumbnail` with `source: rendered` |
| Page has no embedded thumbnail, `generateIfAbsent: false`   | Return `null`                                                         |
| `FPDFPage_GetThumbnailAsBitmap` returns `nullptr`           | Same as "no embedded thumbnail"                                       |
| `FPDF_LoadPage` fails                                       | Throw `PdfException` consistent with other page-level methods         |
| Invalid `pageIndex` (< 0 or ≥ pageCount)                    | Throw `RangeError` before sending to isolate                          |
| Document already closed                                     | Throw `StateError` consistent with other methods                      |
| Bitmap stride > `width * 4` (row padding)                   | Strip padding row-by-row — same logic as `_handleRenderPage`          |
| `FPDFBitmap_Destroy` must still run even if an error occurs | Wrap in `try/finally` inside the handler, same pattern as render      |
| `maxDimension` ≤ 0                                          | Throw `ArgumentError` before doing any work                           |
| Very narrow or very tall page (extreme aspect ratio)        | Scaling preserves aspect ratio; minimum 1px on the short edge         |

### Files affected

| File                                     | Change                                                                 |
| ---------------------------------------- | ---------------------------------------------------------------------- |
| `ffigen.yaml`                            | Add `fpdf_thumbnail.h` to `entry-points` and `include-directives`      |
| `lib/src/generated/pdfium_bindings.dart` | Regenerate (committed artefact)                                        |
| `lib/src/document/isolate_messages.dart` | Add `PdfiumGetPageThumbnailCommand` / `PdfiumGetPageThumbnailResponse` |
| `lib/src/document/pdfium_isolate.dart`   | Add `_handleGetPageThumbnail` handler                                  |
| `lib/src/document/_document_native.dart` | Add `getThumbnail()` method with fallback logic                        |
| `lib/src/document/_document_stub.dart`   | Add unsupported-platform stub                                          |
| `lib/src/document/_document_web.dart`    | Add web stub                                                           |
| `lib/src/document/pdf_document.dart`     | Add public `getThumbnail()` async method                               |
| `lib/src/document/pdf_types.dart`        | Add `PdfThumbnailSource` enum and `PdfThumbnail` type                  |
| `lib/pdfart_core.dart`                   | Export `PdfThumbnailSource` and `PdfThumbnail`                         |
| `test/thumbnail_extraction_test.dart`    | New test file                                                          |
| `test/data/thumbnail_fixture.pdf`        | Synthesised PDF with one embedded thumbnail (via `pikepdf`)            |
| `docs/roadmap/0_03_1.md`                 | Update plan link; mark complete after implementation                   |

## Implementation plan

- [x] Verify `.gitattributes` does not apply line-ending normalisation to
      `test/data/*.pdf` — a corrupted binary fixture will cause
      non-deterministic test failures. Add an exception rule if needed.
- [x] Create `test/data/thumbnail_fixture.pdf` using `pikepdf`: a two-page PDF
      where page 0 has an embedded thumbnail of known dimensions and page 1 has
      none. Commit the generated file.
- [x] Update `ffigen.yaml` to add `fpdf_thumbnail.h` to `entry-points` and
      `include-directives`.
- [x] Regenerate `lib/src/generated/pdfium_bindings.dart` with
      `make ffi_bindings`.
- [x] Add `PdfThumbnailSource` enum and `PdfThumbnail` to
      `lib/src/document/pdf_types.dart`.
- [x] Export both from `lib/pdfart_core.dart`.
- [x] Add `PdfiumGetPageThumbnailCommand` and `PdfiumGetPageThumbnailResponse`
      to `lib/src/document/isolate_messages.dart`.
- [x] Implement `_handleGetPageThumbnail` in
      `lib/src/document/pdfium_isolate.dart`:
  - [x] Call `FPDFBitmap_GetFormat()` on the returned bitmap and handle format
        variants (`FPDFBitmap_BGRA`, `FPDFBitmap_BGRx`). Do not assume BGRA — if
        the embedded thumbnail has no alpha channel PDFium may return `BGRx`.
        Convert to BGRA or throw with a clear message if an unsupported format
        is encountered.
  - [x] Wrap bitmap reads and `FPDFBitmap_Destroy` in `try/finally` so the
        handle is always released, even on error — same pattern as
        `_handleRenderPage`.
- [x] Add `getThumbnail()` to `lib/src/document/_document_native.dart`,
      including the fallback render path:
  - [x] Call `_checkNotClosed()` before the first async step (`getPageSize`) and
        again before the second async step (`renderPageToBytes`) — a `close()`
        call can arrive between them. This mirrors the guard pattern in
        `_extractPlainTextImpl`.
  - [x] Propagate errors from `renderPageToBytes` (`StateError`,
        `PdfiumException`) by re-throwing directly — do not wrap them. This is
        consistent with all other methods in `_document_native.dart`.
- [x] Add stub throwing `UnsupportedError` to
      `lib/src/document/_document_stub.dart` — consistent with the treatment of
      `renderPageToBytes` on unsupported platforms.
- [x] Add stub throwing `UnsupportedError` to
      `lib/src/document/_document_web.dart` — the embedded-thumbnail path
      requires FFI and the fallback render path is also unimplemented on web; do
      not attempt a partial implementation.
- [x] Add public
      `getThumbnail(int pageIndex, {bool generateIfAbsent, int maxDimension})`
      to `lib/src/document/pdf_document.dart`. The doc comment must include:
  - A note that `maxDimension` is a logical pixel budget; callers wanting
    retina-sharp fallback renders on high-DPI displays should multiply
    `maxDimension` by `MediaQuery.devicePixelRatio` before calling (this method
    cannot access `MediaQuery` as it lives in the pure-Dart layer).
- [x] Add a `getThumbnail` section to `docs/spec/rendering.md` covering: public
      API signature, error contract (`RangeError`, `StateError`,
      `PdfiumException`, `ArgumentError`), fallback behaviour, `maxDimension`
      semantics, and the platform support table.
- [x] Write `test/thumbnail_extraction_test.dart` covering:
  - [x] Page with embedded thumbnail returns `PdfThumbnail` with
        `source: embedded`, correct `width`, `height`, and
        `bgra.length == width * height * 4`
  - [x] Page with embedded thumbnail: BGRA bytes are non-trivially non-zero
  - [x] Page with no thumbnail, `generateIfAbsent: true` (default): returns
        `PdfThumbnail` with `source: rendered` and dimensions ≤ `maxDimension`
        on the longest edge
  - [x] Page with no thumbnail, `generateIfAbsent: false`: returns `null`
  - [x] Custom `maxDimension` is respected by the fallback render path
  - [x] Invalid page index (negative, ≥ pageCount) throws `RangeError`
  - [x] `maxDimension ≤ 0` throws `ArgumentError`
  - [x] Calling `getThumbnail` on a closed document throws `StateError`
- [x] Run all tests and confirm ≥ 90% coverage.
- [x] Update `docs/roadmap/0_03_1.md` to mark complete after implementation.

## Reviews

### Review 1: 2026-05-20

_Reviewed: 2026-05-20_

**Problem Statement Assessment**

The problem is real and well-scoped. Embedded thumbnails are a legitimate PDF
feature (ISO 32000-1, §12.3.4) and exposing them avoids the cost of a full
render pass for callers that only need a small preview. The fallback-to-render
approach is sensible UX policy and the `generateIfAbsent` opt-out gives callers
control. Aligns cleanly with the v0.03.1 roadmap entry.

**Proposed Solution Assessment**

The overall approach is sound. Reusing the existing render machinery for the
fallback path is correct — no new PDFium function surface is needed there. Using
`FPDFPage_GetThumbnailAsBitmap` as the primary path is the right choice over the
raw/decoded byte variants because the bitmap-copy pattern already exists in
`_handleRenderPage` and the stride-stripping logic can be shared.

There are a few gaps that need addressing before implementation begins:

1. **Spec entry missing.** The project memory for spec coverage
   (`project_spec_coverage.md`) records that every new public API surface needs
   a full spec entry in `docs/spec/` at the depth of `text_extraction.md`. The
   plan lists no spec file as a deliverable. `docs/spec/rendering.md` mentions
   thumbnail generation in passing (line 14) but has no formal `getThumbnail`
   section. A spec entry covering the public API shape, error contract, fallback
   behaviour, and platform support table must be added as an implementation
   task.

2. **`_document_web.dart` treatment is unspecified.** The plan lists the web
   stub as a file affected but does not say what behaviour it should expose. The
   embedded-thumbnail path requires FFI; the fallback render path is also
   unimplemented on web. The stub should throw `UnsupportedError` consistent
   with `renderPageToBytes` on the same file. This should be stated explicitly
   in the plan so the implementer doesn't try to partially implement the
   fallback on web.

3. **`PdfiumRenderPageResponse` inconsistency in error handling.** The fallback
   path calls `renderPageToBytes`, which on failure throws either `StateError`
   (closed doc) or `PdfiumException` (native failure). The plan does not say how
   `getThumbnail` propagates these — should it re-throw directly, or wrap them?
   Existing methods re-throw directly; state that expectation here to keep the
   pattern consistent.

4. **Pixel format of embedded thumbnail not guaranteed.** The PDFium header
   comment for `FPDFPage_GetThumbnailAsBitmap` says it "returns a nullptr if
   unable to access the thumbnail's stream" — it does not document the bitmap
   format. Looking at the existing PDFium `FPDFBitmap_Create` usage, bitmaps
   default to `FPDFBitmap_BGRx` or `FPDFBitmap_BGRA` depending on the alpha
   channel of the source. The plan assumes BGRA throughout (4 bytes per pixel),
   but if the embedded thumbnail bitmap has no alpha channel PDFium may return a
   `BGRx` (3-bytes-per-pixel, 4-byte-aligned) or `BGR` buffer. The handler must
   call `FPDFBitmap_GetFormat()` and handle format variants, or at minimum
   document the known risk and add a test assertion on
   `bgra.length == width * height * 4` to catch a mismatch at runtime. This is a
   correctness concern, not just defensive coding.

5. **The `close()` contract and active `getThumbnail` futures.** The plan's
   edge-case table covers the "document already closed before call" case, but
   does not address what happens if `close()` is called while a `getThumbnail`
   future is in flight (i.e. between `getPageSize` and `renderPageToBytes` in
   the fallback path). The existing `_document_native.dart` pattern calls
   `_checkNotClosed()` before the isolate round-trip; the fallback path here
   involves two sequential async operations and must guard between them. The
   plan should state that `_checkNotClosed()` is called before each async step
   in the fallback path, consistent with how `_extractPlainTextImpl` handles
   this.

6. **`devicePixelRatio` for fallback render.** The `project_device_pixel_ratio`
   memory records that layout-derived pixel dimensions must be multiplied by
   `MediaQuery.devicePixelRatio` before passing to any native render call.
   `getThumbnail` is on `PdfDocument` (pure Dart, no Flutter dependency), so it
   cannot access `MediaQuery`. This is architecturally correct — `maxDimension`
   is a logical pixel budget the caller controls. However, the doc comment must
   advise callers that if they want retina-sharp fallback renders they should
   multiply `maxDimension` by `devicePixelRatio` themselves. Add this note to
   the public doc comment in the implementation plan.

**Architecture Fit**

The plan fits the isolate model correctly. The embedded-thumbnail path routes
entirely through the isolate; the fallback path is pure Dart in
`_document_native.dart` building on `getPageSize` and `renderPageToBytes` which
already exist. The new types (`PdfThumbnailSource`, `PdfThumbnail`) belong in
`pdf_types.dart` and are exported from `pdfart_core.dart` — this is consistent
with existing types and correctly keeps the feature outside the Flutter entry
point. The `_document_stub.dart` pattern (throw `UnsupportedError`) is well
understood.

**Risk & Edge Cases**

The edge-case table is thorough for the happy path. The main risks not fully
addressed are:

- Bitmap pixel format mismatch (see point 4 above) — this is the most likely
  source of a correctness bug at runtime.
- Interleaved `close()` during fallback's two-step async flow (see point 5).
- The test fixture must be committed as a binary file; confirm the repo does not
  have a `.gitattributes` rule that would corrupt it with line-ending
  normalisation.

**Recommendations**

The plan is very close to ready. Address the following before implementing:

1. Add a spec update task to `docs/spec/rendering.md` (new `getThumbnail`
   section) to the implementation plan.
2. Explicitly state that the web stub throws `UnsupportedError`.
3. Add a note about `FPDFBitmap_GetFormat()` check (or document the known risk)
   in the isolate handler description.
4. Add `_checkNotClosed()` guard between the two async steps in the fallback
   path to the implementation plan.
5. Add a doc-comment note about multiplying `maxDimension` by `devicePixelRatio`
   for high-DPI display.
6. Verify `.gitattributes` does not apply line-ending normalisation to
   `test/data/*.pdf`.

The plan can remain at `Investigated` — none of these are show-stoppers that
require redesign. Items 1–5 are small additions to the implementation checklist
or inline documentation; item 6 is a one-line check. The implementer should
complete them as part of the implementation task without returning to planning.

## Summary

- `PdfDocument.getThumbnail(pageIndex, {generateIfAbsent, maxDimension})` added to the public API and to all three backend files (native, stub, web).
- Embedded thumbnails are extracted via `FPDFPage_GetThumbnailAsBitmap` (experimental PDFium API) inside the `PdfiumIsolate`. The handler calls `FPDFBitmap_GetFormat` to discriminate between `BGRA` and `BGRx` pixel formats, converts `BGRx` to `BGRA` in-place, strips row padding, and wraps bitmap reads in `try/finally` to guarantee `FPDFBitmap_Destroy` is called.
- When no embedded thumbnail is present and `generateIfAbsent` is `true`, the fallback path scales the page's intrinsic PDF dimensions so the longest edge equals `maxDimension` pixels (minimum 1 px on short edge), then delegates to the existing `renderPageToBytes` pipeline. `_checkNotClosed()` is called before each async step to handle concurrent `close()` calls.
- `PdfThumbnailSource` enum and `PdfThumbnail` final class added to `pdf_types.dart` and re-exported via the existing `pdf_document.dart` → `pdfart_core.dart` chain.
- `ffigen.yaml` was updated and bindings regenerated to include `fpdf_thumbnail.h` prior to this session; the isolate message protocol (`PdfiumGetPageThumbnailCommand`, `PdfiumGetPageThumbnailResponse`) was similarly already in place.
- Spec entry added to `docs/spec/rendering.md` covering the public API shape, error contract, fallback behaviour, `maxDimension` semantics, and platform support table.
- `test/thumbnail_extraction_test.dart` adds 29 tests covering value-type unit tests (equality, hashCode, toString, field access) and integration tests (embedded thumbnail, fallback render, `generateIfAbsent: false`, custom `maxDimension`, `RangeError`, `ArgumentError`, and `StateError` on closed document).
- All 534 tests pass; line coverage is 90.3% (above the 90% minimum), excluding auto-generated FFI bindings.
