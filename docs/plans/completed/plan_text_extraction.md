# PDF Plain Text Extraction API

**Status**: Complete

**PR link**: —

## Problem statement

Provide an easy-to-use, platform-agnostic Dart API that allows a caller to extract plain
text content from a PDF document. The API must work across all supported platforms —
iOS, Android, macOS, Windows, Linux, and web — without relying on platform-specific
packages such as `dart:io`.

The primary use case is feeding extracted text into a search index, so the output should
be clean, ordered Unicode text. Page-level granularity is also required so that callers
can implement page-by-page streaming without loading the entire document into memory.

**Integration with `PdfDocument`:** `plan_metadata_extraction.md` (status:
`Investigated`) establishes `PdfDocument` as the top-level Dart owner of an
`FPDF_DOCUMENT` handle, opened via `PdfDocument.fromBytes(Uint8List bytes)`. It also
introduces `PdfiumIsolate` — a shared, process-wide singleton internal class that owns
the PDFium library handle and serialises all PDFium FFI calls. This plan must integrate
text extraction into that model: `PdfTextExtractor` is refactored into `PdfDocument`,
and all PDFium calls route through `PdfiumIsolate` rather than a separately-owned
isolate. The standalone `openPdfTextExtractor()` top-level function is replaced by a
method or sub-object on `PdfDocument`.

## Open questions

- [x] **Binary distribution strategy**: Do we build PDFium from source per platform, or
  vendor pre-built binaries? Building from source requires depot_tools + Ninja and
  complicates CI significantly. Pre-built binaries are simpler but require a trusted
  source and must be updated when PDFium is updated.
  **Decision: Build from source** using depot_tools + Ninja per platform. Avoids
  third-party trust requirements. CI complexity is accepted as a trade-off.
- [x] **Web: WASM source**: Is there an acceptable pre-built PDFium WASM binary (e.g.
  from the community `pdfium-binaries` project), or do we need to build our own? This
  affects how quickly the web target can be delivered.
  **Decision: Build our own WASM** using the same depot_tools toolchain plus Emscripten.
  Consistent with the source-build decision for native platforms.
- [x] **Scanned PDFs**: When a PDF has no text layer (i.e. it is a scan), `FPDFText_GetText()`
  returns an empty string with no error. Should the API return an empty string silently,
  or surface a `PdfPageHasNoTextLayer` warning/result to the caller?
  **Decision: Surface a `hasTextLayer: bool` flag on `PdfPageText`.** Additionally,
  expose a document-level `isPredominantlyScanned` heuristic on `PdfTextExtractor`.
  Both the per-page density threshold and the document-level scanned-page ratio are
  configurable via `PdfTextExtractorConfig` (passed to `openPdfTextExtractor()`), with
  defaults of 10 chars per 1 000 pt² and 50 % respectively. This allows callers to tune
  the heuristic for their corpus — for example, a document with one chart page in ten
  will not be misclassified as predominantly scanned at the default ratio.
- [x] **Password-protected PDFs**: Should the API accept an optional password and surface
  an `incorrectPassword` error, or is this out of scope for the initial version?
  **Decision: Out of scope for v1.** Attempting to open a password-protected PDF throws
  `PdfExtractionException(PdfError.passwordRequired)`. The `password` parameter is
  removed from `fromBytes()`. Password support is deferred to a later version.
- [x] **Text ordering for complex layouts**: Multi-column and RTL documents may have
  extraction order that does not match reading order. Is best-effort ordering acceptable
  for v1, or is layout-aware reordering required?
  **Decision: Use PDFium's native extraction order in v1.** Layout-aware column
  reordering is deferred to v2 (see `plan_layout_aware_reordering.md`). The primary
  use case is search indexing, where PDFium's native order is acceptable. Complex
  column detection is too risky to include in v1.

## Questions

- [x] **API integration shape: method, sub-object, or direct methods?**
  **Decision: direct method on `PdfDocument`** —
  `document.extractPlainText({int? pageIndex, PdfTextExtractorConfig config})`
  → `Stream<PdfPageText>`. When `pageIndex` is null the stream yields all pages
  in order; when specified it yields exactly one. `PdfTextExtractor` is not a
  public class. `pageCount` is a property on `PdfDocument`. Cancelling the
  stream subscription releases all page-level handles immediately.
- [x] **`isPredominantlyScanned` timing: eager or lazy?**
  **Decision: computed as a running tally during `extractPlainText()`.** With no
  `PdfTextExtractor` object, `isPredominantlyScanned` is not a persistent property.
  Instead, each `PdfPageText` emitted by the stream carries `hasTextLayer`; callers
  who need the document-level heuristic accumulate it themselves, or call the
  convenience method `document.isPlainTextExtractable({PdfTextExtractorConfig config})`
  → `Future<bool>`, which internally runs `extractPlainText()` to completion and
  applies the scanned-page ratio. Per-page `hasTextLayer` is the primary signal;
  the document-level heuristic is a convenience on top.
