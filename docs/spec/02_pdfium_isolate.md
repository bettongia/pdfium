# PDFium Isolate Architecture

## Overview

PDFium is not thread-safe. All FFI calls into the native library must happen on
a single, dedicated OS thread. In Dart, that thread is owned by a dedicated
`Isolate` — `PdfiumIsolate` — that runs for the lifetime of the process. All
`PdfDocument` instances share it; the caller's isolate (typically the UI isolate)
communicates with it via typed message-passing and is never blocked.

`PdfiumIsolate` is a process-wide singleton. It is lazily spawned on the first
`PdfDocument.fromBytes()` call. Do not spawn a second isolate, and do not call
`FPDF_InitLibraryWithConfig()` more than once — doing so is a correctness bug.

## Command/Response protocol

All messages are typed Dart classes defined in `isolate_messages.dart`.

### Commands

Every command extends the sealed base class `PdfiumCommand`, which carries a
`replyPort` — the `SendPort` on which the isolate sends its response:

```dart
sealed class PdfiumCommand {
  const PdfiumCommand(this.replyPort);
  final SendPort replyPort;
}
```

Each command is a plain `const`-constructible class. Fields are named and
documented. The `replyPort` is always the first constructor argument.

### Responses

Every response extends the sealed base class `PdfiumResponse`:

```dart
sealed class PdfiumResponse {
  const PdfiumResponse();
}
```

#### Response class convention

For operations that can fail, use **a single response class with `.success(…)`
and `.failure(…)` named constructors** and an `isSuccess` getter. Do not create
separate success/failure subclasses.

```dart
class PdfiumExampleResponse extends PdfiumResponse {
  /// Creates a successful response.
  const PdfiumExampleResponse.success(this.result) : error = null;

  /// Creates a failed response.
  const PdfiumExampleResponse.failure(this.error) : result = null;

  /// The result, or `null` on failure.
  final SomeType? result;

  /// The error that occurred, or `null` on success.
  final PdfError? error;

  /// Whether this response represents a successful operation.
  bool get isSuccess => error == null;
}
```

Payload fields are nullable; they are `null` on the opposite outcome. Callers
check `isSuccess` (or `error == null`) before accessing the payload. For
responses that carry multiple success fields, make those fields private and
expose them via non-nullable getters that assert (`!`) — callers only reach
those getters after checking `isSuccess`, so the assertion never fires in
correct code.

Responses for operations that cannot fail (e.g. `PdfiumCloseDocumentResponse`)
need no named constructors — a plain `const` constructor is sufficient.

### Document tokens

`PdfiumLoadDocumentCommand` returns an opaque `int` token representing the live
`FPDF_DOCUMENT` handle inside the isolate. All subsequent per-document commands
carry this token. The token is only meaningful inside the isolate; it is never a
valid pointer in the caller's address space.

## Adding a new operation

1. **Define the command** — extend `PdfiumCommand`, document all fields, put
   `replyPort` first, keep fields `final`.

2. **Define the response** — extend `PdfiumResponse` with `.success(…)` and
   `.failure(…)` named constructors and an `isSuccess` getter (see convention
   above).

3. **Add a dispatch branch** — add an `else if (message is YourCommand)` branch
   in the message handler loop in `pdfium_isolate.dart`. Wrap all PDFium handle
   lifecycle in a `try/finally` to guarantee cleanup (see below).

4. **Implement the public method** — send the command, `await` the reply port,
   cast the response, and propagate errors via the established `PdfError`
   exception path.

5. **Stub and web** — add the method to `_document_stub.dart` and
   `_document_web.dart`. Both must throw `UnsupportedError` — not
   `UnimplementedError` — to signal that the platform does not support the
   operation, consistent with all other unsupported-platform methods in this
   codebase.

## Memory management inside the isolate

Every PDFium handle has a matching `Close` or `Destroy` function. Dart's
garbage collector does not call these. Inside the isolate handler, always close
page-level and text-level handles in a `try/finally`:

```dart
final textPage = bindings.FPDFText_LoadPage(doc, pageIndex);
try {
  // ... work with textPage ...
} finally {
  bindings.FPDFText_ClosePage(textPage);
}
```

Document handles (`FPDF_DOCUMENT`) are closed by `PdfiumCloseDocumentCommand`
and must not be closed elsewhere.

## UTF-16LE strings (`FPDF_WIDESTRING`)

Several PDFium APIs accept or return `FPDF_WIDESTRING` — a null-terminated
UTF-16LE C string. The established pattern in `pdfium_isolate.dart` (used by the
TOC implementation) is:

1. Encode the Dart `String` to a `Uint16List` (UTF-16LE code units).
2. Allocate a native buffer with `calloc<Uint16>(codeUnits.length + 1)` — the
   `+1` provides the null terminator; `calloc` zero-fills.
3. Copy the code units into the buffer.
4. Pass the buffer pointer as `FPDF_WIDESTRING`.
5. Free the buffer with `calloc.free(ptr)` in a `try/finally`.

Reuse the existing helper in `pdfium_isolate.dart` rather than duplicating this
pattern.

## Coordinate system

PDFium uses PDF user space: origin at the bottom-left of the page, units in
points (1/72 inch). Flutter and most UI frameworks use an origin at the
top-left. Use `FPDF_PageToDevice()` / `FPDF_DeviceToPage()` for all coordinate
conversions. Expose raw PDF coordinates in public API types and document the
coordinate system clearly — callers are responsible for any display transform.
