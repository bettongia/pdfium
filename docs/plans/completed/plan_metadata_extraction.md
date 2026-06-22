# PDF Metadata Extraction (Info Dictionary)

**Status**: Complete

**PR link**: —

## Problem statement

Introduce `PdfDocument` as the top-level Dart abstraction for a loaded PDF file,
and implement Info dictionary metadata extraction as its first capability.

`PdfDocument` mirrors the PDFium model: `FPDF_LoadMemDocument64()` returns a
single document handle used for all subsequent operations (text, annotations,
rendering, metadata). `PdfDocument` is the Dart owner of that handle and exposes
all document-level capabilities as methods and properties. This plan establishes
the class and its metadata surface; future plans add text extraction, annotation
access, and rendering on top of the same foundation.

**Impact on `plan_text_extraction.md`:** the existing `PdfTextExtractor` class
must be refactored to sit inside `PdfDocument` (e.g. `document.extractText()`).
That refactor is in scope for this plan.

PDFium provides `FPDF_GetMetaText()` to read Info dictionary fields, but it is a
raw FFI call returning a UTF-16LE buffer. This plan wraps it behind
`PdfDocument.getMetadata()`, which returns a `PdfMetadata` value object.

XMP metadata is explicitly out of scope; it is deferred to
[`plan_xmp_metadata_extraction.md`](plan_xmp_metadata_extraction.md) (v0.05). This
plan provides the Info-dictionary half of the dual-source strategy: when XMP is
not present, the Info dictionary is the fallback. `PdfDocument`'s API shape must
keep that future integration in mind.

`PdfDocument` must work on all supported platforms — iOS, Android, macOS,
Windows, Linux, and web. The public API (`fromBytes()`, `getMetadata()`,
`getDocumentInfo()`, `close()`) is identical on all platforms; only the backend
differs. On native platforms the backend uses `dart:ffi` + `PdfiumIsolate`; on
web it uses PDFium compiled to WASM, called via `dart:js_interop`. A conditional
import structure (stub / native / web) keeps the platform split internal and
invisible to callers.

**Platform matrix:**

| Platform | Library form          | Backend                  |
| -------- | --------------------- | ------------------------ |
| iOS      | `.xcframework` (arm64)| `_document_native.dart`  |
| Android  | `.so` (arm64/x86\_64) | `_document_native.dart`  |
| macOS    | `.dylib`              | `_document_native.dart`  |
| Windows  | `.dll`                | `_document_native.dart`  |
| Linux    | `.so`                 | `_document_native.dart`  |
| Web      | WASM                  | `_document_web.dart`     |

All native platforms share `_document_native.dart` and `PdfiumIsolate`; only
the binary format differs. The binary build and distribution for each platform
is handled by `plan_pdfium_build_infrastructure.md`.

**Prerequisite:** Native platform binaries and `lib/src/generated/pdfium_bindings.dart`
must be available (from `plan_pdfium_build_infrastructure.md`). The PDFium WASM
build must be complete before Phase 4 (web implementation) can proceed.

## Open questions

- [x] **API shape**: Should metadata be exposed as a `PdfMetadata` value object
      returned by a single call (e.g. `extractor.getMetadata()`), or should
      fields be read individually on demand?
      **Decision: single `PdfMetadata` value object with `final` fields.**
- [x] **Missing fields**: `FPDF_GetMetaText()` returns an empty string for
      fields not present in the Info dictionary. Should the Dart API represent
      missing fields as `null` or as an empty `String`?
      **Decision: `null` for missing fields** — distinguishes "not present" from
      "present but empty", and is idiomatic Dart.
- [x] **Date parsing**: `CreationDate` and `ModDate` use PDF date format
      (`D:YYYYMMDDHHmmSSOHH'mm'`). Should the API return raw strings or parsed
      `DateTime` objects?
      **Decision: `PdfDate` wrapper** — holds both `raw` (`String`) and `value`
      (`DateTime?`), giving callers access to the parsed date while preserving
      the original string when parsing fails or precision is needed.
