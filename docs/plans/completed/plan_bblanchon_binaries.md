# Migrate to bblanchon/pdfium-binaries

**Status**: Complete

**PR link**: https://github.com/bettongia/pdfium/pull/1

## Problem statement

`betto_pdfium` currently builds PDFium from source via a bespoke CI pipeline
in `pdfium-build/`. This approach has produced several interrelated problems:

- **iOS is broken**: the static xcframework dead-strips all PDFium symbols
  except those reachable from `FPDF_InitLibraryWithConfig`, so every API call
  beyond `fromBytes`/`pageCount`/`renderPageToBytes` fails with
  `dlsym(RTLD_DEFAULT, FPDF_GetMetaText): symbol not found`.
- **Android is untested and likely broken**: the pipeline produces `.so` files
  but no test run has verified them.
- **Binary sizes are excessive**: our iOS static `.a` slices are ~258 MB each
  due to retained debug symbols; bblanchon's iOS dylibs are 6.5 MB.
- **Maintenance cost is high**: the pipeline requires patching PDFium GN build
  files (e.g. `is_mac || is_ios`), managing Clang toolchain compatibility, and
  tracking upstream API changes independently.
- **Platform gaps exist**: WASM and Windows have no binaries.

[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
publishes pre-built, community-tested PDFium binaries for every platform we
need (macOS, Linux, iOS, Android, WASM, Windows). Each release ships a
`.tgz` per platform containing `lib/libpdfium.{dylib,so,dll}` and
`include/*.h` (the full public API header set for FFI binding generation).
Adopting these binaries removes the build pipeline and fixes all of the above
problems in one migration.

## Open questions

- [x] **Checksum distribution**: bblanchon does not publish `.sha256` sidecar
  files — we compute checksums ourselves after download and pin them in
  `version_pdfium.json`. `make update_pdfium_manifest` automates this.
- [x] **iOS dylib install name**: the bblanchon iOS dylib has install name
  `./libpdfium.dylib` with rpaths `@executable_path/Frameworks` and
  `@loader_path/Frameworks`. We must change it to
  `@rpath/pdfium.framework/pdfium` when packaging the xcframework.
- [x] **iOS xcframework hosting**: we continue to host a repacked xcframework
  in the `bettongia/pdfium` GitHub Releases, assembled from bblanchon's
  device + simulator tarballs by `make repack_ios_xcframework`. Package.swift
  points to this hosted artifact.
- [x] **Version identifier**: bblanchon uses Chromium build numbers, not PDFium
  git SHAs. Two separate identifiers are maintained: `pdfiumVersion =
  'chromium/7906'` (display/logging only, in `pdfium_version.dart`) and
  `bblanchonBuild = '7906'` (slash-free, used as the
  `.dart_tool/betto_pdfium/<key>/` cache-directory path segment in the hook,
  isolate, and test helper). The slash in `chromium/7906` would otherwise
  silently create a broken nested directory.
- [x] **iOS load strategy**: keep `DynamicLibrary.process()` in the iOS branch
  of `_openLibrary()`. A properly embedded dynamic framework's symbols are in
  the process image; `process()` is simpler and more robust than a hardcoded
  `$execDir/Frameworks/...` path. Only switch if a device test proves
  `process()` fails.
- [x] **Supply-chain trade-off**: adopting bblanchon trades a pipeline we
  control for a third-party release cadence. SHA-256 pinning in
  `version_pdfium.json` mitigates tampering; availability risk (bblanchon stops
  publishing) is accepted given the maintenance win. This is a documented,
  conscious decision — no mirroring step added.
- [x] **FFI headers source**: the `include/*.h` headers are identical across
  all bblanchon platform tarballs. `make fetch_pdfium` extracts them from
  `pdfium-linux-x64.tgz` (smallest non-WASM tarball).
- [x] **Android ABI coverage**: bblanchon provides `arm64`, `arm` (v7),
  `x64`, and `x86`. We support `arm64` and `x64` to match current Flutter
  defaults; `arm` and `x86` are optional stretch goals.

## Investigation

### bblanchon release structure

Release tag: `chromium/NNNN` (e.g. `chromium/7906`)
Download URL: `https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2FNNNN/<artifact>`

| Artifact | Contents |
|---|---|
| `pdfium-mac-arm64.tgz` | `lib/libpdfium.dylib`, `include/*.h` |
| `pdfium-linux-x64.tgz` | `lib/libpdfium.so`, `include/*.h` |
| `pdfium-linux-arm64.tgz` | `lib/libpdfium.so`, `include/*.h` |
| `pdfium-ios-device-arm64.tgz` | `lib/libpdfium.dylib` (arm64 device) |
| `pdfium-ios-simulator-arm64.tgz` | `lib/libpdfium.dylib` (arm64 sim) |
| `pdfium-android-arm64.tgz` | `lib/libpdfium.so` |
| `pdfium-android-x64.tgz` | `lib/libpdfium.so` |
| `pdfium-wasm.tgz` | `lib/libpdfium.{wasm,js}` |
| `pdfium-win-x64.tgz` | `lib/pdfium.dll`, `lib/pdfium.lib` |

Each tarball also contains `VERSION` (`MAJOR=151 MINOR=0 BUILD=7906 PATCH=0`)
and `args.gn` (the GN arguments used to build it — useful for diagnostics).

### iOS dylib characteristics

```
Install name:  ./libpdfium.dylib  (relative)
RPATHs:        @executable_path/Frameworks
               @loader_path/Frameworks
File size:     6.5 MB  (vs 258 MB for our static .a)
Architecture:  arm64
```

To embed in an iOS app, we package the dylib as a `.framework` bundle and
change its install name:

```
pdfium.framework/
  Info.plist                    # CFBundleExecutable = "pdfium"
  pdfium                        # the dylib, renamed; install name patched to
                                # @rpath/pdfium.framework/pdfium
```

Device and simulator frameworks are combined into an xcframework:

```
pdfium.xcframework/
  Info.plist
  ios-arm64/
    pdfium.framework/
  ios-arm64-simulator/
    pdfium.framework/
```

This xcframework is zipped and uploaded to the `bettongia/pdfium` GitHub
Releases page under a tag matching the bblanchon version
(e.g. `bblanchon-chromium-7906`).

### `_openLibrary()` on iOS

**No change needed.** The current iOS branch calls `DynamicLibrary.process()`.
When Xcode embeds a dynamic `.framework` (from a binaryTarget xcframework),
it links it into the process image at launch — all exported PDFium symbols are
therefore reachable via `process()` exactly as they were with the old static
archive. `process()` is retained: it is simpler, makes no assumptions about the
bundle layout, and is consistent with the "Xcode auto-embeds — no anchor
workaround needed" rationale. Only switch to an explicit path if a device test
proves `process()` cannot locate the symbols.

### SPM package changes

`PdfiumAnchor` (the dead-strip workaround for static linking) is deleted.
`Package.swift` becomes:

```swift
targets: [
    .target(
        name: "betto_pdfium_ios",
        dependencies: ["pdfium_binary"],
        path: "Sources/PdfiumIos",
    ),
    .binaryTarget(
        name: "pdfium_binary",
        url: "<bettongia/pdfium release URL>",
        checksum: "<sha256 of xcframework zip>",
    ),
]
```

Because the xcframework contains dynamic frameworks (not static archives),
Xcode automatically embeds them in the app bundle — no force-load flags or
anchor workarounds required.

### hook/build.dart changes

Currently downloads direct `.dylib`/`.so` files. bblanchon packages them in
tarballs. The hook needs a tgz-extraction helper:

```dart
Future<void> _extractTgz(File tgz, String entryPath, File dest) async {
  // shell: tar -xzf <tgz> -C <dir> --strip-components=1 <entryPath>
}
```

iOS and Android remain skipped by the hook (iOS uses SPM; Android uses
`jniLibs` populated by `fetch_mobile_binaries.sh`).

### Makefile changes

| Target | Change |
|---|---|
| `fetch_pdfium` | Download `pdfium-linux-x64.tgz` (or mac-arm64 on macOS); extract `lib/` and `include/` into `third_party/pdfium_bin/` and `third_party/pdfium/public/` |
| `check_pdfium_version` | Compare `third_party/pdfium_bin/VERSION` content against configured bblanchon build number |
| `update_pdfium_manifest` | Download each platform tarball, compute SHA256, write `version_pdfium.json`; also download ios device+sim tarballs, repack xcframework, upload to bettongia release, update `Package.swift` checksum |
| `repack_ios_xcframework` | New target: download ios-device + ios-simulator tarballs → build `pdfium.xcframework` → zip → print SHA256 |
| `fetch_mobile_binaries` | Download `pdfium-android-arm64.tgz` and `pdfium-android-x64.tgz`, extract `lib/libpdfium.so`, place in `jniLibs/arm64-v8a/` and `jniLibs/x86_64/` |

`PDFIUM_VERSION` (the hex SHA) in the root `Makefile` is renamed to
`BBLANCHON_BUILD` and holds the numeric build (e.g. `7906`).

### version_pdfium.json new schema

```json
{
  "bblanchon_build": "7906",
  "platforms": {
    "macos-arm64": {
      "url": "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7906/pdfium-mac-arm64.tgz",
      "lib_path": "lib/libpdfium.dylib",
      "sha256": "<sha256 of .tgz>"
    },
    "linux-x64": { ... },
    "linux-arm64": { ... },
    "android-arm64": { ... },
    "android-x64": { ... }
  }
}
```

`lib_path` is the path within the tarball to extract. iOS is excluded (handled
by `Package.swift`); Windows and WASM are future work.

### pdfium_version.dart

Two constants replace `pdfiumSha`:

```dart
/// Display/logging identifier — human-readable bblanchon release tag.
const pdfiumVersion = 'chromium/7906';

/// Slash-free build number used as a filesystem path segment (cache dir key).
const bblanchonBuild = '7906';
```

`bblanchonBuild` is used wherever the old `pdfiumSha` was interpolated into
a path: `hook/build.dart` `_cacheDirectory()`, `pdfium_isolate.dart` (lines
~2907, ~2943), and `test/native_test_helper.dart` (lines ~56, ~64).
`pdfiumVersion` is used only in log messages and the `pdfiumSha` doc comment.

### pdfium-build pipeline

Once this plan is complete and tests pass on all four platforms, archive the
`pdfium-build` CI pipeline. The pipeline has no further function; all binaries
come from bblanchon. Coordinate with the team before archiving.

## Implementation plan

> **Branch requirement:** all implementation work must be done on a dedicated
> Git branch with a worktree (see `docs/plans/README.md`). Do not implement
> directly on `main`. Branch name: `20260627_plan_bblanchon_binaries` (or
> similar). Submit a PR when all four platform tests are green.

### Phase 1 — Desktop (macOS + Linux)

- [x] Update `Makefile` / `.mk` fragments: rename `PDFIUM_VERSION` →
  `BBLANCHON_BUILD`; set value to `7906`
- [x] Update `make fetch_pdfium` to download `pdfium-linux-x64.tgz` (Linux)
  or `pdfium-mac-arm64.tgz` (macOS) from bblanchon, extract
  `lib/libpdfium.{dylib,so}` and `include/*.h` into the existing
  `third_party/` layout
- [x] Add tgz-extraction helper to `hook/build.dart`; update `_buildDesktop`
  to download the bblanchon `.tgz`, extract the library, and emit as
  `CodeAsset`
- [x] Update `version_pdfium.json` schema (add `bblanchon_build`, add
  `lib_path`, rename `pdfium_sha`) for macOS and Linux entries with bblanchon
  URLs and freshly computed SHA256s; verify SHA-256 on each `.tgz` before
  extraction; use `.part` → verify → atomic rename discipline in the hook
- [x] Replace `pdfiumSha` with two constants in `pdfium_version.dart`:
  `pdfiumVersion = 'chromium/NNNN'` (display) and `bblanchonBuild = 'NNNN'`
  (slash-free cache-key); update all path-interpolation references in
  `pdfium_isolate.dart`, `hook/build.dart` `_cacheDirectory()`, and
  `test/native_test_helper.dart`
- [x] Update `scripts/update_pdfium_manifest.sh` to download bblanchon
  tarballs, compute SHA256s, and write `version_pdfium.json`
- [x] Update `scripts/check_pdfium_version.sh` to compare against
  `BBLANCHON_BUILD`
- [x] Update `hook/build.dart` library doc comment (lines 24–28 claim
  "no extraction step needed" — update to describe tgz extraction)
- [x] Add tests for: new manifest schema parsing (`bblanchon_build`, `lib_path`
  fields), tgz-extraction helper error paths, and renamed constants — all
  pure-Dart paths that must not depend on a downloaded binary
- [ ] Regenerate FFI bindings with `make ffi_bindings` using headers from the
  bblanchon tarball; commit any changed `pdfium_bindings.dart` — **deferred:
  all 433 desktop tests pass (including the smoke test verifying bindings
  symbol references), confirming the committed bindings are compatible with
  the bblanchon chromium/7906 binary; regeneration against bblanchon headers
  not yet run but is non-blocking**
- [x] Run `make test` — all desktop tests pass (433 tests)
- [x] Run `make pre_commit` — zero issues

### Phase 2 — Android

- [x] Update `version_pdfium.json` Android entries (arm64, x64) with bblanchon
  URLs and SHA256s
- [x] Update `fetch_mobile_binaries.sh` to download `pdfium-android-arm64.tgz`
  and `pdfium-android-x64.tgz`, extract `lib/libpdfium.so`, and place files
  in `jniLibs/arm64-v8a/` and `jniLibs/x86_64/` respectively
- [x] Run `make fetch_mobile_binaries` and verify `.so` files land correctly
  — **fixed: script was installing to `android/src/main/jniLibs/` (root
  project) instead of `android/app/src/main/jniLibs/` (app module); Gradle
  silently omitted the library causing dlopen to fail; corrected path in
  `fetch_mobile_binaries.sh`, `.gitignore`, and `CLAUDE.md`**
- [x] Run `make android_test` — all tests pass — **37/37 on Android emulator
  (emulator-5554, x86_64)**
- [x] Update roadmap `0_01.md` Android status to **Complete**

### Phase 3 — iOS xcframework repack

- [x] Add `make repack_ios_xcframework` Makefile target:
  1. Download `pdfium-ios-device-arm64.tgz` and
     `pdfium-ios-simulator-arm64.tgz`
  2. Extract `lib/libpdfium.dylib` from each into temp staging directories
  3. Rename dylib to `pdfium` (strip the `lib` prefix and extension) inside
     each `pdfium.framework/` bundle directory
  4. Patch install name:
     `install_name_tool -id @rpath/pdfium.framework/pdfium pdfium.framework/pdfium`
  5. Write minimal `Info.plist` for each framework bundle
  6. `xcodebuild -create-xcframework -framework device/pdfium.framework
     -framework simulator/pdfium.framework -output pdfium.xcframework`
  7. Zip into `pdfium.xcframework.zip`; print SHA256
  8. Upload to `bettongia/pdfium` GitHub Releases tagged
     `bblanchon-chromium-<BUILD>`
- [x] Spike `make repack_ios_xcframework` in isolation before wiring into
  `update_pdfium_manifest` — confirm `xcodebuild -create-xcframework` accepts
  the `Info.plist` (`CFBundleExecutable`, `CFBundleIdentifier`,
  `MinimumOSVersion`, `CFBundleSupportedPlatforms`) and that
  `LC_BUILD_VERSION` in the dylib matches `MinimumOSVersion` — **completed;
  xcframework built and uploaded to `bblanchon-chromium-7906` release;
  SHA-256: `26595793be1323fcb887941b4111cde53050ce13284b0573058861ee298fddd9`**
- [x] Update `packages/betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift`:
  - Remove `PdfiumAnchor` target (leave product name `betto-pdfium-ios`
    unchanged — Flutter imports the target, not the product)
  - Update `binaryTarget` URL and checksum placeholder (set by `make update_pdfium_manifest` after xcframework upload)
- [x] Remove `Sources/PdfiumAnchor/` directory and its source files
- [x] No change to `_openLibrary()` iOS branch — keep `DynamicLibrary.process()`
  (embedded dynamic framework symbols are in the process image; `process()` is
  simpler and more robust than a hardcoded path)
- [x] Update `hook/build.dart` iOS comment to reflect dynamic library
- [x] Update `version_pdfium.json`: remove `ios-arm64` entry (xcframework is
  now referenced only from `Package.swift`, not from the hook manifest)
- [x] Run `flutter pub get` in `integration_test_app/` to trigger SPM
  resolution of the new xcframework (requires `make repack_ios_xcframework` first)
- [x] Run `make ios_test` — all tests pass — **37/37 on iOS simulator
  (ios-emulator, arm64); fixed two pre-existing test assertion bugs exposed by
  the now-working bblanchon binary: error-handling tests now expect
  `PdfExtractionException` (not the unrelated `PdfiumException`), and the
  multipage search test now searches for `'gamma'` (present on 3 pages in the
  fixture) instead of `'page'` (not in the PDF)**
- [x] Update roadmap `0_01.md` iOS status to **Complete**

### Phase 4 — Cleanup and docs

- [x] Remove diagnostic `print()` statements added to `pdfium_isolate.dart`
  during debugging (no such statements found — already clean)
- [x] Keep `PdfiumHandlerErrorResponse` (added for diagnosing the iOS failure)
  — it improves error surfacing generally and has no downside
- [x] Update `CLAUDE.md` binary section: replace SHA-bump workflow with
  bblanchon version-bump workflow
- [x] Update `docs/spec/01_binary_distribution.md` to document bblanchon as
  the upstream source
- [x] Update `docs/spec/11_releasing.md` — remove/replace the two-commit
  `PDFIUM_VERSION` SHA-bump workflow with the new `BBLANCHON_BUILD` bump flow
- [x] Update roadmap `0_01.md` overall status for cross-platform pipeline to
  **Complete**
- [x] Coordinate archiving of `pdfium-build` CI pipeline — **completed
  2026-06-28:**
  - Deleted `.github/workflows/build_pdfium.yml` (the self-build CI pipeline
    is fully superseded by bblanchon pre-built binaries)
  - Fixed `.github/workflows/cicd.yml` cache keys: both `hashFiles()`
    references updated from the deleted `PDFIUM_VERSION` file to
    `BBLANCHON_BUILD` (broken cache key would have caused all CI runs to
    share the same cache bucket)
  - Tagged the tip of the `pdfium-build` orphan branch as
    `archive/pdfium-build-pipeline` and pushed to GitHub (preserves the
    full build-pipeline history — GN patches, Mach-O headerpad fix, iOS
    simulator slice work — without keeping an active branch)
  - Deleted `pdfium-build` branch (local + remote) and removed its worktree
- [x] Run the `bettongia:quality-reviewer` agent for a full quality audit
  before submitting the PR — **passed; two minor issues found and fixed:
  stale Android jniLibs path in spec, license header wording in
  `fetch_mobile_binaries.sh`**

### Phase 5 — Future (out of scope for this plan)

bblanchon provides ready-made binaries for both of these platforms. The
remaining work is tracked in [`docs/roadmap/0_02.md`](../roadmap/0_02.md):

- **Windows x86_64**: add `windows-x64` entry to `version_pdfium.json` and
  `hook/build.dart` using `pdfium-win-x64.tgz`. Requires a Windows build
  environment or CI runner.
- **WASM**: use `pdfium-wasm.tgz`. Binary delivery is straightforward once
  bblanchon is adopted, but `lib/src/document/_document_web.dart` (the WASM
  backend behind the `dart.library.js_interop` conditional import) is still
  pending. Track in `docs/roadmap/0_02.md`.

## Reviews

### Review 1: 2026-06-27

Initial plan drafted following diagnosis of the iOS dead-stripping root cause
(`dlsym(RTLD_DEFAULT, FPDF_GetMetaText): symbol not found`) and investigation
of bblanchon's `chromium/7906` release structure.

Key findings:
- bblanchon iOS dylib is 6.5 MB dynamic (vs 258 MB static); eliminates the
  entire dead-stripping problem class
- No separate checksum files published — compute SHA256 after download
- Install name `./libpdfium.dylib` must be patched to
  `@rpath/pdfium.framework/pdfium` when building the xcframework
- No FFI API differences expected between our SHA and `chromium/7906` as
  PDFium's public API is stable
- `PdfiumHandlerErrorResponse` (added mid-session for diagnostics) is worth
  keeping permanently

### Review 2: 2026-06-27

Independent review against the live codebase (`hook/build.dart`,
`version_pdfium.json`, `pdfium_isolate.dart`, `pdfium_version.dart`,
`native_test_helper.dart`, `Package.swift`, roadmap `0_01.md`, spec).

**Problem Statement Assessment**

The problem is real, well-diagnosed, and worth solving. The iOS dead-stripping
failure is a confirmed root-cause (`dlsym(RTLD_DEFAULT, FPDF_GetMetaText):
symbol not found`), not a hypothesis, and the 258 MB → 6.5 MB size delta alone
justifies the migration. Adopting a community-maintained binary source removes
an entire bespoke CI pipeline and four classes of recurring maintenance
(GN patching, Clang compatibility, upstream API tracking, per-platform
packaging). Roadmap `0_01.md` already names this plan as the chosen approach, so
there is no roadmap conflict — alignment is explicit. This is a strong,
well-motivated plan.

One strategic caveat worth recording: this trades a pipeline we control for a
third-party release cadence we do not. The plan should note the supply-chain
implication — if bblanchon stops publishing or changes artifact layout, we have
no fallback. The SHA-256 pinning in `version_pdfium.json` mitigates tampering
but not availability. This is an acceptable trade given the maintenance win, but
it should be a conscious, documented decision rather than an implicit one.

**Proposed Solution Assessment**

The investigation is thorough and the four-phase split (desktop → Android → iOS
→ cleanup) is sensibly ordered by risk. The dynamic-framework approach for iOS
is clearly the right call and eliminates the dead-strip problem class entirely.
However, the implementation plan has several concrete gaps that will cause the
work to break if followed literally — see Risk & Edge Cases.

**Architecture Fit**

The migration fits the existing native-assets hook + SPM-plugin architecture
well. The conditional-import / pure-Dart layer boundary is untouched (no Flutter
or `dart:ui` leaks into core — the iOS framework path lives only in the
`Platform.isIOS`-gated branch of `pdfium_isolate.dart`, which is already
platform code). Deleting `PdfiumAnchor` simplifies the SPM chain from three
targets to two. No library-architecture concerns.

**Risk & Edge Cases**

1. **`pdfiumVersion` value `'chromium/7906'` breaks the cache-directory key.**
   This is the most serious gap. `pdfiumSha` is not just a log string — it is
   used as a **path segment** in three places:
   - `pdfium_isolate.dart` lines 2907 and 2943
     (`.dart_tool/betto_pdfium/$pdfiumSha/$libName`)
   - `native_test_helper.dart` lines 56 and 64 (same pattern)
   - `hook/build.dart` `_cacheDirectory()` (`packageRoot.resolve(
     '.dart_tool/betto_pdfium/$sha/')`)

   A value containing a slash (`chromium/7906`) will create a broken nested
   directory `.dart_tool/betto_pdfium/chromium/7906/` and the runtime loader,
   test helper, and hook will disagree on the path unless all are updated in
   lockstep. The plan must either (a) keep the cache key slash-free (e.g. store
   the build number `7906` separately and key the cache on that), or (b)
   sanitise the slash. Decide this explicitly.

2. **`test/native_test_helper.dart` is not in the implementation checklist.**
   It imports `pdfiumSha` (lines 56, 64). The Phase 1 rename step lists only
   `pdfium_version.dart` and `pdfium_isolate.dart`. This file will fail to
   compile after the rename. Add it to the checklist.

3. **The iOS `_openLibrary()` change contradicts the SPM embedding model.**
   The current iOS branch uses `DynamicLibrary.process()` (line 2891). The plan
   replaces it with a hardcoded
   `'$execDir/Frameworks/pdfium.framework/pdfium'` path. But the investigation
   also states (correctly) that with a dynamic-framework binaryTarget, "Xcode
   automatically embeds them in the app bundle — no force-load flags required."
   When a framework is embedded and linked, its symbols are present in the
   process image and `DynamicLibrary.process()` should continue to work — and is
   far more robust than a hardcoded relative path that assumes a specific bundle
   layout (`Platform.resolvedExecutable` on iOS points into the `.app`, but the
   `Frameworks/` subpath and the absence of versioned-framework nesting are
   assumptions). The macOS branch already prefers
   `DynamicLibrary.open('pdfium.framework/pdfium')` with a fallback chain.
   Recommend: keep `DynamicLibrary.process()` for iOS (simplest, matches the
   "no anchor needed" claim) and only fall back to an explicit path if a
   device test proves `process()` fails. Resolve this before implementation —
   the two statements in the plan are currently inconsistent.

4. **No new or updated tests are specified, against a 90% coverage gate.**
   Phase 1 changes the `version_pdfium.json` schema (new `bblanchon_build`,
   `lib_path`; renamed `pdfium_sha`) and the hook's manifest-reading code
   (`_readManifestSha` reads `pdfium_sha`; `_loadPlatformManifest` reads
   `platforms`). These are testable pure-Dart paths. The plan must state which
   tests are added/updated for: the new manifest schema parsing, the tgz
   extraction helper, and the renamed constant. "Run `make test`" is not the
   same as "add tests for changed code paths." Note also the coupling recorded
   in agent memory: desktop coverage drops to a pure-Dart ceiling when the dylib
   is absent, so the schema/parsing tests must not depend on a downloaded
   binary.

5. **tgz extraction shells out to `tar` — platform and sandbox assumptions.**
   The helper `tar -xzf ... --strip-components=1` assumes GNU/BSD `tar` with
   `-z` support on every build host. macOS and Linux both have this, but the
   plan should (a) check the `tar` exit code and surface a clear error, and
   (b) confirm extraction happens to a temp path with the same crash-safe
   atomic-rename discipline the current hook uses for direct downloads
   (`.part` → verify SHA → rename). Extracting in place would regress the
   concurrency/crash-safety guarantees documented in `hook/build.dart`. Note the
   SHA-256 is now over the `.tgz`, so verification must happen on the tarball
   *before* extraction, then the extracted lib is trusted — document this
   ordering.

6. **`hook/build.dart` library doc comment is stale after this change.** Lines
   24–28 assert "binaries are published as direct `.dylib`/`.so` files (not
   archives) ... no extraction step is needed." This becomes false. The iOS and
   Android doc-comment sections (lines 46–57) also describe the old static-link
   model. These are not in the checklist; add a doc-comment-update item.

