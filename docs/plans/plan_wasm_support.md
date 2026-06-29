# Web (WASM) PDFium Support

**Status**: Implementing

**PR link**: _pending_

## Problem statement

`betto_pdfium` has no working web backend. `_document_web.dart` is a complete
stub — every `PdfDocumentImpl` method throws `UnsupportedError`. Users in a
Flutter web or `dart2wasm` context cannot use the package at all.

bblanchon/pdfium-binaries already publishes `pdfium-wasm.tgz` (containing
`lib/libpdfium.wasm` + `lib/libpdfium.js`) with every `chromium/NNNN` release,
so no Emscripten build is required. The work has two parts:

1. **Binary distribution** — get the WASM + JS artifact into the manifest,
   decide how it reaches the browser, and update tooling.
2. **Runtime implementation** — replace `_document_web.dart`'s stubs with
   real `dart:js_interop` calls into the Emscripten module.

The Windows plan (`plan_windows_support.md`) is a soft predecessor — it
validates the `update_pdfium_manifest.sh` editing pattern — but `lib_paths` is
an independent schema extension and the two plans can proceed in parallel.

## Open questions

- [x] **Does bblanchon ship a WASM binary with every release?** Yes —
  `pdfium-wasm.tgz` is listed in `spec/01_binary_distribution.md` as a
  known future artifact. Confirmed present in the bblanchon release structure.

- [x] **How does the WASM+JS pair reach the browser?** See "Distribution
  mechanism" in the Investigation section. Decision: **developer-side asset
  copy** — the package ships a `fetch_wasm_assets.sh` script (and a `make
  fetch_wasm_assets` target) that downloads the WASM+JS pair and places them
  where a Flutter web build expects them (`web/assets/pdfium/`). The package
  initialises the module from that well-known relative URL.

  _Rationale:_ `betto_pdfium` is a pure-Dart package with no Flutter
  dependency; it cannot declare Flutter web assets on the user's behalf. A
  CDN URL is fragile (bblanchon GitHub Releases are not a CDN). The
  developer-copy approach matches how packages like `sqlite3_flutter_libs`
  handle WASM distribution, is transparent to the user, and does not require
  network access at runtime.

- [x] **Does the native-assets hook need to handle web/WASM targets?** No.
  The native-assets hook system (`hook/build.dart`) only runs for native
  compilation targets. Flutter web builds use `dart2js` or `dart2wasm` and
  do not invoke the native-assets hook. The WASM binary is distributed as a
  static file asset, not a `CodeAsset`.

- [x] **Does `version_pdfium.json` need a schema extension for dual-file
  artifacts?** Yes. The current schema has a single `lib_path` per platform.
  WASM requires two files: `lib/libpdfium.wasm` and `lib/libpdfium.js`.
  Extend the schema with an optional `lib_paths` array (multi-file) that
  supersedes `lib_path` when present. The single-file `lib_path` remains
  unchanged for all existing platforms.

- [ ] **Is the Emscripten module API surface known?** The claims in the
  investigation section (`MODULARIZE=1`, `EXPORT_NAME=PDFium`, underscore-
  prefixed exports) are Emscripten conventions and have **not** been verified
  against the actual bblanchon `libpdfium.js`. This must be the first action
  of Phase 2 implementation (step 6): download `pdfium-wasm.tgz`, inspect
  `libpdfium.js`, and record the verified API surface. The interop declarations
  in the investigation section may need adjustment. _Blocks step 7._

- [x] **Sync vs async for v1?** Sync on the browser main thread. As noted in
  the existing stub comment, PDFium WASM Emscripten C functions are
  synchronous. All `PdfDocumentImpl` methods become thin wrappers that call
  the Emscripten functions directly. Callers already expect `Future`-returning
  methods, so the sync internal implementation is invisible to them. A Web
  Worker offload path is explicitly deferred to a later roadmap item. The
  README web section must warn callers that large document operations will
  block the browser main thread; the `Future.delayed(Duration.zero)` trick
  between streaming pages does not help during a single long PDFium call.

