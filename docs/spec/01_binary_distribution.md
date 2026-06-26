# PDFium Binary Distribution

Pre-built PDFium binaries are produced by a CI pipeline on the `pdfium-build`
orphan branch and published as GitHub Releases. This document is the
authoritative contract between the build pipeline and the `main` branch fetch
mechanism.

## Artifact layout

Each GitHub Release tagged `pdfium-<sha>` contains the following files:

| File                                      | Description                       |
| ----------------------------------------- | --------------------------------- |
| `libpdfium-macos-arm64.dylib`             | macOS arm64 shared library        |
| `libpdfium-ios-arm64.xcframework.zip`     | iOS arm64 static xcframework      |
| `libpdfium-linux-x86_64.so`              | Linux x86_64 shared library       |
| `libpdfium-linux-arm64.so`               | Linux arm64 shared library        |
| `libpdfium-android-arm64.so`             | Android arm64 shared library      |
| `libpdfium-android-x86_64.so`            | Android x86_64 shared library     |
| `pdfium-headers.zip`                      | PDFium `public/` headers (same SHA) |
| `VERSION.txt`                             | Commit SHA + build date           |
| `checksums.sha256`                        | SHA256 of all above               |

> **WASM**: placeholder CI job exists; not yet shipping. Will be added as
> `libpdfium-web.wasm` + `libpdfium-web.js` once Emscripten setup is complete.

All binaries are self-contained — they link all PDFium dependencies statically
and have no runtime dependencies on sibling shared libraries.

## Tag format

```
pdfium-<full-git-sha>
```

The SHA is the full 40-character PDFium upstream commit hash stored in
`PDFIUM_VERSION` on the `main` branch.

## VERSION.txt format

```
pdfium_commit=<40-char git SHA>
build_date=<YYYY-MM-DDTHH:MM:SSZ>
```

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
  VERSION                   ← single line: the installed PDFium commit SHA
third_party/pdfium/
  public/                   ← PDFium public headers (extracted from pdfium-headers.zip)
    fpdfview.h
    fpdf_doc.h
    fpdf_text.h
    …
