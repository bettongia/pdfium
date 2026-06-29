# PDFium Binary Distribution

Pre-built PDFium binaries are sourced from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries),
a community-maintained set of cross-platform PDFium releases. This document
is the authoritative contract between the upstream binary source and the
`main` branch fetch mechanism.

## Why bblanchon/pdfium-binaries

The original approach built PDFium from source via a bespoke `pdfium-build`
CI pipeline. This was superseded by the following blocking problems:

- **iOS dead-stripping**: the static xcframework dead-stripped all PDFium
  symbols except those reachable from `FPDF_InitLibraryWithConfig`, causing
  every API call beyond `fromBytes`/`pageCount`/`renderPageToBytes` to fail
  with `dlsym(RTLD_DEFAULT, FPDF_GetMetaText): symbol not found`.
- **Binary size**: iOS static `.a` slices were ~258 MB each; bblanchon's iOS
  dylibs are 6.5 MB — eliminating the dead-stripping problem class entirely.
- **Maintenance cost**: the pipeline required patching PDFium GN build files,
  managing Clang toolchain compatibility, and tracking upstream API changes.

bblanchon/pdfium-binaries provides community-tested dynamic libraries for all
target platforms (macOS, Linux, iOS, Android, WASM, Windows). Adopting these
removes the bespoke pipeline and fixes the above problems in one migration.

**Supply-chain trade-off:** adopting bblanchon trades a pipeline we control for
a third-party release cadence. SHA-256 pinning in `version_pdfium.json`
mitigates tampering; availability risk (bblanchon stops publishing) is accepted
given the maintenance win. This is a documented, conscious decision.

## bblanchon release structure

Release tag: `chromium/NNNN` (e.g. `chromium/7906`)
Download URL: `https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2FNNNN/<artifact>`

| Artifact | Contents |
|---|---|
| `pdfium-mac-arm64.tgz` | `lib/libpdfium.dylib`, `include/*.h` |
| `pdfium-linux-x64.tgz` | `lib/libpdfium.so`, `include/*.h` |
| `pdfium-linux-arm64.tgz` | `lib/libpdfium.so`, `include/*.h` |
| `pdfium-ios-device-arm64.tgz` | `lib/libpdfium.dylib` (arm64 device) |
| `pdfium-ios-simulator-arm64.tgz` | `lib/libpdfium.dylib` (arm64 simulator) |
| `pdfium-android-arm64.tgz` | `lib/libpdfium.so` |
| `pdfium-android-x64.tgz` | `lib/libpdfium.so` |
| `pdfium-wasm.tgz` | `lib/libpdfium.{wasm,js}` (future) |
| `pdfium-win-x64.tgz` | `bin/pdfium.dll` |

Each tarball also contains `VERSION` (`MAJOR=151 MINOR=0 BUILD=NNNN PATCH=0`)
and `args.gn`.

bblanchon does **not** publish separate `.sha256` sidecar files. SHA-256
checksums are computed after download and pinned in `version_pdfium.json`.
`make update_pdfium_manifest` automates this computation.

## Installed layout

`make fetch_pdfium` installs the platform binary and public headers into
`third_party/` (both directories gitignored):

```
third_party/pdfium_bin/
  macos_arm64/
    libpdfium.dylib         ← loaded by Dart FFI on macOS arm64
  linux_x64/
    libpdfium.so            ← loaded by Dart FFI on Linux x86_64
  linux_arm64/
    libpdfium.so            ← loaded by Dart FFI on Linux arm64
  windows_x64/
    pdfium.dll              ← loaded by Dart FFI on Windows x64 (no lib prefix)
  VERSION                   ← single line: the installed bblanchon build number
third_party/pdfium/
  public/                   ← PDFium public headers (extracted from the platform tarball)
    fpdfview.h
    fpdf_doc.h
    fpdf_text.h
    …
```

The `VERSION` file contains a single line — the bare build number (e.g. `7906`)
with no trailing newline. `make check_pdfium_version` compares this against
`BBLANCHON_BUILD` and verifies `third_party/pdfium/public/` exists, failing
with a clear error if either is missing or mismatched.

## Fetch mechanism

`scripts/fetch_pdfium.sh` (invoked via `make fetch_pdfium`):

1. Reads `BBLANCHON_BUILD` to determine the required bblanchon build number.
2. Detects the host platform (`uname -s` / `uname -m`).
3. If `third_party/pdfium_bin/VERSION` already matches **and**
   `third_party/pdfium/public/` exists, exits immediately (idempotent).
