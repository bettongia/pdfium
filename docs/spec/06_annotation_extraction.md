# Annotation Extraction

## Overview

The annotation extraction API allows a caller to read all PDF annotations from a
document. It surfaces reader-workflow artefacts — highlights, sticky notes,
underlines, free-text comments, ink drawings, shapes, links, and more — as a
typed Dart object hierarchy.

Annotation extraction is implemented via `fpdf_annot.h`, which is marked
`// Experimental API.` throughout the PDFium headers. All FFI bindings are kept
behind a Dart abstraction layer so that upstream signature changes are localised
to the implementation files and do not break callers.

**Platform availability:** native platforms only (iOS, Android, macOS, Windows,
Linux). The stub and web backends throw `UnsupportedError`. Form-field annotations
(`FPDF_ANNOT_WIDGET`, `FPDF_ANNOT_XFAWIDGET`) are out of scope for v0.02 and are
earmarked for a dedicated form-extraction plan.

## Public API

### `PdfDocument.extractAnnotations({int? pageIndex})`

Returns `Stream<PdfPageAnnotations>`. When `pageIndex` is `null` (the default)
the stream yields one `PdfPageAnnotations` per page in index order — including
pages with zero annotations, so callers can track full page coverage. When
`pageIndex` is provided the stream yields exactly one entry for that page.

Calling `PdfDocument.close()` while a stream is active terminates the stream
immediately and releases all page-level annotation handles. Callers do not need
to cancel the stream subscription before calling `close()`.

A `RangeError` is thrown when `pageIndex` is provided but is outside
`[0, pageCount)`.

A `StateError` is thrown if the document has already been closed.

### `PdfPageAnnotations`

Immutable result for a single page.

| Property | Type | Description |
|----------|------|-------------|
| `pageIndex` | `int` | 0-based page index. |
| `annotations` | `List<PdfAnnotation>` | All annotations on this page. Empty when the page has no annotations. |

### Annotation type hierarchy

All annotation types extend the sealed base class `PdfAnnotation`.

#### `PdfAnnotation` (sealed base)

| Property | Type | Description |
|----------|------|-------------|
| `pageIndex` | `int` | 0-based index of the page this annotation belongs to. |
| `contents` | `String?` | Text content (`/Contents` entry). `null` when the key is absent; `""` when present but empty — the two cases are intentionally distinguishable. |
| `author` | `String?` | Author (`/T` entry). |
| `rect` | `PdfRect?` | Bounding rectangle in PDF page coordinates (bottom-left origin). `null` when absent or malformed. |
| `color` | `PdfColor?` | Stroke / border colour. `null` when no colour entry is present. |
| `modifiedDate` | `PdfDate?` | Modification date (`/M` entry), parsed via `pdf_date_parser.dart`. `null` when absent or unparseable. |
| `flags` | `int` | Raw `FPDF_ANNOT_FLAG_*` bitmask. |
| `popup` | `PdfPopupAnnotation?` | Inlined popup window. `null` when no popup is attached. |

#### Concrete subtypes

| Class | `PdfAnnotationType` | Type-specific fields |
|-------|---------------------|----------------------|
| `PdfTextAnnotation` | `text` | _(base fields only — sticky notes)_ |
| `PdfFreeTextAnnotation` | `freeText` | _(base fields only)_ |
| `PdfMarkupAnnotation` | `highlight`, `underline`, `squiggly`, `strikeout` | `subtype`, `quadPoints: List<PdfQuadPoints>` |
| `PdfShapeAnnotation` | `square`, `circle` | `subtype`, `interiorColor: PdfColor?` |
| `PdfLineAnnotation` | `line` | `lineStart: PdfPoint`, `lineEnd: PdfPoint` |
| `PdfInkAnnotation` | `ink` | `strokes: List<List<PdfPoint>>` — outer list is strokes, inner list is points per stroke |
| `PdfPolygonAnnotation` | `polygon`, `polyline` | `subtype`, `vertices: List<PdfPoint>` |
| `PdfLinkAnnotation` | `link` | `uri: String?` — `null` when the link targets a page destination rather than a URI |
| `PdfStampAnnotation` | `stamp` | _(base fields only)_ |
| `PdfUnknownAnnotation` | `unknown` | `rawSubtype: int` — raw `FPDF_ANNOT_*` integer for debugging |

#### `PdfAnnotationType` enum

```dart
enum PdfAnnotationType {
  text, freeText, highlight, underline, squiggly, strikeout,
  square, circle, line, ink, polygon, polyline, link, stamp, popup, unknown,
}
```