- [x] **`FPDF_GetFileIdentifier()`**: Should file identifiers (permanent and
      changing) be included in `PdfMetadata`, or are they a separate concern?
      **Decision: `getDocumentInfo()` → `PdfDocumentInfo`** — a single batched
      call returning `fileVersion` (`int?`), `permanentId` (`Uint8List?`), and
      `changingId` (`Uint8List?`). File identifiers and version are
      document-level properties, not content metadata. Identifiers are raw bytes
      (typically MD5 hashes); callers hex-encode as needed. Batching is
      consistent with `getMetadata()` and avoids multiple isolate round-trips.
- [x] **`FPDF_GetDocPermissions()`**: Permissions flags are numeric bitmasks.
      Should they be exposed as a raw `int`, parsed into a `PdfPermissions`
      flags object, or omitted from this plan's scope?
      **Decision: out of scope.** Passwords, encryption, and edit permissions are
      not supported in this first body of work. Deferred to a future plan.
- [x] **Thread safety**: All PDFium calls must run on the dedicated PDFium
      `Isolate`. Should this plan introduce the Isolate architecture, or assume
      it will be added later?
      **Decision: introduce the Isolate architecture in this plan.** `PdfDocument`
      is the right place to establish it — it owns the document handle, and
      building it in now means all subsequent plans (text extraction, annotations,
      Flutter rendering in v0.03) inherit a correct foundation rather than
      retrofitting async message-passing later. All `PdfDocument` public methods
      are `Future`-returning; callers never interact with the PDFium isolate
      directly.

## Investigation

### PDFium API surface

The relevant header is `third_party/pdfium/public/fpdf_doc.h`. The key function
is:

```c
FPDF_EXPORT unsigned long FPDF_CALLCONV FPDF_GetMetaText(
    FPDF_DOCUMENT document,
    FPDF_BYTESTRING tag,
    void* buffer,
    unsigned long buflen);
```

`tag` is a null-terminated ASCII string naming the field. Standard tags:

| Tag            | Meaning                               |
| -------------- | ------------------------------------- |
| `Title`        | Document title                        |
| `Author`       | Author name(s)                        |
| `Subject`      | Subject or description                |
| `Keywords`     | Comma-separated keywords              |
| `Creator`      | Application that created the original |
| `Producer`     | Application that converted to PDF     |
| `CreationDate` | Date document was created             |
| `ModDate`      | Date document was last modified       |

The function uses a two-call pattern: call once with `buffer=null` / `buflen=0`
to get the required buffer size, allocate, then call again to fill. The returned
buffer is UTF-16LE; it must be decoded to a Dart `String` using
`String.fromCharCodes()` on the 16-bit code units.

Additional functions also in `fpdf_doc.h`:

```c
FPDF_EXPORT int FPDF_CALLCONV FPDF_GetFileVersion(
    FPDF_DOCUMENT doc, int* fileVersion);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV FPDF_GetFileIdentifier(
    FPDF_DOCUMENT document,
    FPDF_FILEIDTYPE type,    // FILEIDTYPE_PERMANENT or FILEIDTYPE_CHANGING
    void* buffer,
    unsigned long buflen);

FPDF_EXPORT unsigned long FPDF_CALLCONV FPDF_GetDocPermissions(
    FPDF_DOCUMENT document);
```

`fpdf_doc.h` is not currently in scope for the FFI bindings (`ffigen.yaml` only
covers `fpdfview.h`). This plan must extend `ffigen.yaml` to include
`fpdf_doc.h` and regenerate the bindings.

### PDF date format

PDF dates have the form `D:YYYYMMDDHHmmSSOHH'mm'` where `O` is `+`, `-`, or `Z`
for the UTC offset. The `D:` prefix is optional in practice. A parser must
handle:

- Missing `D:` prefix
- Truncation (some tools emit only `D:YYYYMMDD`)
- `Z` for UTC vs. signed offsets

