# Table of Contents Extraction

**Status**: Complete

**PR link**: —

## Problem statement

PDFs use a bookmark/outline tree as their native Table of Contents (TOC)
structure. Callers need a way to retrieve this tree — entry titles, target page
indices, nesting depth, and optional scroll positions — for display in a
document navigator or for programmatic navigation. The library currently has no
TOC extraction capability. This plan adds a `tableOfContents` property on
`PdfDocument` that returns the full bookmark tree as a `Future<List<PdfTocEntry>>`.

This item corresponds to the **Table of contents extraction** entry in the
[v0.03.1 roadmap](../roadmap/0_03_1.md).

## Open questions

_None — investigation is complete._

## Investigation

### PDFium API

The bookmark tree is exposed through `fpdf_doc.h`, which is already included in
`ffigen.yaml` as a header entry-point. However, `FPDFBookmark_.*` is **not**
in the function include allow-list, so the functions are not currently bound.
The fix is a one-line addition to `ffigen.yaml`, followed by `make ffi_bindings`.

The relevant API chain:

| Function | Purpose |
|---|---|
| `FPDFBookmark_GetFirstChild(doc, NULL)` | Root-level entries (pass `NULL` bookmark for the document root) |
| `FPDFBookmark_GetFirstChild(doc, bookmark)` | First child of an existing entry |
| `FPDFBookmark_GetNextSibling(doc, bookmark)` | Next sibling entry |
| `FPDFBookmark_GetTitle(bookmark, buf, len)` | Entry label as UTF-16LE |
| `FPDFBookmark_GetCount(bookmark)` | Number of direct children (-1 = unknown) |
| `FPDFBookmark_GetAction(bookmark)` | Action handle (may be NULL) |
| `FPDFBookmark_GetDest(doc, bookmark)` | Destination handle (may be NULL) |
| `FPDFAction_GetType(action)` | One of `PDFACTION_GOTO`, `PDFACTION_URI`, etc. |
| `FPDFAction_GetDest(doc, action)` | Destination from a `PDFACTION_GOTO` action |
| `FPDFAction_GetURIPath(doc, action, buf, len)` | URI string from a `PDFACTION_URI` action |
| `FPDFDest_GetDestPageIndex(doc, dest)` | 0-based page index (-1 if invalid) |
| `FPDFDest_GetLocationInPage(dest, ...)` | Optional XYZ scroll position and zoom |

Action type constants defined in `fpdf_doc.h`:

| Constant | Value | Meaning |
|---|---|---|
| `PDFACTION_GOTO` | 1 | Navigate to a page within this document |
| `PDFACTION_REMOTEGOTO` | 2 | Navigate to a page in another document |
| `PDFACTION_URI` | 3 | Open a URI |
| `PDFACTION_LAUNCH` | 4 | Launch an application |
| `PDFACTION_EMBEDDEDGOTO` | 5 | Navigate inside an embedded document |
| `PDFACTION_UNSUPPORTED` | 0 | Anything else |

### Destination resolution

A bookmark's target is resolved as follows:

1. Try `FPDFBookmark_GetAction`. If non-null, inspect `FPDFAction_GetType`:
   - `PDFACTION_GOTO` → call `FPDFAction_GetDest` to get the dest, then
     `FPDFDest_GetDestPageIndex` for the page index.
   - `PDFACTION_URI` → call `FPDFAction_GetURIPath` for the URI string.
   - Anything else → record `pageIndex = null`, `uri = null`.
2. If action is null, try `FPDFBookmark_GetDest` directly and call
   `FPDFDest_GetDestPageIndex`.
3. If both are null the bookmark is a section label with no target.

`FPDFDest_GetLocationInPage` is called when a dest is available and its view
mode is `PDFDEST_VIEW_XYZ` (`= 1`), which carries an optional (x, y, zoom)
position. This is exposed as a nullable `PdfPoint? scrollPosition` field on
`PdfTocEntry` — callers can use it to scroll to the exact anchor, not just the
page.

### Tree walk

