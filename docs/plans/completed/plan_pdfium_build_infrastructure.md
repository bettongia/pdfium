# PDFium macOS Binary Build

**Status**: Complete

**PR link**: —

## Problem statement

All implementation work in this project depends on PDFium compiled to a native
shared library. Without a local binary, no FFI bindings can be loaded, no
integration tests can run, and no Dart implementation work can begin.

This plan covers building a macOS dylib (arm64) locally using depot_tools and
Ninja, generating the initial Dart FFI bindings via `ffigen`, and validating
that the binary loads correctly. It is the minimum required to unblock all
subsequent Dart implementation plans. The dylib produced here is a developer
bootstrapping artifact — it will be replaced by pre-built binaries fetched from
the standalone pipeline (see `plan_pdfium_build_pipeline.md`) and is not
intended to be shipped.

Full cross-platform builds and CI/CD infrastructure are handled separately in
[plan_pdfium_build_pipeline.md](plan_pdfium_build_pipeline.md).

## Open questions

- [x] **depot_tools pinning**: Use HEAD — no pinning required for this plan.
- [x] **Output versioning**: Yes, include a `VERSION` file recording the PDFium
      commit SHA and build date.
- [x] **Architecture scope**: arm64 only for this plan. x86_64 and universal
      binary (`lipo`) are deferred to the standalone build pipeline.

## Investigation

### Clean-room build workspace

All build tooling and source downloads are confined to a `.build/` directory at
the project root. Nothing is written to the home directory or anywhere outside
the project. `.build/` is gitignored and can be deleted to start fresh.

```
.build/                        ← gitignored; rm -rf to reset
  depot_tools/                 ← cloned by make setup
  pdfium_checkout/             ← gclient workspace
    .gclient                   ← written by gclient config
    pdfium/                    ← full PDFium source + clang toolchain (~GB)
      out/mac-arm64/           ← build output
```

Makefile targets set `PATH=.build/depot_tools:$(PATH)` inline — no shell profile
changes are required from the developer.

The one external side-effect is that `gclient` writes a small authentication
cache to `~/.config/gclient`; the multi-gigabyte source tree and toolchain all
stay under `.build/`.

### Build toolchain

PDFium uses Chromium's build system: `depot_tools` (provides `gclient`, `gn`,
`ninja`) and GN + Ninja as the actual build tool. There is no CMake or Makefile
alternative.

`make setup` bootstraps the workspace from scratch:

1. Clone `depot_tools` into `.build/depot_tools/`.
2. Run `gclient config --unmanaged https://pdfium.googlesource.com/pdfium.git`
   inside `.build/pdfium_checkout/`.
3. Run `gclient sync` to download the full source tree and clang toolchain.

Subsequent `make build_pdfium_macos` calls skip setup if
`.build/pdfium_checkout/pdfium` already exists, making incremental rebuilds
fast. The guard uses this path (not `.build/`) so that a partial `gclient sync`
failure — where `.build/` exists but the source tree does not — is retried
correctly rather than silently skipped.

### GN build arguments

The following arguments are passed to `gn gen` for the arm64 release build:

```
is_debug = false
pdf_is_standalone = true
is_component_build = true
pdf_enable_xfa = false
pdf_enable_v8 = false
use_custom_libcxx = false
clang_use_chrome_plugins = false
target_cpu = "arm64"
target_os = "mac"
```

- `is_component_build = true` — produces a `.dylib` suitable for Dart FFI
  (static linking is not supported by the FFI loader).
- `pdf_enable_v8 = false` — disables JavaScript support, significantly reducing
  binary size and compile time.
- `pdf_enable_xfa = false` — disables XFA form support (further reduces size).
- `use_custom_libcxx = false` — uses the system libc++ rather than Chromium's
  bundled one, avoiding linker conflicts on macOS.
- `clang_use_chrome_plugins = false` — skips Chromium-specific clang plugins not
  needed outside the Chromium tree.