Dart's `DateTime.parse()` does not handle this format; a hand-rolled parser is
required. The parser is a good candidate for standalone unit testing with a
table of known edge-case inputs.

### Platform structure and conditional imports

`PdfDocument`'s public API is platform-agnostic; the platform split is hidden
behind a conditional import boundary. The file structure mirrors the pattern
established in `plan_text_extraction.md`:

```
lib/src/document/
  pdf_document.dart          ← public interface + fromBytes() factory w/ conditional import
  _document_stub.dart        ← throws UnsupportedError (fallback)
  _document_native.dart      ← dart:ffi + PdfiumIsolate implementation
  _document_web.dart         ← dart:js_interop / WASM implementation
```

`pdf_document.dart` selects the backend:

```dart
import '_document_stub.dart'
    if (dart.library.ffi) '_document_native.dart'
    if (dart.library.js_interop) '_document_web.dart';
```

On native platforms (`dart.library.ffi`), `_document_native.dart` owns
`PdfiumIsolate` and routes all PDFium calls through it. On web
(`dart.library.js_interop`), `_document_web.dart` loads the PDFium WASM module
once (lazy singleton analogous to `PdfiumIsolate`) and calls it synchronously
via `dart:js_interop`. The WASM module runs on the main thread in v1; a Web
Worker is deferred to a future plan when per-character operations (e.g. text
extraction) make it necessary.

Supporting types (`PdfDate`, `PdfMetadata`, `PdfDocumentInfo`, `PdfDateParser`,
`PdfError`, `PdfExtractionException`) are pure Dart with no platform
dependencies and live in a shared internal file included by both backends.

### FFI bindings scope extension

`ffigen.yaml` will need `fpdf_doc.h` added to its `headers.entry-points`. After
regeneration, the new symbols appear in
`lib/src/generated/pdfium_bindings.dart`. Regeneration is done via
`make ffi_bindings`.

### Edge cases

| Case                              | Behaviour                                                                                    |
| --------------------------------- | -------------------------------------------------------------------------------------------- |
| Field not in Info dictionary      | `FPDF_GetMetaText()` returns a single null char (buffer size 2, i.e. empty UTF-16LE string) |
| PDF has no Info dictionary        | Same as above — function returns empty for all fields                                        |
| Malformed date string             | Parser returns `null` for the `DateTime?`; raw string is preserved                           |
| Non-UTF-16LE encoding in old PDFs | Rare; treat as best-effort decode                                                            |
| Password-protected PDF            | `FPDF_LoadMemDocument64()` returns `NULL`; `FPDF_GetLastError()` returns `FPDF_ERR_PASSWORD` (4); surface as `PdfError.passwordRequired` — distinct from `invalidDocument` so callers can tell the user why the file failed to open |

## Implementation plan

### Phase 1 — FFI bindings extension

- [x] Add `fpdf_doc.h` to `ffigen.yaml` entry-points.
- [x] Run `make ffi_bindings` and commit the updated
      `lib/src/generated/pdfium_bindings.dart`.

### Phase 2 — PDFium Isolate architecture (native only)

> **Scope:** `PdfiumIsolate` is a native-platform concern. Web uses the WASM
> module directly on the main thread (see Phase 4). This phase produces code
> that lives exclusively in `_document_native.dart` and its internal helpers.