The tree walk is recursive. Passing `NULL` (pointer value `0`) as the bookmark
argument to `FPDFBookmark_GetFirstChild` retrieves the root level. The walk
builds a `List<PdfTocEntry>` per level; children are stored directly on each
entry. This produces a tree in a single pass without needing a depth counter.

Cycle protection: PDFium's internal implementation does not prevent malformed
PDFs from containing cycles, but in practice the tree is always a DAG. A
visited-handles `Set<int>` (using the raw pointer integer as identity) guards
against infinite loops.

### Architecture

This is a **document-level** (not per-page) operation that returns a complete
tree in one shot, so the API shape is a `Future`, not a `Stream`:

```dart
Future<List<PdfTocEntry>> get tableOfContents;
```

The isolate pattern used by metadata and annotations applies:

1. A new `PdfiumGetTocCommand` / `PdfiumGetTocResponse` pair is added to
   `lib/src/document/isolate_messages.dart`.
2. The isolate handler in `lib/src/document/_document_native.dart` gains a
   handler case that walks the bookmark tree and builds the response.
3. `PdfDocument.tableOfContents` in `lib/src/document/pdf_document.dart`
   sends the command and returns the result.
4. New types `PdfTocEntry` (and `PdfTocDestination`) are added to
   `lib/src/document/pdf_types.dart` and exported from `lib/pdfart_core.dart`.

This is a pure-Dart feature — no `dart:ui` dependency — so it belongs in
`pdfart_core.dart` per the architectural split in `CLAUDE.md`.

### New domain types

```dart
final class PdfTocEntry {
  final String title;
  final int? pageIndex;         // null if no internal-page destination
  final String? uri;            // non-null only for PDFACTION_URI entries
  final PdfPoint? scrollPosition; // XYZ dest scroll anchor, if present
  final List<PdfTocEntry> children;
}
```

`PdfPoint` already exists in `pdf_types.dart` and can be reused for the scroll
position.

### Edge cases and failure scenarios

- **No bookmarks** — `FPDFBookmark_GetFirstChild(doc, NULL)` returns null;
  return an empty list without error.
- **Section labels** — bookmarks with neither action nor dest; `pageIndex` and
  `uri` will both be `null`. This is valid and must be represented.
- **`FPDFBookmark_GetTitle` returns an empty buffer** — use an empty string; do
  not skip the entry.
- **`FPDFDest_GetDestPageIndex` returns -1** — treat as `pageIndex = null`.
- **Cycle detection** — track visited native handle integers in a `Set<int>`;
  stop recursing if a handle is seen twice. This handles malformed PDFs without
  crashing.
- **`FPDFBookmark_GetCount` returns -1** — this is documented as "unknown";
  do not use it to pre-size lists; rely on `GetFirstChild`/`GetNextSibling`.
- **Remote / embedded / launch actions** — `PDFACTION_REMOTEGOTO`,
  `PDFACTION_LAUNCH`, `PDFACTION_EMBEDDEDGOTO` are exposed with `pageIndex = null`
  and `uri = null`; the raw action type is not surfaced (keep the API surface
  minimal for now).
- **`FPDFDest_GetLocationInPage` failure** — if the call returns `FALSE`,
  set `scrollPosition = null`; do not fail the whole entry.

### Files affected

| File | Change |
|---|---|
| `ffigen.yaml` | Add `FPDFBookmark_.*` to functions include allow-list |
| `lib/src/generated/pdfium_bindings.dart` | Regenerate (committed artefact) |
| `lib/src/document/isolate_messages.dart` | Add `PdfiumGetTocCommand` / `PdfiumGetTocResponse` |
| `lib/src/document/_document_native.dart` | Add isolate handler case |
| `lib/src/document/_document_stub.dart` | Add stub implementation |
| `lib/src/document/_document_web.dart` | Add web stub (throws `UnsupportedError`) |
| `lib/src/document/pdf_document.dart` | Add `tableOfContents` getter |
| `lib/src/document/pdf_types.dart` | Add `PdfTocEntry` |
| `lib/pdfart_core.dart` | Export `PdfTocEntry` |
| `test/toc_extraction_test.dart` | New test file |
| `docs/spec/toc_extraction.md` | New spec file for `tableOfContents` and `PdfTocEntry` |
| `bin/pdfinfo.dart` | Add `--toc` flag |
| `test/pdfinfo_test.dart` | Add `--toc` CLI tests |
| `docs/roadmap/0_03_1.md` | Mark TOC item complete |