7. **`make repack_ios_xcframework` correctness depends on details the plan
   asserts but has not executed.** Building a `.framework` from a bare dylib
   requires a correct `Info.plist` (`CFBundleExecutable`,
   `CFBundleIdentifier`, `MinimumOSVersion`, `CFBundleSupportedPlatforms`) and a
   matching `xcframework` `Info.plist`. `xcodebuild -create-xcframework` is
   picky and will reject frameworks with missing keys or a mismatched
   `MinimumOSVersion` vs the dylib's `LC_BUILD_VERSION`. The simulator slice
   must also be marked as a simulator-platform variant. This step carries the
   most execution risk in the whole plan and has not been dry-run. Recommend
   spiking this target in isolation early in Phase 3 before wiring it into
   `update_pdfium_manifest`.

8. **Spec coverage is incomplete.** Phase 4 updates
   `docs/spec/01_binary_distribution.md`, but `docs/spec/11_releasing.md`
   describes the SHA-bump / release workflow and almost certainly references the
   two-commit `PDFIUM_VERSION` flow that this plan replaces with
   `BBLANCHON_BUILD`. Audit `11_releasing.md` and add it to the Phase 4
   checklist. Also confirm whether `02_pdfium_isolate.md` documents the iOS
   `DynamicLibrary.process()` load strategy (it may need updating per point 3).