- [x] Implement `PdfiumIsolate` as a **process-wide singleton** internal class:
  - A single instance is shared across all `PdfDocument` instances and all
    future plans (text extraction, annotations, rendering). This mirrors the
    PDFium model: `FPDF_InitLibraryWithConfig()` is a one-time process-wide
    call; spawning a second isolate would call it again, which is a correctness
    bug. Low expected call volume makes a serial queue on one isolate safe.
  - Lazily spawned on first use (i.e. the first `PdfDocument.fromBytes()` call)
    and held for the lifetime of the process. It is not torn down when
    documents are closed — tearing down and re-spawning the isolate on every
    open/close cycle is unnecessary complexity given the singleton decision.
  - Exposes a `static PdfiumIsolate get instance` accessor; construction is
    private. A `static Future<PdfiumIsolate> ensureInitialised()` helper
    handles the async spawn-once pattern safely under concurrent callers.
  - Defines a typed message protocol (sealed classes) for all PDFium operations
    in this plan: load document, get metadata, get document info, close
    document. Future plans extend this protocol; the sealed class hierarchy
    lives in a shared internal file so both plans can add variants without
    coupling their public APIs.
  - Routes each operation to the appropriate PDFium FFI call inside the isolate
    and returns the result via a `ReceivePort` completer.
  - Ensures all PDFium FFI calls are made exclusively within this isolate —
    never on the calling isolate.

### Phase 3 — Shared types and conditional import structure

- [x] Define shared internal types (no platform dependencies; used by both
      native and web backends):
  - `PdfDate` — holds `raw` (`String`) and `value` (`DateTime?`).
  - `PdfMetadata` — immutable value object with nullable `final` fields for all
    eight Info dictionary tags (`title`, `author`, `subject`, `keywords`,
    `creator`, `producer`, `creationDate` as `PdfDate?`, `modDate` as
    `PdfDate?`).
  - `PdfDocumentInfo` — immutable value object: `fileVersion` (`int?`),
    `permanentId` (`Uint8List?`), `changingId` (`Uint8List?`). File identifiers
    are raw bytes (typically an MD5 hash); callers needing a hex string can
    encode them with `hex.encode()`.
  - `PdfError` enum — `invalidDocument`, `passwordRequired`.
  - `PdfExtractionException` — holds a `PdfError`.
- [x] Implement `PdfDateParser` — handles `D:YYYYMMDDHHmmSSOHH'mm'` including
      truncated and prefix-omitted variants.
- [x] Create the conditional import scaffold:
  - `lib/src/document/pdf_document.dart` — public `PdfDocument` interface +
    `fromBytes()` factory using conditional imports.
  - `lib/src/document/_document_stub.dart` — throws `UnsupportedError`.
  - `lib/src/document/_document_native.dart` — full native implementation.
  - `lib/src/document/_document_web.dart` — stub (WASM binary not yet ready).
- [x] Implement the native backend in `_document_native.dart`:
  - `fromBytes()` — calls `PdfiumIsolate.ensureInitialised()`, then sends
    bytes to the isolate, which calls `FPDF_LoadMemDocument64()` and returns
    a document handle token.
  - `getMetadata()` — sends a message to the isolate; isolate calls
    `FPDF_GetMetaText()` for each tag using the two-call buffer pattern,
    decodes UTF-16LE, returns `PdfMetadata`.
  - `getDocumentInfo()` — sends a single message; isolate calls
    `FPDF_GetFileVersion()` and `FPDF_GetFileIdentifier()` (both id types) in
    one round-trip, returns `PdfDocumentInfo`.
  - `close()` — sends close message to isolate; isolate calls
    `FPDF_CloseDocument()`. Register `Finalizer` at construction as a safety
    net; detach inside `close()` to prevent double-free.
- [x] Ensure `PdfDocument`'s public API does not preclude future text
      extraction integration (e.g. `document.openTextExtractor()` must be a
      valid addition without breaking changes). This plan does **not** touch
      `PdfTextExtractor`; that refactor is in scope for the revised
      `plan_text_extraction.md`, which will route through `PdfDocument` and
      the shared `PdfiumIsolate` introduced here.
- [x] Add `PdfDocument`, `PdfMetadata`, `PdfDocumentInfo`, `PdfDate`,
      `PdfError`, and `PdfExtractionException` to the public library entry
      point (`lib/pdfart.dart`).
- [x] Add doc comments to all public classes, methods, and properties.
- [x] Add the license header to all new source files.

### Phase 4 — Web implementation