### Output layout

```
.build/                              ← gitignored build workspace
third_party/
  pdfium/                            ← public headers only (git subtree)
  pdfium_bin/                        ← gitignored; populated by make build_pdfium_macos
    macos_arm64/
      libpdfium.dylib
    VERSION                          ← PDFium commit SHA + build date
```

The `third_party/pdfium_bin/` directory layout established here is the
**canonical contract** that `plan_pdfium_build_pipeline.md` must match when it
replaces this local build with CI-fetched pre-built binaries. Any change to this
layout must be coordinated across both plans.

### FFI bindings generation

`ffigen` reads the PDFium public headers from `third_party/pdfium/public/` and
generates Dart bindings. The generated file is committed so that developers
without the full build toolchain can still edit Dart code.

The initial `ffigen` scope covers only `fpdfview.h` — the minimum needed to load
the library and render pages. Headers for text extraction, annotations, and
other features are added as those feature plans are implemented.

## Implementation plan

### Phase 1 — Clean-room workspace and macOS build

- [x] Create a roadmap entry for this infrastructure work in
      `docs/roadmap/0_01.md`.
- [x] Add `.build/` and `third_party/pdfium_bin/` to `.gitignore`.
- [x] Add `make setup` target that:
  - Skips entirely if `.build/pdfium_checkout/pdfium` already exists (same guard
    as `build_pdfium_macos` so a partial `gclient sync` failure is retried
    rather than skipped).
  - Clones depot_tools into `.build/depot_tools/` (skips if already present).
  - Creates `.build/pdfium_checkout/` and runs
    `gclient config --unmanaged https://pdfium.googlesource.com/pdfium.git`.
  - Runs `gclient sync` with `PATH=.build/depot_tools:$(PATH)` and
    `DEPOT_TOOLS_UPDATE=0` to prevent auto-updates during incremental builds.
  - Emits `@echo` progress messages before and after the `gclient sync` step
    (e.g. "gclient sync: this may take 20–40 minutes on first run") so the long
    download does not appear to stall.
- [x] Add `make build_pdfium_macos` target that:
  - Runs `make setup` if `.build/pdfium_checkout/pdfium` does not exist.
  - Runs `gn gen .build/pdfium_checkout/pdfium/out/mac-arm64` with the
    appropriate args (`target_cpu=arm64`, V8/XFA disabled, component build).
  - Runs `ninja -C .build/pdfium_checkout/pdfium/out/mac-arm64 pdfium`.
  - Copies the resulting `libpdfium.dylib` to
    `third_party/pdfium_bin/macos_arm64/`.
  - Runs `install_name_tool -id @rpath/libpdfium.dylib` on the copied dylib.
  - Writes a `VERSION` file to `third_party/pdfium_bin/` recording the PDFium
    commit SHA and build date.
  - **No codesign step**: a locally-built dylib is never assigned the
    `com.apple.quarantine` xattr, so Gatekeeper does not apply and
    `dlopen()` loads it without signing. Ad-hoc signing is deferred to
    `plan_pdfium_build_pipeline.md`, where fetched binaries are downloaded
    and will be quarantined.
- [x] Add `make clean_build` target that removes `.build/` entirely.
- [x] Consolidate existing notes from `build.md` into the above Makefile targets
      and remove `build.md`.
- [x] Document the workflow in `CLAUDE.md`: run `make setup` once, then
      `make build_pdfium_macos`; `make clean_build` to reset. Clarify that the
      binary must exist before running integration tests.

### Phase 2 — FFI bindings generation

- [x] Add `ffigen` to `pubspec.yaml` dev dependencies.
- [x] Create `ffigen.yaml` scoped to `fpdfview.h`.
- [x] Add `make ffi_bindings` target that runs `dart run ffigen`.
- [x] Commit the generated bindings file to the repository.
- [x] Document the regeneration procedure in `CLAUDE.md`.

