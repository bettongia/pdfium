# pdfium-build

Orphan branch of `bettongia/pdfium` that owns the PDFium binary build matrix.
It produces pre-built platform libraries published as GitHub Releases; the `main`
branch consumes them via `make fetch_pdfium`.

This branch contains no Dart code and no PDFium source. It is self-contained: a
Makefile, per-platform build scripts, and nothing else.

## Platform matrix

| Target              | Build host                       | Output                        |
| ------------------- | -------------------------------- | ----------------------------- |
| macOS arm64         | macOS arm64 (local or CI)        | `libpdfium.dylib`             |
| iOS arm64           | macOS arm64 (local or CI)        | `libpdfium.xcframework.zip`   |
| Linux x86_64        | GitHub Actions `ubuntu-latest`   | `libpdfium.so`                |
| Linux arm64         | GitHub Actions `ubuntu-latest`   | `libpdfium.so`                |
| Android arm64       | GitHub Actions `ubuntu-latest`   | `libpdfium.so`                |
| Android x86_64      | GitHub Actions `ubuntu-latest`   | `libpdfium.so`                |
| Web (WASM)          | GitHub Actions `ubuntu-latest`   | `libpdfium.wasm` + `.js`      |

**macOS note:** Linux, Android, and WASM cannot be built locally on macOS.
Podman containers were attempted but abandoned because depot_tools' Go-based
binaries (`vpython3`) crash under QEMU x86_64 emulation on Apple Silicon. Use
a native Linux machine or trigger a CI run instead.

## How it works

`make setup` clones `depot_tools` and runs `gclient sync` to fetch the PDFium
source tree at the commit SHA recorded in `PDFIUM_VERSION` on the `main` branch.
The source (~3–5 GB) is never committed to this branch — it is fetched fresh on
each cold build and cached in CI keyed on the SHA.

`setup.sh` also applies a small set of source patches after sync (see
[Source patches](#source-patches) below).

## Local build (macOS arm64)

Prerequisites: Xcode command-line tools, Python 3, Git.

```bash
# First time only — downloads depot_tools and syncs the PDFium source tree.
# Expect 3-5 GB of downloads and 20-40 minutes on a cold cache.
make setup

# Build the macOS dylib
make build_pdfium_macos

# Build the iOS xcframework
make build_pdfium_ios
```

Artifacts are staged to `dist/<platform>/`:

```
dist/
  mac-arm64/
    libpdfium.dylib
    VERSION
  ios-arm64/
    libpdfium-ios-arm64.xcframework.zip
    VERSION
```

## Makefile targets

| Target                      | Description                                      |
| --------------------------- | ------------------------------------------------ |
| `make setup`                | Clone depot_tools + gclient sync (idempotent)    |
| `make build_pdfium_macos`   | Build macOS arm64 dylib                          |
| `make build_pdfium_ios`     | Build iOS arm64 xcframework                      |
| `make build_pdfium_linux_x64`    | Build Linux x86_64 shared lib              |
| `make build_pdfium_linux_arm64`  | Build Linux arm64 shared lib               |
| `make build_pdfium_android_arm64` | Build Android arm64 shared lib            |
| `make build_pdfium_android_x64`  | Build Android x86_64 shared lib            |
| `make build_pdfium_wasm`    | Build WebAssembly module                         |
| `make clean`                | Delete `dist/` and ninja output dirs             |
| `make purge`                | Delete everything including `build/` (full reset)|

## Bumping the PDFium SHA

1. On `main`, update `PDFIUM_VERSION` to the new commit SHA.
2. On `main`, run `git subtree pull` to update `third_party/pdfium/` (public
   headers only — used for FFI binding generation).
3. On `main`, run `make ffi_bindings` to regenerate `lib/src/generated/pdfium_bindings.dart`.
4. Push `main`. The CI pipeline triggers on the `PDFIUM_VERSION` change and
   rebuilds all platform binaries.
5. After the release publishes, run `make fetch_pdfium` on `main` to pull the
   new binaries into `third_party/pdfium_bin/`.

**SHA consistency invariant:** `PDFIUM_VERSION`, the `third_party/pdfium/`
headers subtree on `main`, and the SHA used by `gclient sync` on this branch
must always point to the same PDFium commit.

## Disk usage

A cold `make setup` downloads approximately 3–5 GB into `build/`. The compiled
output in `build/pdfium_checkout/pdfium/out/` adds another 2–4 GB per platform.
Run `make purge` to remove everything and start fresh.

`gclient` writes a small authentication cache to `~/.config/gclient`. Everything
else stays under `build/`.

## Source patches

`scripts/setup.sh` applies the following patches to the PDFium source after
`gclient sync`. All patches are idempotent (guarded by grep before applying).

| File patched | Reason |
| --- | --- |
| `build/config/ios/ios_sdk.gni` | Declares `ios_automatically_manage_certs`, which `testing/test.gni` references but PDFium never declares in its standalone build. |
| `base/allocator/partition_allocator/…/BUILD.gn` | Removes `-fvisibility-global-new-delete=force-hidden`, incompatible with the iOS 26 SDK's `global_new_delete.h`. |
| `buildtools/third_party/libc++/BUILD.gn` | Same flag removal as above. |
| `third_party/libjpeg_turbo/BUILD.gn` | Removes `assert(use_blink, …)` — PDFium's standalone build sets `use_blink = false` but still depends on libjpeg_turbo. |

The `-fvisibility` and `use_blink` patches are specific to Xcode 26 beta and
PDFium's pinned clang revision. They may become unnecessary once Apple ships the
final Xcode 26 SDK or PDFium upgrades its bundled clang.

## CI pipeline

The GitHub Actions workflow (`.github/workflows/build_pdfium.yml` on `main`)
triggers on any push that modifies `PDFIUM_VERSION`. It:

1. Checks out this branch alongside `main`.
2. Runs `make build_pdfium_<platform>` for each platform on the appropriate
   runner (macOS arm64 for macOS/iOS; `ubuntu-latest` for Linux/Android/WASM).
3. Caches `build/` keyed on the PDFium SHA to avoid full re-syncs on re-runs.
4. Uploads artifacts and publishes a GitHub Release tagged `pdfium-<full-sha>`.

## Release artifact layout

```
libpdfium-macos-arm64.dylib
libpdfium-ios-arm64.xcframework.zip
libpdfium-linux-x86_64.so
libpdfium-linux-arm64.so
libpdfium-android-arm64.so
libpdfium-android-x86_64.so
libpdfium-web.wasm
libpdfium-web.js
VERSION.txt                    ← PDFium commit SHA + build date (ISO-8601 UTC)
checksums.sha256               ← SHA256 of every artifact; verified by make fetch_pdfium
```