> **Prerequisite:** PDFium WASM binary must be built and available
> (`plan_pdfium_build_infrastructure.md`). This phase can be deferred until
> that binary is ready; the native backend from Phase 3 is fully functional
> on its own in the interim.

- [x] `_document_web.dart` stub implemented — throws `UnsupportedError` with
      an actionable message until the WASM binary is available.
- [ ] Load the PDFium WASM module via `fetch()` +
      `WebAssembly.instantiate()` in a lazy singleton — analogous to
      `PdfiumIsolate` on native. Initialise once on the first
      `PdfDocument.fromBytes()` call; hold for the lifetime of the page.
- [ ] Implement full `_document_web.dart` using `dart:js_interop` once WASM
      binary is available.
- [ ] Document the main-thread limitation in the public API: WASM runs
      synchronously on the main thread in v1; callers processing large
      documents on web should be aware that `getMetadata()` may block
      briefly for very large PDFs. A Web Worker path is deferred.

### Phase 5 — `pdfinfo` CLI tool

A developer CLI at `bin/pdfinfo.dart` that accepts a PDF file path and prints
all metadata and document-level properties. Useful for manual testing against
real-world PDF files throughout development.

- [x] Create `bin/pdfinfo.dart`:
  - Accepts a single positional argument: the path to a PDF file.
  - Reads the file using `dart:io` and passes the bytes to
    `PdfDocument.fromBytes()`.
  - Calls `getDocumentInfo()` and `getMetadata()` and prints all fields in a
    readable key/value format. File identifiers are printed as hex strings.
  - For date fields, prints both the parsed value and the raw string (so
    malformed dates from real PDFs are visible).
  - Handles errors clearly: file not found, `PdfError.passwordRequired`,
    `PdfError.invalidDocument`, and unexpected exceptions each produce a
    distinct, actionable message.
  - Exits with code 0 on success, non-zero on error.
- [x] Add the license header to `bin/pdfinfo.dart`.
- [x] Document usage in `README.md` (`dart run bin/pdfinfo.dart <path>`).

### Phase 6 — Tests

Fixtures are shared with `plan_text_extraction.md`. The fixture generation
script (`test/fixtures/generate/generate_fixtures.py`) and the committed PDFs
in `test/fixtures/` cover password-protected, corrupt, and populated-metadata
files. Add any metadata-specific fixtures not already present.

- [x] Unit tests for `PdfDateParser` covering:
  - Full format with `+` offset
  - Full format with `-` offset
  - Full format with `Z` (UTC)
  - `D:` prefix omitted
  - Date only (no time component)
  - Empty string → `null`
  - Malformed strings → `null` with raw string preserved
- [x] Integration tests (native) for `PdfDocument` against real PDF fixtures:
  - A PDF with a populated Info dictionary — verify all eight fields on
    `PdfMetadata` and all fields on `PdfDocumentInfo`.
  - A PDF with a partially populated Info dictionary — missing fields are `null`.
  - A PDF with no Info dictionary at all — all fields are `null`.
  - A password-protected PDF — `PdfDocument.fromBytes()` throws
    `PdfExtractionException(PdfError.passwordRequired)`, not `invalidDocument`.
  - Verify `PdfDocument` closes the underlying handle when `close()` is called
    (no double-free; subsequent calls throw).
- [ ] Integration tests (web) — same fixture set, using the WASM backend:
  - A PDF with a populated Info dictionary — all `PdfMetadata` and
    `PdfDocumentInfo` fields match the native results for the same file.
  - A password-protected PDF — `PdfExtractionException(PdfError.passwordRequired)`.
  - A PDF with no Info dictionary — all fields `null`.
- [ ] Confirm test coverage remains at or above 90%.

### Phase 7 — Documentation

- [x] Update `docs/spec/` with a metadata extraction specification section
      (`docs/spec/metadata_extraction.md`).
- [x] `docs/spec/text_extraction.md` already uses `passwordRequired` correctly
      — no change needed.