## Implementation plan

- [x] Add `FPDFBookmark_.*` to the `functions.include` list in `ffigen.yaml`
- [x] Regenerate `lib/src/generated/pdfium_bindings.dart` with `make ffi_bindings`
- [x] Add `PdfTocEntry` to `lib/src/document/pdf_types.dart` as a `final class` with:
  - [x] All fields declared `final`
  - [x] Doc comment on the class stating that zoom from `PDFDEST_VIEW_XYZ` is not surfaced, and explaining that this is intentional to avoid overriding user accessibility zoom settings (OS zoom, Flutter `textScaleFactor`, etc.)
  - [x] `==` and `hashCode` overrides using recursive deep-equality for `children` (consistent with other value types in the file)
  - [x] `toString()` override
- [x] Export `PdfTocEntry` from `lib/pdfart_core.dart`
- [x] Add `PdfiumGetTocCommand` and `PdfiumGetTocResponse` to `isolate_messages.dart`
- [x] Implement the isolate handler case in `_document_native.dart`:
  - [x] Recursive tree walk with cycle detection
  - [x] Title decoding (UTF-16LE → Dart `String`)
  - [x] Action / dest resolution per the rules above
  - [x] XYZ scroll-position extraction
- [x] Add stub methods in `_document_stub.dart` (throws `UnsupportedError`) and `_document_web.dart` (throws `UnsupportedError`, consistent with all other web stubs)
- [x] Add a note in `_document_native.dart`'s isolate handler confirming that the recursive `PdfTocEntry` tree is deep-copied across the isolate boundary by Dart's message-passing mechanism, and that this is acceptable for the bounded sizes of typical PDF bookmark trees
- [x] Add `tableOfContents` getter to `lib/src/document/pdf_document.dart`
- [x] Write `test/toc_extraction_test.dart` covering:
  - [x] Document with no bookmarks returns empty list
  - [x] Flat bookmark list (no children) returns correct titles and page indices
  - [x] Nested bookmarks produce correct `children` tree structure
  - [x] Deeply nested tree (3+ levels) verifies recursion does not flatten hierarchy or mis-assign children
  - [x] Section-label entry (no dest, no action) has `pageIndex == null` and `uri == null`
  - [x] URI action entry has non-null `uri` and null `pageIndex`
  - [x] `PDFACTION_REMOTEGOTO`, `PDFACTION_LAUNCH`, and `PDFACTION_EMBEDDEDGOTO` entries produce `pageIndex == null` and `uri == null`
  - [x] `FPDFDest_GetDestPageIndex` returning -1 maps to `pageIndex == null`
  - [x] Calling `tableOfContents` after `close()` throws `StateError` (consistent with all other post-close `PdfDocument` calls)
- [x] Write `docs/spec/toc_extraction.md` covering the `tableOfContents` property and `PdfTocEntry` type at the same depth as `text_extraction.md`
- [x] Add `--toc` flag to `bin/pdfinfo.dart`:
  - [x] Calls `tableOfContents` on the loaded `PdfDocument`
  - [x] Prints the bookmark tree to stdout, indented by depth (2 spaces per level)
  - [x] Handles the empty-list case gracefully (prints nothing or a "No bookmarks" message)
- [x] Write CLI tests in `test/pdfinfo_test.dart` (or equivalent) covering:
  - [x] `--toc` on a document with bookmarks prints the correctly indented tree
  - [x] `--toc` on a document with no bookmarks prints the appropriate output
- [x] Run all tests and confirm ≥ 90 % coverage
- [x] Update `docs/roadmap/0_03_1.md` to mark TOC item complete

## Questions