```

The `VERSION` file contains a single line — the bare 40-character SHA with no
trailing newline. `make check_pdfium_version` compares this against
`PDFIUM_VERSION` and also verifies `third_party/pdfium/public/` exists, failing
with a clear error if either is missing or mismatched.

## Fetch mechanism

`scripts/fetch_pdfium.sh` (invoked via `make fetch_pdfium`):

1. Reads `PDFIUM_VERSION` to determine the required SHA.
2. Detects the host platform (`uname -s` / `uname -m`).
3. If `third_party/pdfium_bin/VERSION` already matches **and**
   `third_party/pdfium/public/` exists, exits immediately (idempotent).
4. Requires `gh` (GitHub CLI) to be installed and authenticated.
5. Verifies the GitHub Release `pdfium-<sha>` exists before downloading.
6. Downloads the platform binary, `pdfium-headers.zip`, and `checksums.sha256`
   to a temp directory in one `gh release download` call.
7. Verifies the SHA256 checksum of both the binary and `pdfium-headers.zip`.
8. Installs the binary: copies to `INSTALL_DIR`.
9. On macOS: ad-hoc signs the dylib with `codesign --force --sign -` so
   `dlopen()` succeeds without Gatekeeper quarantine errors.
10. Extracts `pdfium-headers.zip` to `third_party/pdfium/` (produces
    `third_party/pdfium/public/*.h`).
11. Writes `third_party/pdfium_bin/VERSION`.

## Checksum verification

`checksums.sha256` is generated in the CI publish job using `sha256sum` and
covers every file in the release (including `VERSION.txt` and itself is
excluded). Verification on macOS uses `shasum -a 256`; on Linux `sha256sum`.
Both produce compatible output formats.

## Native-assets hook

`hook/build.dart` is the Dart native-assets build hook for `betto_pdfium`. It
runs automatically when `dart build`, `dart run`, or `dart test` is invoked
(including by downstream packages). It:

1. Reads `version_pdfium.json` from the package root to determine the platform
   download URL and expected SHA-256.
2. Checks a per-version cache at `.dart_tool/betto_pdfium/{sha}/` — if the
   binary is already present and the SHA-256 sidecar matches, the download is
   skipped (fast path).
3. Downloads the binary directly (no archive extraction — PDFium releases plain
   `.dylib`/`.so` files).
4. Verifies SHA-256 before an atomic rename to the final path.
5. On macOS: strips `com.apple.quarantine` and related xattrs via `xattr -c`
   so `dlopen()` and Flutter's bundler work without Gatekeeper errors.
6. Emits a `CodeAsset` with `DynamicLoadingBundled` link mode so the build
   system bundles the binary alongside the executable.

### Platform manifest — `version_pdfium.json`

`version_pdfium.json` at the package root is the single source of truth for
download URLs and SHA-256 digests. It must be updated whenever `PDFIUM_VERSION`
is bumped. `scripts/update_pdfium_manifest.sh` (run via `make
update_pdfium_manifest`) rewrites this file automatically by reading
`checksums.sha256` from the GitHub Release.

The manifest contains **six platform entries** — three consumed by the
native-assets hook (`hook/build.dart`) and three consumed exclusively by the
mobile integration test app (`integration_test_app/scripts/fetch_mobile_binaries.sh`):

```json
{
  "pdfium_sha": "<40-char SHA>",
  "platforms": {
    "macos-arm64":  { "url": "...", "sha256": "..." },
    "linux-arm64":  { "url": "...", "sha256": "..." },
    "linux-x64":    { "url": "...", "sha256": "..." },
    "ios-arm64":    { "url": "..libpdfium-ios-arm64.xcframework.zip", "sha256": "..." },
    "android-arm64":{ "url": "..libpdfium-android-arm64.so", "sha256": "..." },
    "android-x64":  { "url": "..libpdfium-android-x86_64.so", "sha256": "..." }
  }
}
```

**Consumer mapping:**

| Platform key    | Consumer                              | Purpose                           |
| --------------- | ------------------------------------- | --------------------------------- |
| `macos-arm64`   | `hook/build.dart`                     | Native-assets dylib staging       |
| `linux-arm64`   | `hook/build.dart`                     | Native-assets .so staging         |
| `linux-x64`     | `hook/build.dart`                     | Native-assets .so staging         |
| `ios-arm64`     | `fetch_mobile_binaries.sh`            | iOS integration test app only     |
| `android-arm64` | `fetch_mobile_binaries.sh`            | Android integration test app only |
| `android-x64`   | `fetch_mobile_binaries.sh`            | Android integration test app only |

The `hook/build.dart` native-assets hook reads only the three hook-supported
platform entries and ignores `ios-arm64`, `android-arm64`, and `android-x64`.
This is intentional: the iOS static xcframework cannot be staged by the
native-assets hook (Flutter iOS enforces dynamic link mode), and Android
native-assets support is pending.

`lib/src/pdfium_version.dart` exports a `pdfiumSha` constant that must equal
`version_pdfium.json`'s `pdfium_sha`. It is used at runtime by `_openLibrary()`
to construct the hook cache path as a fallback when the build system hasn't
staged the binary to a well-known location.

### Unsupported platforms (hook)

| Platform | Status | Reason |
|---|---|---|
| iOS | Hook skipped | PDFium XCFramework is static; Flutter iOS native-assets enforces dynamic link mode |
| Android | Hook skipped | Native-assets Android support pending |
| Windows | Hook skipped | No Windows binary in the build pipeline yet |

On these platforms `_openLibrary()` in the runtime uses platform-appropriate
fallbacks (`DynamicLibrary.process()` for iOS, bare `libpdfium.so` for Android).

The iOS and Android binaries are available in `version_pdfium.json` and are
used by the mobile integration test app (`integration_test_app/`) which bundles
them manually — see [Mobile integration test app](#mobile-integration-test-app).

### Mobile integration test app

`integration_test_app/` is a standalone Flutter app that verifies PDFium works
correctly on iOS and Android by running the same test suite as the desktop
`dart test` suite. It uses a manual binary-bundling approach:

**iOS:**
- `fetch_mobile_binaries.sh` downloads and verifies the xcframework (from the
  `ios-arm64` manifest entry), unzipping it to `ios/Frameworks/pdfium.xcframework`.
- A local Swift Package Manager package at `ios/LocalPackages/pdfium/` vends
  the xcframework via a `binaryTarget`.

**iOS dead-strip prevention:**
Because PDFium is a C library resolved entirely at runtime via
`DynamicLibrary.process()`, the linker has no compile-time references to any
`FPDF_*` symbol and would normally dead-strip the entire static archive. A bare
`binaryTarget` is not sufficient to prevent this.

The local SPM package uses **two targets** to prevent dead-stripping:

1. `pdfium_binary` — the `binaryTarget` pointing to the xcframework.
2. `pdfium` — a source target that depends on `pdfium_binary` and contains
   `Sources/PdfiumAnchor/pdfium_anchor.c`. This C file holds:
   ```c
   extern void FPDF_InitLibraryWithConfig(const void* config);
   __attribute__((used)) static void* __pdfium_anchor =
       (void*)&FPDF_InitLibraryWithConfig;
   ```
   `__attribute__((used))` prevents the compiler from optimising away the
   pointer. The linker then sees a compile-time reference to
   `FPDF_InitLibraryWithConfig`, pulls the translation unit from the archive,
   and the transitive closure of PDFium survives dead-stripping.
   `DynamicLibrary.process()` can then resolve all `FPDF_*` symbols at runtime.

**Android:**
- `fetch_mobile_binaries.sh` downloads and verifies the `.so` files (from the
  `android-arm64` and `android-x64` manifest entries) into
  `android/src/main/jniLibs/{abi}/libpdfium.so`.
- Flutter's Gradle build picks up `jniLibs/` automatically — no `build.gradle`
  changes needed.
- At runtime, `DynamicLibrary.open('libpdfium.so')` resolves the library by
  its bare name (the OS loads it from the APK's `lib/{abi}/` directory).

## Bumping the PDFium version

This is a two-commit workflow because the SHA-256 digests in
`version_pdfium.json` are only known after the CI pipeline has built and
uploaded the binaries.

**Commit 1 — trigger the build:**

1. Update `PDFIUM_VERSION` with the new upstream commit SHA.
2. Commit and push to `main` — CI detects the `PDFIUM_VERSION` change,
   rebuilds all platform binaries from source, packages the `public/` headers
   from the same commit into `pdfium-headers.zip`, smoke-tests all native
   platforms, and publishes a new GitHub Release tagged `pdfium-<sha>`.

**Wait for the CI pipeline to finish and publish the release.**

**Commit 2 — update the hook manifest:**

3. Run `make update_pdfium_manifest` — downloads `checksums.sha256` from the
   just-published release and rewrites `version_pdfium.json` and
   `lib/src/pdfium_version.dart` in one step.
4. Run `make fetch_pdfium` to install the new binary and headers locally.
5. If the public API changed: run `make ffi_bindings` to regenerate
   `lib/src/generated/pdfium_bindings.dart`.
6. Commit `version_pdfium.json`, `lib/src/pdfium_version.dart`, and any
   updated bindings.

The headers are taken from the same pdfium source checkout used to build the
binaries, so binary ABI and header declarations are always in sync.

## Smoke test

The CI pipeline runs `scripts/smoke_test.c` (from the `pdfium-build` branch)
against each native shared library before uploading the artifact. The test:

- `dlopen`s the library
- Resolves `FPDF_InitLibraryWithConfig` and `FPDF_DestroyLibrary` via `dlsym`
- Calls both functions with a zeroed version-2 config
- Exits non-zero on any failure, blocking the publish job

Platforms not covered by the smoke test:
- **iOS** — static xcframework cannot be loaded with `dlopen`; a clean build is
  the acceptance signal.
- **Android** — requires an Android runtime (device or emulator), not available
  on the Linux runner. The ELF binary is verified to have the correct
  architecture via `file(1)` instead.
- **WASM** — placeholder build pending Emscripten setup.

### Why Linux arm64 is cross-compiled

The Linux arm64 binary is **built on `ubuntu-26.04` (x86\_64)** rather than on
a native arm64 runner. The reason is a missing CIPD package: PDFium's `DEPS`
file unconditionally fetches `infra/rbe/client/${platform}` (the Google
Remote Build Execution client), and `infra/rbe/client/linux-arm64` does not
exist in CIPD. On the x86\_64 runner, `infra/rbe/client/linux-amd64` exists and
`gclient sync` succeeds.

The standard suppression mechanisms were tried and found ineffective with the
version of gclient shipped on the arm64 runner:

- `custom_deps: {"buildtools/reclient": None}` in `.gclient` — ignored for
  CIPD deps.
- Adding `'condition': 'False'` to the `buildtools/reclient` dep entry in
  `pdfium/DEPS` — ignored for CIPD deps.

The cross-compiled arm64 binary is uploaded as a CI artifact and then
**smoke-tested by a separate `smoke-test-linux-arm64` job on `ubuntu-26.04-arm`**,
so the full `dlopen` / `dlsym` / init / destroy round-trip is still verified on
real arm64 hardware before the release is published.