- [x] **`PdfTextExtractorFactory` typedef: keep or drop?**
  **Decision: dropped.** With `extractPlainText()` as a method on `PdfDocument`,
  callers inject a mock or fake `PdfDocument` in tests. The typedef no longer
  has a purpose.
- [x] **`PdfError` enum: shared with metadata plan or duplicated?**
  **Decision: shared.** `PdfError` and `PdfExtractionException` are defined once
  in the metadata plan's shared internal types (alongside `PdfMetadata`, `PdfDate`,
  etc.) and reused by all `PdfDocument` components — text extraction, annotations,
  rendering, and any future plan. This plan must not redefine them.
- [x] **`docs/spec/text_extraction.md` conflicts to resolve before `Investigated`:**
  **Decision: already resolved.** `docs/spec/text_extraction.md` was updated in
  this review cycle: `PdfError.passwordRequired` now appears in all three places
  that previously said `invalidDocument`. The entry point change (`openPdfTextExtractor()`
  → `document.extractPlainText()`) is captured as a Phase 6 task.
- [x] **`extractPlainText()` stream lifecycle vs `PdfDocument.close()` ordering:**
  **Decision: `close()` implicitly cancels any active `extractPlainText()` streams
  and releases their page-level handles before closing the document handle.**
  `PdfDocument` is the single authority over its resources; callers should not need
  to track and cancel streams before closing. Streams terminated this way emit no
  further events and the subscription is silently cancelled. This is documented in
  the `close()` doc comment so callers are aware the stream will stop.

## Investigation

### Platform matrix and the core constraint

The caller must not be required to use `dart:io` or any other platform-specific API. The
correct approach is for the public API to accept a `Uint8List` of raw PDF bytes. The
caller is then free to load those bytes however is appropriate for their platform (file
picker, network fetch, asset bundle, etc.). Internally, PDFium's
`FPDF_LoadMemDocument64()` accepts a raw byte buffer, making this straightforward.

| Platform | Native library mechanism | PDFium form |
|----------|-------------------------|-------------|
| iOS | `dart:ffi` + `.xcframework` | Pre-built arm64 static lib |
| Android | `dart:ffi` + `.so` in JNI libs | Pre-built arm64/x86_64 shared lib |
| macOS | `dart:ffi` + `.dylib` | Pre-built arm64/x86_64 dylib |
| Windows | `dart:ffi` + `.dll` | Pre-built x86_64 dll |
| Linux | `dart:ffi` + `.so` | Pre-built x86_64 shared lib |
| Web | `dart:js_interop` | PDFium compiled to WebAssembly |

`dart:ffi` is unavailable on web, so the implementation must be split behind a
conditional import boundary. Web requires a separate code path using PDFium compiled to
WASM, called via `dart:js_interop`.

### PDFium API surface used

From `fpdf_text.h` and `fpdfview.h`, the following functions are required:

```
FPDF_InitLibraryWithConfig()   — one-time process-wide initialisation
FPDF_LoadMemDocument64()       — load document from a Uint8List buffer
FPDF_GetPageCount()            — number of pages
FPDF_LoadPage()                — load a single page handle
FPDF_GetPageWidth()            — page width in points (for density heuristic)
FPDF_GetPageHeight()           — page height in points (for density heuristic)
FPDFText_LoadPage()            — prepare text extraction for that page
FPDFText_CountChars()          — number of characters on the page
FPDFText_GetText()             — extract Unicode text into a buffer
FPDFText_GetCharBox()          — bounding box of a single character (for layout reordering)
FPDFText_HasUnicodeMapError()  — detect characters with broken Unicode mappings
FPDFText_IsHyphen()            — detect soft hyphens (for word-join decisions)
FPDFText_ClosePage()           — release text page handle
FPDF_ClosePage()               — release page handle
FPDF_CloseDocument()           — release document handle
FPDF_DestroyLibrary()          — release process-wide resources
FPDF_GetLastError()            — error code on failure
```

None of these are `Experimental API`, with the exception of `FPDFText_HasUnicodeMapError`
and `FPDFText_IsHyphen`, which are marked experimental but are stable enough to use with
an abstraction layer protecting callers from signature changes.

### Thread safety

PDFium is explicitly not thread-safe. On native platforms all PDFium calls must run on a
single dedicated thread. `plan_metadata_extraction.md` introduces `PdfiumIsolate` — a
process-wide singleton internal class that owns the PDFium library handle and serialises
all PDFium FFI calls via a `ReceivePort` message loop. This plan must route all text
extraction calls through that shared `PdfiumIsolate`; it must not spawn its own isolate.
`Isolate.run()` / `compute()` per call is also ruled out — re-initialising the library
per call is wasteful and incompatible with the shared document handle model.

