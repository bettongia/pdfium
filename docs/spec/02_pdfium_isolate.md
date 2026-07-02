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

This describes the **native** backend (macOS, Linux, iOS, Android, Windows).
See "Web Worker concurrency model" below for the equivalent web (WASM)
architecture — the *shape* is the same (a single dedicated execution context
owns all PDFium state; the caller communicates via typed messages and is
never blocked), but the underlying mechanism is necessarily different on web.

## Web Worker concurrency model

PDFium is not thread-safe on web either, and WASM linear memory is private to
whichever thread instantiated the module — so, just as on native, all PDFium
work for the whole page must happen in one place. Unlike native, that place
cannot be a `dart:isolate` `Isolate`: isolates are not supported on any web
compile target (confirmed against both the
[Flutter isolates doc](https://docs.flutter.dev/perf/isolates#web-platforms-and-compute)
and the [Dart concurrency doc](https://dart.dev/language/concurrency#concurrency-on-the-web);
`compute()` on web runs on the main thread, not a background one). The web
backend therefore uses a dedicated `Worker` (`package:web`) with a
hand-rolled `postMessage` protocol instead — mirroring the *shape* of the
native isolate architecture above (single owner of PDFium state, typed
request/response messages, opaque document tokens) while replacing the
*mechanism* entirely.

See
[`plan_wasm_web_worker_offload.md`](../plans/completed/plan_wasm_web_worker_offload.md)
for the full design investigation and rationale.

### Components

- **`_pdfium_wasm_engine.dart`** — the PDFium marshalling engine: one
  function per operation (load, close, pageCount, metadata, documentInfo,
  pageSize, render, thumbnail, extract text/annotations/images, renderImage,
  search, toc), each taking an explicit `PdfiumModule` and document
  pointer/registry data as parameters. No static, main-thread-only globals —
  this is what makes the same functions safely callable both from a direct
  main-thread test and from inside the worker.
- **`_pdfium_worker_entry.dart`** — the worker-side dispatch shell. A `void
  main()` that installs a `message` listener on the worker's global scope,
  bootstraps the PDFium module via `importScripts('pdfium.js')` (the
  worker-context equivalent of the main thread's `<script>`-tag injection —
  DOM APIs are unavailable in worker scope), owns the module and the
  document registry (`Map<int, ({int docPtr, int bufPtr})>`, exactly mirroring
  native's isolate-side registry shape), and dispatches incoming requests to
  the engine functions above. This file is pre-compiled once via `dart
  compile js` (`make build_wasm_worker`) into the checked-in
  `lib/assets/pdfium_worker.js` artifact — see `spec/01_binary_distribution.md`.
- **`_pdfium_worker_protocol.dart`** — the pure-Dart (no `dart:js_interop`)
  wire format: `WorkerRequest`/`WorkerResponse` envelopes with an integer
  correlation id (replacing what `SendPort`/`ReceivePort` give for free to
  the native isolate), `WorkerOp` constants (one per operation, mirroring the
  native `PdfiumCommand` subclasses), and JSON encode/decode functions for
  every `PdfDocument` result type, including the full `PdfAnnotation`
  sealed-class hierarchy. This file is imported by *both* the main-thread
  client and the worker entry point, despite the two being compiled into
  separate JS bundles — each compiles its own copy of the logic
  independently, so this does not create a shared runtime dependency.
- **`_pdfium_worker_wire.dart`** — the `dart:js_interop`-dependent glue that
  translates `WorkerRequest`/`WorkerResponse` to/from the plain `JSObject`
  shape actually sent over `postMessage`.
- **`_document_web.dart`** — the thin main-thread `PdfDocumentImpl` RPC
  client. Owns no PDFium state directly; every method builds a request,
  sends it, and decodes the response.

### One shared Worker per page

A single `Worker` is spawned lazily on the first `PdfDocument.fromBytes()`
call and reused by every subsequently opened document, multiplexed over it
via opaque integer tokens the worker assigns — directly mirroring native's
one-isolate-per-process model. This avoids N× WASM module instantiation cost
(~5.2 MB each) for apps with multiple documents open at once, at the cost of
documents queuing behind one another's in-flight worker requests rather than
running in true parallel (PDFium is not thread-safe regardless, so this
matches the native model's own trade-off).

### Request/response correlation and per-token ordering

Each request carries a monotonically increasing integer id; the client keeps
a `Map<int, Completer<WorkerResponse>>` of in-flight requests, resolved from
a single shared `onmessage` handler when the matching response arrives. This
replaces what `SendPort`/`ReceivePort` give for free to the native isolate.

Every request for a given document token is additionally serialized through
a **per-token request queue** (`_sendForToken` in `_document_web.dart`) —
each request is chained onto the previous one for that same token. This
guarantees a `close()` call is never processed by the worker while an
earlier request for the same document is still in flight, and vice versa,
without requiring any explicit locking inside the worker itself (the queue
lives entirely on the main-thread client side). Requests for *different*
tokens are not serialized against each other and may interleave.

### Streaming operations: one round trip, not one message per page

Unlike a page-by-page message exchange, the streaming operations
(`extractPlainText`, `extractAnnotations`, `extractImages`, `search`) fetch
**all** requested pages in a single worker round trip — the worker computes
them synchronously in one dispatch, since there is no `await` boundary
between pages inside the worker (PDFium calls are synchronous). The
main-thread client then yields the already-fetched results locally via
`Future.delayed(Duration.zero)` between items, preserving the public
`Stream` API's cooperative-yielding shape (and, for `search`, inserting a
yield point whenever the source page changes) without needing a
multi-message streaming sub-protocol.

### Transferable buffers and the detach caveat

BGRA bitmap results (`renderPageToBytes`, `getThumbnail`, `renderImage`, and
`extractImages(includeBitmap: true)`) are transferred back from the worker as
`ArrayBuffer`s via `postMessage`'s transfer-list parameter, rather than
embedded in the JSON payload or copied — this matters for the multi-megabyte
buffers these operations can return.

**A transferred `ArrayBuffer` is neutered on the sender side once the
transfer completes.** The one place this had to be handled deliberately:
`PdfDocument.fromBytes(bytes)` does **not** transfer the caller-supplied
`bytes` buffer — only worker-*generated* output buffers are transferred. If
`bytes` were transferred, a caller reusing the same buffer for a second
`fromBytes()` call (or simply expecting to still be able to read it
afterwards) would see it silently neutered as an unexpected side effect of
the first call. `WorkerRequest.transferBuffers` (default `true`) exists
specifically so `fromBytes()`'s request can opt out and use a
structured-clone copy instead, matching the native backend's copy-not-move
semantics for caller-supplied input.

### Memory management

The WASM heap (and therefore the PDF byte buffer + PDFium document handle)
lives entirely inside the worker. A main-thread `Finalizer` (backed by
`FinalizationRegistry`) remains as a safety net against forgotten `close()`
calls, but its callback can no longer free memory directly — it posts a
fire-and-forget "close" request for the garbage-collected document's token to
the worker instead, which performs the actual `FPDF_CloseDocument`/`free`
calls there. The response to that fire-and-forget request has no registered
`Completer` and is silently ignored when it arrives.

### Coverage note

Code executing inside a spawned `Worker` runs in a separate Chrome DevTools
Protocol target that `dart test -p chrome --coverage`'s collector cannot
instrument (confirmed by reading the pinned `test-1.31.2` `chrome.dart`
source directly — coverage collection attaches only to a single tab
connection with no worker-target discovery logic). Consequently:

- `_pdfium_wasm_engine.dart` (the marshalling logic) stays plain,
  directly-callable Dart, exercised both by the worker at runtime *and*
  directly by `test/pdfium_wasm_engine_test.dart` (which bypasses the worker
  entirely, calling the bootstrap and engine functions on the main thread) —
  this is what keeps it visible to the web coverage gate.
- `_pdfium_worker_entry.dart`'s dispatch shell (the part that only ever runs
  inside the worker) is marked `// coverage:ignore-start` / `-end`,
  consistent with the project's existing convention for platform-dispatch
  code in this same file's native counterpart, `pdfium_isolate.dart`.

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