- [x] **Does the PDFium isolate (`PdfiumIsolate`) apply on web?** No.
  `pdfium_isolate.dart` uses `dart:ffi`, `dart:io`, and `dart:isolate` — none
  of which are available on web. `_document_web.dart` has no dependency on
  `PdfiumIsolate` and manages the WASM module state directly as a static field.

- [x] **How does the per-document WASM heap buffer get freed on both `close()`
  and the Finalizer path?** The document registry mirrors the native pattern
  from `pdfium_isolate.dart` line 85: `Map<int, ({int docPtr, int bufPtr})]`.
  On `close()`: call `FPDF_CloseDocument(docPtr)` then `module._free(bufPtr)`.
  Dart's `Finalizer<({int docPtr, int bufPtr})>` is backed by
  `FinalizationRegistry` on web (available in all modern browsers) — it works
  in browser context. The Finalizer is registered in `fromBytes()` and
  detached on explicit `close()`. A leaked `_malloc` buffer has no GC backstop
  so this is essential, not optional.

- [x] **How is `renderPageToBytes` stride/row-padding and struct-output
  handled across the WASM heap boundary?** Two cases:
  - **Bitmap stride**: On WASM, `FPDFBitmap_GetBuffer()` returns an int
    (WASM memory address). The raw pixels are `module.HEAPU8.sublist(ptr,
    ptr + stride * height)`. The existing `stripBitmapStride()` function in
    `pdfium_isolate.dart` is pure Dart (`Uint8List` only, no FFI) and is
    extracted to `lib/src/document/_bitmap_utils.dart` so both backends share
    it. This adds one file to the change list.
  - **Struct-output calls** (`FS_RECTF`, `FPDF_IMAGEOBJ_METADATA`): allocate
    with `module._malloc(size)`, pass the int pointer, then read fields by
    offset using `module.HEAPF32` for floats and `module.HEAP32` for ints.
    e.g. `FS_RECTF` (4 floats, 16 bytes): read `HEAPF32[ptr >> 2]`,
    `HEAPF32[(ptr >> 2) + 1]`, etc. `_malloc` must be freed after reading.

- [x] **Can Phase 2 be split into incremental capability-based PRs?** Yes —
  see updated Implementation plan. The stub already throws `UnsupportedError`
  for all methods, so each capability-group PR can land independently without
  regressing callers who are already on the "unsupported" path. Five PRs are
  planned (see Phase 2).

- [x] **Is Windows a genuine prerequisite?** No. `lib_paths` is independent
  of the Windows single-file `lib_path` entry. The prerequisite is downgraded
  to a soft sequencing preference (validates the manifest-editing pattern).
  The two plans can proceed in parallel.

## Investigation

### Binary artifact

bblanchon artifact: `pdfium-wasm.tgz`
Contents:
- `lib/libpdfium.wasm` — compiled PDFium WebAssembly binary
- `lib/libpdfium.js` — Emscripten glue (`MODULARIZE=1, EXPORT_NAME=PDFium`)

The JS file is the entry point: it fetches and instantiates the `.wasm`. Both
files must be co-located; the JS expects the `.wasm` at a relative path.

### Distribution mechanism

The chosen approach: **developer-side static asset copy**.

The package provides a helper script and `make` target:

```
make fetch_wasm_assets   # downloads pdfium-wasm.tgz, verifies SHA-256,
                         # extracts to integration_test_app/web/assets/pdfium/
                         # (or a user-configurable output path)
```

Users of `betto_pdfium` in a Flutter web app must:
1. Run `make fetch_wasm_assets` once per PDFium version bump (or in CI).
2. Copy the extracted files to their app's `web/assets/pdfium/` directory.
3. `_document_web.dart` loads the module from the path
   `assets/pdfium/libpdfium.js` (relative to the app origin).

Document this clearly in the package `README.md` web section.

### `version_pdfium.json` schema extension

Extend with an optional `lib_paths` list for multi-file artifacts:

```json
{
  "bblanchon_build": "7906",
  "platforms": {
    "macos-arm64": {
      "url": "...",
      "lib_path": "lib/libpdfium.dylib",
      "sha256": "..."
    },
    "wasm": {
      "url": "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7906/pdfium-wasm.tgz",
      "lib_paths": ["lib/libpdfium.wasm", "lib/libpdfium.js"],
      "sha256": "..."
    }
  }
}
```

The `lib_paths` key is only present for `wasm`. All other platforms retain
`lib_path`. Consumers that only handle the hook's supported platforms (macOS,
Linux, Windows) read `lib_path` only. The new `fetch_wasm_assets.sh` reads
`lib_paths`.

### `_document_web.dart` implementation

The stub file has the correct class structure and method signatures. The
implementation replaces each `throw UnsupportedError(...)` body. This is a
from-scratch port of the engine boundary from `pdfium_isolate.dart` (~80
PDFium C functions plus UTF-16 string decoding, struct field reads, bitmap
stride handling, annotation subtype dispatch, and the bookmark/action tree
walk) — not a simple fill-in.

**Module lifecycle (static state):**

```dart
// Emscripten PDFium module — loaded once per page lifetime.
static PDFiumModule? _module;

static Future<PDFiumModule> _getModule() async {
  return _module ??= await _loadModule();
}

static Future<PDFiumModule> _loadModule() async {
  // 1. Inject the <script> tag for libpdfium.js (exact API TBD — step 6)
  // 2. Await the module factory (exact name TBD — step 6)
  // 3. Call FPDF_InitLibraryWithConfig(null)
}
```

**Document handle registry — mirrors native pattern:**

`Map<int, ({int docPtr, int bufPtr})>` as a static field, mirroring
`pdfium_isolate.dart` line 85 (`Map<int, ({int docAddress, int bufferAddress})>`).
Token → (FPDF_DOCUMENT address, PDF bytes buffer address) in WASM address
space. No Isolate boundary to cross.

**WASM heap memory for PDF bytes:**

```dart
// Allocate WASM heap, copy bytes, load document.
// bufPtr must stay allocated until FPDF_CloseDocument (PDFium does not copy).
final bufPtr = module._malloc(bytes.length);
module.HEAPU8.setAll(bufPtr, bytes);
final docPtr = module._FPDF_LoadMemDocument64(bufPtr, bytes.length, 0);
_registry[token] = (docPtr: docPtr, bufPtr: bufPtr);
```

**Finalizer for leak prevention:**

```dart
static final _finalizer = Finalizer<({int docPtr, int bufPtr})>(
  (rec) {
    _module?._FPDF_CloseDocument(rec.docPtr);
    _module?._free(rec.bufPtr);
  },
);
// Register in fromBytes(); detach on explicit close().
```

Dart's `Finalizer` is backed by `FinalizationRegistry` in browser JS
environments (all modern browsers) and works correctly on web.

**Bitmap stride for `renderPageToBytes`:**

On WASM, `FPDFBitmap_GetBuffer()` returns an int (WASM heap address). Pixels
are read as `module.HEAPU8.sublist(ptr, ptr + stride * height)`. The existing
`stripBitmapStride()` function in `pdfium_isolate.dart` is pure Dart (no FFI,
only `Uint8List`) and is extracted to `lib/src/document/_bitmap_utils.dart`
so both the native and web backends can import it.

**Struct-output calls (`FS_RECTF`, `FPDF_IMAGEOBJ_METADATA`):**

Allocate a WASM stack frame with `module._malloc(size)`, pass the int pointer
to the PDFium function, then read fields by typed-array offset:

```dart
final ptr = module._malloc(16); // FS_RECTF: 4 × float32 = 16 bytes
try {
  module._FPDF_PageObj_GetBounds(pageObj, ptr, ptr+4, ptr+8, ptr+12);
  // Read via HEAPF32; index is byte-offset ÷ 4
  final left   = module.HEAPF32[ptr >> 2];
  final bottom = module.HEAPF32[(ptr >> 2) + 1];
  // ...
} finally {
  module._free(ptr);
}
```