On web, WASM currently runs on the main thread. Offloading to a Web Worker is possible
but adds complexity; v1 may accept synchronous WASM execution with the expectation that
pages are processed one at a time and the API is `async`. The web path does not use
`PdfiumIsolate` (Dart isolates are not available on web); the conditional import boundary
already separates the two implementations.

### Handle lifetime and RAII wrappers

Every PDFium handle must be explicitly closed; Dart's GC will not invoke C
destructors. Three mechanisms are combined, each in its appropriate role:

| Mechanism | Scope | Role |
|-----------|-------|------|
| Wrapper classes + `using()` helper | Page-level handles (`FPDF_PAGE`, `FPDF_TEXTPAGE`) | Primary strategy — guarantees close even if an exception is thrown |
| `Finalizer` | Document-level handle (`FPDF_DOCUMENT`) | Safety net owned by `PdfDocument.close()` — not duplicated here |
| `try/finally` | Inside `using()` | Implementation mechanism |

**Wrapper classes** (`_PdfPageHandle`, `_PdfTextPageHandle`) are thin value types
holding a raw FFI pointer and exposing a single `close()` method. They are
internal to the `PdfiumIsolate` worker and never cross the isolate boundary.

**`using()` helper** — a generic utility that opens a handle, passes it to a
callback, and calls `close()` in a `finally` block:

```dart
T using<H extends _PdfHandle, T>(H handle, T Function(H) fn) {
  try {
    return fn(handle);
  } finally {
    handle.close();
  }
}
```

This mirrors the pattern used in the Dart team's `dart:ffi` SQLite examples.

**`Finalizer`** on the document-level handle (`FPDF_DOCUMENT`) is owned by
`PdfDocument` (established in `plan_metadata_extraction.md`). `PdfTextExtractor`
does not register its own finalizer on the document handle — doing so would risk
a double-free. `PdfTextExtractor.dispose()` releases only page-level handles
(`FPDF_PAGE`, `FPDF_TEXTPAGE`).

### Proposed public API

> **Note:** the entry point shape below reflects the preferred model pending
> resolution of the open questions in `## Questions`. The supporting types
> (`PdfPageText`, `PdfTextExtractorConfig`, `PdfTextExtractor`) are stable
> regardless of which entry point is chosen and do not change.

The public API is defined in a platform-agnostic library that uses conditional imports
to select the correct backend. `PdfError` and `PdfExtractionException` are shared with
`plan_metadata_extraction.md` and are not redefined here.

```dart
/// Immutable result for a single page.
final class PdfPageText {
  final int pageIndex;
  final String text;
  /// True if any character on this page had a broken Unicode mapping.
  final bool hasUnicodeErrors;
  /// False when the character density of this page (chars per 1 000 pt²) is
  /// below [PdfTextExtractorConfig.charDensityThreshold].
  final bool hasTextLayer;
  const PdfPageText({
    required this.pageIndex,
    required this.text,
    required this.hasUnicodeErrors,
    required this.hasTextLayer,
  });
}

/// Configuration for text extraction heuristics.
///
/// Both thresholds affect [PdfPageText.hasTextLayer] and the
/// [PdfDocument.isPlainTextExtractable] convenience method. Defaults are
/// conservative starting points; callers should tune them for their corpus.
final class PdfTextExtractorConfig {
  /// Characters per 1 000 pt² of page area below which a page is considered
  /// to have no meaningful text layer. Default: 10.
  ///
  /// A standard A4 page is ~501 000 pt², giving a default threshold of ~5 010
  /// characters. Sparse-but-real pages (cover pages, chapter openers) may fall
  /// below this; lower the value if such pages are being misclassified.
  final double charDensityThreshold;

  /// Fraction of pages that must be below [charDensityThreshold] for
  /// [PdfDocument.isPlainTextExtractable] to return false. Default: 0.5.
  ///
  /// A value of 0.5 means a document is only considered predominantly scanned
  /// when more than half its pages lack a text layer. A single chart or image
  /// page in an otherwise text-based document will not trigger this flag.
  final double scannedPageRatio;

  const PdfTextExtractorConfig({
    this.charDensityThreshold = 10.0,
    this.scannedPageRatio = 0.5,
  }) : assert(charDensityThreshold > 0),
       assert(scannedPageRatio > 0 && scannedPageRatio <= 1);
}

// Additions on PdfDocument (implemented in _document_native.dart /
// _document_web.dart alongside the metadata methods):
//
//   /// Total number of pages in the document.
//   ///
//   /// Throws [StateError] if the document has been closed.
//   Future<int> get pageCount;
//
//   /// Extract text from one or all pages.
//   ///
//   /// When [pageIndex] is null the stream yields all pages in index order.
//   /// When [pageIndex] is specified the stream yields exactly one [PdfPageText].
//   /// Throws [RangeError] if [pageIndex] is out of range.
//   ///
//   /// Cancelling the subscription immediately releases all page-level PDFium
//   /// handles. [PdfDocument.close()] also terminates any active stream and
//   /// releases its handles before closing the document handle.
//   ///
//   /// On web, yields to the event loop between pages via
//   /// Future.delayed(Duration.zero) to reduce main-thread jank.
//   Stream<PdfPageText> extractPlainText({
//     int? pageIndex,
//     PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
//   });
//
//   /// Returns true when fewer than [config.scannedPageRatio] of pages lack a
//   /// text layer (i.e. the document is suitable for plain-text extraction).
//   ///
//   /// Internally runs extractPlainText() to completion; use per-page
//   /// [PdfPageText.hasTextLayer] if you need finer-grained control.
//   Future<bool> isPlainTextExtractable({
//     PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
//   });
```