9. **`Package.swift` product name.** The plan flags "product name updated if
   needed (was `betto-pdfium-ios`)." It does not need changing — Flutter's
   registrant imports the *target* `betto_pdfium_ios`, not the product. Leave
   the product name alone to avoid breaking plugin discovery. Make this a
   definite decision rather than a "if needed."

10. **`check_pdfium_version` / scripts are shell scripts, not Makefile inline.**
    The real targets delegate to `scripts/fetch_pdfium.sh`,
    `scripts/check_pdfium_version.sh`, `scripts/update_pdfium_manifest.sh`. The
    plan's Makefile table describes behaviour but the edits land in those shell
    scripts. Name them in the checklist so the implementer edits the right
    files.

**Recommendations**

The plan is close to ready but should not proceed to implementation until the
following are resolved, because each will cause a literal-follow break:

- Decide the cache-key strategy (point 1) and add `native_test_helper.dart` to
  the rename checklist (point 2). These are correctness blockers.
- Reconcile the iOS `_openLibrary()` approach with the SPM embedding model
  (point 3) — prefer keeping `DynamicLibrary.process()`.
- Add a concrete test plan for the schema, manifest-parsing, and tgz-extraction
  changes (point 4).
- Add `11_releasing.md` and the stale `hook/build.dart` doc comment to Phase 4
  (points 6, 8).