4. Reads the expected SHA-256 from `version_pdfium.json` for the platform.
5. Downloads the bblanchon tarball with `curl`.
6. Verifies the SHA-256 of the tarball **before extraction**.
7. Extracts `lib/libpdfium.{dylib,so}` from the verified tarball.
8. Installs the binary to `INSTALL_DIR`.
9. On macOS: ad-hoc signs the dylib with `codesign --force --sign -` so
   `dlopen()` succeeds without Gatekeeper quarantine errors.
10. Extracts the `include/` directory from the same tarball into
    `third_party/pdfium/public/`.
11. Writes `third_party/pdfium_bin/VERSION`.

## Checksum verification

bblanchon does not publish sidecar `.sha256` files. Checksums are computed
by `make update_pdfium_manifest` after downloading each tarball, and stored
in `version_pdfium.json`. Verification uses `shasum -a 256` on macOS and
`sha256sum` on Linux.

The SHA-256 is over the **tarball** (`.tgz`), not the extracted library.
Verification happens before extraction to prevent a corrupt download from
being extracted even partially.

## Native-assets hook

`hook/build.dart` is the Dart native-assets build hook for `betto_pdfium`. It
runs automatically when `dart build`, `dart run`, or `dart test` is invoked
(including by downstream packages). It:

1. Reads `version_pdfium.json` from the package root to determine the platform
   download URL, lib path within the tarball, and expected SHA-256.
2. Checks a per-version cache at `.dart_tool/betto_pdfium/{bblanchon_build}/`
   — if the binary is present and the SHA-256 sidecar matches the tarball hash,
   the download is skipped (fast path).
3. Downloads the bblanchon `.tgz` tarball for the target platform.
4. Verifies SHA-256 of the tarball before extraction — the checksum is over
   the whole tarball, not the extracted library.
5. Atomically renames the verified tarball.
6. Extracts the shared library (`lib_path` field) from the tarball.
7. On macOS: strips `com.apple.quarantine` and related xattrs via `xattr -c`
   so `dlopen()` and Flutter's bundler work without Gatekeeper errors.
8. Emits a `CodeAsset` with `DynamicLoadingBundled` link mode so the build
   system bundles the binary alongside the executable.

### Platform manifest — `version_pdfium.json`

`version_pdfium.json` at the package root is the single source of truth for
download URLs, lib paths, and SHA-256 digests. It must be updated whenever
`BBLANCHON_BUILD` is bumped. `scripts/update_pdfium_manifest.sh` (run via
`make update_pdfium_manifest`) downloads each tarball, computes the SHA-256,
and rewrites this file automatically.

The manifest schema:

```json
{
  "bblanchon_build": "NNNN",
  "platforms": {
    "macos-arm64": {
      "url": "https://github.com/bblanchon/pdfium-binaries/.../pdfium-mac-arm64.tgz",
      "lib_path": "lib/libpdfium.dylib",
      "sha256": "<sha256 of .tgz>"
    },
    "linux-x64":    { "url": "...", "lib_path": "lib/libpdfium.so",    "sha256": "..." },
    "linux-arm64":  { "url": "...", "lib_path": "lib/libpdfium.so",    "sha256": "..." },
    "windows-x64":  { "url": "...", "lib_path": "bin/pdfium.dll",      "sha256": "..." },
    "android-arm64":{ "url": "...", "lib_path": "lib/libpdfium.so",    "sha256": "..." },
    "android-x64":  { "url": "...", "lib_path": "lib/libpdfium.so",    "sha256": "..." }
  }
}
```

**Notes:**
- iOS is **excluded** from the manifest — the xcframework is referenced from
  `Package.swift` (downloaded by SPM, not the hook).
- `lib_path` is the path within the tarball to the shared library.
- SHA-256 is over the `.tgz` file, not the extracted library.

**Consumer mapping:**

| Platform key    | Consumer                              | Purpose                           |
| --------------- | ------------------------------------- | --------------------------------- |
| `macos-arm64`   | `hook/build.dart`                     | Native-assets dylib staging       |
| `linux-arm64`   | `hook/build.dart`                     | Native-assets .so staging         |
| `linux-x64`     | `hook/build.dart`                     | Native-assets .so staging         |
| `windows-x64`   | `hook/build.dart`                     | Native-assets DLL staging         |
| `android-arm64` | `fetch_mobile_binaries.sh`            | Android integration test app only |
| `android-x64`   | `fetch_mobile_binaries.sh`            | Android integration test app only |

`lib/src/pdfium_version.dart` exports two constants:

- `pdfiumVersion = 'chromium/NNNN'` — human-readable display identifier
  (used only in log messages; must **not** be used as a path segment).