**`dart:js_interop` declarations (provisional — verify in step 6):**

```dart
// Exact factory name and modularize style TBD after inspecting libpdfium.js.
extension type PDFiumModule._(JSObject _) implements JSObject {
  external int _malloc(int size);
  external void _free(int ptr);
  external JSUint8Array get HEAPU8;
  external JSFloat32Array get HEAPF32;
  external JSInt32Array get HEAP32;
  external int _FPDF_LoadMemDocument64(int data, int size, int password);
  external void _FPDF_CloseDocument(int doc);
  external int _FPDF_GetPageCount(int doc);
  // … one declaration per PDFium function used
}
```

### Files to change

| File | Change |
|------|--------|
| `version_pdfium.json` | Add `wasm` entry with `lib_paths` |
| `scripts/update_pdfium_manifest.sh` | Download + checksum `pdfium-wasm.tgz`; add wasm block |
| `scripts/fetch_wasm_assets.sh` | New script: download, verify, extract WASM+JS to target dir |
| `packages/betto_pdfium/betto_pdfium.mk` | Add `fetch_wasm_assets` and `web_test` / `web_coverage` targets |
| `lib/src/document/_bitmap_utils.dart` | New: extract `stripBitmapStride` from `pdfium_isolate.dart` (pure Dart, no FFI; shared by both backends) |
| `lib/src/document/pdfium_isolate.dart` | Import `_bitmap_utils.dart`; remove inline `stripBitmapStride` |
| `lib/src/document/_pdfium_js_interop.dart` | New: `dart:js_interop` extension type declarations for `PDFiumModule` |
| `lib/src/document/_document_web.dart` | Full implementation (five incremental PRs — see Phase 2) |
| `packages/betto_pdfium/pubspec.yaml` | Add `web:` to `platforms:` |
| `docs/spec/01_binary_distribution.md` | Document WASM artifact, schema extension, distribution |
| `packages/betto_pdfium/README.md` | Add web setup section with main-thread blocking warning |
| `integration_test_app/web/` | Add `assets/pdfium/` placeholder + gitignore |
| `test/pdf_document_web_test.dart` | New: dedicated web test suite (fetch-based, no dart:io) |
| `CLAUDE.md` | Document `make web_test` and `make web_coverage` commands |

`hook/build.dart` is **not** changed — the hook only runs for native targets.

### Testing

The existing test suite uses `File('test/fixtures/$name').readAsBytesSync()`
(`dart:io`) and passes `dylibPath:` to `fromBytes()`. Neither works under
`dart test -p chrome` — `dart:io` is unavailable in the browser and
`dylibPath` is meaningless. The existing suite **cannot** be run in Chrome
unchanged.

A separate dedicated web test file is required: `test/pdf_document_web_test.dart`.

- Loads fixtures via `fetch()` (relative URL from the `dart test` local test
  server, which serves `test/` as the root).
- Omits `dylibPath:` entirely.
- Covers the same PDF fixtures and assertion logic as the native suite.
- Runs under `dart test -p chrome` with a headless Chrome driver.

Headless Chrome is available on `ubuntu-latest` GitHub Actions runners
(`google-chrome-stable` or `chromium`). A `make web_test` target invokes
`dart test -p chrome test/pdf_document_web_test.dart`.

The web test file is authored incrementally alongside each Phase 2 PR
(capability-by-capability), not written as one large file at the end.

### Coverage

`_document_web.dart` never appears in the native lcov report (the
`dart.library.js_interop` conditional import is never selected on macOS/Linux),
so the 90% native gate does not protect it. This is a genuine gap, not an
acceptable loophole.

**Web coverage is enforced separately:**

- `dart test -p chrome --coverage=coverage/web/` produces lcov data for the
  browser run.
- `make web_coverage` runs this and enforces ≥ 90% line coverage on the web
  target (using the same `genhtml` + line-count approach as `make coverage`).
- The `make cicd` target includes `web_coverage` so it gates CI.

The 90% threshold applies independently to the native run and the web run.
CLAUDE.md is updated to document both targets.

