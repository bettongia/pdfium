# Web (WASM) Backend — Web Worker Offload

**Status**: Implementing

**PR link**: _pending_

## Problem statement

The web (WASM) backend (`lib/src/document/_document_web.dart`) runs all
PDFium calls synchronously on the browser's main thread. For large or complex
documents, a single call (e.g. rendering a large page, extracting text from a
long document) can freeze the tab for a noticeable period. This was an
accepted v1 scoping decision in `plans/completed/plan_wasm_support.md`, with
the Web Worker offload explicitly deferred — it is the reason `README.md`
marks Web (WASM) platform support as "(beta)" rather than plain "Supported".

This plan investigates and implements a background-thread execution model for
the web backend so PDFium work no longer blocks the main thread, bringing web
parity with native platforms (where `PdfiumIsolate` already isolates all FFI
calls to a dedicated `Isolate`).

## Investigation

### Current state

`_document_web.dart` holds the PDFium Emscripten module and a document
registry (`Map<int, ({int docPtr, int bufPtr})>`) as **static fields on the
main thread**. Every `PdfDocumentImpl` method calls directly into the module
(`module.fpdf*(...)`), which is a synchronous WASM call — there is no
asynchronous boundary at all today, unlike the native backend.

### Native precedent

`pdfium_isolate.dart` gives a structural template worth mirroring:

- A single dedicated `Isolate` owns the PDFium bindings and a
  `Map<int, ({int docAddress, int bufferAddress})>` document registry
  (`pdfium_isolate.dart:85`).
- All calls cross the isolate boundary as typed command objects
  (`isolate_messages.dart`) sent over a `SendPort`/`ReceivePort` pair, with a
  reply port carried on each command for the response.
- Handles are opaque integer tokens outside the isolate — pointers never
  cross the boundary directly.

A worker-based web design should adopt the same shape: a command/response
protocol, an opaque token registry that lives entirely on the worker side, and
a thin RPC client on the main thread. **However, the mechanism for crossing
the boundary is genuinely different on web, and this is the crux of the open
questions below.**

### Why this is not a mechanical port of the isolate pattern — CONFIRMED

`dart:isolate` does not mean the same thing on web as it does on native, and
this is now confirmed against primary sources rather than assumed:

- [Flutter docs — Isolates and `compute()` on the web](https://docs.flutter.dev/perf/isolates#web-platforms-and-compute):
  *"Dart web platforms, including Flutter web, don't support isolates."*
  `compute()` on web runs the computation **on the main thread**; it is only
  a compatibility shim so shared code compiles, not a concurrency mechanism.
- [dart.dev — Concurrency on the web](https://dart.dev/language/concurrency#concurrency-on-the-web):
  *"The Dart web platform ... does not support isolates."* Neither source
  distinguishes dart2js/dartdevc from dart2wasm — **the restriction applies
  uniformly to all web compile targets**, not just the older JS compilers.
  This resolves the "dart2wasm-only" scope-cut question from the first draft
  of this plan: there is no compile target on which `Isolate.spawn` gives
  real background execution on web today. The dart2js-vs-dart2wasm framing
  in the original draft of this section was speculative and is superseded by
  this finding.
- The dart.dev page names the actual alternative directly: *"Dart web apps
  can use web workers to run scripts in background threads similar to
  isolates,"* while cautioning that *"web workers' functionality and
  capabilities differ somewhat from isolates"* — specifically, (1) data sent
  between a worker and the main thread is **copied** (structured clone),
  which can be slow for large messages, and (2) a worker is only created "by
  declaring a separate program entrypoint and compiling it separately" —
  there is no `Isolate.spawn`-equivalent one-liner.

**Conclusion: `dart:isolate` is not usable at all for this feature on web.**
The implementation must use a raw `Worker` (`package:web`) with a hand-rolled
`postMessage` protocol. This resolves the isolate-vs-worker open question
below outright, and removes it as a design fork — there was never a real
choice.

Neither source mentions `Cross-Origin-Opener-Policy` / cross-origin isolation
requirements for plain `Worker` + `postMessage` usage — that requirement is
specific to `SharedArrayBuffer`/shared-memory threading, which a message-copy
worker protocol does not need. Combined with `plan_wasm_support.md`'s
confirmed finding that the bblanchon `pdfium.wasm` build has **no threads and
no Asyncify**, there is no indication this feature requires COOP/COEP headers
on the consumer's server. This should still be confirmed empirically (a
`Worker` instantiating `pdfium.js` unmodified) before being treated as settled,
but it is no longer the significant open risk the first draft treated it as.

### Implementation approach: hand-rolled `Worker`, not `dart:isolate`

The implementation manages a raw `Worker` (`package:web`) directly:

- A dedicated worker bootstrap script loads `pdfium.js`/`pdfium.wasm` and
  speaks a custom `postMessage` protocol.
- The request/response correlation (message IDs, matching replies to callers)
  that `SendPort`/`ReceivePort` gives for free on native must be hand-built —
  mirroring the *shape* of `isolate_messages.dart`'s command classes, but
  serialised across `postMessage` instead of sent as Dart objects.
- Typed-array results (bitmap bytes) can move without copying via
  transferable objects (`postMessage(data, [buffer])`), avoiding the
  structured-clone cost the dart.dev page warns about for large messages —
  this matters directly for `renderPageToBytes`/`getThumbnail`, which return
  multi-megabyte BGRA buffers.
- Confirmed real cost: the worker needs its **own compiled entry point**,
  distinct from the main app bundle (dart.dev: "declaring a separate program
  entrypoint and compiling it separately"). This is a genuine build-pipeline
  complication beyond the current `make fetch_wasm_assets` static-file-copy
  model — see the distribution open question below.

`package:sqlite3_web` solves close to the same problem (WASM SQLite blocking
the main thread) with a dedicated worker + custom RPC channel, and is worth
reading as a design reference (not a dependency) before finalising the
protocol shape here.

### Worker glue: DECIDED — option (b), pre-compiled Dart, checked in

The (a) plain-JS vs. (b) pre-compiled-Dart fork is now resolved in favour of
**(b)**, on the strength of two corrected/confirmed findings from Review 1 and
the coverage investigation above:

1. Option (a) would duplicate `_document_web.dart`'s marshalling body (the
   two-call buffer pattern, UTF-16LE decoding, stride stripping, annotation
   walking), not the trivial `_pdfium_js_interop.dart` bindings as an earlier
   draft of this plan wrongly assumed — a large, intricate, permanently-
   diverging hand-written-JS surface.
2. The confirmed coverage gap means marshalling logic must stay as plain,
   directly-callable Dart regardless — under (b) the worker simply *calls*
   that already-tested logic from within its own thin dispatch shell; under
   (a) none of it would ever be Dart, or covered, at all.

**Why (b) doesn't reintroduce a consumer build step.** The dart.dev
"declaring a separate program entrypoint and compiling it separately"
constraint is about *who* compiles the worker, not *whether* it can be
pre-compiled once. The worker entry point's logic is entirely self-contained
within `betto_pdfium` — it only needs PDFium marshalling and the RPC protocol,
nothing about any particular consumer app's code — so nothing prevents
`betto_pdfium`'s own release process from compiling it once, independent of
any consumer, exactly the way `pdfium.wasm`/`pdfium.js` themselves are
pre-built binaries the package merely distributes. The worker's compiled JS is
also fully decoupled from whatever compiler produced the main app's own bundle
(dart2js or dart2wasm) — the two communicate only via `postMessage`, so there
is no requirement that they share a compile target.

**Concrete sketch:**

- New file `lib/src/document/_pdfium_worker_entry.dart` — a `void main()` that
  installs a `self.onmessage` (`WorkerGlobalScope`) listener, loads the PDFium
  module via `importScripts('pdfium.js')` (the worker-context equivalent of
  today's `<script>`-tag injection — DOM APIs are unavailable in worker scope,
  so this is a real, small divergence from `_loadModule()`'s current
  implementation, not a drop-in reuse), and dispatches incoming commands to
  the *same* marshalling functions `_document_web.dart` already defines and
  the existing test suite already exercises directly.
- A new maintainer-only `make` target in `betto_pdfium.mk`, run when
  `_pdfium_worker_entry.dart` or its dependencies change — analogous to
  `make repack_ios_xcframework` in spirit (a release-time regeneration step,
  not something consumers ever run):

  ```makefile
  # build_wasm_worker: regenerate the checked-in worker entry-point bundle.
  # Run by maintainers after changing _pdfium_worker_entry.dart or its
  # dependencies; consumers never run this.
  build_wasm_worker:
      cd $(BETTO_PKG) && dart compile js -O2 \
          -o lib/assets/pdfium_worker.js \
          lib/src/document/_pdfium_worker_entry.dart
  .PHONY: build_wasm_worker
  ```

- The resulting `lib/assets/pdfium_worker.js` is checked into the package
  repository — small checked-in build artifacts are an established pattern in
  this package family (`zstd`'s `lib/assets/zstd.wasm`), though **the
  delivery mechanism differs, not just the artifact**: `zstd` reaches
  consumers via Flutter's `flutter: assets:` package-asset auto-bundling,
  which `betto_pdfium` cannot use (it has no `flutter:` pubspec section and
  must stay pure Dart). `pdfium_worker.js` reaches consumers the same way
  `pdfium.wasm`/`pdfium.js` already do — via `fetch_wasm_assets.sh` copying it
  into `web/assets/pdfium/` — not via package-asset bundling. It is expected
  to be small (RPC dispatch + calls into existing logic, not a WASM binary),
  unlike `pdfium.wasm` itself, but that is the only thing it shares with the
  zstd precedent.
- `fetch_wasm_assets.sh` (or its future equivalent) gains one line: after
  extracting `pdfium.wasm`/`pdfium.js` from the bblanchon tarball, also copy
  the package's own checked-in `lib/assets/pdfium_worker.js` into the same
  `web/assets/pdfium/` output directory. This preserves the existing
  single-command consumer workflow exactly — no new step is added to what a
  consumer runs. That copy must resolve `lib/assets/pdfium_worker.js` via a
  path relative to `betto_pdfium`'s own package root as installed in the
  consumer's pub cache, not a path relative to a source checkout — the script
  runs inside a consumer app that has `betto_pdfium` as a pub dependency, not
  inside this repository.

This design keeps the package-boundary promise intact: `betto_pdfium` owns and
ships the compiled worker artifact; a consumer's only action remains running
the existing asset-fetch step.

### Third-party alternative considered: `isolate_manager` — not recommended

[`isolate_manager`](https://pub.dev/packages/isolate_manager) (v6.3.2,
verified publisher, actively maintained) was evaluated as a possible
dependency to shortcut the hand-rolled `Worker`/`postMessage` protocol. It
provides a uniform isolate-like API across native, web, and WASM, with
`compute()`-style one-off calls and `createShared()`/`create()` for
longer-lived isolates, auto-compiling annotated Dart functions into JS Web
Workers via a `dart run isolate_manager:generate` CLI step. It independently
confirms this plan's core finding — that `dart:isolate` doesn't work on web
and Web Workers are the real mechanism — but three mismatches make it
unsuitable here:

1. **The code-generation step is app-scoped, not library-scoped.** The
   generator "scans the `lib/` directory by default and outputs to `web/`" —
   this is designed to run inside the *consuming app's* own build, not to be
   pre-run once by a library author and shipped as a static artifact. Adopting
   it would mean every app depending on `betto_pdfium` (`betto_pdf_widgets`
   included) would need to add `isolate_manager` as a dev dependency and run
   its generator themselves. That directly contradicts the package boundary
   already settled above — `betto_pdfium` owns the worker glue in full, and a
   consumer's only responsibility is the existing one-time asset-fetch step.
2. **State persistence for a long-lived, stateful engine is undocumented.**
   This plan's design needs one WASM module + document registry
   (`Map<int, ({int docPtr, int bufPtr})>`) to stay alive across many
   separate, heterogeneous calls (load, metadata, render, search, close, ...).
   `isolate_manager`'s docs and examples only demonstrate stateless
   computations (fibonacci, counting) through `createShared()`; there is no
   documented guarantee that top-level/static state inside the worker survives
   across multiple `.compute()` calls the way it needs to here.
3. **Direct `dart:js_interop` use inside a managed worker is not a documented,
   first-class capability.** Even the `@isolateManagerCustomWorker` escape
   hatch is framed as giving "Dart-level control over lifecycle and result
   handling" via an `IsolateManagerController`, not a documented path for
   driving a WASM module's JS interop surface directly. Since this worker's
   entire job is instantiating and calling into the PDFium Emscripten module
   via `dart:js_interop`, building on an abstraction that doesn't design for
   this is a real risk, and would likely require bypassing most of
   `isolate_manager`'s machinery anyway — at which point it isn't buying
   anything over the plain hand-rolled `Worker` already scoped in this plan.

Additionally, `isolate_manager`'s data-transfer model (primitives-only direct
transfer, `ImType` wrapper classes for everything else, and transferables
"disabled by default" on WASM) is a worse fit than the direct
`postMessage(data, [buffer])` transferable-object approach this plan already
specifies for multi-megabyte BGRA bitmap results.

**Verdict: do not take `isolate_manager` as a dependency for this work.** It
independently corroborates the plan's Web-Worker conclusion, but it is built
for a different problem (ad-hoc parallel computation over serializable data)
than this plan's requirement (a long-lived, JS-interop-heavy, stateful engine
host with a binary-transfer-optimized custom protocol). The hand-rolled
`Worker` + `postMessage` approach above remains the right direction.

