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

## Bumping the PDFium version

1. Update `PDFIUM_VERSION` with the new upstream commit SHA.
2. Commit and push to `main` — CI detects the `PDFIUM_VERSION` change,
   rebuilds all platform binaries from source, packages the `public/` headers
   from the same commit into `pdfium-headers.zip`, smoke-tests all native
   platforms, and publishes a new GitHub Release tagged `pdfium-<sha>`.
3. Run `make fetch_pdfium` locally to install the new binary and headers.
4. If the public API changed: run `make ffi_bindings` to regenerate
   `lib/src/generated/pdfium_bindings.dart` and commit the result.

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
- **Linux arm64** — cross-compiled on an x86_64 runner; cannot `dlopen` an
  arm64 ELF. ELF architecture verified via `file(1)`.
- **WASM** — placeholder build pending Emscripten setup.