- [x] Update `README.md` to mention metadata extraction and the `pdfinfo` CLI.
- [x] Update the v0.01 roadmap entry to mark this item ✅ Complete.
- [x] Move this plan to `docs/plans/completed/` and update status to Complete.

## Reviews

### Review 1: 2026-05-18

_Reviewed: 2026-05-18_

**Problem Statement Assessment**

The problem is real and the scoping is appropriate. Info dictionary metadata extraction is the most universally supported metadata path in PDFs, and establishing `PdfDocument` as the top-level Dart abstraction is the correct foundational decision — PDFium's model is one document handle per open file, so the Dart side should mirror this exactly. The XMP deferral is sensible; it requires bespoke byte-level parsing and is rightfully its own plan. The prerequisite chain (build infra → FFI bindings → metadata) is accurately stated.

**Proposed Solution Assessment**

Strengths:

- `PdfMetadata` as an immutable value object with nullable `final` fields is idiomatic Dart and models the PDF spec correctly (field presence vs. field value are distinct states).
- `PdfDate` preserving both the raw string and a parsed `DateTime?` is the right trade-off — caller gets the parsed value, but malformed dates from real-world PDFs are not silently discarded.
- Placing the persistent `PdfiumIsolate` here rather than deferring it is the right call. The text extraction plan (`plan_text_extraction.md`) already demands this architecture, and retrofitting isolate message-passing into `PdfTextExtractor` after the fact would be costly. Building it once in `PdfDocument` gives all subsequent plans a correct, shared foundation.
- The two-call buffer pattern for `FPDF_GetMetaText()` is correctly identified and documented.
- The `pdfinfo` CLI in Phase 4 is a concrete, low-cost testing tool against real-world PDFs that is genuinely useful throughout development.

Concerns — these are not blockers but must be addressed before or during implementation:

1. **`PdfTextExtractor` refactor is vague and under-scoped.** The plan says "refactor `PdfTextExtractor` to be accessible via `PdfDocument`" with "exact surface TBD". But `plan_text_extraction.md` defines a detailed, settled API (`openPdfTextExtractor()`, `PdfTextExtractor` interface, `PdfTextExtractorFactory` typedef). There is a real tension here: `plan_text_extraction.md`'s entry point is a standalone top-level function — it does not assume `PdfDocument` exists. If this plan refactors `PdfTextExtractor` into `PdfDocument`, it potentially conflicts with or partially implements `plan_text_extraction.md`, which is also status `Investigated`. The implementer needs a clear instruction: is this plan allowed to touch `PdfTextExtractor` at all, or should it only ensure the `PdfDocument` API shape does not preclude future integration? As written the "exact surface TBD" deferral will cause confusion when both plans are in flight.

2. **Isolate architecture is shared state with `plan_text_extraction.md`.** Both plans independently describe a persistent PDFium `Isolate`. When both are implemented they must use the same isolate (PDFium is process-wide; you cannot run two `FPDF_InitLibraryWithConfig()` instances). This plan owns the isolate and `plan_text_extraction.md` must consume it — but `plan_text_extraction.md` was written as if it owns the isolate itself. The implementation plan for text extraction will need to be updated to route through `PdfiumIsolate` rather than spawning its own. This is not a problem for this plan, but it is a coordination risk worth flagging.

3. **`fileVersion`, `permanentId`, `changingId` as `Future`-returning properties are unusual.** Dart convention uses `get` for synchronous access and methods for async work. Making `permanentId` a property that returns a `Future<String?>` will feel wrong to callers — it looks like synchronous access but is not. Either use methods (`getPermanentId()`, `getFileVersion()`) for consistency with `getMetadata()`, or batch them into a `PdfDocumentInfo` object returned by a single method call (similar to how `PdfMetadata` batches the Info dictionary). Having both `getMetadata()` as a method and `permanentId` as a getter-shaped `Future` is inconsistent.