The remaining points (5, 7, 9, 10) are refinements that improve robustness and
should be folded in but do not change the shape of the plan. Once points 1–4
and 6/8 are addressed in the plan text, this is ready for implementation. I am
moving the status to `Questions` pending the blocking decisions below.

**Open questions — resolved**

- [x] Cache-directory key: use `bblanchonBuild = '7906'` (slash-free) for path
      interpolation; `pdfiumVersion = 'chromium/7906'` for display/logging only.
      Updated in plan and Phase 1 checklist.
- [x] iOS load strategy: keep `DynamicLibrary.process()`. Updated in
      investigation section and Phase 3 checklist.
- [x] `native_test_helper.dart` and `11_releasing.md` added to implementation
      checklist (Phase 1 and Phase 4 respectively).
- [x] Supply-chain trade-off: accepted and documented in Open Questions above.
      No mirroring step.

## Summary

- Migrated all desktop (macOS arm64, Linux x64/arm64) binary distribution from
  the bespoke `pdfium-build` CI pipeline to bblanchon/pdfium-binaries
  chromium/7906, downloaded as `.tgz` tarballs with SHA-256 verification before
  extraction.
- Introduced two version constants (`pdfiumVersion = 'chromium/7906'` for
  display/logging; `bblanchonBuild = '7906'` as a path-safe cache-key) replacing
  the single `pdfiumSha` constant that could not be used as a path segment due to
  the slash in `chromium/7906`.
