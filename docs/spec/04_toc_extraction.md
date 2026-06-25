# Table of Contents Extraction

## Overview

The Table of Contents (TOC) extraction API allows a caller to retrieve the
bookmark/outline tree embedded in a PDF document. PDFs use an "Outline"
dictionary as their native TOC structure; each entry has a display title and an
optional destination — an internal page index, an XYZ scroll anchor, or a URI.
Entries nest arbitrarily deeply to form a tree.

The API is a single `Future`-returning property on `PdfDocument` — no streaming
is needed because the entire bookmark tree is a small, bounded data structure.
The resulting tree is returned as a `List<PdfTocEntry>` whose elements may each
carry a `children` list of their own `PdfTocEntry` values.

This feature belongs to the pure-Dart entry point (`package:betto_pdfium/betto_pdfium.dart`) and has
no dependency on `dart:ui` or Flutter.

## Public API

### `PdfDocument.tableOfContents`

```dart
Future<List<PdfTocEntry>> get tableOfContents;
```

Returns the root-level bookmark entries. Each entry may carry child entries
accessible via `PdfTocEntry.children`.

Returns an empty list when the document has no bookmarks. Never throws for a
well-formed open document.

Throws `StateError` if called after `PdfDocument.close()`.

**Platform support:** Native (dart:ffi) only. On web and the fallback stub
platform, `tableOfContents` throws `UnsupportedError` immediately.

### `PdfTocEntry`

Immutable value type representing a single bookmark entry.

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | Display title of the bookmark. May be empty for bookmarks with no title text. |
| `pageIndex` | `int?` | Zero-based page index this entry navigates to, or `null` if no internal-page destination is present. |
| `uri` | `String?` | URI string for `PDFACTION_URI` bookmarks, or `null` for all other entry types. |
| `scrollPosition` | `PdfPoint?` | XYZ scroll anchor within the destination page (PDF user space, bottom-left origin), or `null` if the destination does not carry explicit position coordinates. |
| `children` | `List<PdfTocEntry>` | Nested child entries in document order. Empty for leaf entries. |

`PdfTocEntry` implements `==`, `hashCode`, and `toString()`. Equality is
deep-recursive over `children`.

#### Zoom omission

`FPDFDest_GetLocationInPage` returns an (x, y, zoom) triple for
`PDFDEST_VIEW_XYZ` destinations. The zoom value is intentionally **not**
surfaced. Exposing zoom risks overriding the user's OS accessibility zoom
settings or Flutter's `textScaleFactor`, which would create a hostile
experience for users who rely on display magnification. Only the (x, y) scroll
anchor is captured via `scrollPosition`.

## Destination resolution

A bookmark's target is resolved by the following algorithm inside the PDFium
isolate:

1. Call `FPDFBookmark_GetAction`. If the action is non-null, inspect
   `FPDFAction_GetType`:
   - `PDFACTION_GOTO` (1): call `FPDFAction_GetDest` → page index via
     `FPDFDest_GetDestPageIndex`. Optionally extract an XYZ scroll position.
   - `PDFACTION_URI` (3): call `FPDFAction_GetURIPath` → `uri` string.
   - All other action types (`PDFACTION_REMOTEGOTO`, `PDFACTION_LAUNCH`,
     `PDFACTION_EMBEDDEDGOTO`, `PDFACTION_UNSUPPORTED`): both `pageIndex`
     and `uri` are `null`.
2. If the action is null, call `FPDFBookmark_GetDest` directly → page index.
3. If both the action and the direct destination are null, the entry is a
   section label with no navigation target. Both `pageIndex` and `uri` are
   `null`.

`FPDFDest_GetDestPageIndex` returning -1 is treated as `pageIndex = null`.

## Tree walk

The tree is walked recursively inside the PDFium isolate using
`FPDFBookmark_GetFirstChild` and `FPDFBookmark_GetNextSibling`. Passing a null
pointer as the bookmark argument to `FPDFBookmark_GetFirstChild` retrieves the
root-level entries.

**Cycle detection:** a `Set<int>` of visited raw pointer addresses guards
against malformed PDFs that contain cycles in the bookmark dictionary. When a
previously-seen handle address is encountered, recursion stops without
emitting that entry.

**`FPDFBookmark_GetCount`:** this function returns -1 for an unknown child
count. It is not used to pre-size lists; `GetFirstChild`/`GetNextSibling` drive
traversal unconditionally.

## Isolate boundary

The complete `List<PdfTocEntry>` tree is built inside the PDFium isolate and
deep-copied to the calling isolate by Dart's standard message-passing
serialisation. This is safe and correct for the bounded sizes of typical PDF
bookmark trees (hundreds to low thousands of entries at most).

## Behaviour by scenario

| Scenario | Behaviour |
|----------|-----------|
| No bookmarks | Returns an empty list. No error. |
| Section-label entry (no dest, no action) | `pageIndex == null`, `uri == null`, `scrollPosition == null`. Entry is included in the tree. |
| URI action entry | `uri` is non-null, `pageIndex == null`. |
| GOTO action entry | `pageIndex` is the zero-based page index. `scrollPosition` is set when the dest carries XYZ coordinates. |
| Remote / launch / embedded action | `pageIndex == null`, `uri == null`. Entry is included with those null fields. |
| `FPDFBookmark_GetTitle` returns empty buffer | `title` is an empty string; the entry is still included. |
| `FPDFDest_GetDestPageIndex` returns -1 | `pageIndex == null`. |
| `FPDFDest_GetLocationInPage` returns FALSE | `scrollPosition == null`. The entry is still included. |
| Cycle in bookmark tree | Recursion stops at the repeated handle. The cyclic entry is silently omitted. |
| `tableOfContents` after `close()` | Throws `StateError`. |
| Web / stub platform | Throws `UnsupportedError`. |

## Platform notes

On native platforms all PDFium calls run on the `PdfiumIsolate` — the
process-wide singleton that serialises all FFI calls. The caller's isolate is
never blocked. On web, `tableOfContents` throws `UnsupportedError` until the
PDFium WASM build is available.

## `bin/pdfinfo.dart` CLI

The `--toc` flag causes `pdfinfo` to call `tableOfContents` and print the
bookmark tree to stdout. Output format (plain text):

```
--- Table of Contents ---
  Chapter 1 → page 1
  Chapter 2 → page 3
    Section 2.1 → page 4
  Appendix
```

- Each entry is indented two spaces per nesting level (root entries are
  indented two spaces).
- Internal-page destinations show `→ page N` (1-based).
- URI destinations show `→ <uri>`.
- Section-label entries with no target show the title only.
- When the document has no bookmarks, `(no bookmarks)` is printed.

In JSON mode (`--json --toc`), a `"toc"` key is added to the root object. Each
entry is a JSON object with `"title"`, optional `"pageIndex"` (0-based),
optional `"uri"`, optional `"scrollPosition"` (`{"x": …, "y": …}`), and
optional `"children"` array. Omitting `--toc` omits the `"toc"` key entirely.