### Reference implementations in the Bettongia monorepo family

Two sibling projects were reviewed for prior art:

- **`packages/betto_pdfium/integration_test_app`** and **`pdf_widgets/example`**
  (the `betto_pdf_widgets` example app, which depends on `betto_pdfium`
  transitively) are real Flutter consumers, but **neither currently has a
  working Flutter web target**: `integration_test_app/web/` contains only the
  manually-created `assets/pdfium/` directory used by `dart test -p chrome` —
  there is no `web/index.html`, so `flutter run -d chrome` / `flutter build
  web` has never actually been exercised against this package. `pdf_widgets/
  example` has no `web/` directory at all. **This is a real gap**: no genuine
  end-to-end Flutter web build has ever loaded `_document_web.dart` in the way
  an actual consumer app would.

  **Correction (Review 1, 2026-07-02):** an earlier draft of this plan named
  `pdf_widgets/example` as the "designated reference implementation," but
  `pdf_widgets` is a **separate sibling repository** (`../pdf_widgets`), not
  part of this monorepo — this repo contains only `betto_pdfium` and
  `betto_pdfium_ios`. A cross-repo scaffold change is not actionable within
  this plan's own PR. **Decision: `integration_test_app` (in this repo) is the
  primary reference implementation and validation target.** It already has a
  `web/assets/pdfium/` directory and is the natural home for a real
  `flutter create --platforms web .` scaffold; it becomes the app used to
  validate the worker approach against an actual Flutter web build/serve
  pipeline (not just `dart test -p chrome`).

  `pdf_widgets/example` remains valuable as the **downstream adoption target**
  — it is the real-world consumer this feature ultimately needs to work for —
  but adapting it is out-of-repo work with its own coordination and review.
  This plan's deliverable for that repo is *documentation*, not code: see
  "Downstream consumer adoption guide" below.
- **`zstd` (`betto_zstd`)** is a sibling pure-Dart-plus-WASM package
  (`lib/src/zstd_web.dart`) with the *same* main-thread-blocking limitation —
  it is not a precedent for the RPC/worker protocol itself, it's synchronous
  main-thread `dart:js_interop` code, structurally identical in spirit to
  today's `_document_web.dart`. What it *does* offer is a materially simpler
  **distribution** precedent: `zstd.wasm` (~325 KB) is checked directly into
  the package at `lib/assets/zstd.wasm` and declared in `pubspec.yaml` under
  `flutter: assets:`, so any Flutter app depending on `betto_zstd` gets the
  WASM binary automatically via Flutter's package-asset bundling — no
  `make fetch_wasm_assets`-style manual copy step is needed. `pdfium.wasm` is
  ~5.2 MB (16× larger), which is presumably why `plan_wasm_support.md` chose
  the manual-copy model instead — but the zstd precedent is directly relevant
  to **this** plan: whatever glue script drives the worker does not need to
  be large, so it could plausibly follow zstd's checked-in-asset model even
  though the PDFium WASM binary itself does not. See the distribution open
  question below.

### Package boundary: what `betto_pdfium` must provide vs. what a consumer does

`betto_pdfium`'s README states the package's core promise: *"the public API
is identical on all platforms ... no code changes are needed when targeting
the web."* That promise sets the boundary directly:

- **`betto_pdfium` owns**: the worker RPC protocol, the `PdfDocumentImpl`
  client-side implementation that talks to the worker, and the worker glue
  artifact itself (whichever of options (a)/(b) below is chosen). None of
  this requires Flutter — `Worker`/`postMessage`/`dart:js_interop` are plain
  web-platform APIs, consistent with the package's existing "pure Dart, works
  in CLI/server-side/Flutter alike" design (`CLAUDE.md` Architecture section).
  If a downstream consumer had to hand-write worker/postMessage plumbing
  itself, the "no code changes on web" promise would break, and every
  consumer of `betto_pdfium` (not just `betto_pdf_widgets`) would have to
  reimplement the same marshalling code the package already owns for the
  main-thread path today.