## Implementation plan

### Phase 1: Binary distribution (one PR)

- [ ] **1. Update `update_pdfium_manifest.sh`**
  - Add `WASM_SHA=$(_fetch_sha "pdfium-wasm.tgz" "$WORK/wasm.tgz")`.
  - Add `"wasm"` block to the `version_pdfium.json` heredoc with `lib_paths`.

- [ ] **2. Run `make update_pdfium_manifest`**
  - Rewrites `version_pdfium.json` with the `wasm` entry.

- [ ] **3. Write `scripts/fetch_wasm_assets.sh`**
  - Reads `version_pdfium.json` `wasm.url` and `wasm.sha256`.
  - Downloads `pdfium-wasm.tgz`, verifies SHA-256.
  - Extracts `lib/libpdfium.wasm` and `lib/libpdfium.js` to
    `integration_test_app/web/assets/pdfium/` (default; overridable via
    `WASM_OUTPUT_DIR` env var).
  - Idempotent (skips if already installed at same build number).

- [ ] **4. Add `fetch_wasm_assets`, `web_test`, and `web_coverage` targets
  to `betto_pdfium.mk`**

- [ ] **5. Update `spec/01_binary_distribution.md`**
  - Document WASM artifact and `lib_paths` schema extension.
  - Document distribution mechanism (developer-side asset copy).
  - Add `fetch_wasm_assets` to consumer-mapping table.

- [ ] **5a. Add `web:` to `platforms:` in `pubspec.yaml`.**

### Phase 2: Runtime implementation (five incremental PRs)

Each PR lands independently. The stub continues throwing `UnsupportedError`
for unimplemented methods — callers already handle this path.

#### Step 6 — Emscripten API verification (gates all Phase 2 PRs)

- [ ] **6. Inspect the real `libpdfium.js` from `pdfium-wasm.tgz`:**
  - Record the actual `EXPORT_NAME` (assumed `PDFium` — verify).
  - Record whether `MODULARIZE=1` or `EXPORT_ES6` is used.
  - Confirm that `_FPDF_*` exports are present (vs. `ccall`/`cwrap` only).
  - Confirm C functions are synchronous (not `Asyncify`-wrapped).
  - Update `_pdfium_js_interop.dart` declarations to match.
  - Update this plan section with the verified facts.
  _This step blocks all runtime implementation._

#### Step 7 — Shared utilities (prerequisite for all web PRs)

- [ ] **7. Extract `stripBitmapStride` to `_bitmap_utils.dart`**
  - Move the function from `pdfium_isolate.dart` to a new
    `lib/src/document/_bitmap_utils.dart` (pure Dart, no FFI import).
  - Update `pdfium_isolate.dart` to import from `_bitmap_utils.dart`.
  - No behaviour change; existing tests still pass.

#### PR 2a — Module load + document lifecycle

- [ ] **8. Implement `_loadModule()`, `fromBytes()`, `close()`, `pageCount`**
  - Create `_pdfium_js_interop.dart` with verified extension type declarations.
  - Implement `_loadModule()`: inject `<script>`, await factory, call
    `FPDF_InitLibraryWithConfig`.
  - Implement `fromBytes()`: allocate WASM heap, copy bytes,
    `FPDF_LoadMemDocument64`, register `(docPtr, bufPtr)` token, attach
    Finalizer.
  - Implement `close()`: `FPDF_CloseDocument`, `_free(bufPtr)`, detach
    Finalizer.
  - Implement `pageCount`.
  - Write `test/pdf_document_web_test.dart` covering load/close/pageCount
    via `fetch()`-loaded fixtures.

#### PR 2b — Metadata and page geometry

- [ ] **9. Implement `getMetadata`, `getDocumentInfo`, `getPageSize`,
  `isPlainTextExtractable`**
  - UTF-16 string reads via `HEAPU8` (two bytes per char, little-endian).
  - Add tests to `pdf_document_web_test.dart`.

#### PR 2c — Text and annotation extraction

