# Annotation creation, editing, and deletion (highlight & sticky note)

**Status**: Investigated

**PR link**: _not yet submitted_

## Problem statement

The library can already extract and display annotations, and the Quietly example
app renders them in the sidebar. However, nothing is writable: users cannot
create new highlights, add sticky notes, edit an existing note's content, or
delete any annotation. There is also a visible gap in the example app: sticky
notes' written content is never surfaced interactively (the sidebar cards show a
dash when `contents` is empty, and tapping a card does nothing).

This plan covers all the work required to close that gap for the two annotation
types in scope for v0.04:

* **Highlight** — `PdfMarkupAnnotation` with `subtype == PdfAnnotationType.highlight`
* **Sticky note** — `PdfTextAnnotation`

Deliverables:

1. Pure-Dart core: `PdfDocument` gains mutation methods and a save-to-bytes API.
2. Flutter widget library: interactive annotation creation, viewing, editing, and
   deletion integrated into the page view and the annotation list panel.
3. Example app (Quietly): all four interactions wired up with file persistence.

## Open questions

_All resolved during investigation — see Investigation section._

## Investigation

### What already exists

**FFI bindings (`lib/src/generated/pdfium_bindings.dart`):**

The following PDFium write-path functions are already bound and ready to use:

| PDFium function | Purpose |
|---|---|
| `FPDFPage_CreateAnnot` | Create a new annotation of a given subtype |
| `FPDFPage_RemoveAnnot` | Delete annotation at a given index |
| `FPDFAnnot_SetColor` | Set annotation colour |
| `FPDFAnnot_SetRect` | Set bounding rectangle |
| `FPDFAnnot_SetStringValue` | Write string keys (`Contents`, `T`, `M`, …) |
| `FPDFAnnot_SetFlags` | Set flag bitmask |
| `FPDFAnnot_AppendAttachmentPoints` | Append quad-point sets for highlights |
| `FPDFPage_GenerateContent` | Flush page changes to the document structure |
| `FPDFText_GetCharIndexAtPos` | Hit-test a PDF point → character index |
| `FPDFText_CountRects` / `FPDFText_GetRect` | Get bounding boxes for a char range |
| `FPDFText_GetCharBox` | Bounding box for a single character |

**Not yet bound:** `FPDF_SaveAsCopy`, `FPDF_SaveWithVersion`, and the
`FPDF_FILEWRITE` struct from `fpdf_save.h`. These are required to serialise a
mutated document back to bytes. The header exists at
`third_party/pdfium/public/fpdf_save.h` but has not been added to the ffigen
config.

**Type layer (`lib/src/document/pdf_types.dart`):**

All annotation model classes exist, but `PdfAnnotation` (the sealed base) has
no `annotationIndex` field. Mutation and deletion require a stable per-page
index that matches `FPDFPage_GetAnnot(page, index)`. This field must be added.

**Isolate protocol (`lib/src/document/isolate_messages.dart`):**

Read commands exist for annotation extraction; no write commands exist. New
commands and response types are needed for create, update, delete, and save.

**Widget layer (`lib/src/widgets/pdf_annotation_view.dart`):**

Read-only. Cards are displayed but not tappable. No text selection or annotation
creation is wired into the page canvas.

**Example app state (`example/lib/state/document_state.dart`):**

`OpenDocument` caches `annotationsFuture` (a `Future<List<PdfPageAnnotations>>`
resolved once on open). After a mutation the cache must be invalidated and
reloaded; or the in-memory list updated directly and the file persisted via
`saveToBytes()` + file write.

---

### Key design decisions

#### 1. Annotation identity

PDFium identifies annotations by page index and an integer position within the
page's annotation list (`FPDFPage_GetAnnot(page, index)`). This index is the
only stable identity during the lifetime of an open document; it changes if an
earlier annotation on the same page is deleted.

Decision: add `annotationIndex: int` to the `PdfAnnotation` base class. The
isolate populates it when extracting annotations. Callers must re-extract (or
update their local list) after any mutation that could shift indices (i.e.,
deletion).

#### 2. Saving to disk

`FPDF_SaveAsCopy` takes an `FPDF_FILEWRITE` struct whose `WriteBlock` field is
a C function pointer. In Dart FFI this requires a `NativeCallable.isolateLocal`
to vend a native function pointer from a Dart closure. This is supported in
Dart 3.x.