- [x] Should `PdfTocEntry` expose the zoom value from `PDFDEST_VIEW_XYZ` destinations?
  _Decision: Zoom is intentionally omitted. Surfacing zoom risks overriding user accessibility settings (OS zoom, Flutter `textScaleFactor`, etc.). The x/y scroll position is captured via `PdfPoint? scrollPosition` as already specified. A doc comment on `PdfTocEntry` must explain that zoom is not surfaced and why._
- [x] What should the `_document_web.dart` stub do for `tableOfContents`?
  _Decision: Throw `UnsupportedError`, consistent with all other web stubs in the codebase._
- [x] Is the `pdfinfo.dart --toc` CLI enhancement in scope for this plan?
  _Decision: In scope. A new phase of implementation tasks is added covering: a `--toc` flag on `bin/pdfinfo.dart` that calls `tableOfContents` and prints the tree indented by depth, plus a corresponding test in `test/pdfinfo_test.dart` (or equivalent CLI test file). `bin/pdfinfo.dart` and `test/pdfinfo_test.dart` are added to the files-affected table._

## Reviews

### Review 1: 2026-05-20

Verified all plan claims against the current codebase:

- `FPDFBookmark_.*` is absent from `ffigen.yaml`'s functions include allow-list — confirmed, one-line addition needed.
- `FPDFAction_.*` and `FPDFDest_.*` are **already** in the allow-list, so those bindings are already generated. Only the bookmark functions need adding.
- `fpdf_doc.h` exists in `third_party/pdfium/public/` with all required functions (`FPDFBookmark_GetFirstChild`, `GetNextSibling`, `GetTitle`, `GetCount`, `GetDest`, `GetAction`).
- `PdfiumGetTocCommand` / `PdfiumGetTocResponse` are absent from `isolate_messages.dart` — confirmed.
- No TOC handler case in `_document_native.dart` — confirmed.
- `_document_stub.dart` and `_document_web.dart` both exist with the expected pattern (UnsupportedError throws); neither has a `tableOfContents` stub — confirmed.
- `PdfTocEntry` is absent from `pdf_types.dart`; `PdfPoint` exists and can be reused — confirmed.
- `tableOfContents` getter is absent from `pdf_document.dart` — confirmed.
- `test/toc_extraction_test.dart` does not yet exist — confirmed.

No changes to the investigation or implementation plan are required. Plan is ready to implement.

### Review 2: 2026-05-20

_Reviewed: 2026-05-20_

**Problem Statement Assessment**

The problem is real and well-scoped. A bookmark/outline tree is a core navigational feature of PDFs, and the library has a clear gap. The roadmap entry at `docs/roadmap/0_03_1.md` explicitly names this work and links to this plan — alignment is confirmed. The API shape (`Future<List<PdfTocEntry>>` on `PdfDocument`) is consistent with the existing `getMetadata()` / `getDocumentInfo()` precedent for document-level, one-shot retrieval.

**Proposed Solution Assessment**

The investigation is thorough: the PDFium function chain is fully enumerated, the two-path destination resolution (action vs. direct dest) is documented precisely, and the cycle-detection mechanism is reasonable. The decision to walk the tree recursively inside the isolate and return the complete result in one `Future` — rather than streaming — is the right call: this is a small, bounded data structure, not a per-page pipeline.

The reuse of `PdfPoint` for `scrollPosition` is appropriate; its semantics (PDF user-space coordinates with a bottom-left origin) align with how `FPDFDest_GetLocationInPage` returns XYZ coordinates.

There are, however, several gaps that need resolving before the plan can be confidently handed to an implementer.

**Architecture Fit**

The plan correctly places the feature in `pdfart_core.dart` (pure Dart, no `dart:ui` dependency). The isolate message protocol extension follows the established pattern: command/response pair, token-based document reference, no direct FFI from the caller's isolate. No architectural concerns.

**Risk and Edge Cases — Gaps Found**

1. **`PdfTocEntry` lacks `==`, `hashCode`, and `toString()`.**
   Every other value type in `pdf_types.dart` — `PdfMetadata`, `PdfPageText`, `PdfRect`, `PdfPoint`, `PdfColor`, `PdfQuadPoints`, `PdfDate`, `PdfDocumentInfo` — implements all three. `PdfTocEntry` will contain a `List<PdfTocEntry> children`, so `==` requires a recursive deep-equality helper (like `_listEqual` already in the file). The plan does not mention this, and the implementation checklist has no task for it. This is a concrete bug waiting to happen: tests that construct expected `PdfTocEntry` trees and compare them with `==` will fail silently unless overrides are present.