### Phase 3 — Validation

- [x] Write a minimal Dart FFI smoke test that loads `libpdfium` and calls
      `FPDF_InitLibraryWithConfig()` + `FPDF_DestroyLibrary()` successfully on
      macOS arm64. The test skips gracefully when the dylib is absent so CI
      passes before the binary is built.
- [x] Verify the generated FFI bindings compile cleanly (`dart analyze .` — zero
      issues; bindings in `lib/src/generated/pdfium_bindings.dart` are
      `ignore_for_file: type=lint` as emitted by ffigen).
- [x] Run `make test` and confirm the smoke test passes (1 skipped when dylib
      absent, 1 passed for the bindings import test; 2 tests total pass).

### Phase 4 — Documentation

- [x] Update `addlicense_config.txt` to ignore `.build/**` (the clean-room
      workspace already has `third_party/**` covered).
- [x] Update `README.md` with a "Building PDFium" section describing
      `make setup` and `make build_pdfium_macos`.
- [x] Update `CLAUDE.md` with the full output layout and versioning convention.
- [x] Move this plan to `docs/plans/completed/` and update status to Complete.

## Reviews

### Review 1: 2026-05-18

_Reviewed: 2026-05-18_

**Problem Statement Assessment**

The problem is real and correctly scoped. Without a loadable `libpdfium.dylib`,
nothing else in the project can proceed — no FFI bindings can be exercised, no
integration tests can run, and no Dart implementation work is meaningful.
Treating this as a prerequisite gating item (rather than Phase 1 of some feature
plan) is exactly the right call. The constraint to arm64 macOS for this plan,
with a reference to the separate cross-platform pipeline plan, is appropriate
scoping.

One tension in the problem statement is worth naming explicitly: the plan says
it will "unblock all subsequent Dart implementation plans", yet
`plan_pdfium_build_pipeline.md` describes the longer-term answer (pre-built
binaries fetched from a standalone repo). This plan's output — a locally-built
dylib — is a developer bootstrapping step, not the eventual production artifact.
That distinction is implicit but should be stated clearly so implementers
understand the build they produce here will be replaced, not shipped.

**Proposed Solution Assessment**

Strengths:

- The clean-room `.build/` workspace is the right call. Keeping depot_tools and
  the multi-gigabyte pdfium checkout inside the project boundary makes the
  process reproducible and prevents polluting the developer's home directory.
- Inlining `PATH=.build/depot_tools:$(PATH)` into Makefile targets is correct —
  it avoids requiring shell profile changes and makes the targets
  self-contained.
- The GN argument set is sensible. Disabling V8 and XFA reduces binary size and
  compile time substantially with no loss for this project's goals.
- `is_component_build = true` is necessary for Dart FFI; noting the reasoning in
  the plan is good practice.
- Committing the generated FFI bindings is the right call for a Dart package —
  contributors who only need to edit Dart code should not need the full C++
  toolchain.
- Scoping `ffigen` to `fpdfview.h` only initially is prudent; adding headers
  incrementally as features are implemented avoids generating dead code.

Weaknesses and gaps:

1. **`~/.config/gclient` side-effect is under-documented.** The plan mentions
   this in a subordinate clause. Given the stated goal of "nothing is written to
   the home directory", this side-effect deserves a more prominent callout —
   ideally a note in the `make setup` documentation so developers are not
   surprised.

2. **No `GCLIENT_CACHE_DIR` or `DEPOT_TOOLS_UPDATE` control.** `gclient` by
   default also auto-updates depot_tools on every run (`DEPOT_TOOLS_UPDATE=1`).
   The plan does not mention setting `DEPOT_TOOLS_UPDATE=0` in the Makefile
   target environment, which could cause unexpected network fetches during
   incremental rebuilds. This should be set explicitly.

