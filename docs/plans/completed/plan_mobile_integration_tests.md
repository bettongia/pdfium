# Mobile integration test app (iOS and Android)

**Status**: Complete

**PR link**: _not yet submitted_

## Problem statement

The existing test suite (`dart test`) covers macOS arm64 and Linux (x64, arm64)
— the platforms where `DynamicLibrary.open()` loads a pre-built PDFium dylib from
`third_party/pdfium_bin/`. There is no test coverage for iOS or Android.

The pdfium-build pipeline already publishes the required native artifacts in
every GitHub Release:
- `libpdfium-ios-arm64.xcframework.zip` — static xcframework (linked at build time)
- `libpdfium-android-arm64.so` — shared library
- `libpdfium-android-x86_64.so` — shared library

This plan creates a standalone Flutter app in `integration_test_app/` that
runs the equivalent of the desktop test suite on a connected iOS or Android
device. Tests are run manually (`flutter test integration_test/ -d <device-id>`);
CI automation is out of scope for this plan.

## Open questions

- [x] What release artifacts are available for mobile? → xcframework (iOS static)
      and two Android `.so` files; confirmed from the live release.
- [x] Does iOS need `DynamicLibrary.open()` or `DynamicLibrary.process()`?
      → Static xcframework → `DynamicLibrary.process()` after CocoaPods links it.
- [x] Is the zstd `integration_test_app` pattern a good match? → Yes; only
      binary bundling and the library-load path differ.

## Investigation

### Release artifacts

From `gh release view pdfium-<sha> --repo bettongia/pdfium`:

| Artifact                              | Platform       | Load mechanism              |
| ------------------------------------- | -------------- | --------------------------- |
| `libpdfium-macos-arm64.dylib`         | macOS arm64    | `DynamicLibrary.open(path)` |
| `libpdfium-linux-x86_64.so`           | Linux x64      | `DynamicLibrary.open(path)` |
| `libpdfium-linux-arm64.so`            | Linux arm64    | `DynamicLibrary.open(path)` |
| `libpdfium-android-arm64.so`          | Android arm64  | `DynamicLibrary.open('libpdfium.so')` |
| `libpdfium-android-x86_64.so`        | Android x86_64 | `DynamicLibrary.open('libpdfium.so')` |
| `libpdfium-ios-arm64.xcframework.zip` | iOS arm64      | `DynamicLibrary.process()`  |

### Library loading: RESOLVED

`_defaultDylibPath()` in `lib/src/document/pdfium_isolate.dart` only handled
Linux and macOS. These changes were implemented as part of the native-assets
hook work.

**Implemented in `lib/src/document/`:**

1. `isolate_messages.dart` — `PdfiumInitCommand.dylibPath` changed from
   `String` to `String?`; `null` means "auto-detect via `_openLibrary()`".

2. `pdfium_isolate.dart` (isolate entry point) — now dispatches on nullability:
   ```dart
   final dylib = message.dylibPath != null
       ? ffi.DynamicLibrary.open(message.dylibPath!)
       : _openLibrary();
   ```

3. `pdfium_isolate.dart` — `_defaultDylibPath()` replaced by two functions:
   - `_defaultDylibPathOrNull()` — returns the legacy `third_party/pdfium_bin/`
     path if it exists (backward compat with `make fetch_pdfium`), else `null`.
     Returns `null` immediately for iOS and Android (no legacy path for mobile).
   - `_openLibrary()` — full multi-strategy loader:
     iOS → `DynamicLibrary.process()`, Android/Linux → bare `libpdfium.so`,
     macOS → tries framework bundle, then exe-adjacent, then hook cache.

4. `_spawn()` updated to call `_defaultDylibPathOrNull()` instead of the old
   `_defaultDylibPath()`.

### Integration test app structure

Mirrors `bettongia/zstd/integration_test_app/`:

```
integration_test_app/
  lib/
    main.dart                    # minimal Flutter scaffold (same as zstd)
  integration_test/
    pdfium_test.dart             # full test suite (see "Test coverage" below)
  assets/                        # PDF fixtures (mirrors test/fixtures/ + test/data/)
    data/
      00_empty.pdf
      01_basic.pdf
      thumbnail_fixture.pdf
      arxiv/                     # arxiv fixture PDFs
    fixtures/
      annotated_text.pdf
      annotated_shapes.pdf
      annotated_ink.pdf
      annotated_extra.pdf
      broken_image_metadata.pdf
      corrupt.pdf
      deep_toc.pdf
      empty_uri_link.pdf
      fit_toc.pdf
      flat_toc.pdf
      full_metadata.pdf
      large.pdf
      mixed.pdf
      multi_column.pdf
      multi_image.pdf
      multi_page_annotated.pdf
      nested_toc.pdf
      no_annotations.pdf
      no_images.pdf
      no_metadata.pdf
      no_toc.pdf
      partial_metadata.pdf
      password.pdf
      popup_annotation.pdf
      popup_freetext.pdf
      popup_multi.pdf
      scanned.pdf
      search_multipage.pdf
      search_single.pdf
      single_column.pdf
      single_image.pdf
      soft_hyphens.pdf
      zero_ink_stroke.pdf
      zero_polygon_vertices.pdf
  scripts/
    fetch_mobile_binaries.sh     # download Android .so + iOS xcframework from release
  android/
    src/main/jniLibs/            # gitignored; populated by fetch_mobile_binaries.sh
      arm64-v8a/libpdfium.so
      x86_64/libpdfium.so
  ios/
    Frameworks/                  # gitignored; populated by fetch_mobile_binaries.sh
      pdfium.xcframework/
    LocalPackages/
      pdfium/
        Package.swift            # local SPM package: source target + binaryTarget
        Sources/
          PdfiumAnchor/
            pdfium_anchor.c      # references FPDF_InitLibraryWithConfig to prevent dead-stripping
  pubspec.yaml
  .gitignore
```

### iOS binary embedding

The xcframework is static, so it must be linked at compile time. CocoaPods is
being discontinued; Swift Package Manager is used instead.

Flutter's SPM support is enabled with:
```bash
flutter config --enable-swift-package-manager
```

A local SPM package vends the xcframework. A bare `binaryTarget` is not
sufficient: because PDFium is a C library with no Swift/ObjC wrapper and Dart
resolves all symbols at runtime via `DynamicLibrary.process()`, the linker has
zero compile-time references to `FPDF_*` and is free to dead-strip the entire
archive. To prevent this, the package adds a thin C source target that
explicitly references `FPDF_InitLibraryWithConfig`, mirroring the established pattern in this project where a thin native source
target creates compile-time symbol references to a static xcframework so that
`DynamicLibrary.process()` can resolve them at runtime.

