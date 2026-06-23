# PDFium Cross-Platform Build Pipeline

**Status**: Investigated

**PR link**: —

## Problem statement

Once the macOS binary is available (see
[plan_pdfium_build_infrastructure.md](plan_pdfium_build_infrastructure.md)), the
project needs pre-built PDFium binaries for all target platforms to ship a
working package. Building these inside `betto_pdfium`'s main development branch
is impractical: the toolchain (depot_tools, NDK, Emscripten) is heavy, slow, and
unrelated to Dart development. A CI failure in the C++ build should not block
Dart work.

This plan covers establishing a dedicated `pdfium-build` orphan branch within
this repository that owns the full PDFium build matrix and publishes versioned
binary artifacts to GitHub Releases. `betto_pdf` then fetches the appropriate
release artifact at development time rather than building from source. Windows
support is deferred to a later phase pending a test environment.

## Decisions

- **Branch strategy**: An orphan `pdfium-build` branch within this repo houses
  the PDFium build Makefile and per-platform build scripts. The `main` branch is
  not polluted with C++ toolchain concerns.
- **`PDFIUM_VERSION` file**: A `PDFIUM_VERSION` file in `main` records the
  PDFium commit SHA in use. A change to this file is the explicit trigger for a
  binary rebuild. This makes the current PDFium version immediately visible at
  the repo root.
- **Makefile as the portability layer**: All build logic lives in Makefile
  targets on `pdfium-build`. CI pipelines are thin wrappers that call
  `make <target>`. Swapping or adding a CI system costs almost nothing.
- **Containers**: Podman provides rootless Linux containers for Linux and
  Android builds. macOS and iOS build natively on the host.
- **CI**: GitHub Actions is the sole CI system. The pipeline lives at
  `.github/workflows/build_pdfium.yml` on `main`, checks out `pdfium-build`
  during build jobs, and calls the same Makefile targets that developers run
  locally. No self-hosted agent is required.
- **Local development**: Developers invoke the same Makefile targets directly
  (e.g. `make build_pdfium_macos`) to validate builds locally before pushing.
  The Makefile is the portability layer; CI is a thin wrapper around it.
- **Release publishing is GitHub Actions only**: Publishing is restricted to
  GitHub-hosted runners. Deploying binaries built on a developer machine is
  undesirable from a supply-chain and reproducibility standpoint. GitHub Actions
  is the exclusive authoritative publisher.
- **Release tag format**: GitHub Release tags use `pdfium-<full-sha>`, where
  `<full-sha>` is the complete PDFium commit SHA stored in `PDFIUM_VERSION`.
  `make fetch_pdfium` constructs this tag directly from `PDFIUM_VERSION`.
  Partial SHAs are never used. This format is consistent across the tag, the
  fetch mechanism, and `VERSION.txt`.
- **Artifact distribution**: GitHub Releases on this repo. `make fetch_pdfium`
  in `main` reads `PDFIUM_VERSION` and downloads the matching release into
  `third_party/pdfium_bin/`.
- **Windows**: Dropped from scope entirely — no test environment available and
  removed from the project roadmap.