`popup` appears in this enum for completeness but is never emitted as a
top-level annotation — see [Popup annotations](#popup-annotations) below.

### Supporting value types

All value types implement `==`, `hashCode`, and `toString`.

| Type | Fields |
|------|--------|
| `PdfRect` | `left`, `bottom`, `right`, `top` (all `double`) |
| `PdfPoint` | `x`, `y` (both `double`) |
| `PdfQuadPoints` | `p1`, `p2`, `p3`, `p4` (`PdfPoint` — four corners of one highlighted quad) |
| `PdfColor` | `r`, `g`, `b`, `a` (all `double`, range 0–255) |
| `PdfPopupAnnotation` | `rect: PdfRect?`, `flags: int` |

## Coordinate system

All coordinates are in the PDF page coordinate space with a **bottom-left
origin**. This is consistent with how the text layer currently reports character
bounds. Callers that need screen coordinates (top-left origin) must apply
`FPDF_PageToDevice()` / `FPDF_DeviceToPage()` themselves.

## Popup annotations

`FPDF_ANNOT_POPUP` annotations are the floating comment windows that PDF viewers
display alongside sticky notes and free-text annotations. They are not emitted as
top-level entries in `PdfPageAnnotations.annotations`. Instead, when a popup is
linked to a parent annotation via `FPDFAnnot_GetLinkedAnnot()`, its data is
inlined as the optional `popup` field on the parent `PdfAnnotation`. If no popup
is present, `popup` is `null`.

## Out-of-scope annotation types

The following annotation subtypes are skipped by the extractor and never appear
in the output:

| Subtype | Reason |
|---------|--------|
| `FPDF_ANNOT_WIDGET`, `FPDF_ANNOT_XFAWIDGET` | Form fields — out of scope for v0.02; earmarked for a dedicated form-extraction plan. |
| `FPDF_ANNOT_FILEATTACHMENT`, `FPDF_ANNOT_SOUND`, `FPDF_ANNOT_MOVIE`, `FPDF_ANNOT_SCREEN`, `FPDF_ANNOT_REDACT`, `FPDF_ANNOT_WATERMARK`, `FPDF_ANNOT_THREED`, `FPDF_ANNOT_RICHMEDIA` | Multimedia / special types — out of scope for v0.02. |

Annotations whose subtype is unrecognised by the current binding are emitted as
`PdfUnknownAnnotation` with `rawSubtype` carrying the raw integer, so no
information is silently discarded.

## Behaviour by scenario

| Scenario | Behaviour |
|----------|-----------|
| Page with no annotations | `PdfPageAnnotations.annotations` is an empty list. No error. |
| `contents` key absent | `annotation.contents` is `null`. |
| `contents` key present but empty | `annotation.contents` is `""`. Distinguishable from absent. |
| No colour entry | `annotation.color` is `null`. |
| Malformed `/Rect` entry | `annotation.rect` is `null`. No crash. |
| Quad-points count not a multiple of 8 | Trailing incomplete quad is truncated. |
| `FPDF_ANNOT_UNKNOWN` or unmapped subtype | Emitted as `PdfUnknownAnnotation` with `rawSubtype`. |
| Popup annotation | Inlined as `annotation.popup` on parent; not emitted top-level. |
| Widget / form annotation | Silently skipped. |
| Concurrent `extractAnnotations()` calls | Permitted. The isolate handles concurrent streams via per-request `SendPort`s. |
| Document with no pages | Stream completes immediately with no items. |
| Password-protected PDF | `PdfExtractionException(PdfError.passwordRequired)`. |
| Corrupt / non-PDF bytes | `PdfExtractionException(PdfError.invalidDocument)`. |
| `pageIndex` out of range | `RangeError`. |
| Called after `close()` | `StateError`. |
| `close()` called mid-stream | Stream terminates immediately; all page-level handles released. |

## Platform notes

On native platforms all PDFium calls run on the `PdfiumIsolate` singleton. The
UI isolate is never blocked. The isolate uses a two-pass algorithm per page:

1. **First pass** — iterate every annotation index; extract non-`POPUP` annotations
   and record `POPUP` annotation pointers with their handle addresses.
2. **Second pass** — for each recorded popup, call `FPDFAnnot_GetLinkedAnnot()` to
   retrieve the parent handle, look it up in the first-pass index by page-annotation
   index (`FPDFPage_GetAnnotIndex()`), and inline the popup data onto the parent.

On the stub (non-FFI) and web backends, `extractAnnotations()` throws
`UnsupportedError`. An empty stream is explicitly avoided because it would silently
appear to succeed with no data, masking the unsupported platform.

## Limitations

### No per-page range filter

`extractAnnotations()` accepts an optional single `pageIndex` but not a page
range. Range-based extraction is a known limitation to revisit in a future plan.

### Read-only

Annotation write-back is not supported in v0.02. Modifying or creating annotations
requires `fpdf_save.h` and is earmarked for a future plan.

### `fpdf_annot.h` is Experimental API

Nearly all functions in `fpdf_annot.h` carry the `// Experimental API.` comment
in the PDFium headers. The FFI bindings are kept behind Dart abstraction so that
upstream signature changes are isolated to implementation files.