4. **Password-protected PDFs: the spec in `docs/spec/text_extraction.md` says `PdfError.invalidDocument` for password-protected files.** The metadata extraction plan correctly proposes `PdfError.passwordRequired`. This is a spec inconsistency — the text extraction spec was written first and classified password-protected files as `invalidDocument`. Both plans now use `passwordRequired` (this plan explicitly, text extraction plan also in its implementation plan though it contradicts the spec file). The spec file `docs/spec/text_extraction.md` needs to be updated in Phase 6 of this plan, or the inconsistency will confuse future implementers.

5. **No test fixtures strategy.** Phase 5 lists what tests are needed but says nothing about where the PDF fixtures come from. `plan_text_extraction.md` has an entire Phase 4 dedicated to fixture generation (Python `fpdf2`, `make fixtures`, etc.). This plan should either reference those same fixtures (if they are shared) or define its own generation strategy. Without fixtures, the integration tests listed in Phase 5 cannot run.

6. **`PdfiumIsolate` teardown condition is underspecified.** The plan says "confirm the isolate is torn down cleanly when no documents remain open." This raises questions: is the isolate shared across multiple `PdfDocument` instances? Is it a singleton? If document A and B are both open and A closes, does the isolate stay up? Shared singleton (torn down when the last document closes) is the correct model — but the plan does not state this explicitly, which will lead to implementation ambiguity.

7. **`FPDF_GetFileIdentifier()` decoding is not addressed.** The investigation covers `FPDF_GetMetaText()` buffer decoding (UTF-16LE) but does not address how file identifier bytes (which are raw binary, not UTF-16LE strings) should be represented in Dart. These are typically 16-byte MD5 hashes. Returning them as `String?` will likely require hex encoding; returning `Uint8List?` is more correct. The plan should specify this.

**Architecture Fit**

The plan fits the architecture well. `PdfDocument` mirrors PDFium's own document-handle model, the `Isolate` approach matches the thread-safety constraints documented in `CLAUDE.md`, and `FPDF_LoadMemDocument64()` accepting a `Uint8List` keeps the API platform-agnostic. The `Finalizer`-as-safety-net pattern (with `close()` as the primary mechanism) is consistent with the pattern established in `plan_text_extraction.md`.

The conditional import question (web vs native) that looms large in `plan_text_extraction.md` is not addressed here. For metadata extraction specifically, on web PDFium will be compiled to WASM — does `PdfDocument.fromBytes()` need platform-conditional imports? The plan is silent on web support. If metadata extraction must also work on web, the isolate model does not apply and a WASM path is required. If metadata extraction is native-only for now, say so.

**Risk & Edge Cases**

The edge case table is good. Two gaps:

- What happens if `close()` is called while `getMetadata()` is in progress? The plan specifies no ordering or cancellation semantics.
- What happens if `PdfDocument.fromBytes()` is called concurrently with multiple `Uint8List` values before any has resolved? The single-isolate model must serialise these, but the plan does not document this behaviour.

**Recommendations**