**`ios/LocalPackages/pdfium/Package.swift`:**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pdfium",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "pdfium", targets: ["pdfium"]),
    ],
    targets: [
        .target(
            name: "pdfium",
            dependencies: ["pdfium_binary"],
            path: "Sources/PdfiumAnchor"
        ),
        .binaryTarget(
            name: "pdfium_binary",
            path: "../../Frameworks/pdfium.xcframework"
        ),
    ]
)
```

**`ios/LocalPackages/pdfium/Sources/PdfiumAnchor/pdfium_anchor.c`:**
```c
extern void FPDF_InitLibraryWithConfig(const void* config);
__attribute__((used)) static void* __pdfium_anchor = (void*)&FPDF_InitLibraryWithConfig;
```

The `__attribute__((used))` prevents the compiler from optimising away the
reference. The linker then sees a reference to `FPDF_InitLibraryWithConfig`,
pulls that translation unit from the archive, and the transitive closure of the
library survives dead-stripping. `DynamicLibrary.process()` can then resolve
all `FPDF_*` symbols at runtime.

The path `../../Frameworks/pdfium.xcframework` is relative to the `Package.swift`
and resolves to `ios/Frameworks/pdfium.xcframework` — the gitignored location
populated by `fetch_mobile_binaries.sh`.

The local package must be added to the Flutter Xcode project once (File → Add
Package Dependencies → Add Local → select `ios/LocalPackages/pdfium/`). The
resulting `project.pbxproj` change is committed to the repo so subsequent
developers only need to run `fetch_mobile_binaries.sh`.

After linking, PDFium symbols are in the process image →
`DynamicLibrary.process()` works.

### Android binary embedding

Shared libraries placed in `jniLibs/` are automatically packaged by Gradle and
loaded by the OS when the app starts. Dart can then call
`DynamicLibrary.open('libpdfium.so')`.

No `build.gradle` changes needed — Flutter's default Gradle setup picks up
`android/src/main/jniLibs/` automatically.

### `fetch_mobile_binaries.sh`

Reads download URLs and SHA-256 digests from `../version_pdfium.json` (the
same manifest the native-assets hook uses) rather than re-fetching
`checksums.sha256` from GitHub. This keeps a single source of truth for all
platform checksums.

`version_pdfium.json` must be extended to include iOS and Android entries
before this script can be written (see implementation plan item below).
`scripts/update_pdfium_manifest.sh` must be updated at the same time to
extract those additional SHA-256s.

Once `version_pdfium.json` contains all six platform entries, the script:
1. Parses the `ios-arm64`, `android-arm64`, and `android-x64` entries
2. Downloads and verifies each file against the known SHA-256
3. Unzips the xcframework; places `.so` files directly
4. Installs to:
   - `android/src/main/jniLibs/arm64-v8a/libpdfium.so`
   - `android/src/main/jniLibs/x86_64/libpdfium.so`
   - `ios/Frameworks/pdfium.xcframework/` (unzipped from `.xcframework.zip`)

> **Android note**: the Android `.so` artifacts in the release tagged
> `pdfium-75ea0a73…` were initially broken (5 KB stub). Root cause: the
> release was built before commit `873adf898` ("Always define COMPONENT_BUILD")
> landed in the `pdfium-build` branch. Without `COMPONENT_BUILD`, `FPDF_EXPORT`
> expanded to nothing; `-fvisibility=hidden` hid all symbols; `--gc-sections`
> removed all code. Fix shipped 2026-06-26:
> - `build_pdfium.yml`: Android cache key bumped `v2 → v3` (forces a fresh
>   build); publish job now deletes an existing release before re-creating so
>   re-runs replace rather than fail.
> - `pdfium-build/scripts/build_android.sh`: size guard added — build fails
>   with a clear error if neither the stripped nor unstripped `.so` exceeds
>   1 MiB, with a pointer to the COMPONENT_BUILD patch.
>
> The release was rebuilt on 2026-06-26. Both Android artifacts in
> `pdfium-75ea0a73…` are now confirmed working (>3 MB each). Android manifest
> entries and emulator verification are unblocked.

> **Future**: once the hook gains working Android support, `flutter build` will
> bundle the `.so` automatically via native-assets and the Android half of
> `fetch_mobile_binaries.sh` can be dropped.

### Test coverage

The integration test suite replicates the desktop test suite as closely as
possible. PDFs are loaded via `rootBundle.load()` and converted to `Uint8List`:

```dart
Future<Uint8List> loadAsset(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List();
}
```

Test groups to cover:

| Group                  | Key PDFs                                              | Assertions                                    |
| ---------------------- | ----------------------------------------------------- | --------------------------------------------- |
| Smoke                  | `01_basic.pdf`                                        | `PdfDocument.fromBytes()` succeeds; `close()` |
| Page count             | `01_basic.pdf`, `multi_page_annotated.pdf`            | `pageCount` matches expected value            |
| Metadata               | `full_metadata.pdf`, `no_metadata.pdf`, `partial_metadata.pdf` | field values and null handling      |
| Plain text extraction  | `single_column.pdf`, `multi_column.pdf`, `soft_hyphens.pdf` | non-empty text; known strings       |
| Rendering              | `01_basic.pdf`                                        | BGRA byte count = width × height × 4         |
| Annotations            | `annotated_text.pdf`, `annotated_shapes.pdf`, `annotated_ink.pdf`, `no_annotations.pdf` | type counts |
| Image extraction       | `single_image.pdf`, `multi_image.pdf`, `no_images.pdf` | image count; non-empty bytes         |
| Table of contents      | `flat_toc.pdf`, `nested_toc.pdf`, `no_toc.pdf`        | title/depth of first entry; empty list        |
| Search                 | `search_single.pdf`, `search_multipage.pdf`           | match count; rect non-empty                   |
| Thumbnail              | `thumbnail_fixture.pdf`, `01_basic.pdf`               | non-empty BGRA bytes                          |
| Error handling         | `corrupt.pdf`, `password.pdf`, `00_empty.pdf`         | `PdfiumException` thrown; no crash            |

### Files to create

- `integration_test_app/lib/main.dart`
- `integration_test_app/pubspec.yaml`
- `integration_test_app/integration_test/pdfium_test.dart`
- `integration_test_app/scripts/fetch_mobile_binaries.sh`
- `integration_test_app/ios/LocalPackages/pdfium/Package.swift`
- `integration_test_app/.gitignore`
- All PDF assets copied from `test/fixtures/` and `test/data/`

### Files to modify (in root package)

- `version_pdfium.json` — add `ios-arm64`, `android-arm64`, `android-x64` entries
- `scripts/update_pdfium_manifest.sh` — extract and write the three new SHA-256s

### Files modified (already done)

- `lib/src/document/isolate_messages.dart` — `dylibPath: String` → `String?` ✓
- `lib/src/document/pdfium_isolate.dart` — `_defaultDylibPathOrNull()` and
  `_openLibrary()` added; isolate entry point updated ✓

### License headers

All new Dart and shell files must carry the Apache 2.0 header from
`@header_template.txt`. The `integration_test_app/` is a separate package and
is not covered by the root `addlicense_config.txt`. License headers should be
added manually.

### Running the tests

```bash
# One-time global setup
flutter config --enable-swift-package-manager