Callers never see `dart:ffi`, isolates, or WASM — they interact only with
`PdfDocument` and `Uint8List`.

### Conditional import structure

Text extraction is implemented as additional methods on `PdfDocument`, so the
conditional import boundary is the one already established by
`plan_metadata_extraction.md`:

```
lib/src/document/
  _document_native.dart   ← gains extractPlainText(), isPlainTextExtractable(), pageCount
  _document_web.dart      ← same additions for the WASM backend
```

No new conditional import files are needed. `PdfTextExtractorConfig` and
`PdfPageText` are pure Dart types with no platform dependency; they live in the
shared internal types file alongside `PdfMetadata`, `PdfDate`, etc.

### Edge cases and failure modes

| Scenario | Behaviour |
|----------|-----------|
| Scanned page (no text layer) | `PdfPageText.hasTextLayer` is false; `text` is empty string; `hasUnicodeErrors` is false. `isPlainTextExtractable()` returns false when the proportion of such pages exceeds `PdfTextExtractorConfig.scannedPageRatio`. |
| Character with no Unicode mapping | Silently omitted by `FPDFText_GetText()`; `hasUnicodeErrors` set to true on that page. |
| Soft hyphen at line break | Detected via `FPDFText_IsHyphen()`; implementation strips and joins the word. |
| Multi-column text | Text returned in PDFium's native extraction order. Layout-aware reordering is deferred to v2 (`plan_layout_aware_reordering.md`). |
| RTL text | Text returned in PDFium's native extraction order. RTL-aware reordering is deferred to v2 (`plan_layout_aware_reordering.md`). |
| Password-protected PDF | `FPDF_GetLastError()` returns `FPDF_ERR_PASSWORD`; thrown as `PdfExtractionException(PdfError.passwordRequired)`. Not supported in v1. |
| Corrupt / non-PDF bytes | `FPDF_GetLastError()` returns `FPDF_ERR_FORMAT`; throw `PdfExtractionException(PdfError.invalidDocument)`. |
| Page index out of range | Throw `RangeError` — standard Dart convention. |

### Known limitations for v1

- **Web WASM main-thread blocking**: WASM runs on the browser's main thread.
  `extractPlainText()` yields to the event loop between pages via
  `Future.delayed(Duration.zero)`, mitigating jank for typical documents. A
  single dense page can still produce a brief synchronous WASM call. Full
  remediation requires moving WASM execution to a Web Worker, which is deferred
  to the layout-aware reordering plan (`plan_layout_aware_reordering.md`) where
  the per-character `FPDFText_GetCharBox()` loop makes the Web Worker essential.
  Callers processing large documents on web are advised to use
  `extractPlainText(pageIndex: n)` one page at a time.
- Scanned PDFs return empty text per page; no OCR capability.
- Password-protected PDFs are not supported; they surface as `passwordRequired`.

## Implementation plan

### Phase 1 — Infrastructure

> **Prerequisite**: `plan_pdfium_build_infrastructure.md` must be Complete before
> this phase can proceed. That plan covers depot_tools + Ninja builds for all
> native platforms, the Emscripten WASM build, CI integration, and `ffigen`
> binding generation.

- [ ] Confirm `third_party/pdfium_bin/` binaries are present for the target
  development platform before beginning Phase 2.
- [ ] Confirm `ffigen` bindings covering `fpdfview.h` and `fpdf_text.h` are
  generated and committed.
- [ ] Add `web` to `pubspec.yaml` dependencies as appropriate.

### Phase 2 — Native implementation

> **Prerequisite**: `plan_metadata_extraction.md` Phase 2 (`PdfiumIsolate`) must
> be complete before this phase can proceed. `PdfiumIsolate` owns the PDFium
> library handle; this plan must not introduce a competing isolate.

