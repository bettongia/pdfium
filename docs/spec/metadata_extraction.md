# Metadata Extraction (Info Dictionary)

## Overview

The metadata extraction API allows a caller to read the standard PDF Info
dictionary fields from a loaded document. It works across all supported
platforms — iOS, Android, macOS, Windows, Linux, and web — without requiring
platform-specific code from the caller.

## Public API

### `PdfDocument`

The top-level abstraction for a loaded PDF file. All document-level operations
are methods on this class.

#### `PdfDocument.fromBytes(Uint8List bytes)`

Factory that loads a PDF from raw bytes.

Throws `PdfExtractionException` with:

- `PdfError.passwordRequired` — the document is password-protected. Passwords
  are not supported in v1; callers should surface a meaningful message to the
  user.
- `PdfError.invalidDocument` — the bytes are corrupt, truncated, or not a
  valid PDF.

#### `getMetadata()` → `Future<PdfMetadata>`

Returns all eight standard Info dictionary fields in a single round-trip.

#### `getDocumentInfo()` → `Future<PdfDocumentInfo>`

Returns document-level properties: PDF file version and file identifiers
(permanent and changing), in a single round-trip.

#### `close()` → `Future<void>`

Releases the native PDFium document handle. Safe to call more than once.
After `close()` returns, `getMetadata()` and `getDocumentInfo()` throw
`StateError`.

### `PdfMetadata`

Immutable value object returned by `getMetadata()`. All fields are nullable;
a `null` value means the field was not present in the Info dictionary (as
opposed to being present but empty — these are distinct states in the PDF
specification).

| Field          | Type       | PDF Tag        | Description                            |
| -------------- | ---------- | -------------- | -------------------------------------- |
| `title`        | `String?`  | `Title`        | Document title                         |
| `author`       | `String?`  | `Author`       | Author name(s)                         |
| `subject`      | `String?`  | `Subject`      | Subject or description                 |
| `keywords`     | `String?`  | `Keywords`     | Comma-separated keywords               |
| `creator`      | `String?`  | `Creator`      | Application that created the original  |
| `producer`     | `String?`  | `Producer`     | Application that converted to PDF      |
| `creationDate` | `PdfDate?` | `CreationDate` | Date and time the document was created |
| `modDate`      | `PdfDate?` | `ModDate`      | Date and time of last modification     |

### `PdfDate`

Holds both the raw string and the parsed `DateTime` for date fields.

| Property | Type        | Description                                           |
| -------- | ----------- | ----------------------------------------------------- |
| `raw`    | `String`    | The raw string as stored in the PDF Info dictionary   |
| `value`  | `DateTime?` | Parsed UTC `DateTime`, or `null` if parsing failed    |

The PDF date format is `D:YYYYMMDDHHmmSSOHH'mm'` (ISO 8601-like but distinct).
The `D:` prefix is optional. Truncated formats (e.g. date-only) are handled.
When parsing fails, `value` is `null` and `raw` is preserved for debugging.

### `PdfDocumentInfo`

Immutable value object returned by `getDocumentInfo()`.

| Property      | Type          | Description                                                |
| ------------- | ------------- | ---------------------------------------------------------- |
| `fileVersion` | `int?`        | PDF file version as an integer (e.g. 17 for PDF 1.7)       |
| `permanentId` | `Uint8List?`  | Permanent file identifier bytes (typically 16-byte MD5)    |
| `changingId`  | `Uint8List?`  | Changing file identifier bytes (typically 16-byte MD5)     |

File identifiers are raw bytes. To obtain a hex string:

```dart
final hex = info.permanentId
    ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();
```

### `PdfError`

Enum of error reasons surfaced via `PdfExtractionException`.

| Value               | Meaning                                                  |
| ------------------- | -------------------------------------------------------- |
| `invalidDocument`   | Bytes are corrupt, truncated, or not a valid PDF         |
| `passwordRequired`  | Document is password-protected; passwords not supported  |

### `PdfExtractionException`

Thrown when a PDF operation fails. Holds a `PdfError` in its `error` field.

## Behaviour by scenario

| Scenario                        | Behaviour                                                |
| ------------------------------- | -------------------------------------------------------- |
| Field not in Info dictionary    | `null` on the corresponding `PdfMetadata` field          |
| PDF has no Info dictionary      | All `PdfMetadata` fields are `null`                      |
| Malformed date string           | `PdfDate.value` is `null`; `PdfDate.raw` is preserved    |
| Password-protected PDF          | `PdfExtractionException(PdfError.passwordRequired)`      |
| Corrupt or non-PDF bytes        | `PdfExtractionException(PdfError.invalidDocument)`       |
| File identifiers absent         | `PdfDocumentInfo.permanentId` and `.changingId` are null |
| `close()` called twice          | Second call is a no-op; no exception                     |
| Method called after `close()`   | `StateError` is thrown                                   |

## Platform notes

On native platforms (iOS, Android, macOS, Windows, Linux) all PDFium calls run
on a dedicated `Isolate` (the `PdfiumIsolate` singleton). The caller's isolate
is never blocked.

On web, PDFium is compiled to WebAssembly and runs on the browser main thread.
A Web Worker path is deferred — see `plan_layout_aware_reordering.md`.

## Limitations

### Passwords not supported

Password-protected documents cannot be opened in v1. The `passwordRequired`
error allows callers to surface a clear message to the user. Support for
user-password-protected documents is deferred to a future plan.

### XMP metadata not included

This API covers only the Info dictionary. XMP metadata (the richer modern
format) is deferred to `plan_xmp_metadata_extraction.md` (v0.05). When XMP is
not present, the Info dictionary is the fallback.

### `FPDF_GetDocPermissions` not exposed

Document permissions (edit, print, copy restrictions) are not surfaced in v1.
They are deferred to a future plan focused on encryption and DRM.

## Developer CLI

A developer tool is available for inspecting real-world PDF files:

```bash
dart run bin/pdfinfo.dart <path-to-pdf>
```

Prints all Info dictionary fields and document properties in a readable
key/value format. Date fields show both the parsed ISO 8601 value and the
original raw string. File identifiers are shown as hex strings. Errors produce
distinct, actionable messages with a non-zero exit code.