# One-time per-clone setup (from integration_test_app/)
scripts/fetch_mobile_binaries.sh
# Then open ios/Runner.xcworkspace in Xcode and add the local package:
#   File → Add Package Dependencies → Add Local → select ios/LocalPackages/pdfium/
# Commit the resulting project.pbxproj change.

# iOS (device or simulator with arm64 support)
flutter test integration_test/ -d <device-id>

# Android
flutter test integration_test/ -d <device-id>
```

## Implementation plan

- [x] **`pdfium_isolate.dart` and `isolate_messages.dart`** — `dylibPath` made
      nullable; `_openLibrary()` handles iOS (`DynamicLibrary.process()`) and
      Android (`DynamicLibrary.open('libpdfium.so')`); isolate entry point
      dispatches on null. Done as part of native-assets hook work.

- [x] **Extend `version_pdfium.json`** — add `ios-arm64`, `android-arm64`, and
      `android-x64` entries. Update `scripts/update_pdfium_manifest.sh` to
      extract those three additional SHA-256s from `checksums.sha256` when
      updating the manifest.

- [x] **`fetch_mobile_binaries.sh`** — reads URLs and SHA-256 digests from
      `../version_pdfium.json` (no separate `checksums.sha256` download);
      downloads, verifies, and installs into `android/src/main/jniLibs/` and
      `ios/Frameworks/`. Support `--ios-only` flag while Android artifacts
      remain broken.

- [x] **Flutter app scaffold** — `lib/main.dart` and `pubspec.yaml` (with asset
      declarations for all PDFs in `assets/`).

- [x] **Makefile targets** — add the following to the root `Makefile`,
      following the same pattern as the mobile targets in the ONNX Runtime
      package:
      - `sync_fixtures` — copies `test/fixtures/` and `test/data/` into
        `integration_test_app/assets/` via `rsync -a --delete`
      - `fetch_mobile_binaries` — runs
        `integration_test_app/scripts/fetch_mobile_binaries.sh`
      - `ios_test` — depends on `sync_fixtures` and `fetch_mobile_binaries`;
        boots the simulator if not already booted, then runs
        `flutter test integration_test/` against it
      - `android_test` — depends on `sync_fixtures` and
        `fetch_mobile_binaries`; launches the Android emulator, waits for
        device, then runs `flutter test integration_test/`
      - `emulator_ios_create` / `emulator_android_create` — one-time AVD/
        simulator creation
      - `emulators_stop` / `emulators_stop_ios` / `emulators_stop_android`
        — tear down running emulators

- [x] **Populate PDF fixtures** — run `make sync_fixtures` to perform the
      initial copy of `test/fixtures/` and `test/data/` into
      `integration_test_app/assets/`; commit the result.

- [x] **`ios/LocalPackages/pdfium/` SPM package** — create `Package.swift`
      with a source target (`pdfium`) depending on a `binaryTarget`
      (`pdfium_binary`) pointing to `../../Frameworks/pdfium.xcframework`.
      Create `Sources/PdfiumAnchor/pdfium_anchor.c` with an
      `__attribute__((used))` pointer to `FPDF_InitLibraryWithConfig` to
      prevent linker dead-stripping. Enable Flutter SPM support with
      `flutter config --enable-swift-package-manager`. Add the local package
      to the Xcode project (one-time manual step); commit the
      `project.pbxproj` change so the reference is version-controlled.

- [x] **`.gitignore`** — exclude `android/src/main/jniLibs/` and
      `ios/Frameworks/`.

- [x] **`integration_test/pdfium_test.dart`** — full test suite covering all
      groups in the table above. Use `rootBundle.load()` for PDF bytes.

- [ ] **Verify on iOS simulator** — run `scripts/fetch_mobile_binaries.sh` then
      `flutter test integration_test/ -d <simulator-id>`; confirm all tests pass.
      (Deferred: requires Xcode simulator and Flutter; run manually with `make ios_test`)

- [ ] **Verify on Android emulator** — same but with an Android device/emulator.
      (Deferred: requires Android emulator; run manually with `make android_test`)

- [x] **Update `docs/spec/01_binary_distribution.md`** — two additions:
      (a) document the three new `version_pdfium.json` entries (`ios-arm64`,
      `android-arm64`, `android-x64`) and clarify they are consumed by
      `fetch_mobile_binaries.sh`, not the native-assets hook; (b) document the
      iOS dead-strip prevention mechanism (SPM source target with C anchor
      file) so future maintainers understand why `Package.swift` has two
      targets rather than just a `binaryTarget`.

- [x] **Update `CLAUDE.md`** — document the `integration_test_app/` and how to
      run it.

- [x] **Quality review** — invoke the `bettongia:quality-reviewer` agent to
      audit all code and changes produced by this plan before marking the work
      complete.

- [x] **`make pre_commit` must pass** — run `make pre_commit` (format check,
      static analysis, license check, tests) and confirm it exits cleanly.
      Result: 398 tests pass, zero analyzer issues, zero license issues.

## Reviews

### Review 1: 2026-06-26

**Problem Statement Assessment**

The problem is real and worth solving. The desktop suite (`dart test`) genuinely
cannot exercise the iOS and Android library-load paths — `DynamicLibrary.process()`
(iOS static link) and bare-name `DynamicLibrary.open('libpdfium.so')` (Android)
are platform-gated branches in `_openLibrary()` that no host test can reach.
Without an on-device harness these branches ship unverified. The investigation
is thorough and the "already done" claims check out: the nullable `dylibPath`,
`_defaultDylibPathOrNull()`, and `_openLibrary()` all exist as described in
`lib/src/document/pdfium_isolate.dart` and `isolate_messages.dart`.

Two framing concerns:

1. **No roadmap entry.** Nothing in `docs/roadmap/` covers a mobile integration
   test harness. v0.07 ("Ship it everywhere") produced the artifacts but does not
   mention verifying them on device. A verification harness for the v0.07 mobile
   targets should be recorded as a roadmap item (most naturally under v0.07, or a
   new milestone) so this work is traceable. The plan should reconcile this.

2. **Scope honesty on Android.** The plan states the Android `.so` artifacts in
   the current release are broken (5 KB stub). Yet the implementation checklist
   still contains "Verify on Android emulator — confirm all tests pass." That is
   not achievable with a broken binary. The Android verification step is a
   contradiction with the stated artifact state — see open questions.

**Proposed Solution Assessment**

Strengths: mirroring the established `zstd/integration_test_app/` pattern is
sensible; keeping CI automation out of scope is a reasonable first cut; sourcing
URLs and digests from `version_pdfium.json` (single source of truth) is the right
call and consistent with the native-assets hook.

Weaknesses:

- **The zstd pattern is a weaker match than claimed for the binary path.** zstd
  relies entirely on its native-assets hook for both iOS and Android — its app
  has no `scripts/`, no `jniLibs/`, no local SPM package (verified). This plan
  invents a whole manual fetch/embed pipeline (`fetch_mobile_binaries.sh`,
  `jniLibs/`, local SPM binary target) precisely because the pdfium hook skips
  iOS/Android. So there is no zstd precedent to copy for the hardest part. Open
  question 3 ("zstd pattern is a good match → Yes") overstates the alignment for
  the binary-bundling path specifically.

- **iOS static-link dead-stripping is unaddressed and is the single biggest
  technical risk.** A static xcframework only contributes symbols the linker
  sees referenced. Nothing in the Dart, Swift, or `GeneratedPluginRegistrant`
  code references `FPDF_*` at link time — Dart resolves them at runtime via
  `DynamicLibrary.process()`. The linker is therefore free to dead-strip the
  entire PDFium archive, after which `process()` lookups fail at runtime. SPM
  `binaryTarget` does not force-load by default. This typically needs
  `-force_load`/`-all_load` or an undefined-symbol reference
  (`-Wl,-u,_FPDF_InitLibraryWithConfig`) in the linker flags. The plan must
  account for this or the iOS path will likely fail at first run.

**Architecture Fit**

- The pure-Dart constraint of the package is preserved. `integration_test_app/`
  is a separate Flutter package depending on `betto_pdfium` by path; it does not
  pull Flutter into `lib/`. The already-landed isolate changes use only
  `dart:ffi`/`dart:io` — no Flutter leakage. Library-architecture layering is
  intact; no barrel or public-API changes are proposed. PASS on layer integrity.

- **Spec drift.** `docs/spec/01_binary_distribution.md` documents the
  `version_pdfium.json` manifest with exactly three platform entries
  (macos-arm64, linux-arm64, linux-x64) and an explicit "Unsupported platforms
  (hook): iOS/Android skipped" table. This plan extends the manifest with
  `ios-arm64`, `android-arm64`, `android-x64` entries that the hook will *not*
  consume — they exist solely for `fetch_mobile_binaries.sh`. That is a
  meaningful change to the documented contract and will confuse the next reader
  (entries present but hook-skipped). Updating spec 01 to describe the extended
  manifest and which consumer reads which entries must be an explicit task in
  this plan. It currently is not.

**Risk & Edge Cases**

- **Recording a SHA-256 for a known-broken Android stub.** Adding digests for
  the 5 KB stub bakes a checksum for a non-functional binary into the manifest.
  When the pipeline is fixed the artifact (and digest) changes and the manifest
  must be rewritten again. This gives a false impression of completeness. Prefer
  deferring the Android manifest entries until the artifact is real, rather than
  pinning a digest to a stub.

- **Fixture duplication and drift.** Copying ~40 PDFs from `test/fixtures/` and
  `test/data/` into `integration_test_app/assets/` creates a second copy that
  will silently diverge from the canonical fixtures as the desktop suite evolves.
  Flutter cannot declare assets outside the package root, so some sync mechanism
  (a copy/sync script run before the on-device suite, reusing the fetch pattern)
  is preferable to a one-time manual copy. The plan lists "Copy PDF fixtures" as
  a manual checklist item with no anti-drift strategy.

- **Generated native project trees.** The file tree shows only
  `ios/LocalPackages/`, `ios/Frameworks/`, and `android/src/main/jniLibs/`. For
  the committed `project.pbxproj` package reference to be meaningful, the full
  `flutter create`-generated `ios/Runner.xcodeproj`/`.xcworkspace` and the
  Android Gradle project must be version-controlled (zstd commits these). The
  plan is silent on whether the generated trees are committed or regenerated —
  clarify, because the manual "Add Local Package" step depends on a committed
  Xcode project.

- **Coverage of the already-landed branches.** The iOS/Android arms of
  `_openLibrary()`/`_defaultDylibPathOrNull()` cannot execute on a macOS/Linux
  host, so they count against the 90% line-coverage gate unless coverage-ignored.
  Confirm whether they are already excluded or accepted; this plan adds no host
  tests and must not regress `make coverage`.

- Stale resolved-answer text: open question 2's recorded answer still says
  "after CocoaPods links it" while the investigation switches to SPM. Minor, but
  tidy it so the decision record is internally consistent.

**Recommendations**

The investigation is strong and the core runtime change is already in place, but
this is not yet ready to implement. Resolve the open questions below first —
particularly the iOS dead-strip linker question (a likely first-run failure) and
the spec-update task. Recommend: (a) add the linker force-load handling to the
iOS plan; (b) add a "update spec 01" task; (c) descope Android to "scaffold +
manifest entry deferred until the artifact is fixed" and remove the
"verify all tests pass on Android" step; (d) add an anti-drift fixture-sync
mechanism; (e) reconcile against `docs/roadmap/`.

**Open questions**

- [x] How will iOS avoid linker dead-stripping of the statically-linked PDFium
      archive? `DynamicLibrary.process()` only works if the symbols survive the
      link. Does the SPM `binaryTarget` need `-force_load` / `-all_load` / a
      `-Wl,-u,_FPDF_InitLibraryWithConfig` reference, and where is that flag set?
      _Decision: the local SPM package adds a thin C source target
      (`Sources/PdfiumAnchor/pdfium_anchor.c`) alongside the `binaryTarget`.
      The C file holds a single `__attribute__((used))` pointer to
      `FPDF_InitLibraryWithConfig`, giving the linker a compile-time reference
      that prevents dead-stripping without needing any Xcode linker flag changes.
      See the "iOS binary embedding" section for the full `Package.swift` and
      source file._
- [x] Add an explicit task to update `docs/spec/01_binary_distribution.md` for
      the extended `version_pdfium.json` (ios-arm64, android-arm64, android-x64)
      and to clarify that those entries are consumed by `fetch_mobile_binaries.sh`,
      not the hook. Will the plan own this spec change?
      _Decision: yes, this plan owns the spec update. Two spec tasks are added
      to the implementation plan: one for the extended manifest entries, one for
      the iOS dead-strip prevention mechanism (the SPM source target pattern)._
- [x] Android scope: given the artifacts are a broken 5 KB stub, should the
      "Verify on Android emulator" step and the Android manifest digests be
      deferred until the build pipeline ships a real `.so`, rather than pinning a
      checksum to a stub?
      _Decision: unblocked. The release `pdfium-75ea0a73…` was rebuilt
      2026-06-26; both Android artifacts are confirmed working (>3 MB each).
      Android manifest entries and emulator verification proceed as planned —
      no deferral needed._
- [x] Are the full `flutter create`-generated `ios/` and `android/` project
      trees committed (so the `project.pbxproj` local-package reference is
      reproducible), or regenerated per clone?
      _Decision: committed. The `project.pbxproj` local-package reference
      requires the surrounding Xcode project to be version-controlled, and
      committing the generated trees is consistent with how the zstd
      `integration_test_app` is structured in this project._
- [x] What is the anti-drift strategy for the ~40 duplicated PDF fixtures — a
      sync script run before the on-device suite, or accepted manual copy?
      _Decision: a `make sync_fixtures` target in the root `Makefile` that
      copies `test/fixtures/` and `test/data/` into
      `integration_test_app/assets/`. It is wired as a prerequisite of
      `make ios_test` and `make android_test` so fixtures are always
      up-to-date before a mobile test run. The initial population of
      `integration_test_app/assets/` is done by running `make sync_fixtures`
      once; the assets directory is committed so the app works without a
      prior sync, but the target ensures the canonical source stays in sync
      as the desktop suite evolves._
- [x] Do the iOS/Android branches added to `pdfium_isolate.dart` keep
      `make coverage` at/above 90% (coverage-ignored or otherwise accounted for)?
      _Decision: the package does not currently meet the 90% gate, so this
      plan does not regress against it. Instead: (a) apply
      `// coverage:ignore` pragmas to the iOS/Android platform-gated branches
      in `pdfium_isolate.dart` — they are unreachable on the macOS/Linux test
      host and mocking them would not constitute meaningful coverage; (b) any
      new Dart code added to the main package by this plan should aim for 90%
      coverage of that new code specifically; (c) `integration_test_app/`
      code is itself the test harness and does not require unit test coverage
      of its own._