3. **`make setup` skips if `.build/` exists, but the plan is silent on partial
   failures.** If `gclient sync` fails partway through (network drop, disk
   full), `.build/pdfium_checkout/pdfium` may not exist but `.build/` does. The
   skip check "if `.build/pdfium_checkout/pdfium` does not exist" in
   `build_pdfium_macos` is fine, but `make setup` should guard on the same path,
   not on `.build/` existence. This is an easy crash-recovery failure mode.

4. **No codesign step.** `build.md` already documents that macOS 13+ may require
   ad-hoc signing (`codesign --force --sign -`) for the dylib to load. The plan
   includes `install_name_tool` but omits the signing step entirely. Given the
   target hardware (arm64, i.e. Apple Silicon Macs running macOS 13 or 14+),
   this is not a hypothetical — it is likely to be needed. The
   `build_pdfium_macos` target should include ad-hoc signing, or at minimum the
   plan should explicitly defer it with a rationale.

5. **`third_party/pdfium_bin/` placement and eventual replacement.** The plan
   outputs the dylib to `third_party/pdfium_bin/macos_arm64/`. This is
   gitignored. However, the `plan_pdfium_build_pipeline.md` plan also targets
   `third_party/pdfium_bin/` as the fetch destination for CI-built binaries. The
   two plans share a destination path without explicitly coordinating the
   handoff. This is fine as long as both plans produce the same directory
   layout, but it should be called out so the implementer knows the layout here
   is the canonical contract that the pipeline plan must match.

6. **The smoke test in Phase 3 calls `FPDF_InitLibraryWithConfig()`** but
   `fpdfview.h` also exports the simpler `FPDF_InitLibrary()`. Either works;
   `FPDF_InitLibraryWithConfig()` is the correct production form since it
   accepts allocator callbacks. The plan should confirm which form is intended
   and document whether the `FPDF_LIBRARY_CONFIG` struct fields should be zeroed
   for the smoke test.

7. **Test coverage accounting.** The 90% coverage requirement applies to Dart
   code. The Phase 3 smoke test is a Dart integration test — it counts toward
   coverage. However, it is the _only_ Dart test being written in this plan, and
   `lib/src/pdfart_base.dart` already exists. The plan should confirm that the
   smoke test either covers existing Dart code or that existing coverage is not
   regressed. If the only Dart file is a stub, this is fine, but it should be
   stated.

8. **`build.md` consolidation.** The plan correctly calls for removing
   `build.md` and folding its content into the Makefile and `CLAUDE.md`. Do not
   leave `build.md` in place post-implementation — it currently instructs
   developers to install depot_tools to `~/depot_tools`, which directly
   contradicts this plan's clean-room approach. Leaving both in place would
   create a confusing conflict.

**Architecture Fit**

The plan fits the existing architecture well. The Makefile-first convention is
already established; adding `make setup`, `make build_pdfium_macos`, and
`make ffi_bindings` follows the existing pattern. The `.build/` workspace
respects the project boundary. Using `ffigen` against
`third_party/pdfium/public/` is consistent with the headers-only subtree
approach already in place.

No spec contradictions were identified. There is no roadmap file yet for this
version, so no roadmap alignment issue, but a roadmap entry for the binary build
infrastructure should be created before or alongside implementation.

**Risk and Edge Cases**

- **`gclient sync` download size.** This is 2-5 GB depending on platform. First-
  time setup can take 20-40 minutes. The plan acknowledges this but does not
  suggest any Makefile messaging (e.g.
  `@echo "gclient sync: this may take 20-40 minutes on first run"`) to prevent
  developers from thinking the process has stalled.
- **`use_custom_libcxx = false` compatibility.** This is the right default for
  macOS, but if the system libc++ version is significantly older than what
  PDFium expects, the build may fail. This has been observed with some macOS
  versions. The plan should note that if the build fails with libc++ ABI errors,
  the developer should file an issue rather than silently toggling this flag.