2. **`PdfTocEntry` type declaration is not settled.**
   The plan shows `final class PdfTocEntry`. Every other value type in this file is also `final class`. That is consistent. However, the plan never calls out whether `PdfTocEntry` should be a `final class` or a `sealed class`. Given that `PdfAnnotation` is `sealed` (because it has meaningful subtypes), and `PdfTocEntry` does not, `final class` is the right choice — but the implementation task list should state it explicitly so the implementer does not introduce an inconsistency.

3. **`scrollPosition` carries only x/y; zoom is silently dropped.**
   `FPDFDest_GetLocationInPage` returns three values when the view mode is `PDFDEST_VIEW_XYZ`: x, y, and zoom. The plan captures x and y via `PdfPoint` but discards zoom. For a navigator use-case this is acceptable, but the plan does not acknowledge the omission. If a caller wanted to replicate the exact PDF viewer state (e.g. jump to a heading at a specific magnification), this information is lost. The plan should either add a `double? zoom` field to `PdfTocEntry` (preferred) or explicitly document in `PdfTocEntry`'s doc comment that zoom is not preserved.

4. **`_document_web.dart` stub handling is not specified.**
   The plan lists `_document_web.dart` as a file to update, but unlike `_document_stub.dart` (which always throws `UnsupportedError`), the web backend has a different shape — it may return an empty list rather than throw, depending on how other stubs are handled there. The plan should clarify: throw `UnsupportedError` or return `Future.value([])`.

5. **No spec update.**
   The `docs/spec/` directory has a spec file for every existing major public API surface (metadata, text extraction, annotations, rendering). This plan introduces a new public type (`PdfTocEntry`) and a new method (`tableOfContents`) but includes no task to add a corresponding `docs/spec/toc_extraction.md`. Per the project's spec coverage requirement, this must be added.

6. **`pdfinfo.dart` CLI enhancement is in the roadmap but not in the plan.**
   The roadmap item at `docs/roadmap/0_03_1.md` explicitly states: "bin/pdfinfo.dart will be enhanced with a `--toc` flag that adds TOC information to the result." This is absent from both the implementation plan's task list and the files-affected table. If this work is in scope for this plan (as the roadmap implies), it must be added. If it is deferred, the roadmap entry should be updated to reflect that.

7. **Test fixture coverage is incomplete.**
   The test list covers the main structural cases but is missing:
   - A deeply nested tree (3+ levels) to verify that recursion does not flatten the hierarchy or mis-assign children.
   - A test verifying that `tableOfContents` throws `StateError` (or similar) when called after `close()`, consistent with the behaviour of all other `PdfDocument` methods.
   - A test for `PDFACTION_REMOTEGOTO` / `PDFACTION_LAUNCH` / `PDFACTION_EMBEDDEDGOTO` entries to confirm they produce `pageIndex == null` and `uri == null` as specified.

8. **`PdfiumGetTocResponse` serialisation is not discussed.**
   `PdfTocEntry` is a tree (recursive `List<PdfTocEntry> children`). When the isolate sends this tree back to the main isolate via a `SendPort`, Dart's isolate message passing requires the value to be either a `SendPort`, a primitive, or a structure composed entirely of those. Dart does support passing arbitrary Dart objects across isolates (they are deep-copied), but this should be explicitly confirmed as safe for the nested list structure — particularly given that large TOCs in technical PDFs can be hundreds of nodes. The plan should note that the tree is deep-copied across the isolate boundary and confirm this is acceptable.

**Recommendations**

The plan is well-structured and the PDFium investigation is solid. Before it goes to implementation, the following items must be addressed:

- Add implementation tasks for `==`, `hashCode`, and `toString()` on `PdfTocEntry` (with recursive children equality).
- Decide and document whether zoom from `PDFDEST_VIEW_XYZ` is exposed or dropped; update the type definition accordingly.
- Clarify `_document_web.dart` stub behaviour.
- Add a `docs/spec/toc_extraction.md` task to the implementation checklist.
- Add the `pdfinfo.dart --toc` CLI task (or explicitly defer it and update the roadmap).
- Expand the test list to cover: 3-level nesting, `close()`-then-`tableOfContents` throws, and non-goto action types.
- Add a note confirming isolate message-passing of the recursive tree structure is acceptable.

Because these gaps are specific and bounded — none require rethinking the architecture — the status is moved to `Questions` pending the implementer's decisions on the zoom field, the web stub, and the CLI scope. Once those are settled the plan is ready to implement.

### Review 3: 2026-05-20

_Reviewed: 2026-05-20_

All three open questions from Review 2 have been resolved and recorded in the `## Questions` section above. The decisions are sound:

- **Zoom omission** is well-reasoned. Surfacing a zoom value from a PDF bookmark to a Flutter caller risks fighting the user's OS accessibility zoom or Flutter's `textScaleFactor`. Omitting it and documenting why in the `PdfTocEntry` doc comment is the right call. The doc comment task is now explicit in the implementation checklist.
- **`_document_web.dart` throws `UnsupportedError`** — consistent with every other web stub; no special-casing needed.
- **`pdfinfo --toc` is in scope** — the roadmap entry was clear, and it is now fully represented with implementation tasks and CLI tests.

All checklist items identified in Review 2 as missing are now present:

- `final class` declaration with explicit doc comment on zoom omission, `==`, `hashCode`, and `toString()` — added to the `PdfTocEntry` task.
- Isolate boundary deep-copy note — added as an explicit implementation task in `_document_native.dart`.
- `docs/spec/toc_extraction.md` — added as a task and to the files-affected table.
- Three additional test cases (3-level nesting, `close()`-then-`tableOfContents` throws, non-goto action types) — added to the test checklist.
- `bin/pdfinfo.dart` `--toc` flag and corresponding CLI tests — added as a dedicated phase with two implementation tasks and two test tasks.
- `bin/pdfinfo.dart` and `test/pdfinfo_test.dart` — added to the files-affected table.

The plan is complete and ready for implementation. Status set to `Investigated`.

## Summary

- Added `FPDFBookmark_.*` to `ffigen.yaml` and regenerated `pdfium_bindings.dart` to expose the full PDFium bookmark API.
- Implemented `PdfTocEntry` as a `final class` in `pdf_types.dart` with full value semantics (`==`, `hashCode`, `toString()`), recursive child equality, and a doc comment explaining why the `PDFDEST_VIEW_XYZ` zoom value is intentionally omitted.
- Added `PdfiumGetTocCommand` / `PdfiumGetTocResponse` to the isolate message protocol.
- Implemented `_handleGetToc` in `pdfium_isolate.dart`: recursive tree walk via `FPDFBookmark_GetFirstChild` / `GetNextSibling`, cycle detection via a `Set<int>` of visited handle addresses, UTF-16LE title decoding, two-path destination resolution (action → dest or direct dest), and XYZ scroll-position extraction.
- Added `tableOfContents` getter to `PdfDocumentImpl`, `PdfDocument`, `_document_stub.dart` (throws `UnsupportedError`), and `_document_web.dart` (throws `UnsupportedError`).
- Wrote `test/toc_extraction_test.dart` (20 tests: 13 unit tests for `PdfTocEntry` value semantics + 7 native integration tests).
- Added `--toc` flag to `bin/pdfinfo.dart` with indented plain-text and JSON output modes.
- Wrote `test/pdfinfo_test.dart` (9 CLI integration tests covering both output modes and edge cases).
- Generated four TOC fixture PDFs (`no_toc.pdf`, `flat_toc.pdf`, `nested_toc.pdf`, `deep_toc.pdf`) via an inline Python script.
- Wrote `docs/spec/toc_extraction.md` at the same depth as other spec files.
- Updated `docs/roadmap/0_03_1.md` to mark the TOC item complete.
- All 278 tests pass; zero analyzer warnings or errors.