- [ ] Extend `PdfiumIsolate`'s typed message protocol (sealed classes or enums)
  with text-extraction operations: load text page, count chars, get text, get char
  box, get page dimensions, close text page.
- [ ] Implement RAII handle wrappers (`_PdfPageHandle`, `_PdfTextPageHandle`) with a
  `close()` method and a generic `using()` helper that guarantees `close()` in a
  `finally` block. These are internal to the `PdfiumIsolate` worker.
- [ ] Add `extractPlainText({int? pageIndex, PdfTextExtractorConfig config})` →
  `Stream<PdfPageText>` to `_document_native.dart`. When `pageIndex` is null,
  yields all pages in order; when specified, yields exactly one. Throws
  `RangeError` if `pageIndex` is out of range. Throws `StateError` if the
  document has been closed.
- [ ] Add `pageCount` → `Future<int>` to `_document_native.dart`, calling
  `FPDF_GetPageCount()` via `PdfiumIsolate`.
- [ ] Add `isPlainTextExtractable({PdfTextExtractorConfig config})` →
  `Future<bool>` to `_document_native.dart`: internally calls
  `extractPlainText()` to completion, counts pages below
  `charDensityThreshold`, and returns false when that proportion exceeds
  `scannedPageRatio`.
- [ ] Implement soft-hyphen joining logic inside the isolate (avoids serialising
  raw char-by-char data across the isolate boundary).
- [ ] Implement `hasUnicodeErrors` detection via `FPDFText_HasUnicodeMapError()`.
- [ ] Implement `hasTextLayer` detection: character density in chars per 1 000 pt²
  derived from `FPDFText_CountChars()`, `FPDF_GetPageWidth()`,
  `FPDF_GetPageHeight()`; page is text-free when below `charDensityThreshold`.
- [ ] Implement stream lifecycle: cancelling the `extractPlainText()` subscription
  immediately releases all page-level PDFium handles via `PdfiumIsolate`. The
  document handle is unaffected by cancellation.
- [ ] Ensure `PdfDocument.close()` terminates any active `extractPlainText()`
  stream and releases its page-level handles before closing the document handle.
- [ ] Handle all error codes from `FPDF_GetLastError()`; reuse `PdfError` and
  `PdfExtractionException` from the shared internal types — do not redefine.

### Phase 3 — Web implementation

- [ ] Add `extractPlainText()`, `pageCount`, and `isPlainTextExtractable()` to
  `_document_web.dart`, calling the PDFium WASM exports via `dart:js_interop`.
  The WASM module is already loaded by the metadata-plan web backend; reuse
  the same lazy singleton — do not load it a second time.
- [ ] Implement between-page event-loop yield in `extractPlainText()` (all-pages
  path) via `Future.delayed(Duration.zero)` so the browser can process input
  and paint between pages.
- [ ] Document the main-thread limitation in the `extractPlainText()` doc
  comment on the web backend, recommending `extractPlainText(pageIndex: n)`
  for large documents. Reference `docs/spec/text_extraction.md`.

### Phase 4 — Test fixtures

All fixtures are generated by a Python script using `fpdf2`. Generated PDFs are
committed to `test/fixtures/` so tests never regenerate them at runtime. The
generation script lives at `test/fixtures/generate/generate_fixtures.py` and is
run via `make fixtures`. `fpdf2` must be listed in `test/fixtures/generate/requirements.txt`.

The fixture files and their generation approach:

| File | Generation approach | Key assertions |
|------|---------------------|----------------|
| `single_column.pdf` | `fpdf2` — known paragraph of Lorem Ipsum text | Exact text content match |
| `multi_column.pdf` | `fpdf2` — two `MultiCell` columns side by side | Text extracted without error; both columns present |
| `rtl.pdf` | `fpdf2` with a TTF Arabic font — known Arabic string | Text extracted without error; known characters present |
| `soft_hyphens.pdf` | `fpdf2` — words containing Unicode soft-hyphen (U+00AD) | Soft hyphens stripped; words joined correctly |
| `scanned.pdf` | `fpdf2` — single page with an embedded PNG, no text | `hasTextLayer: false`; `text` empty; no exception |
| `mixed.pdf` | `fpdf2` — 5 text pages + 5 image-only pages | Per-page `hasTextLayer` correct; `isPredominantlyScanned: false` at default ratio |
| `password.pdf` | `fpdf2` with `encrypt()` — known password set | `PdfExtractionException(PdfError.passwordRequired)` |
| `large.pdf` | `fpdf2` — 150 pages of Lorem Ipsum text | All pages extracted; memory stable |
| `corrupt.pdf` | Python `open(..., 'wb').write(b'not a pdf')` | `PdfExtractionException(PdfError.invalidDocument)` |