- **A consumer app provides**: exactly what it already provides for the
  existing (non-worker) WASM setup — running `make fetch_wasm_assets` (or its
  future equivalent) once per version bump, and serving the resulting static
  files from its own web build output. No protocol code, no manual RPC
  wiring, no bespoke build step beyond what's already required today.
- **`integration_test_app`'s role is in-repo validation, not implementation.**
  As the primary reference implementation (see above), it exists to catch
  real-world distribution/UX friction a synthetic `dart test -p chrome` suite
  wouldn't — e.g. does the worker script actually load correctly from a
  `flutter build web` output tree, does `flutter run -d chrome` hot-reload
  cleanly with a live worker, etc. It is not expected to contain any
  worker/protocol logic of its own.

### Downstream consumer adoption guide (deliverable)

`betto_pdf_widgets` (and its example app, `pdf_widgets/example`, a separate
sibling repository) is the real-world downstream consumer this feature exists
to serve — it is what actually renders PDFs in a Flutter UI and is where the
current main-thread-blocking behaviour is most visible to end users. Adapting
that repository is out of scope for this plan's implementation (see the
cross-repo correction above), but this plan should still produce the artifact
that makes that adoption straightforward, since nobody else is positioned to
write it — `betto_pdfium`'s own maintainers know the worker design and its
consequences better than a `betto_pdf_widgets` maintainer coming to it cold.

**Deliverable: an "Adopting the Web Worker backend" guide**, written as part of
this plan's implementation work and shipped in `betto_pdfium`'s own docs
(README "Web (WASM)" section, expanded — not a new standalone doc unless it
grows too large). It should cover, concretely, once the design questions below
are settled:

- **What changes for existing consumers, and what doesn't.** The `PdfDocument`
  public API is unchanged (per the package boundary above) — this should be
  stated explicitly and prominently, since it's the main thing an adopting
  maintainer needs to know before anything else.
- **Distribution/setup delta.** Whatever `make fetch_wasm_assets` (or its
  successor) now places at `web/assets/pdfium/` — does a new worker-glue file
  get added there too? Does the consumer need to reference it anywhere (e.g.
  `web/index.html`), or is it entirely self-contained the way `pdfium.js` is
  today? This depends on the still-open distribution/build-artifact decision
  (option (a) vs (b)) and cannot be finalised until that's resolved.
- **New behavioural characteristics to test for**, framed for a widget-package
  maintainer rather than a package-internals reader: the main thread no longer
  blocks during large renders/extractions, so UI that previously "just froze"
  during a big operation may now need its own loading-state handling to look
  correct (a progress affordance was previously optional/cosmetic since the
  freeze made the point moot; post-offload it becomes load-bearing UX). This is
  a genuine opportunity for `betto_pdf_widgets` specifically, not just a
  caveat — flag it as such in the guide.
- **A migration checklist** (numbered steps) a `betto_pdf_widgets` maintainer
  can follow directly: bump `betto_pdfium`, re-run the asset-fetch step, check
  for the new worker file being served, smoke-test a large-document render on
  web, confirm no main-thread jank in DevTools' Performance panel.
- **Known limitations carried over or newly introduced** (e.g. if worker
  startup adds first-load latency, or if very large messages still copy under
  the hood on some compile targets) so `betto_pdf_widgets` doesn't have to
  rediscover them independently.

This guide is written once the implementation is functionally complete (it
documents what was actually built, not what was planned), but it should be
tracked as an explicit line item in the Implementation plan section below so
it isn't dropped the way `plan_wasm_support.md`'s own Phase 3 documentation
step nearly was. `pdf_widgets/example`'s own adoption then becomes a follow-up
piece of work in that repository, informed by this guide — not something this
plan or its PR needs to execute.

### Memory-model consequence

WASM linear memory is private to whichever thread instantiated the module. If
the module moves into a worker, **all** PDFium work must happen there — there
is no split where cheap calls stay on the main thread and expensive ones move
to the worker. The static `_module`/`_registry` singleton in
`_document_web.dart` would need to move into the worker's global scope
entirely; `PdfDocumentImpl` on the main thread becomes a thin RPC client,
structurally parallel to how native's `pdfium_isolate.dart` owns the FFI
bindings while `_document_native.dart` stays a thin caller.

### Testing impact — CONFIRMED: worker-executed code cannot be coverage-gated

`test/pdf_document_web_test.dart` runs under `dart test -p chrome` (see
`make web_test` / `make web_coverage`, `betto_pdfium.mk:207–233`). Rather than
leave this as a documented assumption, the actual mechanism was read directly
from the pinned dependency: `test-1.31.2` (exact version in this repo's
`pubspec.lock`), `lib/src/runner/browser/chrome.dart`:

- `_connect()` (lines 153–198) opens exactly **one** `ChromeConnection`, finds
  the single tab whose URL matches the test runner's URL
  (`tabs.firstWhereOrNull((tab) => tab.url == url.toString())`), and calls
  `tab.connect()` to get one `WipConnection` to that tab.
- `Profiler.enable` and `Profiler.startPreciseCoverage` (lines 191–195) are
  sent **only on that single tab connection**. `gatherCoverage()` (lines
  92–109) later calls `Profiler.takePreciseCoverage` on that same connection.
  `debugger.onScriptParsed` (line 185) — which builds the `scriptId → URL` map
  coverage results are resolved against — likewise only listens on that one
  tab's debugger session.
- There is **no `Target.setAutoAttach`, no `Target.setDiscoverTargets`, no
  worker-target handling anywhere in this file.** A dedicated `Worker` spawned
  from the page is a genuinely separate Chrome DevTools Protocol target/V8
  isolate. Chrome's Profiler domain is scoped per attached target/session —
  code executing inside a target the collector never attached to is
  structurally invisible to it, not just unlikely to be captured.

**Conclusion: `make web_coverage`, as currently implemented, cannot see any
code that executes inside a spawned `Worker`, full stop** — this holds
regardless of whether the worker runs hand-written JS or Dart-compiled JS
(the gap is about which CDP target executed the code, not which language
produced it). This resolves open question Q6 definitively (not merely
"provisionally") and forces a concrete structural decision, not just a
caveat: **PDFium marshalling logic must remain plain, directly-callable Dart,
exercised by the existing test suite via normal (uncovered-by-worker) calls;
the code that runs *inside* the worker must be reduced to a thin
postMessage-dispatch shell that calls into that already-tested logic.** This
has a direct, favourable consequence for the (a)/(b) distribution question
below: under option (b) (a small Dart worker entry point), the worker calls
the *same* marshalling functions the main-thread test suite already exercises
directly — coverage still applies to the logic itself, just not to the
dispatch shell wrapping it (a small, low-risk, boilerplate-shaped gap,
comparable in kind to the existing `// coverage:ignore-start` blocks around
platform-dispatch code in `pdfium_isolate.dart`). Under option (a) (hand-written
JS), none of that logic is Dart at all, so none of it is covered by
construction — a strictly worse outcome. This strengthens, rather than
merely maintains, the lean toward option (b).

### Open design question: one worker, or one per document?

Today one WASM module is shared by every open `PdfDocument` on the page
(`static PdfiumModule? _module`). A worker-based design could either:

1. Keep one worker per page, multiplexing documents over it via tokens
   (mirrors native's one-isolate-per-process model), or
2. Spawn one worker per `PdfDocument` (simpler cancellation/isolation
   semantics, but N× WASM instantiation cost — each worker loads its own copy
   of `pdfium.wasm` — for N concurrently open documents).

No current behaviour spec covers concurrent multi-document use on web, so
this needs an explicit decision.

## Open questions

- [x] Does `Isolate.spawn` provide genuine background-thread execution on
      web, for either dart2js or dart2wasm compiled output? _Resolved: No._
      Both the [Flutter isolates doc](https://docs.flutter.dev/perf/isolates#web-platforms-and-compute)
      and the [Dart concurrency doc](https://dart.dev/language/concurrency#concurrency-on-the-web)
      confirm isolates are unsupported on web outright, with no distinction
      between compile targets. `compute()` on web runs on the main thread.
- [x] Is a scope cut to dart2wasm-only worker offload meaningful? _Resolved:
      No — moot._ The restriction applies to all web compile targets equally,
      so there is no "dart2wasm gets real threads" option to cut down to.
- [x] Should the implementation use `dart:isolate` directly, or a hand-rolled
      `Worker` + `postMessage` protocol? _Resolved: `Worker` + `postMessage`._
      `dart:isolate` is not an option on web at all (see above); this was
      never actually a fork in the design.
- [x] Could `package:isolate_manager` be used instead of hand-rolling the
      `Worker`/`postMessage` protocol? _Resolved: No._ Its code-generation
      step is app-scoped (scans the consumer's own `lib/`, writes to the
      consumer's own `web/`), which would push a new build-step burden onto
      every `betto_pdfium` consumer and contradicts the package-boundary
      decision above; state persistence for a long-lived stateful worker
      across many heterogeneous calls is undocumented; and direct
      `dart:js_interop` use inside a managed worker (needed to drive the
      PDFium Emscripten module) is not a documented first-class capability.
      See the "Third-party alternative considered" subsection above.
- [ ] Is requiring the consuming app's web server to set
      `Cross-Origin-Opener-Policy: same-origin` /
      `Cross-Origin-Embedder-Policy: require-corp` necessary? _Provisionally
      resolved: No — not required._ Neither source ties plain `Worker` +
      `postMessage` usage to cross-origin isolation (that requirement is
      specific to `SharedArrayBuffer`/shared-memory threading), and
      `pdfium.wasm` is confirmed single-threaded (no Asyncify) per
      `plan_wasm_support.md`. Should be confirmed empirically (a `Worker`
      loading `pdfium.js` unmodified in a plain, non-isolated page) before
      being treated as fully settled, but is no longer a significant risk.
- [x] Does `dart test -p chrome --coverage` correctly instrument code running
      inside a spawned `Worker`? _Resolved: No, confirmed by reading source._
      `test-1.31.2`'s `chrome.dart` (the exact version pinned in this repo's
      lockfile) attaches Chrome DevTools Protocol's `Profiler.startPreciseCoverage`
      to a single tab connection only, with no worker-target discovery or
      attachment logic anywhere in the file — code executing inside a spawned
      `Worker` is a different CDP target and is structurally invisible to this
      collector. Design consequence: marshalling logic stays as plain,
      directly-callable Dart exercised by the existing test suite; the code
      running inside the worker is reduced to a thin postMessage-dispatch
      shell only. See "Testing impact" above.
- [x] One worker shared across all documents on a page, or one worker per
      `PdfDocument`? _Resolved: one shared worker per page_, mirroring
      native's one-isolate-per-process (`PdfiumIsolate`) singleton model —
      recommended in Review 1. This avoids N× WASM module instantiation cost
      (~5.2 MB each) and N× worker spin-up latency for apps with multiple
      documents open at once, at the cost of documents queuing behind one
      another's in-flight worker requests rather than running fully in
      parallel. One-worker-per-document would technically be memory-safe too
      (each worker's `FPDF_InitLibraryWithConfig` call is isolated in its own
      linear memory, so the native "never init twice" invariant isn't
      violated across separate workers), but the cost trade-off doesn't
      justify it as the default. The static `_module`/`_registry` singleton
      shape in `_document_web.dart` carries over directly to "one worker,
      many documents multiplexed via tokens."
- [x] Does distribution need to change — i.e. does `make fetch_wasm_assets`
      (or a new target) need to also produce/ship a worker bootstrap script?
      _Resolved: yes, option (b)._ A small Dart worker entry point
      (`_pdfium_worker_entry.dart`) is pre-compiled to JS **by the
      betto_pdfium release process** via a new maintainer-only
      `make build_wasm_worker` target and checked into the package at
      `lib/assets/pdfium_worker.js` (mirroring the `zstd` precedent of a
      small checked-in artifact). `fetch_wasm_assets.sh` gains one line to
      also copy that file into `web/assets/pdfium/`. No consumer build step
      changes. See "Worker glue: DECIDED" above for the full sketch. This
      corrects the earlier (now-superseded) framing that option (a) would
      only duplicate `_pdfium_js_interop.dart`'s trivial `external` bindings —
      Review 1 confirmed it would actually duplicate `_document_web.dart`'s
      much larger marshalling body, and the confirmed coverage gap (Q6)
      independently reinforces the same conclusion. Still to validate during
      implementation: a real `flutter build web` run via `integration_test_app`
      (the in-repo validation target) should confirm the checked-in worker
      artifact loads correctly from a real build output tree, not just
      `dart test -p chrome`.
- [x] Where does `Finalizer`/`FinalizationRegistry` cleanup live once the WASM
      heap is owned by a worker? _Resolved (Review 1): it must stay, not be
      dropped._ Worker termination (tab close/navigation) does make explicit
      cleanup moot for whole-page teardown, but not for the long-lived-page,
      many-documents-opened-and-closed-over-time case, which is the one that
      actually leaks. The `Finalizer` moves to the main thread's
      `PdfDocumentImpl` as before, but its callback can no longer touch the
      heap directly (that lives in the worker now) — it must instead post a
      "free this document's buffers" request to the worker, which performs
      the actual `fpdfCloseDocument`/`free` calls. Exact message-protocol
      shape is an implementation-time detail, not a further open design
      question.
- [x] Should `integration_test_app` or `pdf_widgets/example` be given a real
      `flutter create --platforms web .` scaffold as groundwork for this plan?
      _Re-opened by Review 1, now re-resolved: `integration_test_app`._ The
      prior resolution named `pdf_widgets/example`, but `pdf_widgets` is a
      **separate repository** (`../pdf_widgets`), not part of this monorepo
      (which contains only `betto_pdfium` and `betto_pdfium_ios`) — a
      `flutter create` scaffold there is a cross-repo change outside this
      plan's PR boundary. `integration_test_app` is the in-repo primary
      reference implementation and validation target instead; it already has
      a `web/assets/pdfium/` directory as a head start. See "Reference
      implementations" above.
- [x] How much must `betto_pdfium` itself provide vs. a downstream consumer
      (e.g. `betto_pdf_widgets`)? _Resolved: `betto_pdfium` owns the worker
      protocol, the client-side implementation, and the worker glue artifact
      in full — this follows directly from the package's own "no code changes
      needed on web" promise._ A consumer's only responsibility is running
      the existing asset-fetch step and serving the static files, exactly as
      today. `integration_test_app`'s role is end-to-end validation, not
      providing any implementation piece. See the Package boundary
      subsection above.
- [ ] How does `betto_pdf_widgets` (a separate, out-of-repo consumer) actually
      adopt this once it ships? Not implemented as part of this plan — instead
      this plan must produce an "Adopting the Web Worker backend" guide
      (README addition) as an explicit Implementation plan deliverable, so a
      `betto_pdf_widgets` maintainer has a concrete migration checklist rather
      than having to reverse-engineer the change from source. See "Downstream
      consumer adoption guide" above; remains open until that guide is
      written (which happens once the implementation itself is functionally
      complete).

## Implementation plan

### Workflow

- **All work happens on a dedicated branch, in a Git worktree**, per
  `docs/plans/README.md`. Branch name: `20260702_plan_wasm_web_worker_offload`
  (date-prefixed, per the required convention).
- **Work proceeds in the phases below, in order.** Each phase ends with
  **one commit** on that branch covering exactly that phase's changes. Do not
  squash phases together and do not split a single phase across multiple
  commits — one phase, one commit.
- **The implementer checks off each task's checkbox in this plan file, in
  this same branch, as it is completed** — the plan file is a living
  document during implementation, not just a pre-implementation artifact.
  Phase-end commits should include the updated plan file alongside the code
  changes for that phase.
- **Despite being organised into phases, this entire plan is delivered as a
  single pull request** at the end of Phase 8 — not one PR per phase. This is
  a deliberate deviation from the incremental-PR structure
  `plan_wasm_support.md` used for its own Phase 2; that precedent does not
  apply here.
- Every phase that touches Dart source must leave `make pre_commit` (native
  suite) passing before moving to the next phase. Phases that touch the web
  backend must additionally leave `make web_test` passing. `make
  web_coverage`'s ≥ 90% gate must hold from Phase 4 onward (see below for why
  it isn't at risk before then).

### Phase 1 — Extract a worker-reusable PDFium engine (pure refactor)

No behavioural change; this phase only restructures existing code so it can
be called from both the main thread and a future worker.

- [x] Extract **one worker-reusable engine function per PDFium operation** —
  load, close, pageCount, metadata, documentInfo, pageSize, render,
  thumbnail, extractText/annotations/images, renderImage, search, toc — into
  a new file, e.g. `lib/src/document/_pdfium_wasm_engine.dart`. Each function
  takes an explicit `PdfiumModule` and document registry (or docPtr/token) as
  parameters — no static, main-thread-only globals. This is **not** limited to
  the code that already happens to be a top-level function: the already-top-
  level low-level readers (`_readMetaTextField:823`, `_extractPageAnnotations:979`,
  `_searchPage:1922`, `_walkBookmarkTree:2026`, `_extractPageImages:1747`)
  extract cleanly as-is, but the **per-operation orchestration for the hot
  paths that justify this whole feature currently lives inline inside the
  instance methods themselves**, reading `_module!`/`_registry[_token]`
  directly — `fromBytes` (`:180–214`: malloc → heap-copy →
  `fpdfLoadMemDocument64` → error mapping → registry insert),
  `renderPageToBytes` (`:438–520`: page-count check → `fpdfLoadPage` →
  bitmap create/render → stride strip → teardown), `getThumbnail` (`:534+`),
  `getDocumentInfo` (`:277–299`), and the three streaming `_extract*Impl`
  bodies. That inline orchestration must be pulled into the engine module
  too, not just the readers — Phase 3 deletes `_document_web.dart`'s
  main-thread orchestration when it rewrites the class into a thin `Worker`
  client, and if this hot-path logic isn't extracted here, Phase 2's worker
  and Phase 4's coverage tests will have nothing to call for load, render,
  thumbnail, documentInfo, or the streaming operations. The instance methods
  in `_document_web.dart` become thin callers of these engine functions for
  the remainder of this phase (unchanged behaviour).
- [x] **Also extract the module-bootstrap logic** (today's `_loadModule()` —
  the `<script>`-tag injection + `onRuntimeInitialized` wait) into the same
  file (or an adjacent one), as a function independently callable on the
  main thread. This is deliberate: Phase 3 rewrites `_document_web.dart` into
  a thin `Worker` RPC client and removes its reason to load a module
  directly, but Phase 4's coverage-preserving tests still need to load a
  PDFium module **on the main thread, bypassing the worker** — without this
  extraction, that capability would disappear once Phase 3 lands, and Phase 4
  would have nothing left to call.
- [x] `_document_web.dart` calls the extracted engine and bootstrap functions
  exactly as before; `_module`/`_registry` stay where they are for now.
  Behaviour is unchanged — this phase does **not** introduce the `Worker` yet.
- [x] Run `make pre_commit` and `make web_test` — the full existing test
  suite must pass unchanged, since this phase is a pure refactor.
- [x] Commit: `refactor(wasm): extract PDFium marshalling engine into a
  worker-reusable module`.

### Phase 2 — Worker entry point and build tooling

- [x] Write `lib/src/document/_pdfium_worker_entry.dart` — a `void main()`
  that installs a `self.onmessage` listener (`WorkerGlobalScope`), loads the
  PDFium module via `importScripts('pdfium.js')` (the worker-context
  equivalent of today's `<script>`-tag injection in `_loadModule()` — DOM
  APIs are unavailable in worker scope, so this loading step is genuinely new
  code, not reused from the main-thread path), owns the module + document
  registry, and dispatches incoming commands to the Phase 1 engine functions,
  posting results back via `postMessage` (with transferables for bitmap
  results — see Phase 3 for the detach caveat).
- [x] Add the maintainer-only `build_wasm_worker` target to
  `betto_pdfium.mk` (sketch already in the Investigation section above):
  compiles `_pdfium_worker_entry.dart` to `lib/assets/pdfium_worker.js` via
  `dart compile js -O2`.
- [x] Run `make build_wasm_worker` and check the resulting
  `lib/assets/pdfium_worker.js` into the repository (mirrors the `zstd`
  precedent of a small checked-in artifact).
- [x] Update `fetch_wasm_assets.sh` to also copy the package's checked-in
  `lib/assets/pdfium_worker.js` into the consumer's `web/assets/pdfium/`
  output directory, alongside `pdfium.wasm`/`pdfium.js`. No new consumer-facing
  step is introduced — this rides the existing `make fetch_wasm_assets` call.
- [x] Commit: `feat(wasm-worker): add worker entry point and build tooling`.

### Phase 3 — RPC protocol and main-thread client rewrite

- [x] Define the command/response message shapes for the `postMessage`
  protocol — mirroring the *shape* of `isolate_messages.dart`'s command
  classes (one message type per operation: load, metadata, page size, render,
  extract text/annotations/images, search, TOC, thumbnail, close), but
  serialised as plain `Map`/primitive structures suitable for structured
  clone, with a message-id field for request/response correlation (the
  native isolate gets this for free via `SendPort`/`ReceivePort`; the
  hand-rolled protocol must replicate it explicitly). (Written in Phase 2 as
  `_pdfium_worker_protocol.dart` / `_pdfium_worker_wire.dart`, since the
  worker entry point needed it to exist first; the client-side use of it
  below is this phase's own work.)
- [x] Rewrite `_document_web.dart`'s `PdfDocumentImpl` to become a thin RPC
  client: lazily spawn **one shared `Worker`** for the page lifetime (per the
  Q7 decision above), send commands with a correlation id, and resolve a
  `Completer` per in-flight request when the matching response arrives.
- [x] Use `postMessage(data, [buffer])` transferables for BGRA bitmap
  results. Note explicitly in code comments that a transferred `ArrayBuffer`
  is neutered on the sender side — the worker must transfer a copy it no
  longer needs, or re-read from the WASM heap afterwards, not reuse the
  transferred buffer.
- [x] Specify and implement `close()`/cancellation ordering against in-flight
  worker RPCs: a `close()` call must be sequenced so it does not race
  in-flight requests for the same document token.
- [x] Relocate `Finalizer` handling: the main-thread `Finalizer` callback can
  no longer touch the WASM heap directly (it lives in the worker now) — it
  must post a "free this document" request to the worker instead, which
  performs the actual `fpdfCloseDocument`/`free` calls there.
- [x] Run `make pre_commit`. `make web_test` is expected to still pass
  functionally at this point, though its coverage contribution for the
  worker-executed paths is addressed in Phase 4, not this phase. (Both pass;
  `make web_test` exercises the real Worker end-to-end in Chrome already.)
- [x] Commit: `feat(wasm-worker): rewire PdfDocumentImpl as a Worker RPC
  client`.

### Phase 4 — Coverage-preserving direct engine tests

This phase exists specifically because of the confirmed finding that
`make web_coverage` cannot instrument code executing inside a spawned
`Worker` (see "Testing impact" above) — without it, moving logic into the
worker would silently erode the 90% web coverage gate.

**Known baseline going into this phase:** `make web_coverage` was already
fixed once, ahead of this plan's implementation, to correctly measure only
this package's own source (`lcov --extract '*/betto_pdfium/lib/*'`) and to
run the platform-agnostic shared test files under the browser platform too
(see `docs/roadmap/0_02.md`'s "Web coverage gate" follow-on item). With that
fix, the correctly-measured baseline is **83%**, not 90% — the gap is real
(mostly missing annotation-subtype fixtures in
`test/pdf_document_web_test.dart`, e.g. the popup-linking `switch` in
`_document_web.dart` around lines 1579–1646), not a measurement artifact.
This phase's "confirm ≥ 90% still holds" checkbox therefore needs the
missing ~7 points closed as part of this work, not just preserved — budget
for that when scoping this phase, not just for the worker-specific direct
tests.

- [x] Add a new test file (or a clearly separated section of an existing one)
  that loads the PDFium module **directly on the main thread** using the
  Phase 1 bootstrap function, bypassing the `Worker` entirely, and calls the
  Phase 1 engine functions directly against real fixture PDFs — exercising
  the same code paths the worker executes at runtime, but in a context
  `dart test -p chrome --coverage-path` can see. (`test/pdfium_wasm_engine_test.dart`,
  added to `WEB_TEST_FILES`.)
- [x] Mark the worker-side dispatch shell in `_pdfium_worker_entry.dart`
  (the `main()`/`onmessage` glue itself, as distinct from the engine
  functions it calls) with `// coverage:ignore-start` / `-end`, consistent
  with the project's existing convention for platform-dispatch code in
  `pdfium_isolate.dart`. (Done in Phase 2 when the file was written.)
- [x] Close the pre-existing ~7-point gap to 90% (see baseline note above) —
  add fixtures/assertions for the currently-uncovered annotation subtypes
  and other scattered branches, not just the new worker-related code.
  (Wired up several previously-generated-but-unused fixtures —
  `annotated_extra.pdf`, `popup_freetext.pdf`, `popup_multi.pdf`,
  `zero_ink_stroke.pdf`, `zero_polygon_vertices.pdf`, `empty_uri_link.pdf`,
  and `test/data/thumbnail_fixture.pdf` — into both
  `test/pdf_document_web_test.dart` and the new direct-engine test file.)
- [x] Run `make web_coverage` and confirm ≥ 90% holds. (92.8% — 1403/1512
  lines, up from an 88.3%/83.5% pre-Phase-4 baseline.)
- [ ] Commit: `test(wasm-worker): add direct engine tests to preserve
  coverage gate`.

### Phase 5 — Adapt the end-to-end web test suite

This phase assumes a `Worker` can be spawned and can successfully
`importScripts('pdfium.js')` under the `dart test -p chrome` harness (which
already serves `web/assets/pdfium/` for the existing suite) — i.e. that the
worker doesn't only work from a real `flutter build web` output tree. If that
assumption turns out to be false, treat it as a signal to pull the relevant
Phase 6 scaffolding forward rather than working around it here.

- [ ] Adjust `test/pdf_document_web_test.dart` for the new async/worker
  timing (module + worker startup latency, request/response round trips).
  This suite now validates end-to-end correctness through the real worker
  path — it is not expected to move the coverage number (Phase 4 already
  covers that), only to keep proving the public API behaves identically.
- [ ] Run `make web_test` and `make web_coverage` together; both must pass.
- [ ] Commit: `test(wasm-worker): adapt end-to-end web suite for
  worker-backed execution`.

### Phase 6 — Real-world validation via `integration_test_app`

- [ ] Give `integration_test_app` a real `flutter create --platforms web .`
  scaffold (it currently has none — see Investigation). Wire it to serve the
  `pdfium.wasm`/`pdfium.js`/`pdfium_worker.js` trio from a real
  `flutter build web` / `flutter run -d chrome` output tree, not just the
  `dart test -p chrome` harness.
- [ ] Manually verify (Chrome DevTools Performance panel) that a large-document
  render no longer blocks the main thread, and empirically confirm the Q5
  COOP/COEP non-requirement in this real Flutter build context too (not just
  the `dart test` harness).
- [ ] Commit: `test(wasm-worker): validate worker offload in a real Flutter
  web build via integration_test_app`.

### Phase 7 — Documentation, spec updates, and the adoption guide

- [ ] Update `spec/01_binary_distribution.md`: lines 251–257 currently state
  main-thread blocking is "deferred to a future roadmap item" — rewrite this
  now that it has shipped, and document the `pdfium_worker.js` artifact and
  `make build_wasm_worker`.
- [ ] Add a web-worker concurrency section to `spec/02_pdfium_isolate.md`
  alongside the existing native isolate description, so both backends'
  concurrency models are documented in one place.
- [ ] Update `README.md`: drop (or rephrase) the "(beta)" qualifier on Web
  (WASM) platform support now that main-thread blocking is resolved, and add
  the "Adopting the Web Worker backend" guide (see "Downstream consumer
  adoption guide" above) — public API unchanged, distribution/setup delta,
  new behavioural characteristics worth testing, a numbered migration
  checklist, and any carried-over limitations.
- [ ] Update `CHANGELOG.md` under the in-progress version entry.
- [ ] Update `docs/roadmap/0_02.md` to mark the "Web backend: Web Worker
  offload" follow-on item complete.
- [ ] Commit: `docs(wasm-worker): update specs, README, CHANGELOG, roadmap`.

### Phase 8 — Finalise

- [ ] Run `make pre_commit` and `make web_coverage` one final time on the
  full branch.
- [ ] Update this plan's **Status** to `Complete`, write the **Summary**
  section below, and move this file to `docs/plans/completed/`.
- [ ] Commit: `chore(wasm-worker): finalise plan, mark complete`.
- [ ] Push the branch and open **one** pull request covering all eight
  phases/commits._

Implementation must not begin before this plan reaches `Investigated` status,
and even then, not without an explicit go-ahead._

## Reviews

### Review 1: 2026-07-02

**Problem Statement Assessment**

The problem is real, correctly scoped, and traceable. Main-thread blocking is
an acknowledged v1 limitation, documented in `_document_web.dart` (lines 20–28),
in `spec/01_binary_distribution.md` (lines 251–257), and it is the stated reason
the README marks Web (WASM) as "Supported (beta)" (`README.md:22`). The plan
correctly identifies that closing this gap is what lets the "(beta)" qualifier
drop, and it is a named follow-on item in the v0.02 roadmap. Alignment is clean;
no roadmap conflict. This is worth solving.

One framing caveat worth stating: the `Future.delayed(Duration.zero)` yields in
the streaming methods already give *per-page* cooperative breaks, so the acute
freeze is a single long synchronous PDFium call within one page — chiefly
`renderPageToBytes`/`getThumbnail` on large pages, and `fpdfLoadMemDocument64` +
first-page load on large documents. The plan understands this (memory-model
section), but the implementation plan, when written, should prioritise the
render/load hot-path as the thing that actually justifies the worker's
complexity, rather than treating every method uniformly.

**Proposed Solution Assessment**

The investigation is unusually thorough and appropriately self-critical. Three
things are done well:

1. The `dart:isolate`-doesn't-work-on-web conclusion is now backed by two
   primary sources and correctly kills the dart2wasm-vs-dart2js fork. That is
   the right call and closes three questions legitimately.
2. The `isolate_manager` rejection is well-reasoned. The app-scoped
   code-generation point (its generator scans the *consumer's* `lib/` and writes
   to the *consumer's* `web/`) is the decisive one and is consistent with this
   package's "no code changes on web" promise. Rejecting it is correct.
3. Adopting the native `pdfium_isolate.dart` command/token/registry *shape*
   while acknowledging the *mechanism* is entirely different is exactly the right
   mental model.

The main weakness is that the distribution question — the single most important
unresolved design fork — rests on an inaccurate premise. See Architecture Fit.

**Architecture Fit**

Layer integrity (library-architecture skill): **PASS with one caveat.**
`betto_pdfium` is pure Dart (`pubspec.yaml`: no Flutter dependency, `sdk:
^3.12.0`). `Worker`/`postMessage`/`dart:js_interop` are plain web-platform APIs
and do not pull in Flutter, so the worker client on the main thread preserves
the Core-layer boundary. The plan's package-boundary decision (betto_pdfium owns
all worker glue; the consumer only fetches/serves assets) is correct and follows
directly from the package's cross-platform-parity promise. No new public API
surface is proposed — `PdfDocument` stays identical — which is the right
outcome. The one caveat: option (b) proposes a Dart worker entry point
pre-compiled by the release process. A Dart-authored worker that imports
`dart:js_interop` is still pure Dart and does not breach the layer boundary, so
(b) is architecturally acceptable; the objection to it is a build-pipeline one,
not a layering one.

The `design` and `inclusivity` skills do not apply: this plan has no UI surface.
It is infrastructure inside a pure-Dart package. (The eventual "loading
indicator" UX lives in downstream widget consumers, not here.)

Spec impact: the plan does **not** currently list spec updates as a work item,
and it must. At minimum `spec/01_binary_distribution.md` lines 251–257 (the
"Main-thread blocking … deferred to a future roadmap item" note) become false
once this ships and must be rewritten. `spec/02_pdfium_isolate.md` describes the
concurrency model and should gain a web-worker counterpart section so the two
backends' concurrency stories are both documented. Add "update specs" to the
implementation plan explicitly.

**Critical accuracy issue — the distribution question's premise is wrong.**

The distribution open question and the zstd "checked-in artifact" precedent both
lean on the idea that option (a) — plain JS worker glue — would "duplicate the
PDFium call/marshalling logic between `_pdfium_js_interop.dart` (main-thread
Dart) and the JS worker file." I checked: `_pdfium_js_interop.dart` is **not**
marshalling logic. It is 631 lines of pure `extension type PdfiumModule` with
`external` binding declarations (verified: lines 45–631 are all `external`
signatures like `int malloc(int)`, `int fpdfLoadMemDocument64(...)`). The actual
marshalling/call logic — the two-call buffer pattern, UTF-16LE decoding, stride
stripping, annotation walking — lives as top-level functions in
`_document_web.dart` (e.g. `_readMetaTextField`, `_extractPageText`,
`renderPageToBytes`). So:

- Option (a) does **not** duplicate `_pdfium_js_interop.dart`; it would
  duplicate the far larger and more intricate body of `_document_web.dart`. That
  makes (a) considerably *worse* than the plan implies — reimplementing the
  annotation/text/search marshalling in hand-written JS is a large, bug-prone,
  permanently-diverging surface. The plan should strengthen its lean toward (b),
  not treat the two as a close call.
- The zstd precedent is weaker than presented for a second reason: zstd's worker
  (if it had one) would marshal trivial byte-in/byte-out; PDFium's marshalling
  is an order of magnitude more complex. "Small checked-in glue" is realistic
  for zstd and unrealistic for a hand-written-JS PDFium worker. It remains a
  fine precedent for *asset-shipping mechanics*, but not for the "the glue is
  small" inference.

This does not change the conclusion (hand-rolled Worker, option (b) direction),
but the reasoning behind it needs correcting before the question can be closed,
because a future implementer reading the current text could reasonably pick (a).

**Cross-repo reference inaccuracy.** The plan repeatedly calls
`pdf_widgets/example` a member of "the Bettongia monorepo family" and the
"designated reference implementation." `pdf_widgets` is **not** in this
monorepo — this repo contains only `betto_pdfium` and `betto_pdfium_ios`.
`pdf_widgets` exists as a *separate sibling repository* (`../pdf_widgets`). This
matters concretely: you cannot add a `flutter create --platforms web` scaffold
to `pdf_widgets/example` as part of *this* repo's plan/PR — it is a
cross-repository change with its own review, versioning, and a path-dependency
question (does it even depend on this package via a path or a pub version?).
Question 11 is checked off as "Resolved: pdf_widgets/example," but the resolution
is not actionable within this repo's boundary. Either (i) designate the
in-repo `integration_test_app` as the web scaffold target (it already has a
`web/assets/` directory and is the natural home), or (ii) keep `pdf_widgets` as
the validation target but explicitly mark it out-of-repo groundwork with its own
coordination. I am re-opening this as a review question rather than accepting the
current resolution.

**Risk & Edge Cases**

- **Worker-side coverage (open Q6) is the hardest blocker and is
  under-appreciated.** `make web_coverage` runs `dart test -p chrome
  --coverage-path=... test/pdf_document_web_test.dart` and enforces ≥90% by
  counting `DA:` lines in the lcov (`betto_pdfium.mk:214–233`). Code executing
  inside a spawned `Worker` runs in a *separate JS realm* the test runner's
  coverage collector very likely does not instrument. If option (b) is chosen,
  essentially *all* the interesting logic moves into the worker and would fall
  outside the gate — reproducing exactly the blind spot `plan_wasm_support.md`
  Review 1 already had to fix. This is not merely "verify before implementation";
  it is potentially design-determining. If worker code can't be coverage-gated
  in-realm, the plan may need to keep the marshalling functions as *plain
  testable Dart* invoked identically on both main-thread and worker paths (so
  the existing suite covers them directly), with only the thin
  postMessage-dispatch shell running uncovered in the worker. Please spike this
  before `Investigated`, and record the fallback design if the spike is negative.
- **`fpdfInitLibraryWithConfig` singleton invariant.** The native side is
  emphatic: never init the library twice. The one-worker-vs-one-per-document
  question (Q7) has a correctness dimension the plan frames only as a
  cost/footprint trade-off. One-worker-per-document means N independent WASM
  instances each calling `FPDF_InitLibraryWithConfig` in their own isolated
  linear memory — which is *safe* precisely because memory is not shared, but it
  multiplies the ~5.2 MB module instantiation N times and adds per-document
  worker spin-up latency. One shared worker mirrors native and is almost
  certainly right; the plan should just decide it (I lean strongly to
  one-shared-worker) rather than leaving it fully open.
- **Async conversion of a currently-sync API.** The public API is already
  `Future`-returning on both backends, so no signature changes — good. But the
  streaming methods currently interleave `_closed` checks between synchronous
  page calls (e.g. `_document_web.dart:414–423`). Once each page call is an async
  round-trip to the worker, cancellation semantics change: a `close()` issued
  mid-flight must be sequenced against in-flight worker requests. The plan should
  note how `close()`/cancellation is ordered against outstanding RPCs (the
  native isolate gets this via port ordering; the hand-rolled protocol must
  replicate it).
- **Transferable-buffer detach.** The plan proposes `postMessage(data,
  [buffer])` transferables for BGRA results — correct for perf, but a
  transferred `ArrayBuffer` is *neutered* on the sender side. The worker must
  transfer a copy it no longer needs, or re-read from the WASM heap afterwards.
  Worth a one-line note so it isn't discovered as a heisenbug.
- **COOP/COEP (Q5).** Provisional resolution (not required for plain
  `Worker`+`postMessage`, only for `SharedArrayBuffer`) is technically sound and
  consistent with the confirmed no-threads/no-Asyncify PDFium build. Fine to
  leave as "confirm empirically during the distribution spike."
- **Finalizer relocation (Q9).** Currently the `Finalizer` frees WASM heap
  buffers on GC (`_document_web.dart:98–104`). Once the heap lives in the worker,
  a main-thread `Finalizer` can only *post a free-request* to the worker; it
  cannot touch the heap directly. And worker termination (tab close/navigation)
  does make explicit per-document cleanup moot for the whole-page-teardown case,
  but *not* for the long-lived-page-many-documents case, which is the one that
  leaks. So the Finalizer must stay (as an RPC trigger), not be dropped. Worth
  resolving explicitly.

**Recommendations**

The investigation is close to implementation-ready, and the hard mechanism
question is genuinely settled. Do not promote to `Investigated` yet — two items
are design-determining, not just confirm-later:

1. **Run the worker-side coverage spike (Q6) now.** Its outcome may force the
   "keep marshalling as plain testable Dart, thin dispatch shell in worker"
   design. This is the single biggest open risk.
2. **Correct the distribution reasoning (Q8)** to reflect that option (a)
   duplicates `_document_web.dart`'s marshalling body, not the trivial
   `_pdfium_js_interop.dart` bindings — then commit to option (b) with a concrete
   `make` target sketch (analogous to `repack_ios_xcframework`).
3. **Resolve the `pdf_widgets` cross-repo boundary** — either move web-scaffold
   validation to the in-repo `integration_test_app`, or explicitly scope it as
   out-of-repo groundwork.
4. **Decide Q7** in favour of one shared worker (recommended).
5. **Add spec updates** (`01_binary_distribution.md`, `02_pdfium_isolate.md`) as
   an explicit implementation-plan work item.
6. Write the phased implementation plan (mirroring `plan_wasm_support.md`'s
   incremental PR structure) once 1–2 land.

Once the coverage spike and the distribution correction are done and Q7 is
decided, this is ready for `Investigated`. Everything else is confirm-during-
implementation detail.

**Open questions from this review**

- [x] Does `dart test -p chrome --coverage` instrument code executing inside a
      spawned `Worker` (separate JS realm)? _Resolved: No — confirmed by
      reading `test-1.31.2`'s `chrome.dart` source directly (the version
      pinned in this repo's lockfile), not by browser experiment: coverage
      collection attaches CDP's `Profiler` domain to a single tab connection
      with no worker-target attachment logic at all._ Adopted design: the
      "marshalling logic stays as plain Dart covered by the existing suite;
      only a thin postMessage-dispatch shell runs in the worker" structure,
      as this review's Recommendation 1 anticipated. See Q6 and "Testing
      impact" above.
- [x] Correct the option (a)/(b) distribution reasoning and commit to one.
      _Resolved: option (b)._ Reasoning corrected (option (a) duplicates
      `_document_web.dart`'s marshalling body, not the `external`-only
      `_pdfium_js_interop.dart` bindings) and reinforced by the confirmed
      coverage gap. Concrete `make build_wasm_worker` target sketched. See
      "Worker glue: DECIDED" above.
- [x] Resolve the `pdf_widgets` cross-repo boundary: `pdf_widgets` is a separate
      repository (`../pdf_widgets`), not part of this monorepo. _Resolved:_
      `integration_test_app` is the in-repo web-scaffold/validation target;
      `pdf_widgets` adoption is scoped as out-of-repo follow-up work, informed
      by a new "Adopting the Web Worker backend" guide this plan must produce
      as an explicit deliverable. See "Downstream consumer adoption guide"
      with its own coordination. Question 11's current "Resolved" state is not
      actionable within this repo.
- [x] Decide Q7 (one shared worker vs one-per-document). _Resolved: one
      shared worker_, mirroring native's one-isolate-per-process model; the
      `FPDF_InitLibraryWithConfig`-once invariant applies per worker and isn't
      violated either way, but the cost trade-off favours one shared worker.
      See Q7 above.
- [ ] Add spec updates as an explicit implementation-plan item:
      `spec/01_binary_distribution.md` lines 251–257 become false on ship;
      `spec/02_pdfium_isolate.md` should gain a web-worker concurrency section.
- [ ] Specify `close()`/cancellation ordering against in-flight worker RPCs, and
      the transferable-buffer detach handling for BGRA results.

### Review 2: 2026-07-02

This review covers only the new **Implementation plan** section (Workflow +
Phases 1–8), which did not exist at Review 1. The already-resolved architecture
questions (mechanism, `isolate_manager`, worker cardinality, coverage
instrumentation, cross-repo boundary, Finalizer placement) are not re-litigated
except where the phased plan exposes a new problem with one of them. Status
remains `Investigated` pending the one blocking correction below.

**Problem Statement Assessment**

Unchanged from Review 1 — the problem is real, scoped, and roadmap-aligned
(`docs/roadmap/0_02.md:129–149` names this exact follow-on). No new concerns.

**Proposed Solution Assessment**

The eight-phase structure is sound in outline and the sequencing instinct is
correct: refactor to make logic worker-reusable (P1) → add the worker + build
tooling (P2) → rewire the client and protocol (P3) → restore coverage (P4) →
adapt E2E (P5) → validate in a real Flutter build (P6) → docs/spec (P7) →
finalise (P8). The dependency chain is mostly right, each phase has a named
commit, and the workflow rules (dedicated dated worktree branch, one commit per
phase, single PR at the end, plan checkboxes updated in-branch) are unambiguous
and match `docs/plans/README.md`. The single-PR-not-per-phase deviation is
stated explicitly with a reason — good.

The Phase 1 amendment (also extract the module-bootstrap so Phase 4 can load a
module on the main thread after Phase 3 removes that path from
`_document_web.dart`) is the right *kind* of fix. But it is **incomplete**, and
the same class of defect it addresses recurs elsewhere in Phase 1. See below —
this is the one blocking item.

**Architecture Fit**

No change to the layer verdict from Review 1: `betto_pdfium` stays pure Dart
(`pubspec.yaml` has no `flutter:` section and no Flutter dependency), and
`Worker`/`postMessage`/`dart:js_interop` do not breach that. `design` and
`inclusivity` skills still do not apply (no UI). Spec updates are now correctly
present as Phase 7 work items, resolving the outstanding Review 1 spec gap — and
the cited line references check out: `spec/01_binary_distribution.md:251–257` is
indeed the "Main-thread blocking … deferred to a future roadmap item" note, and
`spec/02_pdfium_isolate.md` exists and is the right home for a web-worker
counterpart section. Both Review 1 spec open questions are therefore now
dischargeable (checked off below).

**Risk & Edge Cases**

1. **BLOCKING — Phase 1's extraction scope is under-specified and repeats, for
   the render/load hot-path, the exact "later phase deletes what an earlier
   phase failed to preserve" defect the bootstrap amendment just fixed.**

   Phase 1 says to extract "the marshalling logic currently living as top-level
   functions in `_document_web.dart`." I verified what is and isn't a top-level
   function. The low-level *readers* are top-level and already take
   `PdfiumModule` as a parameter — e.g. `_readMetaTextField` (`:823`),
   `_extractPageAnnotations` (`:979`), `_searchPage` (`:1922`),
   `_walkBookmarkTree` (`:2026`), `_extractPageImages` (`:1747`). Those extract
   cleanly as written.

   But the **per-operation orchestration** lives *inline inside the instance
   methods*, reading `_module!`/`_registry[_token]` directly, and is **not**
   top-level:
   - `fromBytes` (`:180–214`): `malloc` → `heapu8.set` → `fpdfLoadMemDocument64`
     → error-code mapping → registry insert.
   - `renderPageToBytes` (`:438–520`): page-count check → `fpdfLoadPage` →
     bitmap create/fill/`fpdfRenderPageBitmap` → buffer read → `stripBitmapStride`
     → bitmap/page teardown.
   - `getThumbnail` (`:534+`), `getDocumentInfo` (`:277–299`,
     inline file-version int32-out-pointer read), and the three streaming
     `_extract*Impl` bodies all likewise carry inline module/registry-coupled
     logic.

   Review 1 explicitly named `renderPageToBytes`/`getThumbnail` and
   `fpdfLoadMemDocument64` as *the* hot-paths that justify this whole feature.
   Under Phase 1 as literally written, that orchestration is **not** extracted
   (it isn't a top-level function); Phase 3 then rewrites `_document_web.dart`
   into a thin RPC client and deletes it; and Phase 2's worker entry point —
   told to "dispatch incoming commands to the Phase 1 engine functions" — has no
   engine function to call for `load`, `render`, `thumbnail`, `documentInfo`,
   or the stream operations. The worker would be left re-implementing the most
   important logic from scratch, which is precisely the duplication the option-
   (b) decision exists to avoid, and precisely the coverage-erosion Phase 4
   exists to prevent (re-implemented-in-worker logic is invisible to
   `web_coverage`).

   **Fix:** Phase 1 must extract, into the engine module, one worker-reusable
   function *per PDFium operation* (load, close, pageCount, metadata,
   documentInfo, pageSize, render, thumbnail, extractText/annotations/images,
   renderImage, search, toc), each taking an explicit `PdfiumModule` + registry
   (or docPtr/token) parameter — not merely the already-top-level readers plus
   the bootstrap. The instance methods in `_document_web.dart` should become
   thin callers of these for the duration of Phase 1 (unchanged behaviour), so
   that when Phase 3 deletes the main-thread orchestration, the engine functions
   it moves to are already the single source of truth the worker and the Phase 4
   tests both call. Restate Phase 1's first checkbox accordingly.

2. **Non-blocking — the zstd distribution precedent is cited for a mechanism it
   doesn't actually share.** Phase 2 (and the Investigation) justify checking
   `pdfium_worker.js` into `lib/assets/` by "mirroring the `zstd` precedent."
   But zstd's checked-in `lib/assets/zstd.wasm` reaches consumers via Flutter's
   `flutter: assets:` **package-asset bundling** — and `betto_pdfium` has no
   `flutter:` section in its pubspec (it is pure Dart and must stay so). So the
   auto-bundling half of the zstd precedent does not transfer. What *does* make
   the plan work is a different, already-established mechanism:
   `fetch_wasm_assets.sh` copies files into the consumer's `web/assets/pdfium/`,
   and Phase 2's "one extra copy line" rides that. The plan's mechanism is
   therefore fine; only the justification is misleading. Recommend the plan stop
   leaning on zstd for anything beyond "small checked-in artifact is an
   acceptable pattern," and state plainly that delivery is via
   `fetch_wasm_assets.sh` copy, not package-asset bundling. One concrete thing
   to confirm during Phase 2/6: `fetch_wasm_assets.sh` currently sources
   `pdfium.wasm`/`pdfium.js` from a downloaded tarball; the new line must copy
   the worker JS from the *package's own tree in the pub cache*
   (`lib/assets/pdfium_worker.js`), so the script needs a reliable
   package-root-relative path that works when `betto_pdfium` is a pub
   dependency, not just when run from a source checkout.

3. **Non-blocking — Phase 5 vs Phase 6 ordering is defensible but worth a note.**
   Phase 5 adapts `test/pdf_document_web_test.dart` (the `dart test -p chrome`
   suite) to real worker timing *before* Phase 6 stands up the actual
   `flutter build web` scaffold. If the worker only ever loads correctly from a
   real Flutter build tree (Phase 6) and not from the `dart test -p chrome`
   harness's asset layout, Phase 5 could stall on infrastructure that Phase 6
   is meant to establish. This is probably fine (the harness already serves
   `web/assets/pdfium/` for the existing suite), but Phase 5 should state the
   assumption that a `Worker` can be spawned and can `importScripts` under the
   `dart test -p chrome` harness, and treat "it can't" as a trigger to pull the
   relevant Phase 6 scaffolding earlier rather than working around it.

4. **Non-blocking — close()/cancellation and transferable-detach are correctly
   captured.** Phase 3 now carries both Review 1 items explicitly (close()
   sequencing against in-flight RPCs; the neutered-ArrayBuffer note). Good — the
   corresponding Review 1 open question can be checked off.

5. **Non-blocking — the adoption guide is correctly pinned as a Phase 7 line
   item**, addressing Review 1's worry that it would be dropped the way
   `plan_wasm_support.md`'s docs step nearly was. It remains gated on
   implementation being functionally complete, which is the right sequencing.

**Recommendations**

The phased plan is close and the workflow rules are implementer-ready. One
blocking correction before this is safe to implement:

1. **Rewrite Phase 1's extraction scope (item 1 above)** to extract a
   worker-reusable function per PDFium operation — including the inline
   orchestration in `fromBytes`, `renderPageToBytes`, `getThumbnail`,
   `getDocumentInfo`, and the streaming impls — not just the already-top-level
   readers and the bootstrap. Without this, Phase 3 deletes the hot-path logic
   Phase 2's worker and Phase 4's tests both depend on. This is the same defect
   shape as the bootstrap issue already caught; the amendment fixed one instance
   of it, not the category.

Then, non-blocking, fold in during implementation: correct the zstd-precedent
framing (item 2), state the Phase 5 harness assumption (item 3), and confirm the
pub-cache-relative worker-copy path (item 2).

Because the blocking item is a scoping clarification to a single phase rather
than an unresolved design fork, I am leaving **Status: Investigated** — this does
not need to drop back to `Questions`. Fix Phase 1's wording before starting
implementation; the fix is mechanical and the design decisions behind it are all
already settled.

**Open questions from this review**

- [x] Phase 1 must extract a worker-reusable engine function *per PDFium
      operation* (load, render, thumbnail, documentInfo, pageSize, streaming
      extracts, search, toc, close), not only the already-top-level readers +
      bootstrap. _Resolved: Phase 1's first checkbox rewritten_ to explicitly
      cover the inline orchestration in `fromBytes` (`:180`),
      `renderPageToBytes` (`:438`), `getThumbnail` (`:534`), `getDocumentInfo`
      (`:277`), and the `_extract*Impl` bodies, not just the already-top-level
      readers and the bootstrap.

**Discharged from prior reviews**

- [x] Add spec updates as an explicit implementation-plan item. _Resolved:
      Phase 7 now lists `spec/01_binary_distribution.md` (lines 251–257 verified
      as the stale note) and a new `spec/02_pdfium_isolate.md` web-worker
      section._
- [x] Specify `close()`/cancellation ordering against in-flight worker RPCs and
      transferable-buffer detach handling. _Resolved: both are explicit Phase 3
      checkboxes._

## Summary

_Not started._