The approach: inside `_document_native.dart`, a `PdfiumSaveDocumentCommand`
handler allocates a `NativeCallable`, builds the `FPDF_FILEWRITE` struct on the
native heap (via `calloc`), calls `FPDF_SaveAsCopy`, collects the chunks written
by `WriteBlock` into a `BytesBuilder`, frees native memory, and returns the
accumulated `Uint8List` to Dart.

The `fpdf_save.h` header must be added to `lib/src/generated/ffigen.yaml` (or
an equivalent manual binding), and bindings regenerated via `make ffi_bindings`.

#### 3. Creating a highlight from a text selection

Creating a highlight requires:

1. The user selects a text range on the page (drag gesture).
2. The drag start/end screen points are converted to PDF user-space coordinates
   using the current viewport transform (already available from the page widget).
3. `FPDFText_GetCharIndexAtPos` maps each endpoint to a character index.
4. `FPDFText_CountRects` + `FPDFText_GetRect` returns per-line bounding
   rectangles for the character range; each rectangle becomes one
   `FS_QUADPOINTSF` struct.
5. `FPDFPage_CreateAnnot(FPDF_ANNOT_HIGHLIGHT)` creates the annotation,
   `FPDFAnnot_AppendAttachmentPoints` adds the quad points, and
   `FPDFAnnot_SetColor` sets the colour.

This UX requires text-layer hit-testing inside the isolate — a new command
`PdfiumGetTextSelectionRectsCommand` that takes (pageIndex, startPdfPoint,
endPdfPoint) and returns the character range and the quad rects. The widget
layer then feeds these to a separate `PdfiumCreateHighlightCommand`.

For pages without a text layer (scanned PDFs), the command returns an empty list
and the widget shows a "no selectable text" message.

#### 4. Sticky note creation

Sticky notes do not require text selection: the user taps a blank area of the
page, which opens a creation dialog. The dialog captures the note text. A
`PdfiumCreateTextAnnotationCommand` receives the PDF-space tap position plus the
note text and optional author.

The sticky note icon is rendered by PDFium as part of `FPDF_ANNOT` rendering
(already enabled). Hit-testing a tap against existing note icons requires
checking whether the tap point falls within a `PdfTextAnnotation.rect` in
PDF coordinates.

#### 5. Edit and delete

Edit: only `Contents` (and optionally `Author`) are editable for both types.
`FPDFAnnot_SetStringValue(annot, "Contents", utf16leValue)` updates in-place.
`FPDFPage_GenerateContent` is called after the change, then `FPDF_SaveAsCopy`
serialises the document.

Delete: `FPDFPage_RemoveAnnot(page, annotationIndex)` followed by
`FPDFPage_GenerateContent` and `FPDF_SaveAsCopy`. All in-memory
`PdfPageAnnotations` lists must be re-fetched after a deletion to keep indices
coherent.

#### 6. Post-mutation state management in the example app

After any mutation:

1. Call `document.saveToBytes()` → write to the original file path (or a new
   path if the file is read-only).
2. Call `document.refreshAnnotations(pageIndex)` (a new convenience wrapper
   around `extractAnnotations` for a single page) to get fresh `PdfAnnotation`
   objects with updated indices.
3. Update `OpenDocument.annotationsFuture` so the sidebar rebuilds.

This keeps the in-memory model and the file in sync after every change.

#### 7. Impact on `pdfart_core.dart` vs `pdfart.dart` boundary

All new `PdfDocument` methods (`addHighlight`, `addTextAnnotation`,
`updateAnnotationContents`, `updateAnnotationColor`, `deleteAnnotation`,
`saveToBytes`) are pure-Dart and must live in `pdfart_core.dart`. They have no
Flutter dependency.

Widget-layer additions (`AnnotationEditDialog`, text-selection overlay,
`PdfAnnotationView` interactivity) belong in the Flutter entry point only.

---

### Risks and constraints

* **Experimental API**: almost all of `fpdf_annot.h` is marked
  `// Experimental API.` — function signatures may change across PDFium builds.
  The existing Dart abstraction layer (sealed types + isolate protocol) already
  localises this risk; no new design is needed.
* **`FPDF_FILEWRITE` NativeCallable lifecycle**: the `NativeCallable` must be
  closed after `FPDF_SaveAsCopy` returns. Forgetting this leaks a native thunk.
* **Index shifting after deletion**: callers must always re-fetch the
  annotation list after a `deleteAnnotation` call.
* **Round-trip fidelity**: saving a file that was originally produced by Adobe
  Acrobat or macOS Preview may drop features PDFium does not support (e.g.,
  rich-text popup content). The plan scope is limited to Contents + quad points,
  which round-trip safely.