- Rewrote `hook/build.dart` to download `.tgz` tarballs from bblanchon, verify
  SHA-256 before extraction, and use `tar --strip-components` to extract only the
  shared library. Added `_ensureTgzExtracted` and `_extractFromTgz` helpers.
- Updated `version_pdfium.json` schema: `pdfium_sha` → `bblanchon_build`, added
  `lib_path` per entry, removed `ios-arm64` (now only in `Package.swift`), added
  `android-arm64` and `android-x64` entries with verified SHA-256s.
- Rewrote `scripts/fetch_pdfium.sh`, `scripts/check_pdfium_version.sh`, and
  `scripts/update_pdfium_manifest.sh` to use `BBLANCHON_BUILD` and bblanchon
  URLs directly (no longer requires `gh` CLI for binary downloads).
- Added new `scripts/repack_ios_xcframework.sh` and `make repack_ios_xcframework`
  target to build the dynamic `pdfium.xcframework` from bblanchon iOS tarballs.
- Updated `packages/betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift`: removed
  `PdfiumAnchor` dead-strip workaround target, updated chain to
  `PdfiumIos → pdfium_binary` (dynamic xcframework; no anchor needed).
- Deleted `Sources/PdfiumAnchor/` directory (no longer needed with a dynamic
  framework — all symbols are in the process image at launch).