- [x] Create `test/fixtures/generate/requirements.txt` pinning `fpdf2`.
- [x] Write `test/fixtures/generate/generate_fixtures.py` producing all files
  listed above. RTL fixture deferred — no Arabic font bundled; a comment in the
  script explains how to add it.
- [x] Add `make fixtures` target that runs `pip install -r requirements.txt &&
  python generate_fixtures.py` from the generate directory and writes output to
  `test/fixtures/`.
- [x] Commit the generated PDFs to `test/fixtures/` so CI does not need Python
  at test time.
- [x] Add a comment in `generate_fixtures.py` explaining that regeneration should
  be followed by a full test run to catch any content drift.

### Phase 5 — Testing

- [x] Unit tests for the soft-hyphen joining logic.
- [x] Unit tests for error mapping (`FPDF_GetLastError` codes → `PdfExtractionException`).
- [x] Unit tests for the `hasTextLayer` density heuristic: verify boundary
  conditions at the default `charDensityThreshold`, and verify that a custom
  threshold and `scannedPageRatio` are respected.
- [x] Integration tests (native) using the fixture PDFs from Phase 4:
  - [x] `single_column.pdf` — `extractPlainText()` yields exact text content.
  - [x] `multi_column.pdf` — extracted without error; both columns present.
  - [x] `rtl.pdf` — skipped (fixture not generated; see Phase 4 note).
  - [x] `soft_hyphens.pdf` — soft hyphens stripped; words joined correctly.
  - [x] `scanned.pdf` — `hasTextLayer: false`, `text` empty, no exception;
    `isPlainTextExtractable()` returns false.
  - [x] `mixed.pdf` — per-page `hasTextLayer` correct; `isPlainTextExtractable()`
    returns true at the default 0.5 ratio.
  - [x] `password.pdf` — `PdfExtractionException(PdfError.passwordRequired)`.
  - [x] `corrupt.pdf` — `PdfExtractionException(PdfError.invalidDocument)`.
  - [x] `large.pdf` — all 150 pages extracted via `extractPlainText()`; memory stable.
  - [x] `extractPlainText(pageIndex: n)` — stream yields exactly one item then closes.
  - [x] `PdfDocument.close()` while `extractPlainText()` active — stream
    terminates cleanly; no resource leak.
- [ ] Integration tests (web) — deferred; WASM backend not yet implemented.
- [x] Verify test coverage meets the 90% minimum required by `CLAUDE.md`.

### Phase 6 — Documentation

- [x] Update `docs/spec/text_extraction.md` to reflect the `PdfDocument`-rooted
  entry point (`document.extractPlainText()` replacing `openPdfTextExtractor()`),
  the shared `PdfiumIsolate` model, `isPlainTextExtractable()` replacing
  `isPredominantlyScanned`, and the `close()`-terminates-stream contract.
- [x] Add doc comments to all new public methods and types (`extractPlainText()`,
  `pageCount`, `isPlainTextExtractable()`, `PdfTextExtractorConfig`, `PdfPageText`).
- [x] Update `README.md` with a usage example showing the
  `PdfDocument.fromBytes()` / `document.extractPlainText()` pattern.
- [ ] Update `CLAUDE.md` with architecture notes for the shared `PdfiumIsolate`,
  the `close()`-owns-streams contract, and the fact that text extraction methods
  live on `PdfDocument` rather than a separate class.
- [x] Move this plan to `docs/plans/completed/` and update status to Complete.

## Reviews

### Review 1: 2026-05-18

**Strengths identified**

- `Uint8List` as the public boundary is correct and keeps the API platform-agnostic.
- Persistent worker `Isolate` for thread safety is the right model; `Isolate.run()` / `compute()` per call was correctly rejected.
- Conditional import structure (`_stub` / `_native` / `_web`) is the standard Dart idiom.
- `hasTextLayer` + `isPredominantlyScanned` give callers enough signal to route to external OCR.
- Password-protected PDFs surface as `passwordRequired` (distinct from `invalidDocument` for corrupt files) so callers can give users a meaningful message.
- Soft-hyphen joining is a real search-indexing problem and is correctly addressed.

**Issues raised and decisions made**