- [x] Should this work be recorded as a roadmap item (e.g. under v0.07) so the
      mobile-verification effort is traceable?
      _Decision: done. The mobile integration test app is explicitly documented
      in `docs/roadmap/0_01.md` as a planned item under the v0.01 milestone,
      with scope, status table, and a pointer to this plan._

## Summary

- Added `ios-arm64`, `android-arm64`, and `android-x64` entries to
  `version_pdfium.json` using checksums from the `pdfium-75ea0a73…` GitHub
  Release, giving `fetch_mobile_binaries.sh` a single source of truth for URLs
  and digests.

- Updated `scripts/update_pdfium_manifest.sh` to extract and write all six
  platform SHA-256 values (three hook platforms + three mobile platforms)
  whenever the PDFium SHA is bumped.

- Created `integration_test_app/` — a standalone Flutter package that hosts the
  on-device test suite. Key files:
  - `lib/main.dart` — minimal Flutter scaffold
  - `pubspec.yaml` — declares all PDF fixture assets
  - `integration_test/pdfium_test.dart` — 11 test groups (Smoke, Page count,
    Metadata, Plain text, Rendering, Annotations, Image extraction, TOC, Search,
    Thumbnail, Error handling + Page size) mirroring the desktop suite
  - `scripts/fetch_mobile_binaries.sh` — downloads and SHA-256-verifies the iOS
    xcframework and Android `.so` files from the manifest; supports
    `--ios-only` / `--android-only` flags
  - `.gitignore` — excludes `ios/Frameworks/` and `android/src/main/jniLibs/`

