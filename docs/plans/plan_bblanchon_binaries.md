# Migrate to bblanchon/pdfium-binaries

**Status**: Investigated

**PR link**: _pending_

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
- [x] **Version identifier**: bblanchon uses Chromium build numbers
  (`chromium/7906`), not PDFium git SHAs. `version_pdfium.json` gains a
  `bblanchon_build` field; `pdfiumSha` in `pdfium_version.dart` is renamed
  `pdfiumVersion` and holds the `chromium/NNNN` string.
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

Currently calls `DynamicLibrary.process()` (static link). With a dynamic
framework embedded by Xcode at `<App>.app/Frameworks/pdfium.framework/pdfium`,
change to:

```dart
// iOS: PDFium is an embedded dynamic framework
final execDir = File(Platform.resolvedExecutable).parent.path;
return ffi.DynamicLibrary.open(
    '$execDir/Frameworks/pdfium.framework/pdfium',
);
```

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

Rename `pdfiumSha` → `pdfiumVersion`; value becomes `'chromium/7906'`.
Update all references in `pdfium_isolate.dart` log messages.

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

- [ ] Update `Makefile` / `.mk` fragments: rename `PDFIUM_VERSION` →
  `BBLANCHON_BUILD`; set value to `7906`
- [ ] Update `make fetch_pdfium` to download `pdfium-linux-x64.tgz` (Linux)
  or `pdfium-mac-arm64.tgz` (macOS) from bblanchon, extract
  `lib/libpdfium.{dylib,so}` and `include/*.h` into the existing
  `third_party/` layout
- [ ] Add tgz-extraction helper to `hook/build.dart`; update `_buildDesktop`
  to download the bblanchon `.tgz`, extract the library, and emit as
  `CodeAsset`
- [ ] Update `version_pdfium.json` schema (add `bblanchon_build`, add
  `lib_path`, rename `pdfium_sha`) for macOS and Linux entries with bblanchon
  URLs and freshly computed SHA256s
- [ ] Rename `pdfiumSha` → `pdfiumVersion` in `pdfium_version.dart`; update
  all references in `pdfium_isolate.dart`
- [ ] Update `make update_pdfium_manifest` to download bblanchon tarballs,
  compute SHA256s, and write `version_pdfium.json`
- [ ] Update `make check_pdfium_version` to compare against `BBLANCHON_BUILD`
- [ ] Regenerate FFI bindings with `make ffi_bindings` using headers from the
  bblanchon tarball; commit any changed `pdfium_bindings.dart`
- [ ] Run `make test` — all desktop tests pass
- [ ] Run `make pre_commit` — zero issues

### Phase 2 — Android

- [ ] Update `version_pdfium.json` Android entries (arm64, x64) with bblanchon
  URLs and SHA256s
- [ ] Update `fetch_mobile_binaries.sh` to download `pdfium-android-arm64.tgz`
  and `pdfium-android-x64.tgz`, extract `lib/libpdfium.so`, and place files
  in `jniLibs/arm64-v8a/` and `jniLibs/x86_64/` respectively
- [ ] Run `make fetch_mobile_binaries` and verify `.so` files land correctly
- [ ] Run `make android_test` — all tests pass
- [ ] Update roadmap `0_01.md` Android status to **Complete**

### Phase 3 — iOS xcframework repack

- [ ] Add `make repack_ios_xcframework` Makefile target:
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
- [ ] Update `packages/betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift`:
  - Remove `PdfiumAnchor` target and `Sources/PdfiumAnchor/` directory
  - Update `binaryTarget` URL and checksum to the new xcframework
  - Product name updated if needed (was `betto-pdfium-ios`)
- [ ] Remove `Sources/PdfiumAnchor/` directory and its source files
- [ ] Update `_openLibrary()` in `pdfium_isolate.dart` iOS branch:
  change from `DynamicLibrary.process()` to path-based
  `DynamicLibrary.open('$execDir/Frameworks/pdfium.framework/pdfium')`
- [ ] Update `hook/build.dart` iOS comment to reflect dynamic library
- [ ] Update `version_pdfium.json`: remove `ios-arm64` entry (xcframework is
  now referenced only from `Package.swift`, not from the hook manifest)
- [ ] Run `flutter pub get` in `integration_test_app/` to trigger SPM
  resolution of the new xcframework
- [ ] Run `make ios_test` — all tests pass
- [ ] Update roadmap `0_01.md` iOS status to **Complete**

### Phase 4 — Cleanup and docs

- [ ] Remove diagnostic `print()` statements added to `pdfium_isolate.dart`
  during debugging (the `_readMetaText` and `_handleLoadDocument` prints)
- [ ] Keep `PdfiumHandlerErrorResponse` (added for diagnosing the iOS failure)
  — it improves error surfacing generally and has no downside
- [ ] Update `CLAUDE.md` binary section: replace SHA-bump workflow with
  bblanchon version-bump workflow
- [ ] Update `docs/spec/01_binary_distribution.md` to document bblanchon as
  the upstream source
- [ ] Update roadmap `0_01.md` overall status for cross-platform pipeline to
  **Complete**
- [ ] Coordinate archiving of `pdfium-build` CI pipeline once all four
  platform tests are green
- [ ] Run the `bettongia:quality-reviewer` agent for a full quality audit
  before submitting the PR

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

## Summary

_To be completed once implementation is done._