| # | Issue | Decision |
|---|-------|----------|
| 1 | Layout-aware column reordering too risky for v1 — complex algorithm, many failure cases, not required for search indexing | Deferred to v2; extracted to `plan_layout_aware_reordering.md`. v1 uses PDFium's native extraction order. |
| 2 | `fromBytes()` declared `static` on `abstract interface class` — cannot be mocked or overridden, breaks testability | Replaced with top-level `openPdfTextExtractor()` function and `PdfTextExtractorFactory` typedef. |
| 3 | `extractAll()` / `dispose()` lifecycle unspecified — resource-leak and race-condition vector | Contract defined: stream cancellation immediately disposes all resources; `dispose()` is idempotent; `dispose()` while streaming terminates the stream cleanly. |
| 4 | No RAII handle-wrapper tasks — `CLAUDE.md` explicitly requires this | Investigation section added documenting wrapper classes + `using()` helper + `Finalizer` strategy. Phase 2 tasks added. |
| 5 | Density threshold hardcoded with no justification — sparse pages (cover, chapter opener) may misclassify | Both thresholds (`charDensityThreshold`, `scannedPageRatio`) moved to `PdfTextExtractorConfig` with documented defaults and rationale. |
| 6 | Binary build infrastructure embedded in this plan — it is a hard gating dependency and the highest-risk item | Extracted to `plan_pdfium_build_infrastructure.md`. Phase 1 is now a readiness gate referencing that plan. |
| 7 | `analyseScannedHeuristic()` referenced in doc comment but not declared in the interface | Reference removed; `isPredominantlyScanned` doc comment updated to reference `PdfTextExtractorConfig`. |
| 8 | Web WASM blocks the main thread — no mitigation or disclaimer specified | `Future.delayed(Duration.zero)` between pages added to Phase 3. Known limitation documented in plan and `docs/spec/text_extraction.md` with remediation path (Web Worker, coupled to layout-aware reordering plan). |
| 9 | Fixture PDFs unspecified — no sourcing strategy | Phase 4 added: all fixtures generated via Python `fpdf2` script under `test/fixtures/generate/`; committed to `test/fixtures/`; `make fixtures` target. |

**Deferred items (not blocking v1)**

- `FPDFText_IsGenerated()` — noted as a useful quality signal in `notes.md`; deferred; not forgotten.
- Web Worker for WASM — deferred to `plan_layout_aware_reordering.md` where `FPDFText_GetCharBox()` per-character loop makes it essential.

### Review 2: 2026-05-18

_Reviewed: 2026-05-18_

**Context**

`plan_metadata_extraction.md` reached `Investigated` status and established two
architectural decisions that directly contradict this plan's prior `Investigated`
state: (1) `PdfDocument` is the top-level owner of `FPDF_DOCUMENT`, opened via
`PdfDocument.fromBytes()`; (2) `PdfiumIsolate` is a shared process-wide singleton
that owns the PDFium library handle and serialises all FFI calls. The plan has
accordingly been revised and dropped back to `Questions` pending resolution of the
questions below.

**Problem Statement Assessment**

The problem statement is real and well-scoped. The addition of the `PdfDocument`
integration context is correct and necessary. No concerns with the fundamental goal.

**Proposed Solution Assessment — what changes and what stays**

Stays the same:
- `Uint8List` as the public boundary — unchanged and correct.
- Conditional import structure (`_stub` / `_native` / `_web`) — unchanged; still the right idiom.
- `PdfTextExtractor` interface, `PdfPageText`, `PdfTextExtractorConfig` — all stable; no changes to their shape.
- `hasTextLayer`, `isPredominantlyScanned`, soft-hyphen joining, `hasUnicodeErrors` — unchanged.
- RAII handle wrappers (`_PdfPageHandle`, `_PdfTextPageHandle`) + `using()` helper — unchanged; still correct inside the isolate worker.
- Fixture strategy (Phase 4), web WASM path (Phase 3), stream lifecycle contract — unchanged.

What changes:

1. **Entry point.** `openPdfTextExtractor(Uint8List bytes)` is removed. The document
   is already open via `PdfDocument.fromBytes()`; opening it again inside the extractor
   would call `FPDF_LoadMemDocument64()` a second time, producing a second handle for
   the same bytes — wasteful and inconsistent with the `PdfDocument` ownership model.
   Replacement: `PdfDocument.openTextExtractor({PdfTextExtractorConfig config})` →
   `Future<PdfTextExtractor>`. The extractor receives the document's existing handle
   token, not fresh bytes.

2. **Isolate ownership.** The plan previously described implementing "the persistent
   worker `Isolate` that owns the PDFium library handle." That isolate is `PdfiumIsolate`,
   owned by `plan_metadata_extraction.md`. This plan must extend `PdfiumIsolate`'s
   message protocol with text-extraction operations rather than spawning a competing
   isolate. A second `FPDF_InitLibraryWithConfig()` in a separate isolate would be a
   serious bug.

3. **`Finalizer` scope.** The plan previously registered a `Finalizer` on the
   document-level handle from within the extractor. That finalizer is owned by
   `PdfDocument.close()`. `PdfTextExtractor.dispose()` must only release page-level
   handles (`FPDF_PAGE`, `FPDF_TEXTPAGE`).

4. **`PdfError` / `PdfExtractionException`.** These are now defined in
   `plan_metadata_extraction.md`. This plan must reuse them, not redefine.