- [ ] **10. Implement `extractPlainText`, `extractAnnotations`**
  - Streaming: yield between pages with `Future.delayed(Duration.zero)`.
  - Annotation subtype dispatch mirrors `pdfium_isolate.dart`.
  - Add tests.

#### PR 2d — Rendering

- [ ] **11. Implement `renderPageToBytes`, `getThumbnail`**
  - Use `stripBitmapStride` from `_bitmap_utils.dart`.
  - BGRA buffer read from `HEAPU8` with stride handling.
  - Add tests.

#### PR 2e — Images, search, TOC

- [ ] **12. Implement `extractImages`, `renderImage`, `search`,
  `tableOfContents`**
  - Struct-output calls via `_malloc`/`HEAPF32`/`HEAP32` pattern.
  - Bookmark tree walk mirrors native `_handleGetToc`.
  - Add tests.

### Phase 3: Documentation and release (one PR)

- [ ] **13. Update `packages/betto_pdfium/README.md`**
  - Add "Web" section: `make fetch_wasm_assets` step, `web/assets/pdfium/`
    placement, and an explicit main-thread blocking warning for large documents.

- [ ] **14. Update `CLAUDE.md`** — document `make web_test` and
  `make web_coverage` in the Commands section.

- [ ] **15. Run `make pre_commit`** — all native tests pass.

- [ ] **16. Run `make web_coverage`** — web coverage ≥ 90%.

- [ ] **17. Update `docs/roadmap/0_02.md`** — mark WASM item complete.

## Reviews

### Review 1: 2026-06-29

**Problem Statement Assessment**

The problem is real and worth solving. `_document_web.dart` is a pure stub —
every method throws `UnsupportedError`, so the package is unusable in any
Flutter web or `dart2wasm` context. WASM support is an explicit, accepted item
on the v0.02 roadmap (`docs/roadmap/0_02.md`), and the spec already lists
`pdfium-wasm.tgz` as a known future artifact in
`docs/spec/01_binary_distribution.md`. Alignment is good and the motivation is
clearly stated.

One framing concern: the plan repeatedly describes the runtime work as
"replace each `throw UnsupportedError(...)` body with a real implementation"
and "the stub file already has the correct class structure." This badly
understates the work. The stub is a façade; the actual PDFium logic lives in
`pdfium_isolate.dart` (3,051 lines) and `_document_native.dart` (790 lines),
and spans **~80 distinct PDFium C functions** plus substantial marshalling
(UTF-16 string decode, struct field reads, bitmap stride handling, annotation
subtype dispatch, the bookmark/action tree walk). The web backend must
reimplement all of that marshalling against `dart:js_interop` and the
Emscripten heap. This is a from-scratch reimplementation of the entire engine
boundary, not a stub fill-in. See Recommendations.

**Proposed Solution Assessment**

Strengths:

- The distribution decision (developer-side asset copy via
  `fetch_wasm_assets.sh`, no runtime CDN, SHA-256 pinned) is the right call and
  consistent with the existing bblanchon supply-chain contract and the
  `sqlite3_flutter_libs` precedent. The rationale is well argued.
- Correctly identifies that the native-assets hook does **not** run for web
  targets, and that `PdfiumIsolate` (dart:ffi/dart:io/dart:isolate) does not
  apply on web. Keeping the WASM module state as a static field in
  `_document_web.dart` is the correct shape.
- The `lib_paths` optional-array schema extension is minimal and backward
  compatible — single-file `lib_path` is untouched for all existing platforms.
- Layer architecture is preserved: `_document_web.dart` stays pure Dart
  (`dart:js_interop`, `dart:typed_data`), with no Flutter or `dart:ui` import,
  so the Core-layer boundary the package depends on is intact.

Weaknesses:

- **The testing strategy rests on a false assumption.** The plan says tests can
  be run by "configure existing tests to also run in Chrome." They cannot, as
  written. Every fixture-based test loads bytes via
  `File('test/fixtures/$name').readAsBytesSync()` (`dart:io`) and passes
  `dylibPath:` to `fromBytes` — both are native-only. Under `dart test -p
  chrome`, `dart:io` is unavailable and `dylibPath` is meaningless. The web
  test suite must be a **separate** set of tests that load fixtures via
  `fetch()`/`rootBundle` and omit `dylibPath`. This is real, non-trivial work
  that the plan does not budget for. Phase 2 step 9 hand-waves it.

- **Several technical claims are asserted, not verified.** Open questions 5 and
  6 state the Emscripten export name is `PDFium`, that `MODULARIZE=1` is set,
  that functions are reachable as `pdfium._FPDF_XXX()`, and that the C
  functions are synchronous. These are plausible Emscripten defaults but are
  marked confirmed without evidence from the actual bblanchon `libpdfium.js`.
  If the build instead uses `EXPORT_ES6`, a different `EXPORT_NAME`, async
  instantiation, or does not export the underscore-prefixed symbols (only
  `ccall`/`cwrap`), the entire interop layer changes. These need to be verified
  against the real artifact before this is "Investigated," not assumed.

- **`renderPageToBytes` BGRA byte-order and stride handling on WASM is
  unexamined.** The native path reads `FPDFBitmap_GetBuffer` + `GetStride` and
  copies row-by-row. On WASM the buffer is a pointer into `HEAPU8` and the same
  stride/row-padding logic must be reimplemented. The plan's per-method sketch
  only covers the trivial `getMetadata` shape and does not address the
  bitmap/stride or struct-output (`FPDF_IMAGEOBJ_METADATA`,
  `FS_RECTF`) cases, which are the hard parts.

**Architecture Fit**

Good. The conditional-import façade in `pdf_document.dart` already wires
`dart.library.js_interop → _document_web.dart`, so no public API change is
needed and the contract "the public API is identical on all platforms" is
honoured. The spec update (`01_binary_distribution.md`) is correctly included
in scope. The `lib_paths` extension is the only schema change and it is
additive.

Note the path-coupling invariant: `version_pdfium.json` URLs embed the build
number as `chromium%2F7906`. The new `wasm` entry must be regenerated by
`make update_pdfium_manifest`, not hand-edited, so it stays consistent with the
other platforms on every version bump.

**Risk & Edge Cases**

- **Prerequisite ordering vs. status.** The plan (and the roadmap) state Windows
  must land first to exercise the schema-extension path. Yet `lib_paths` is a
  *different* extension from anything Windows introduces — Windows is a plain
  single-file `lib_path` entry. So the stated prerequisite does not actually
  de-risk the WASM schema work. Either the dependency is weaker than claimed
  (the plans are independent and can proceed in parallel), or the intent was
  that Windows validates the `update_pdfium_manifest.sh` editing pattern
  generally. Worth clarifying so this plan is not blocked on a false
  dependency.
- **WASM heap lifetime.** The sketch correctly notes the PDF byte buffer must
  outlive the document (PDFium does not copy it) and be freed only after
  `FPDF_CloseDocument`. Good. But the registry must also guarantee the buffer
  pointer is tracked per-document and freed on `close()` and on the Finalizer
  path — a leaked `_malloc` on web has no GC backstop. The plan should state
  the buffer-pointer bookkeeping explicitly.
- **Main-thread blocking.** v1 sync-on-main-thread is a reasonable scoping
  choice, but rendering a large page or extracting text from a 300-page
  document will freeze the browser tab. The deferral to a Web Worker is fine,
  but the README web section must warn callers prominently, and the streaming
  methods' `Future.delayed(Duration.zero)` yield trick does not actually
  unblock the main thread during a single long PDFium call — it only yields
  *between* pages. State this limitation honestly.
- **Coverage gate.** The plan asserts the 90% gate "applies to the native run
  and is unaffected." That is true mechanically (the web file is never selected
  on macOS/Linux, so it does not appear in the native lcov). But it means the
  entire web backend ships with **zero** contribution to the enforced coverage
  number — the project's primary quality gate is blind to it. The web test
  suite must therefore have its own enforced coverage measurement, or the
  90%-on-native framing becomes a loophole that lets a large, untested file
  land. CLAUDE.md requires 90% "at all times"; a second runtime with no gate
  violates the spirit of that. Decide how web coverage is enforced.