- **macOS x86_64**: Dropped from scope entirely —
  [Flutter is dropping support for this target](https://blog.flutter.dev/whats-new-in-flutter-3-44-b0cc1ad3c527).
- **Web (WASM)**: In scope for phase 1. PDFium is compiled to WebAssembly via
  Emscripten, producing a `.wasm` + `.js` module pair. Emscripten toolchain runs
  inside a dedicated Podman container.

## Platform scope (phase 1)

| Platform       | Cross-compile host | Library form              | Toolchain           |
| -------------- | ------------------ | ------------------------- | ------------------- |
| macOS arm64    | macOS arm64 host   | dylib                     | depot_tools + Ninja |
| iOS arm64      | macOS arm64 host   | static lib (.xcframework) | Xcode cross-compile |
| Linux x86_64   | Podman container   | shared lib                | depot_tools + Ninja |
| Android arm64  | Podman container   | shared lib                | NDK                 |
| Android x86_64 | Podman container   | shared lib                | NDK                 |
| Web (WASM)     | Podman container   | .wasm + .js               | Emscripten          |

## Artifact layout per GitHub Release

```
libpdfium-macos-arm64.dylib
libpdfium-ios-arm64.xcframework.zip
libpdfium-linux-x86_64.so
libpdfium-android-arm64.so
libpdfium-android-x86_64.so
libpdfium-web.wasm
libpdfium-web.js
VERSION.txt                    ← PDFium commit SHA + build date (ISO-8601 UTC)
checksums.sha256               ← SHA256 of every artifact above; verified by make fetch_pdfium
```

## Branch layout

### `pdfium-build` (orphan branch)

```
pdfium-build/
  Makefile                     ← PDFium build targets (build_pdfium_macos, etc.)
  scripts/
    build_macos.sh
    build_ios.sh
    build_linux.sh             ← runs inside Podman container
    build_android.sh           ← runs inside Podman container
    build_wasm.sh              ← runs inside Podman container
  containers/
    linux.Dockerfile           ← depot_tools + Ninja image
    android.Dockerfile         ← NDK image
    wasm.Dockerfile            ← Emscripten + depot_tools image
  third_party/
    pdfium/                    ← PDFium source (git subtree, same SHA as main)
    depot_tools/               ← pinned subtree or documented install step
  README.md
```

### `main` additions

- `PDFIUM_VERSION` — PDFium commit SHA; change triggers binary rebuild
- `Makefile` — retains Dart targets; gains `fetch_pdfium` target
- `.github/workflows/build_pdfium.yml` — GitHub Actions CI pipeline

## CI pipeline behaviour

The GitHub Actions pipeline is the sole CI path. Developers can run the same
Makefile targets locally to validate before pushing.

1. Trigger: push to `main` that modifies `PDFIUM_VERSION`.
2. Check out `pdfium-build` branch alongside `main`.
3. Run `make build_pdfium_<platform>` for each platform in the matrix.
   - macOS and iOS: run on a macOS arm64 runner natively.
   - Linux, Android, and WASM: run inside Podman containers.
4. Upload per-platform binaries as pipeline artifacts.
5. On success: publish a GitHub Release tagged with the PDFium SHA, attaching
   all binaries and a `VERSION.txt`.

## Fetch mechanism in `main`

`make fetch_pdfium` reads `PDFIUM_VERSION`, downloads the matching GitHub
Release artifacts into `third_party/pdfium_bin/`, and ad-hoc signs all
dylibs/shared libs (`codesign --force --sign -`) to clear the
`com.apple.quarantine` xattr applied to files downloaded from GitHub Releases.

## Implementation plan

### Phase 1 — `pdfium-build` branch setup

- [ ] Create the orphan `pdfium-build` branch.
- [ ] Add PDFium source as a git subtree (mirror the same commit SHA recorded in
      `PDFIUM_VERSION` on `main`).
- [ ] Add depot_tools as a pinned subtree or document the install step.
- [ ] Write per-platform build scripts (`scripts/build_*.sh`).
- [ ] Write Podman `Dockerfile`s for Linux, Android, and WASM (Emscripten) build
      environments.
- [ ] Write the `pdfium-build` `Makefile` with targets for each platform.
- [ ] Write `README.md` documenting the branch purpose, how to trigger a build,
      and how to consume artifacts.

### Phase 2 — `main` branch additions

- [ ] Add `PDFIUM_VERSION` file to `main` recording the current PDFium commit
      SHA.
- [ ] Add `make fetch_pdfium` target to the `main` `Makefile`.
- [ ] Add `make check_pdfium_version` target to the `main` `Makefile`: compares
      the SHA in `PDFIUM_VERSION` against the commit the `third_party/pdfium/`
      subtree is pinned to and fails with a clear error if they differ. Wire
      this target into `make pre_commit` so version drift is caught before any
      commit lands.
- [ ] Move PDFium-specific build targets out of the `main` `Makefile` and into
      the `pdfium-build` `Makefile`.

### Phase 3 — CI build matrix

- [ ] Add `.github/workflows/build_pdfium.yml` to `main`: trigger on
      `PDFIUM_VERSION` change, check out `pdfium-build`, run Makefile targets
      for each platform, upload artifacts.
- [ ] Cache depot_tools sync and `out/` directories keyed on the PDFium commit
      SHA to avoid full rebuilds on re-runs (`actions/cache`).

### Phase 4 — Release publishing

- [ ] Add a smoke test step before publishing: load each platform binary and
      call `FPDF_InitLibraryWithConfig()` / `FPDF_DestroyLibrary()`. Fail the
      pipeline and block the Release if any platform binary does not pass.
- [ ] Generate `checksums.sha256` covering all platform artifacts and
      `VERSION.txt`.
- [ ] Add release publishing step to GitHub Actions: on successful build and
      smoke test, create a GitHub Release tagged `pdfium-<full-sha>` and attach
      all platform binaries, `VERSION.txt`, and `checksums.sha256`.

### Phase 5 — Fetch integration and documentation

- [ ] Validate `make fetch_pdfium` end-to-end: downloads, unpacks, verifies
      checksums, and signs binaries correctly.
- [ ] Write `docs/spec/binary_distribution.md` formalising the binary
      distribution contract: artifact layout, tag format, `VERSION` file format,
      fetch mechanism, and checksum verification.
- [ ] Update `CLAUDE.md` to document the `PDFIUM_VERSION` bump workflow
      (including the required `git subtree pull` and `make ffi_bindings` steps)
      and `make fetch_pdfium`. Point to `docs/spec/binary_distribution.md` as
      the authoritative reference.
- [ ] Update `README.md` to reference the `pdfium-build` branch and the fetch
      workflow.
- [ ] Move this plan to `docs/plans/completed/` and update status to Complete.

## Questions

- [x] The roadmap (`docs/roadmap/0_07.md`) targets macOS x86*64, Windows x86_64,
      and Web (WASM) as phase 1 platforms, but the plan explicitly excludes all
      three. Should the plan be treated as a partial implementation of the
      roadmap item (with the excluded platforms deferred to a subsequent phase),
      or should the roadmap entry be updated to match the plan's actual scope?
      This needs explicit alignment before implementation begins. \_Decision:
      macOS x86_64 is dropped entirely (Flutter is dropping support). Windows is
      dropped entirely from the roadmap (no test environment, out of scope). Web
      (WASM) is added to this plan's phase 1 scope. The roadmap entry in
      `docs/roadmap/0_07.md` is updated to reflect these decisions.*

- [x] The plan places build scripts and Dockerfiles in an orphan `pdfium-build`
      branch within this repository. The roadmap (v0.07) describes a "standalone
      `pdfium-binaries` repository". These are architecturally different
      choices: an orphan branch shares the GitHub Release space with Dart code,
      while a separate repo gives clean ownership, independent issue tracking,
      and no risk of cross-contaminating CI. Which model has been decided, and
      should the plan (or roadmap) be updated accordingly? _Decision: Use the
      orphan `pdfium-build` branch within this repo (already reflected in the
      plan). No separate repository. The roadmap entry is to be updated to
      remove any reference to a standalone `pdfium-binaries` repository._

- [x] The plan specifies that release publishing is **GitHub Actions only**,
      with Woodpecker used solely for validation. This means the primary
      (self-hosted) CI path cannot produce an authoritative release — it always
      depends on the backup (GitHub-hosted). Is this intentional, or should
      Woodpecker be the authoritative publisher with GitHub Actions as the
      backup? _Decision: Woodpecker is dropped entirely. GitHub Actions is the
      sole CI system and the exclusive publisher. Deploying binaries built on a
      developer machine is undesirable from a supply-chain standpoint;
      GitHub-hosted runners are the only authoritative build environment. Local
      development uses the same Makefile targets directly without a CI agent._

- [x] The `make fetch_pdfium` target reads `PDFIUM_VERSION` (a commit SHA) to
      identify the release to fetch. GitHub Releases are tagged by convention;
      the plan does not specify what the Release tag format is. Is the tag
      simply the PDFium commit SHA (e.g. `pdfium-abc1234`)? This must be defined
      before implementing `fetch_pdfium`. _Decision: Release tags use the format
      `pdfium-<full-sha>`, where `<full-sha>` is the complete PDFium commit SHA
      stored in `PDFIUM_VERSION`. This format is used consistently in the GitHub
      Release tag, in `make fetch_pdfium` (which constructs the tag from
      `PDFIUM_VERSION`), and in the artifact layout `VERSION.txt`. Partial SHAs
      are not used._

- [x] Woodpecker CI is described as "self-hosted, primary" but there is no
      mention of which machine(s) run the Woodpecker agent, what macOS version
      they run, or who maintains them. The macOS and iOS builds must run
      natively on arm64 — is the Mac Mini build server referenced in Phase 3
      already provisioned, or is its setup a prerequisite that should be listed
      as a Phase 0 task? _Decision: Woodpecker is dropped entirely. GitHub
      Actions macOS arm64 runners handle native macOS and iOS builds. No
      self-hosted agent is needed._

## Review

_Reviewed: 2026-05-21 (final — all questions resolved)_

**Problem Statement Assessment**

Sound and correctly motivated. Separating PDFium binary production from Dart
development is the right call: the toolchain is heavy, unrelated to Dart work,
and a C++ build failure should not block Dart CI. The platform scope (macOS
arm64, iOS arm64, Linux x86_64, Android arm64/x86_64, WASM) is now consistent
with the updated roadmap. All four blocking questions have been resolved and
recorded.

**Proposed Solution Assessment**

The core architectural decisions are good:

- Makefile-as-portability-layer is already established in this project. Thin CI
  wrappers keep CI system migration cheap, and developers use the same targets
  locally without any agent infrastructure.
- Podman for rootless Linux/Android/WASM builds is the right choice. No
  privileged daemon, images can be pinned for reproducibility.
- `PDFIUM_VERSION` as the explicit, human-readable rebuild trigger is clean and
  auditable.
- GitHub Actions as the sole CI system and exclusive publisher with an explicit
  supply-chain rationale is well-reasoned and documented.
- The `pdfium-<full-sha>` tag format is simple, unambiguous, and directly
  derivable from `PDFIUM_VERSION` without any mapping table.

Remaining gaps that the implementer must address (none are blockers for
`Investigated` status, but all must be resolved during implementation):

1. **`gclient sync` vs baked source.** ✅ _Resolved._ `gclient sync` runs at
   build time on `pdfium-build` (inside each container/host). The full PDFium
   source is never committed to the branch — it is too large (~several GB) and
   changes with each SHA update, making baked images impractical. CI caches the
   synced source tree keyed on the PDFium SHA so subsequent runs avoid a full
   re-sync. The `third_party/pdfium/` subtree on `main` (public headers only) is
   retained as-is — it is the source of truth for `ffigen` FFI binding
   generation and is unrelated to the build-time source fetch on `pdfium-build`.
   The Phase 1 task "Add PDFium source as a git subtree" is updated accordingly:
   the branch documents the `gclient sync` approach in its `README.md` rather
   than committing the source. **SHA consistency invariant:** `PDFIUM_VERSION`,
   the `third_party/pdfium/` headers subtree on `main`, and the SHA used by
   `gclient sync` on `pdfium-build` must always point to the same PDFium commit.
   A `PDFIUM_VERSION` bump must be accompanied by a matching `git subtree pull`
   to update the headers, followed by `make ffi_bindings` to regenerate the Dart
   FFI bindings. The Phase 5 documentation task must describe this bump workflow
   explicitly.

2. **`depot_tools` on `pdfium-build`.** ✅ _Resolved._ depot_tools is cloned at
   build time (consistent with `make setup` on `main`). It is not baked into
   container images — depot_tools updates frequently and baking it would require
   image rebuilds on every update. The CI cache (keyed on the PDFium SHA) covers
   the depot_tools clone alongside the `gclient sync` output. The
   `pdfium-build/README.md` must document the depot_tools clone step and the
   expected cache behaviour. The branch layout entry for `depot_tools/` is
   removed — there is no subtree; the clone happens at build time only.

3. **Cache strategy detail.** ✅ _Resolved._ GitHub Actions caches the
   depot_tools clone and `gclient sync` output keyed on the PDFium SHA using
   `actions/cache`. A cache miss triggers a full `gclient sync` + Ninja build.
   Based on experience building PDFium locally, a cold build takes well under 20
   minutes on a good broadband connection. The `pdfium-build/README.md` must
   call out the cache size explicitly and explain why it exists — the synced
   source tree is several GB and a developer running the Makefile targets
   locally without a warm cache will see significant disk usage and download
   time without warning.

4. **Artifact integrity.** ✅ _Resolved._ A `checksums.sha256` file is published
   alongside the release artifacts in Phase 4. `make fetch_pdfium` verifies each
   downloaded artifact against this file before unpacking. Verification failure
   must abort with a clear error — never silently continue with a corrupt or
   tampered binary that will be loaded via FFI. The `checksums.sha256` file and
   the verification step are added to the artifact layout and Phase 4/5
   implementation tasks respectively.

5. **Error handling in `make fetch_pdfium`.** ✅ _Resolved._ Binaries in
   `third_party/pdfium_bin/` use stable filenames (e.g. `libpdfium.dylib`) so
   the Dart FFI loader always has a predictable path without reading
   `PDFIUM_VERSION` at runtime. The installed SHA is recorded in the `VERSION`
   file; `make check_pdfium_version` compares it against `PDFIUM_VERSION` to
   detect staleness. `make fetch_pdfium` must:
   - Download artifacts to a temp directory, verify `checksums.sha256`, then
     atomically replace `third_party/pdfium_bin/` on success — a partial
     download never leaves a corrupt install.
   - Fail with a clear error naming the expected tag (e.g. `pdfium-<sha>`) when
     the GitHub Release does not exist, rather than silently returning a 404.
   - Be idempotent: re-running when the correct version is already installed
     (VERSION matches PDFIUM_VERSION) skips the download entirely.

6. **iOS xcframework packaging.** ✅ _Resolved._ Implementation detail left to
   the implementer. `scripts/build_ios.sh` must cover: GN args
   (`target_os="ios"`, `ios_deployment_target`), the
   `xcodebuild -create-xcframework` packaging step, and structuring the output
   as `libpdfium-ios-arm64.xcframework.zip` for the Release artifact. No
   additional constraints from planning.

7. **Smoke test before publish.** ✅ _Resolved._ Phase 4 must include a
   validation step before any Release artifact is attached. Each platform binary
   must be loaded and exercise `FPDF_InitLibraryWithConfig()` /
   `FPDF_DestroyLibrary()` successfully. A platform binary that fails this check
   must block the Release — no unvalidated binary is ever published. This task
   is added to the Phase 4 implementation checklist.

8. **Spec update.** ✅ _Resolved._ A new spec document in `docs/spec/` must
   formalise the binary distribution contract (artifact layout, tag format,
   `VERSION` file format, fetch mechanism, checksum verification). This is added
   as a Phase 5 task. `CLAUDE.md` retains its summary but defers to the spec as
   the authoritative reference.

9. **NDK and Emscripten version pinning.** ✅ _Resolved._ NDK and Emscripten
   versions must be read from PDFium's own build scripts (e.g. `DEPS`,
   `build/config/android/config.gni`, and the Emscripten pin in `third_party/`)
   rather than chosen independently. Deviating from PDFium's pinned versions
   risks runtime crashes (NDK) or broken WASM output (Emscripten). The
   Dockerfiles must extract and use these versions directly, and the pinned
   versions must be documented in `pdfium-build/README.md` with a note directing
   the maintainer back to the PDFium source when bumping the SHA.