* **Text selection UX complexity**: the drag-to-select gesture conflicts with
  the existing pan gesture in `PdfPageViewer`. A mode toggle (read vs. annotate)
  will be needed to disambiguate gestures.
* **`annotationIndex` is a breaking API change**: all construction sites for
  `PdfAnnotation` subtypes must be updated. Existing tests will need a parameter
  added.

---

## Implementation plan

### Phase 1 — FFI bindings for `fpdf_save.h`

- [ ] Add `fpdf_save.h` to the ffigen configuration (or add manual bindings for
  `FPDF_FILEWRITE`, `FPDF_SaveAsCopy`, `FPDF_SaveWithVersion`).
- [ ] Run `make ffi_bindings` to regenerate `lib/src/generated/pdfium_bindings.dart`.
- [ ] Verify that `FPDF_SaveAsCopy` and `FPDF_FILEWRITE` appear in the generated
  file and the project compiles.

### Phase 2 — Core type changes

- [ ] Add `annotationIndex: int` to `PdfAnnotation` base class (required field).
- [ ] Update all `PdfAnnotation` subclass constructors to pass `annotationIndex`
  through `super`.
- [ ] Update the extraction logic in `_document_native.dart` to capture the
  annotation index (the loop counter in `FPDFPage_GetAnnotCount` / `FPDFPage_GetAnnot`).
- [ ] Update all existing `PdfAnnotation` construction sites in tests to include
  `annotationIndex: 0` (or appropriate values).
- [ ] Run tests; confirm no regressions.

### Phase 3 — Isolate commands and handlers (core write path)

New commands in `isolate_messages.dart`:

- [ ] `PdfiumGetTextSelectionRectsCommand(token, pageIndex, startX, startY,
  endX, endY)` → `PdfiumGetTextSelectionRectsResponse(charIndex, charCount,
  quadRects)`.  Uses `FPDFText_GetCharIndexAtPos`, `FPDFText_CountRects`,
  `FPDFText_GetRect`.
- [ ] `PdfiumCreateHighlightAnnotationCommand(token, pageIndex, quadRects, color,
  contents?)` → `PdfiumCreateAnnotationResponse(annotationIndex)`. Uses
  `FPDFPage_CreateAnnot`, `FPDFAnnot_AppendAttachmentPoints`,
  `FPDFAnnot_SetColor`, `FPDFAnnot_SetRect`, optional `FPDFAnnot_SetStringValue`
  for Contents, then `FPDFPage_GenerateContent`.
- [ ] `PdfiumCreateTextAnnotationCommand(token, pageIndex, x, y, contents,
  author?)` → `PdfiumCreateAnnotationResponse(annotationIndex)`. Uses
  `FPDFPage_CreateAnnot`, `FPDFAnnot_SetRect`, `FPDFAnnot_SetStringValue`
  (Contents, T), `FPDFAnnot_SetColor`, `FPDFPage_GenerateContent`.
- [ ] `PdfiumUpdateAnnotationCommand(token, pageIndex, annotationIndex, contents,
  color?)` → `PdfiumUpdateAnnotationResponse`. Uses `FPDFPage_GetAnnot`,
  `FPDFAnnot_SetStringValue`, optional `FPDFAnnot_SetColor`,
  `FPDFPage_GenerateContent`.
- [ ] `PdfiumDeleteAnnotationCommand(token, pageIndex, annotationIndex)` →
  `PdfiumDeleteAnnotationResponse`. Uses `FPDFPage_RemoveAnnot`,
  `FPDFPage_GenerateContent`.
- [ ] `PdfiumSaveDocumentCommand(token)` → `PdfiumSaveDocumentResponse(bytes)`.
  Uses `FPDF_SaveAsCopy` with `NativeCallable` + `BytesBuilder`.
- [ ] Wire all handlers into the isolate dispatch switch in
  `_document_native.dart`.

### Phase 4 — `PdfDocument` public API

- [ ] `Future<List<PdfRect>> getTextSelectionRects(int pageIndex, PdfPoint start, PdfPoint end)` — returns per-line rects for the given selection range (empty if no text layer).
- [ ] `Future<PdfMarkupAnnotation> addHighlight(int pageIndex, List<PdfQuadPoints> quadPoints, {PdfColor? color, String? contents})` — creates a highlight; default color is semi-transparent yellow.
- [ ] `Future<PdfTextAnnotation> addTextAnnotation(int pageIndex, PdfPoint position, {required String contents, String? author, PdfColor? color})` — creates a sticky note at `position`.
- [ ] `Future<void> updateAnnotationContents(int pageIndex, int annotationIndex, String contents)` — updates the Contents string.
- [ ] `Future<void> updateAnnotationColor(int pageIndex, int annotationIndex, PdfColor color)` — updates the annotation color.
- [ ] `Future<void> deleteAnnotation(int pageIndex, int annotationIndex)` — removes the annotation and flushes page content.
- [ ] `Future<Uint8List> saveToBytes()` — serialises the current (mutated) document.
- [ ] Export all new methods from `pdfart_core.dart` (no Flutter dependency).
- [ ] Write unit tests for all public methods (create, update, delete, save round-trip). Test against real PDFs; include files authored by different tools (arXiv test set, macOS Preview output).