- **`depot_tools` HEAD pinning.** The open question resolved to "no pinning
  required", which is pragmatic for bootstrapping. However, depot_tools HEAD can
  introduce breaking changes. Implementers should be aware that if
  `gclient sync` breaks in the future, pinning will need to be revisited. A
  comment in the Makefile is sufficient.
- **Parallel `ninja` without `-j` flag.** The plan specifies
  `ninja -C ... pdfium` without `-j$(nproc)` or similar. Ninja defaults to a
  number of jobs based on available CPUs, which is usually fine, but for a CI
  environment it is worth making this explicit. This is a minor concern for the
  local-build scope of this plan.

**Recommendations**

1. Add ad-hoc codesign to the `build_pdfium_macos` Makefile target, or add an
   explicit Phase 3 item for it with a rationale for deferral.
2. Set `DEPOT_TOOLS_UPDATE=0` in the Makefile target to prevent automatic
   depot_tools updates during incremental builds.
3. Make the `make setup` skip guard check for `.build/pdfium_checkout/pdfium`
   (not just `.build/`) to survive partial failures.
4. Add progress messaging to `make setup` so the 20-40 minute download does not
   appear to stall.
5. Explicitly state in the plan that `third_party/pdfium_bin/` directory layout
   is the canonical contract for `plan_pdfium_build_pipeline.md` to match.
6. Create a roadmap entry for this infrastructure work before starting
   implementation.
7. Remove `build.md` as a Phase 1 item (it is currently listed as Phase 4) — its
   contradictory instructions are a live hazard. Move removal earlier.

Overall, this is a solid, well-scoped plan. The gaps above are implementation
details rather than fundamental problems. The plan is ready for implementation
once items 1 through 3 are addressed (either in the implementation or by
updating the plan tasks to make them explicit).

## Summary

- Added `make setup`, `make build_pdfium_macos`, `make clean_build`, and
  `make ffi_bindings` targets to `Makefile`. All targets use an inline
  `PATH=.build/depot_tools:$(PATH) DEPOT_TOOLS_UPDATE=0` environment so no
  shell profile changes are required.
- The `make setup` and `make build_pdfium_macos` guards both check for
  `.build/pdfium_checkout/pdfium` (not just `.build/`) so partial `gclient sync`
  failures are retried rather than silently skipped.
- Progress `@echo` messages added around the 20–40 minute `gclient sync` step.
- `build.md` was removed in Phase 1 (not deferred to Phase 4) because its
  instructions to install depot_tools to `~/depot_tools` directly contradicted
  the clean-room approach.
- `ffigen ^13.0.0` added to `pubspec.yaml` dev dependencies. `ffigen.yaml`
  scoped to `fpdfview.h` only. Generated bindings committed at
  `lib/src/generated/pdfium_bindings.dart` (1 259 lines; 505 FPDF_ references).
- Dart FFI smoke test at `test/pdfium_smoke_test.dart` skips gracefully when
  `third_party/pdfium_bin/macos_arm64/libpdfium.dylib` is absent, allowing CI
  to pass before the binary is built. Two tests pass, one skipped.
- `addlicense_config.txt` updated to ignore `.build/**`.
- `README.md` rewritten with a "Building PDFium" section covering prerequisites,
  `make setup`, `make build_pdfium_macos`, `make clean_build`, and
  `make ffi_bindings`.
- `CLAUDE.md` updated with the complete build workflow, output layout, versioning
  convention, codesigning rationale, and repository layout including the new
  `lib/src/generated/`, `third_party/pdfium_bin/`, and `.build/` directories.
- `docs/roadmap/0_01.md` populated with the PDFium build infrastructure item
  and placeholder entries for subsequent feature plans.
- `third_party/pdfium_bin/` directory layout is the canonical contract for
  `plan_pdfium_build_pipeline.md` to match when CI-fetched binaries replace the
  local build.