**Recommendations**

1. **Reframe Phase 2 scope.** Replace the "replace the stubs" language with an
   explicit enumeration of the PDFium functions and marshalling routines to be
   ported (the ~80 functions in `pdfium_isolate.dart`). Consider splitting the
   runtime work by capability (load+metadata+pageCount first; then text; then
   render; then images/annotations/search/TOC/thumbnail) so it can land
   incrementally behind the already-throwing stub. A single 80-function PR is
   not reviewable.
2. **Rewrite the testing section.** Acknowledge that the existing suite cannot
   run in Chrome unchanged. Specify a dedicated web test file that loads
   fixtures via `fetch()`/`rootBundle`, and a concrete plan for measuring and
   enforcing web coverage.
3. **Verify the Emscripten contract against the real artifact** before moving
   back to Investigated. Download `pdfium-wasm.tgz`, inspect `libpdfium.js`,
   and record the actual `EXPORT_NAME`, modularize style, and whether
   underscore-prefixed exports are present. Pin these as confirmed facts.
4. **Address bitmap stride / struct-output marshalling** in the investigation,
   since these are the highest-risk parts of the port and are currently
   unaddressed.
5. **Clarify the Windows prerequisite.** State whether it is a genuine blocker
   or a soft sequencing preference, given `lib_paths` is independent of the
   Windows changes.

The plan is well-researched on distribution and architecture, and the
distribution decision is sound. But the runtime-implementation and testing
sections are not yet at "ready to implement" depth, and two load-bearing
assumptions (Emscripten API surface; existing tests running in Chrome) are
unverified or incorrect. Recommend resolving the open questions below before
returning to `Investigated`.

**Open questions**

- [x] How will the web test suite actually load fixtures and assert coverage?
      _Resolved:_ A dedicated `test/pdf_document_web_test.dart` loads fixtures
      via `fetch()` from the `dart test` local server and omits `dylibPath:`.
      Web coverage is enforced separately via `make web_coverage`
      (`dart test -p chrome --coverage=coverage/web/`) with a ≥ 90% gate,
      included in `make cicd`. See updated Testing and Coverage sections.
- [ ] Has the real bblanchon `libpdfium.js` been inspected to confirm
      `EXPORT_NAME=PDFium`, `MODULARIZE=1`, synchronous C functions, and the
      availability of `_FPDF_*` exports? _Unresolved — requires downloading
      the artifact. Scheduled as implementation step 6 (gates all Phase 2
      PRs). The interop declarations are marked provisional until then._
- [x] How is the per-document WASM heap buffer pointer tracked and guaranteed
      freed? _Resolved:_ Registry is `Map<int, ({int docPtr, int bufPtr})]`
      mirroring the native pattern. `close()` calls `FPDF_CloseDocument` then
      `_free(bufPtr)`. A `Finalizer<({int docPtr, int bufPtr})>` backed by
      `FinalizationRegistry` (available in all modern browsers) provides the
      leak-prevention backstop. See updated `_document_web.dart` section.
- [x] How is bitmap stride/row-padding and struct-output marshalling handled?
      _Resolved:_ `stripBitmapStride` is extracted to `_bitmap_utils.dart`
      (pure Dart); bitmap pixels are read from `HEAPU8`. Struct-output calls
      use `_malloc`/`HEAPF32`/`HEAP32` with explicit offset reads; pointer is
      freed after reading. See updated implementation section.
- [x] Is Windows genuinely a prerequisite? _Resolved:_ No — downgraded to a
      soft sequencing preference. `lib_paths` is independent of the Windows
      single-file entry. The two plans can proceed in parallel.
- [x] Should Phase 2 be split into incremental PRs? _Resolved:_ Yes — five
      capability-based PRs (2a–2e) behind the existing throwing stub. See
      updated implementation plan.

## Summary

_Pending implementation._