- `bblanchonBuild = 'NNNN'` — slash-free build number used at runtime by
  `_openLibrary()` to construct the hook cache path as a fallback when the
  build system hasn't staged the binary.

### Unsupported platforms (hook)

| Platform | Status | Notes |
|---|---|---|
| iOS | Hook skipped | Dynamic xcframework via SPM binaryTarget; `DynamicLibrary.process()` at runtime |
| Android | Hook skipped | `.so` in `jniLibs/` via `fetch_mobile_binaries.sh`; `DynamicLibrary.open('libpdfium.so')` at runtime |
| Windows | Supported | `pdfium.dll` staged via `hook/build.dart` like macOS/Linux; no `codesign` step (not applicable on Windows) |

## iOS xcframework

bblanchon provides separate tarballs for the iOS device and simulator slices.
We repack them into a single `pdfium.xcframework` hosted on the
`bettongia/pdfium` GitHub Release tagged `bblanchon-chromium-<BUILD>`.

### Repack process (`make repack_ios_xcframework`)

`scripts/repack_ios_xcframework.sh`:

1. Downloads `pdfium-ios-device-arm64.tgz` and `pdfium-ios-simulator-arm64.tgz`.
2. Extracts `lib/libpdfium.dylib` from each.
3. Renames each dylib to `pdfium` (frameworks use the bare name without `lib`
   prefix or extension).
4. Patches the install name:
   `install_name_tool -id @rpath/pdfium.framework/pdfium pdfium.framework/pdfium`
5. Writes a minimal `Info.plist` for each `pdfium.framework/` bundle:
   `CFBundleExecutable`, `CFBundleIdentifier`, `MinimumOSVersion`,
   `CFBundleSupportedPlatforms`.
6. Runs `xcodebuild -create-xcframework` to combine device + simulator frameworks.
7. Zips the result into `pdfium.xcframework.zip` and prints the SHA-256.
8. Uploads to `bettongia/pdfium` GitHub Releases tagged `bblanchon-chromium-<BUILD>`.

### SPM package (`Package.swift`)

`packages/betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift` declares a
two-target chain:

```swift
targets: [
    .target(
        name: "betto_pdfium_ios",
        dependencies: ["pdfium_binary"],
        path: "Sources/PdfiumIos",
    ),
    .binaryTarget(
        name: "pdfium_binary",
        url: "<bettongia/pdfium release URL>/pdfium.xcframework.zip",
        checksum: "<sha256 of xcframework zip>",
    ),
]
```

Because the xcframework contains **dynamic** frameworks (not static archives),
Xcode automatically embeds them in the app bundle — no force-load flags or
anchor workarounds are required. `DynamicLibrary.process()` locates all PDFium
symbols at runtime because the embedded dynamic framework is loaded into the
process image at launch.

Run `make update_pdfium_manifest` after `make repack_ios_xcframework` to update
`Package.swift` with the new URL and checksum.

## Android shared libraries

`integration_test_app/scripts/fetch_mobile_binaries.sh` downloads the Android
`.tgz` tarballs from bblanchon, verifies SHA-256, extracts `lib/libpdfium.so`,
and places the files in:

```
android/app/src/main/jniLibs/arm64-v8a/libpdfium.so
android/app/src/main/jniLibs/x86_64/libpdfium.so
```

Flutter's Gradle build picks up `jniLibs/` automatically. At runtime,
`DynamicLibrary.open('libpdfium.so')` resolves the library by its bare name
(the OS loads it from the APK's `lib/{abi}/` directory).

## Bumping the bblanchon version

A single-commit workflow (no CI pipeline to wait for):

1. Update `BBLANCHON_BUILD` with the new bblanchon build number.
2. Run `make repack_ios_xcframework` — downloads bblanchon iOS tarballs, builds
   the `pdfium.xcframework`, and uploads it to a new `bettongia/pdfium` release
   tagged `bblanchon-chromium-<NEW_BUILD>`.
3. Run `make update_pdfium_manifest` — downloads each bblanchon tarball,
   computes SHA-256s, rewrites `version_pdfium.json` and
   `lib/src/pdfium_version.dart`, and updates `Package.swift`.
4. Run `make fetch_pdfium` to install the new binary and headers locally.
5. Run `make ffi_bindings` if the bblanchon headers differ from the previous
   release (PDFium's public API is stable but occasionally updated).
6. Commit `BBLANCHON_BUILD`, `version_pdfium.json`, `lib/src/pdfium_version.dart`,
   `Package.swift`, and any regenerated `lib/src/generated/pdfium_bindings.dart`.