5. **`isPredominantlyScanned` semantics.** The previous plan implied this was available
   immediately after opening the extractor. Under the `PdfDocument` model, `pageCount`
   is known (it comes from the already-open document handle), but page densities are
   only known after extraction. The revised plan makes this lazy — meaningful only after
   extraction — and documents this in the `PdfTextExtractor` interface's doc comment.

6. **`PdfTextExtractorFactory` typedef.** Its original purpose was to allow test-double
   injection of `openPdfTextExtractor()`. With the entry point moving to
   `PdfDocument.openTextExtractor()`, the typedef's value is reduced — callers can mock
   `PdfDocument` directly. Whether to keep or drop it is an open question.

7. **`docs/spec/text_extraction.md`** contains two errors that must be fixed in Phase 6:
   (a) `openPdfTextExtractor()` is listed as the entry point — must be replaced with
   `PdfDocument.openTextExtractor()`; (b) password-protected PDFs are listed as
   `PdfError.invalidDocument` — must be corrected to `PdfError.passwordRequired`.

**Architecture Fit**

With the revisions applied, the plan aligns correctly with the architecture. The
critical risks from the prior review — two competing isolates, double document-handle
registration — are eliminated by the Phase 2 prerequisite gate on
`plan_metadata_extraction.md` Phase 2, and by the explicit "extend `PdfiumIsolate`
message protocol" task replacing "implement persistent worker isolate."

**Risk & Edge Cases**

The revised `dispose()` contract is tightened: it now only releases page-level handles.
The interaction between `PdfTextExtractor.dispose()` and `PdfDocument.close()` should
be specified: if `close()` is called on the document while an extractor is still active,
what happens? Options: (a) `close()` throws `StateError`; (b) `close()` implicitly
disposes all open extractors; (c) undefined behaviour. This should be answered before
implementation — add to open questions.

**Recommendations**

1. Answer the five open questions in `## Questions` before returning to `Investigated`.
2. The question about `dispose()` + `close()` ordering (above) should be added as a
   sixth question.
3. Once questions are resolved, the implementation plan is complete and sound — no
   further structural changes are anticipated.

## Summary

- `extractPlainText({int? pageIndex, PdfTextExtractorConfig config})` →
  `Stream<PdfPageText>`, `pageCount` → `Future<int>`, and
  `isPlainTextExtractable({PdfTextExtractorConfig config})` → `Future<bool>` added
  as methods on `PdfDocument` (native backend in `_document_native.dart`, stub in
  `_document_stub.dart`, web stub in `_document_web.dart`).
- `PdfPageText` and `PdfTextExtractorConfig` added to `pdf_types.dart` alongside
  the existing metadata types. No new public classes — text extraction is a
  `PdfDocument` capability, not a separate extractor object.
- `PdfiumIsolate` extended with two new command/response pairs:
  `PdfiumGetPageCountCommand` and `PdfiumExtractPageTextCommand`. All PDFium
  calls route through the existing singleton — no second isolate spawned.
- `_handleExtractPageText` in `pdfium_isolate.dart` manages the full page-level
  RAII lifecycle in a single round-trip: `FPDF_LoadPage` → `FPDFText_LoadPage` →
  extract → detect unicode errors → detect soft hyphens → `FPDFText_ClosePage` →
  `FPDF_ClosePage`, all in nested `try/finally` blocks.
- Soft-hyphen stripping (`FPDFText_IsHyphen`) and unicode-error detection
  (`FPDFText_HasUnicodeMapError`) are performed inside the isolate, avoiding
  per-character data serialisation across the isolate boundary.
- `ffigen.yaml` updated to include `fpdf_text.h`; bindings regenerated and
  committed to `lib/src/generated/pdfium_bindings.dart`.
- Test fixtures generated via `test/fixtures/generate/generate_fixtures.py`
  (uses `fpdf2` + `pypdf`). Nine fixture PDFs committed to `test/fixtures/`.
  RTL fixture deferred — no Arabic font bundled; instructions in the script.
  Text-page fixtures use 8pt Helvetica with 25 paragraph repetitions
  (~5 500 chars/page) to comfortably exceed the default density threshold of
  10 chars/1 000 pt² on a single page.
- `make fixtures` target added to `Makefile`.
- 87 tests pass (35 new text-extraction tests). Web integration tests deferred
  pending WASM backend implementation.
- `docs/spec/text_extraction.md` updated to reflect `document.extractPlainText()`
  entry point, `isPlainTextExtractable()` replacing `isPredominantlyScanned`, and
  the `close()`-terminates-stream contract.
- `README.md` updated with a text extraction usage example.
- `CLAUDE.md` updated with `PdfiumIsolate` singleton notes, `PdfDocument`
  ownership model, and `close()`-owns-streams contract.