1. Resolve the `PdfTextExtractor` refactor scope: state explicitly that this plan only ensures `PdfDocument`'s API does not preclude text extraction integration — implementation of that integration is in `plan_text_extraction.md`. Remove the vague "exact surface TBD" clause.
2. Specify that `PdfiumIsolate` is a process-wide singleton (or at minimum document-lifetime-shared) and document the teardown rule explicitly.
3. Replace `Future`-returning properties (`fileVersion`, `permanentId`, `changingId`) with either methods or a single batched call — the current shape violates Dart property conventions.
4. Specify how file identifiers are encoded in the Dart API (`Uint8List?` vs hex `String?`).
5. Add a fixture strategy to Phase 5 (reference `plan_text_extraction.md`'s `test/fixtures/` approach or state which fixtures are shared).
6. Address web platform scope explicitly — either commit to a web path or explicitly mark this plan as native-only for v1.
7. Update `docs/spec/text_extraction.md` in Phase 6 to align `passwordRequired` vs `invalidDocument` for password-protected documents.

None of these concerns block the plan from being implementable — the core approach is sound. Items 1–3 are the most important to resolve to avoid implementation confusion.

## Summary

- Introduced `PdfDocument` as the top-level Dart abstraction for a loaded PDF
  file. The public API (`fromBytes()`, `getMetadata()`, `getDocumentInfo()`,
  `close()`) is identical on all platforms; only the backend differs.

- Implemented `PdfiumIsolate` as a process-wide singleton that owns the single
  dedicated PDFium isolate. All PDFium FFI calls run on this isolate — never
  on the calling isolate — satisfying the thread-safety constraint. The isolate
  is lazily spawned and held for the process lifetime.

- Extended `ffigen.yaml` to include `fpdf_doc.h` and regenerated
  `lib/src/generated/pdfium_bindings.dart` with `FPDF_GetMetaText`,
  `FPDF_GetFileVersion`, `FPDF_GetFileIdentifier`, and `FPDF_GetDocPermissions`.

- Implemented shared types (`PdfMetadata`, `PdfDate`, `PdfDocumentInfo`,
  `PdfError`, `PdfExtractionException`) in `lib/src/document/pdf_types.dart`
  with no platform dependencies.

- Implemented `PdfDateParser` with a hand-rolled parser for the PDF date format
  `D:YYYYMMDDHHmmSSOHH'mm'` including truncated and prefix-omitted variants.
  The parser always constructs UTC `DateTime` values and preserves the raw
  string when parsing fails.

- Created the conditional import structure (`pdf_document.dart`,
  `_document_native.dart`, `_document_stub.dart`, `_document_web.dart`).
  The native backend is fully implemented; the web backend is a stub pending
  the PDFium WASM binary from `plan_pdfium_build_infrastructure.md`.

- Added a `Finalizer` to `PdfDocumentImpl` as a safety net against forgotten
  `close()` calls, with proper detach inside `close()` to prevent double-free.

- Created `bin/pdfinfo.dart` — a developer CLI for inspecting real-world PDF
  files. Shows all metadata fields and document properties; prints both parsed
  and raw date strings; exits with distinct codes for each error type.

- Generated PDF test fixtures using `fpdf2` and `pypdf` (Python) and committed
  them to `test/fixtures/`. The fixture generation script is at
  `test/fixtures/generate/generate_fixtures.py`.

- Wrote 57 tests across three test files: `pdf_date_parser_test.dart`
  (25 unit tests for the date parser including all edge cases),
  `pdf_document_test.dart` (29 integration tests against real fixtures, plus
  value-object tests), and the existing `pdfium_smoke_test.dart` (3 tests).
  All tests pass. Coverage of hand-written library code is 91.6%
  (auto-generated `pdfium_bindings.dart` excluded).

- Resolved a cross-test interference bug: the smoke test's
  `FPDF_DestroyLibrary()` call and `PdfiumIsolate`'s `FPDF_InitLibraryWithConfig()`
  share a process-wide PDFium refcount. Fixed by removing `DestroyLibrary` from
  the smoke test (accepting a one-time refcount leak at process exit) and adding
  `PdfiumIsolate.resetForTesting()` for test isolation.

- Resolved a test parallelism bug: `setUp`/`tearDown` with a shared mutable
  `doc` variable caused race conditions when Flutter test ran async tests in
  parallel. Fixed by switching to `setUpAll`/`tearDownAll` with a shared
  `PdfMetadata` / `PdfDocumentInfo` result object.

- Key deviation from the plan: the isolate bootstrap protocol was redesigned
  so the spawned isolate sends its command `SendPort` immediately on startup
  (before the `PdfiumInitCommand`), allowing the main isolate to send commands
  without a separate bootstrap port. This simplifies the message flow.

- `docs/spec/metadata_extraction.md` added. Roadmap `0_01.md` updated to mark
  the metadata extraction milestone complete.