10. **Podman machine lifecycle.** ✅ _Resolved._ Linux, Android, and WASM builds
    run inside Podman containers on GitHub Actions runners. The GitHub Actions
    runner environment handles the Podman socket lifecycle; no Mac Mini or
    persistent machine configuration is required. The `pdfium-build/README.md`
    must document how to start Podman locally for developers running the
    Makefile targets on their own machine.

**Architecture Fit**

The plan integrates cleanly with the existing project structure. The orphan
branch keeps `main` free of C++ toolchain concerns. The
`third_party/pdfium_bin/` layout established by
`plan_pdfium_build_infrastructure.md` is respected. The Makefile convention is
consistent throughout. There is no Flutter UI in this plan, so design and
inclusivity requirements do not apply.

**Risk and Edge Cases**

- **Build time.** Cold-cache runs across all six platform targets will likely
  exceed 3 hours of CI wall time. Cache hit rate is critical; the cache strategy
  must be implemented carefully.
- **`pdfium-build` branch drift.** As `main` advances, `pdfium-build` must be
  kept in sync (GN args, new headers, NDK/Emscripten updates). Assign clear
  ownership for this maintenance in `pdfium-build/README.md`.
- **Quarantine on downloaded dylibs.** The ad-hoc signing step in
  `make fetch_pdfium` correctly addresses the macOS quarantine issue for dylibs.
  WASM/JS artifacts are not affected.

**Recommendations**

All blocking questions are resolved. The implementation plan is actionable. The
gaps noted above (especially checksum verification, `gclient sync` strategy, and
the smoke test) should be addressed during their respective phases, not deferred
further.

Status: `Investigated` — ready for implementation.

## Summary

_To be completed after implementation._