- Created `integration_test_app/ios/LocalPackages/pdfium/` — a local SPM package
  with two targets (`pdfium` source target + `pdfium_binary` binaryTarget) to
  prevent linker dead-stripping of the static xcframework. The C anchor file
  (`Sources/PdfiumAnchor/pdfium_anchor.c`) holds an `__attribute__((used))`
  pointer to `FPDF_InitLibraryWithConfig`.

- Added Makefile targets: `sync_fixtures`, `fetch_mobile_binaries`, `ios_test`,
  `android_test`, `emulator_ios_create`, `emulator_android_create`,
  `emulators_stop`, `emulators_stop_ios`, `emulators_stop_android`. The
  `ios_test` and `android_test` targets depend on `sync_fixtures` so fixtures
  are always up-to-date before a mobile run.

- Ran `make sync_fixtures` to populate `integration_test_app/assets/` with all
  40+ PDF fixtures from `test/fixtures/` and `test/data/`.

- Added `// coverage:ignore-start/end` pragmas to the iOS/Android branches of
  `_openLibrary()` in `pdfium_isolate.dart`, and a `// coverage:ignore-next-line`
  to the iOS/Android early-return in `_defaultDylibPathOrNull()`. These branches
  are unreachable on the macOS/Linux test host.

- Added `integration_test_app/**` exclusion to `analysis_options.yaml` so
  `dart analyze` does not attempt to resolve Flutter SDK packages that are not
  available to the root Dart analyzer.

- Updated `docs/spec/01_binary_distribution.md` to document: (a) the extended
  six-entry manifest and the consumer-mapping table distinguishing hook vs.
  mobile entries; (b) the iOS dead-strip prevention mechanism (two-target SPM
  package with C anchor file); (c) the Android `jniLibs/` bundling approach.

- Updated `CLAUDE.md` to document `integration_test_app/` in the repository
  layout, the Makefile mobile targets, environment variable overrides, and
  one-time setup steps for iOS (SPM local package registration) and Android.

- `make pre_commit` passes cleanly: 398 tests, zero analyzer issues, zero
  license issues.

- Deviations from plan:
  - "Verify on iOS simulator" and "Verify on Android emulator" are deferred —
    they require physical/emulated devices unavailable in this environment. The
    `make ios_test` and `make android_test` targets are wired and ready; the
    verification step is manual.
  - An `analysis_options.yaml` exclusion was added (not in the original plan)
    to prevent the root `dart analyze` from scanning the Flutter-dependent
    `integration_test_app/` package.