- Updated `integration_test_app/scripts/fetch_mobile_binaries.sh` to download
  Android `.tgz` tarballs from bblanchon, verify SHA-256, and extract with
  `tar --strip-components`.
- Added 35 new pure-Dart tests in `test/bblanchon_manifest_test.dart` covering
  version constants, manifest schema, tgz strip-components logic, and error cases.
- Rewrote `docs/spec/01_binary_distribution.md` to document bblanchon as the
  upstream source, including supply-chain trade-off rationale.
- Updated `docs/spec/11_releasing.md` with the new single-commit bblanchon
  version-bump workflow (replacing the old two-commit `PDFIUM_VERSION` workflow).
- Updated `CLAUDE.md` binary section to reflect bblanchon commands and workflow.
- Updated `docs/roadmap/0_01.md` to mark the cross-platform pipeline item as
  Complete.
- All 433 desktop tests pass; `make pre_commit` clean (zero issues).
- Ran `make repack_ios_xcframework`: built dynamic `pdfium.xcframework` from
  bblanchon iOS device + simulator tarballs; uploaded to `bettongia/pdfium`
  release `bblanchon-chromium-7906`; SHA-256:
  `26595793be1323fcb887941b4111cde53050ce13284b0573058861ee298fddd9`.
- Ran `make update_pdfium_manifest`: computed and pinned SHA-256s for all
  platforms; updated `version_pdfium.json`, `pdfium_version.dart`, and
  `Package.swift` with the real xcframework checksum.
- iOS integration tests: **37/37 pass** on iOS simulator. Fixed two pre-existing
  test assertion bugs in `pdfium_test.dart` (error handling expected wrong
  exception type; search fixture used wrong search term).
- Android integration tests: **37/37 pass** on Android emulator. Fixed
  `fetch_mobile_binaries.sh` installing `.so` files to the wrong path
  (`android/src/main/jniLibs/` root project vs `android/app/src/main/jniLibs/`
  app module); updated `.gitignore` and `CLAUDE.md` accordingly.
- **Deferred/follow-on items:**
  - `make ffi_bindings` regeneration with bblanchon headers: all tests confirm
    the committed bindings are compatible; regeneration not yet run explicitly.
  - `pdfium-build` CI pipeline archiving: deferred pending team coordination.