### Phase 5 — Flutter widget layer

**`PdfAnnotationView` interaction:**

- [ ] Make each annotation card tappable (wrap in `InkWell`).
- [ ] On tap: show `AnnotationDetailSheet` (a modal bottom sheet / dialog) with
  the full annotation contents, edit and delete actions.

**`AnnotationDetailSheet` widget (new):**

- [ ] Shows annotation type badge, page number, full contents text.
- [ ] "Edit" button → transitions the content area to an editable `TextField`;
  confirm/cancel buttons.
- [ ] "Delete" button → confirmation dialog → calls `deleteAnnotation`,
  refreshes the list.
- [ ] Accessible: all interactive elements have semantic labels; dialog is
  announced to screen readers.
- [ ] Localised: all string labels are passed in; no hard-coded strings.

**Annotation overlay on `PdfPageView` (new `PdfAnnotationInteractionLayer`):**

- [ ] Overlay widget positioned above the rendered page bitmap.
- [ ] Reads `PdfViewerController` to get the current page index and the
  viewport-to-PDF coordinate transform.
- [ ] Hit-tests taps against visible `PdfTextAnnotation.rect` values; on hit,
  opens `AnnotationDetailSheet` for that annotation.
- [ ] Recognises long-press to enter text-selection mode (when the page has a
  text layer); exits on drag completion or cancellation.

**Text selection for highlight creation:**

- [ ] In selection mode, a `GestureDetector` covers the page; drag start/end
  positions are converted to PDF space and sent to
  `getTextSelectionRects` (via the isolate).
- [ ] A transparent overlay paints selection highlight rects in real time (while
  dragging, use char-box approximation; refine on release).
- [ ] On drag end: show an action toolbar with "Highlight" and "Cancel" options.
- [ ] Tapping "Highlight" calls `addHighlight`; the controller switches back to
  normal mode and the page re-renders with `FPDF_ANNOT`.

**Annotation creation toolbar:**

- [ ] `PdfViewerController` gains an `annotationMode` enum
  (`normal`, `selectText`, `addNote`).
- [ ] The example app's viewer toolbar gains an "annotate" icon that cycles
  `annotationMode`.
- [ ] In `addNote` mode, a tap on blank page area opens a "new note" text dialog,
  then calls `addTextAnnotation`.
- [ ] Write widget tests for `AnnotationDetailSheet` and the interaction layer.

### Phase 6 — Example app (Quietly)

- [ ] `OpenDocument` gains a mutable `List<PdfPageAnnotations>` field (replaces
  `annotationsFuture`); kept in sync after each mutation.
- [ ] Expose `refreshAnnotationsForPage(int pageIndex)` on `OpenDocument` that
  re-extracts a single page's annotations and updates the list.
- [ ] Wire all four mutation paths (create highlight, create note, edit, delete)
  to call `document.saveToBytes()` followed by a file write back to
  `filePath` (if available) or offer a "save as" dialog.
- [ ] Surface the annotation interaction layer in `PdfViewerPane`.
- [ ] Add localisation keys for all new UI strings in `l10n/app_en.arb`.
- [ ] Manual test with at least three real PDFs (arXiv paper, macOS Preview
  annotated file, Acrobat annotated file).

### Phase 7 — Documentation and release readiness

- [ ] Add doc comments to all new public methods on `PdfDocument`.
- [ ] Update `docs/spec/` to describe the annotation write API and the save
  round-trip contract.
- [ ] Update `docs/roadmap/0_04.md` to mark this plan complete.
- [ ] Run `make pre_commit` (format + analyze + license check) — zero warnings.
- [ ] Run `make coverage` — confirm ≥ 90% line coverage.

---

## Reviews

### Review 1: 2026-05-22

Initial plan drafted after codebase investigation. All open questions resolved
during investigation; plan proceeds directly to Investigated status.

---

## Summary

_To be populated after implementation is complete._
