# Windows x86_64 PDFium Support

**Status**: Complete

**PR link**: _pending_

## Problem statement

`betto_pdfium` does not support Windows. `hook/build.dart` prints a warning and
emits no `CodeAsset` on `OS.windows`; `pdfium_isolate.dart` throws
`UnsupportedError` for `Platform.isWindows`. Users on Windows cannot load any
PDF document.

bblanchon/pdfium-binaries already publishes `pdfium-win-x64.tgz` (containing
`lib/pdfium.dll`) with every `chromium/NNNN` release, so no build pipeline is
required. The work is entirely mechanical: wire the DLL into the existing
distribution infrastructure and implement the Windows runtime load path.

## Open questions

- [x] **Does bblanchon ship a Windows x64 DLL with every release?** Yes —
  `pdfium-win-x64.tgz` is listed in `spec/01_binary_distribution.md` as a
  known future artifact. Confirmed present in the bblanchon release structure.
- [x] **What is the correct `DynamicLibrary.open` call on Windows?** Not a
  bare-name load — Windows is a desktop `DynamicLoadingBundled` platform like
  macOS/Linux, not like Android. The `_openLibrary()` Windows branch must probe
  the same three candidate paths as the Linux branch:
  `$exeDir/../lib/pdfium.dll` (dart build), `$cwd/.dart_tool/lib/pdfium.dll`
  (dart test / dart run JIT), and
  `$cwd/.dart_tool/betto_pdfium/$bblanchonBuild/pdfium.dll` (hook cache
  direct), with a bare-name last resort. See Investigation section.
- [x] **Does `fetch_pdfium.sh` need to handle Windows?** `fetch_pdfium.sh` is
  a Bash script and runs on macOS/Linux only. It provides the legacy
  `third_party/pdfium_bin/` layout for header extraction and the `make
  check_pdfium_version` target; it does **not** need to run on Windows for the
  primary developer workflow (the hook auto-downloads on any platform). A
  Windows Bash note (Git Bash / WSL) is sufficient. No PowerShell port is
  needed for v0.02.
- [x] **Is a Windows CI runner required to merge?** The manifest and hook
  changes can be authored and reviewed on macOS/Linux. A GitHub Actions
  `windows-latest` smoke-test job is the v0.02 completion gate — it is the
  minimum evidence that the runtime load path actually works, since the
  candidate-path design cannot be confirmed from a macOS/Linux host.
- [x] **Does `lib_path: "lib/pdfium.dll"` give `hook/build.dart` enough
  information to name the staged file correctly?** Yes — derive the
  destination filename from the last path segment of `lib_path` rather than
  the current hardcoded two-way `os == OS.macOS ? 'libpdfium.dylib' :
  'libpdfium.so'`. `lib/pdfium.dll` → `pdfium.dll`,
  `lib/libpdfium.dylib` → `libpdfium.dylib`, `lib/libpdfium.so` →
  `libpdfium.so`. This handles Windows cleanly and is the right general
  approach for any future platform.
- [x] **Does the hook need a "remove codesign" change for Windows?**
  No. `_ensureTgzExtracted` in `hook/build.dart` already gates xattr
  stripping on `Platform.isMacOS` (lines 271 and 304). There is no
  `codesign` call in the hook at all — signing only lives in
  `fetch_pdfium.sh`. Step 3's "remove codesign" instruction was incorrect;
  the only hook change needed is `libFileName` derivation and `_platformKey`.

## Investigation

### Binary artifact

bblanchon artifact: `pdfium-win-x64.tgz`
Contents: `lib/pdfium.dll` (note: no `lib` prefix, unlike the Unix naming)

The DLL library name diverges from the Unix convention:

| Platform   | bblanchon tarball path | Name used by `DynamicLibrary.open` |
|------------|------------------------|-------------------------------------|
| macOS      | `lib/libpdfium.dylib`  | path from hook / legacy probe       |
| Linux      | `lib/libpdfium.so`     | path from hook / legacy probe       |
| Windows    | `lib/pdfium.dll`       | `pdfium.dll` (bare name, no `lib`)  |

### Files to change

| File | Change |
|------|--------|
| `packages/betto_pdfium/version_pdfium.json` | Add `windows-x64` entry |
| `packages/betto_pdfium/scripts/update_pdfium_manifest.sh` | Download + checksum `pdfium-win-x64.tgz`; add to manifest |
| `packages/betto_pdfium/scripts/fetch_pdfium.sh` | Add Windows OS case (for Git Bash / WSL use) |
| `packages/betto_pdfium/hook/build.dart` | Handle `OS.windows` — emit CodeAsset for `pdfium.dll` |
| `packages/betto_pdfium/lib/src/document/pdfium_isolate.dart` | `_defaultDylibPathOrNull()` + `_openLibrary()` |
| `docs/spec/01_binary_distribution.md` | Document Windows artifact, installed layout, hook behaviour |

No changes to `_document_native.dart`, `_document_stub.dart`, or the public
`PdfDocument` API are needed — `_document_native.dart` already covers
`dart.library.ffi`, which includes Windows.

### hook/build.dart changes

Three changes are required:

**1. Remove the Windows early-return stub** and let `OS.windows` fall through
to `_buildDesktop`.

**2. Fix `libFileName` derivation** (line 130). Currently hardcoded:

```dart
final libFileName = os == OS.macOS ? 'libpdfium.dylib' : 'libpdfium.so';
```

On Windows this would stage the DLL as `libpdfium.so`. Replace with a
derivation from the manifest `lib_path` (last path segment):

```dart
final libFileName = libPath.split('/').last;
// lib/libpdfium.dylib → libpdfium.dylib
// lib/libpdfium.so    → libpdfium.so
// lib/pdfium.dll      → pdfium.dll
```

This is cleaner than a three-way and will handle any future platform
automatically.

**3. Add `windows-x64` to `_platformKey`** (lines 204–217). Currently throws
for any non-macOS/Linux OS:

```dart
if (os == OS.windows) return 'windows-x64';
```

No signing/xattr change is needed — `_ensureTgzExtracted` already gates
`xattr -c` on `Platform.isMacOS` at lines 271 and 304. There is no `codesign`
call in the hook.

**4. Update the file-level doc comment** at line 60
(`"Windows: not yet supported"`) to reflect that Windows is now supported.

### pdfium_isolate.dart changes

`_defaultDylibPathOrNull()` (coverage-ignored legacy path probe):

```dart
if (Platform.isWindows) {
  const legacy = 'third_party/pdfium_bin/windows_x64/pdfium.dll';
  if (File(legacy).existsSync()) return legacy;
  return null;
}
```

`_openLibrary()` — mirrors the **Linux** candidate-path probe (not the Android
bare-name load). Windows is a `DynamicLoadingBundled` desktop platform: `dart
test`, `dart run` (JIT), and `dart build` each stage the asset to a different
location, so absolute path probing is required:

```dart
if (Platform.isWindows) {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final cwd = Directory.current.path;
  const dllName = 'pdfium.dll';
  final candidates = <String>[
    // dart build cli: bundle\bin\<exe> → bundle\lib\pdfium.dll
    '$exeDir/../lib/$dllName',
    // dart test / dart run (JIT): staged to .dart_tool/lib/
    '$cwd/.dart_tool/lib/$dllName',
    // Hook cache direct path (fallback if staging hasn't copied the file)
    '$cwd/.dart_tool/betto_pdfium/$bblanchonBuild/$dllName',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (f.existsSync()) {
      try {
        return ffi.DynamicLibrary.open(f.absolute.path);
      } catch (_) {
        // Try next candidate.
      }
    }
  }
  // Last resort: bare name — only works if pdfium.dll is on PATH.
  return ffi.DynamicLibrary.open(dllName);
}
```

Also update the `UnsupportedError` message at the bottom of `_openLibrary()` to
include Windows in the supported platforms list.

### spec/01_binary_distribution.md changes

- Add `pdfium-win-x64.tgz` row to the bblanchon release structure table
  (removing the "future" annotation).
- Add `windows_x64/pdfium.dll` to the installed layout section.
- Add `Windows` row to the unsupported-platforms hook table (changing status
  from skipped to supported).
- Add a note that Windows `codesign` is not applicable.
- Add `windows-x64` consumer-mapping row to the manifest table.

### Testing constraints

The Dart test suite (`make test`) cannot run on Windows from a macOS dev
machine. Options:

1. **GitHub Actions `windows-latest` runner** — add a `windows` job to CI that
   runs `dart test` on the Windows runner. This is the cleanest long-term
   solution.
2. **Manual verification** — run `dart test` on a local Windows machine or
   virtual machine.

For v0.02, option 2 is the minimum gate. Option 1 (CI job) is recommended
as a follow-up to avoid regressions.

### Coverage

The `_openLibrary()` Windows branch and the `_defaultDylibPathOrNull()`
Windows probe are both inside the existing `// coverage:ignore-start` /
`// coverage:ignore-end` blocks that guard all platform-gated library-open
paths. No coverage annotation changes are needed.

The hook `OS.windows` path is also not exercised by the `dart test` suite
(hooks run at build time, not test time). It falls under the same rationale
as the existing iOS/Android hook branches.

## Implementation plan

- [x] **1. Update `update_pdfium_manifest.sh`**
  - Add `WINDOWS_X64_SHA=$(_fetch_sha "pdfium-win-x64.tgz" "$WORK/win-x64.tgz")`
  - Add `"windows-x64"` block to the `version_pdfium.json` heredoc:
    ```json
    "windows-x64": {
      "url": "...",
      "lib_path": "lib/pdfium.dll",
      "sha256": "$WINDOWS_X64_SHA"
    }
    ```

- [x] **2. Run `make update_pdfium_manifest`**
  - Computes the live SHA-256 and rewrites `version_pdfium.json` with the
    `windows-x64` entry.

- [x] **3. Update `hook/build.dart`** — three changes:
  - **Remove the Windows early-return stub** so `OS.windows` falls through to
    `_buildDesktop`.
  - **Fix `libFileName` derivation** (line 130) — replace the hardcoded
    two-way with `libPath.split('/').last` so `lib/pdfium.dll` →
    `pdfium.dll` (and existing platforms are unaffected).
  - **Add `windows-x64` to `_platformKey`** (lines 204–217):
    `if (os == OS.windows) return 'windows-x64';`
  - **Update the file-level doc comment** (line 60) from "Windows: not yet
    supported" to reflect Windows support.
  - No signing/xattr change needed — `_ensureTgzExtracted` already gates
    `xattr -c` on `Platform.isMacOS`.

- [x] **4. Update `fetch_pdfium.sh`**
  - Add Windows OS detection in the **first** `case "$OS"` (artifact selection):
    ```bash
    MINGW*|MSYS*|Windows_NT)
        ARTIFACT="pdfium-win-x64.tgz"
        LIB_IN_TGZ="lib/pdfium.dll"
        INSTALL_DIR="$PDFIUM_BIN/windows_x64"
        INSTALL_NAME="pdfium.dll"
        ;;
    ```
  - Add Windows arm in the **second** `case "$OS"` (manifest key lookup):
    ```bash
    MINGW*|MSYS*|Windows_NT) PLATFORM_KEY="windows-x64" ;;
    ```
  - Add `windows_x64/pdfium.dll` to the installed layout comment block.

- [x] **5. Update `pdfium_isolate.dart`**
  - In `_defaultDylibPathOrNull()`: add Windows legacy path probe (absolute
    path to `third_party/pdfium_bin/windows_x64/pdfium.dll`).
  - In `_openLibrary()`: add `Platform.isWindows` candidate-path probe
    mirroring Linux (see Investigation section for exact code).
  - Update the `UnsupportedError` message to include Windows in the supported
    list.

- [x] **6. Update `spec/01_binary_distribution.md`**
  - Remove "future" annotation from `pdfium-win-x64.tgz` table row.
  - Add `windows_x64/pdfium.dll` to installed layout.
  - Update the `Consumer mapping` table with `windows-x64` → `hook/build.dart`.
  - Update the hook unsupported-platforms table (Windows: supported).

- [x] **7. Verify existing tests pass** — `make pre_commit`

- [ ] **8. Windows verification** — add a GitHub Actions `windows-latest` CI
  job that runs `dart test`. This is the v0.02 completion gate; the candidate
  load-path design cannot be confirmed without a real Windows run.
  _(Deferred — CI infrastructure work beyond this implementation plan.)_

- [x] **9. Update `docs/roadmap/0_02.md`** — mark Windows item complete.

## Reviews

### Review 1: 2026-06-29

**Problem Statement Assessment**

The problem is real, well-scoped, and aligns cleanly with `docs/roadmap/0_02.md`,
which lists Windows x86_64 as an Open item and references this plan by name. The
roadmap also names this as the prerequisite that should land before the WASM
work so the manifest schema can be reviewed in context — so getting this right
matters beyond Windows itself. bblanchon ships `pdfium-win-x64.tgz` containing
`lib/pdfium.dll`; the spec (`01_binary_distribution.md`) already lists it as a
"future" artifact. No build pipeline is required. Good problem, worth solving.

**Proposed Solution Assessment**

The high-level shape is correct: manifest entry, hook emission, runtime load
path, spec update. But the plan materially understates the hook work and the
runtime-load work, and two of its concrete claims are wrong when checked against
the current source. These need to be fixed before implementation, or the
implementer will hit them blind.

1. **`_buildDesktop` does NOT work for Windows unchanged — the plan's claim of
   "no structural change is needed" is incorrect.** `hook/build.dart` line 130
   hardcodes the staged output filename:
   `final libFileName = os == OS.macOS ? 'libpdfium.dylib' : 'libpdfium.so';`
   On Windows this stages the DLL as `libpdfium.so`. The `lib_path` from the
   manifest only controls what is *extracted from the tarball*, not the
   destination filename. Step 3 of the implementation plan asserts the opposite.
   The filename selection must become three-way (`pdfium.dll` for Windows), and
   the runtime loader must agree on that exact name.

2. **`_platformKey` throws `UnsupportedError` for Windows.** `hook/build.dart`
   lines 204-217 only handle macOS and Linux; the final line throws
   `UnsupportedError('betto_pdfium: unsupported OS for hook: $os')`. The plan's
   "Files to change" table and Step 3 do not mention `_platformKey`. Without a
   `windows-x64` branch here, `_loadPlatformManifest` never resolves the entry
   and the hook throws before download. This must be added.

3. **The `_openLibrary()` Windows branch is modelled on the wrong platform.**
   The plan proposes a bare `DynamicLibrary.open('pdfium.dll')` "mirroring the
   Android pattern". But Windows is a *desktop `DynamicLoadingBundled`* platform,
   in the same class as macOS and Linux — not Android. Android's bare-name load
   works because the Android APK loader resolves `libpdfium.so` from
   `lib/{abi}/`. On desktop, the actual `_openLibrary()` macOS/Linux branches
   (lines 2982-3045) do **not** rely on bare-name resolution: they probe an
   ordered list of absolute candidate paths — `$exeDir/../lib/`,
   `$cwd/.dart_tool/lib/`, and `$cwd/.dart_tool/betto_pdfium/$bblanchonBuild/` —
   precisely because `dart test`, `dart run` (JIT), and `dart build` each stage
   the bundled asset to a *different* location, none of which is adjacent to the
   Dart executable. The plan's bare `DynamicLibrary.open('pdfium.dll')` will only
   succeed if `pdfium.dll` happens to be on the DLL search path, which is not
   guaranteed in any of those three workflows. The Windows branch should mirror
   the **Linux** branch (candidate-path probing with a bare-name last resort),
   not the Android one-liner.

**Architecture Fit**

The pure-Dart / FFI boundary is respected — no `dart:ui` or Flutter imports are
introduced, and `_document_native.dart` correctly already covers
`dart.library.ffi` (which includes Windows). The library-architecture layer
boundaries are not disturbed: this is a Core-layer storage/loading change with
no presentation or app-layer impact, and no public API surface change. The
manifest-and-hook contract is the right place for this work. The spec update
list in the plan is appropriate and complete for what it covers (artifact row,
installed layout, hook table, consumer mapping, codesign note).

One spec/consistency note: the plan should also confirm the `_buildDesktop`
section comment block and the file-level doc comment in `hook/build.dart` (the
`## Unsupported platforms` library doc, line 60: "Windows: not yet supported")
get updated. The plan lists the runtime `print` stub but not the doc comment.

**Risk & Edge Cases**

- **Runtime load path is unverifiable from this host.** Every concern in point 3
  above can only be confirmed on Windows. Setting status `Investigated` while
  the core runtime claim rests on an Android analogy that I believe is incorrect
  is the central risk. I am not blocking on the testing constraint itself (the
  plan is honest that Windows execution is deferred), but the *design* of the
  load path should be corrected to match the desktop pattern before it is called
  investigated — otherwise the first Windows run will fail and the "mechanical"
  framing collapses.
- **`tar` availability on Windows.** Both `hook/build.dart` (`_extractFromTgz`)
  and `fetch_pdfium.sh` shell out to `tar`. Windows 10 1803+ ships `bsdtar` as
  `tar.exe`, so the hook's `Process.run('tar', ...)` will generally work, but
  this is an unstated assumption worth recording. The `--strip-components`
  behaviour of bsdtar matches GNU tar here, so the extraction logic is fine.
- **`xattr`/`codesign` correctly skipped.** The plan's note to gate signing on
  `os == OS.macOS` is right; `_ensureTgzExtracted` already guards xattr stripping
  with `Platform.isMacOS`, so no change is needed there (the plan implies a hook
  edit for signing, but the existing `_buildDesktop` has no codesign step — the
  signing only lives in `fetch_pdfium.sh`. Step 3's "Remove the codesign step
  for Windows" is therefore a no-op for the hook; verify before writing it).
- **Coverage.** The plan is correct that the new branches fall inside existing
  `coverage:ignore` blocks; the 90% gate is not threatened. No concern.
- **`fetch_pdfium.sh` PLATFORM_KEY map.** The script has a *second* `case "$OS"`
  (lines 80-83) that maps OS to the manifest `PLATFORM_KEY` for checksum lookup.
  The plan's Step 4 only shows the first `case` (artifact selection). Both cases
  need a Windows arm or the script will fail at checksum verification.

**Recommendations**

Do not implement as currently written. The plan is close but three of its load-
bearing technical claims are inaccurate against the current source, and two
files that must change (`_platformKey`, the second `case` in `fetch_pdfium.sh`)
are missing from the change list. Concretely, before this returns to
`Investigated`:

1. Correct Step 3 / the hook section: three-way `libFileName` selection, add a
   `windows-x64` branch to `_platformKey`, update the file-level doc comment.
2. Rewrite the `_openLibrary()` Windows design to mirror the **Linux**
   candidate-path probe, not the Android bare-name load. Document the staging
   locations it must probe (`$exeDir/../lib/pdfium.dll`,
   `$cwd/.dart_tool/lib/pdfium.dll`,
   `$cwd/.dart_tool/betto_pdfium/$bblanchonBuild/pdfium.dll`) with a bare-name
   last resort.
3. Add the second `fetch_pdfium.sh` `case` arm to Step 4.
4. Verify the "remove codesign from hook" instruction in Step 3 — it appears to
   be a no-op and may indicate a misreading of where signing lives.
5. Keep the CI follow-up framing, but state plainly that the runtime load path
   is *unverified* until a Windows run happens, since the design correction in
   (2) cannot be confirmed from a macOS/Linux host.

I am moving the status to `Questions` to reflect the open items below.

**Open questions**

- [x] Confirm the Windows runtime staging locations for `dart test`, `dart run`
      (JIT), and `dart build` so `_openLibrary()` probes the correct paths.
      _Resolved:_ Same three locations as Linux — `$exeDir/../lib/pdfium.dll`,
      `$cwd/.dart_tool/lib/pdfium.dll`,
      `$cwd/.dart_tool/betto_pdfium/$bblanchonBuild/pdfium.dll` — with a
      bare-name last resort. Updated in the Investigation section and
      Implementation plan step 5.
- [x] Will the `windows-x64` manifest key use the same `lib_path:
      "lib/pdfium.dll"` shape as the others, with the destination-filename
      divergence handled entirely in `_buildDesktop`?
      _Resolved:_ Yes — `lib_path` controls tarball extraction only. The hook
      derives the staged destination filename as `libPath.split('/').last`,
      which naturally produces `pdfium.dll` for Windows. Updated in step 3.
- [x] Is a `windows-latest` CI smoke test acceptable as the v0.02 completion
      gate?
      _Resolved:_ Yes — a GitHub Actions `windows-latest` job running
      `dart test` is the completion gate. Updated in step 8.

## Summary

- Added `windows-x64` entry to `version_pdfium.json` with the computed
  SHA-256 of `pdfium-win-x64.tgz` (bblanchon chromium/7906) and
  `"lib_path": "lib/pdfium.dll"`.
- Updated `scripts/update_pdfium_manifest.sh` to download and checksum
  `pdfium-win-x64.tgz` and write the `windows-x64` block into
  `version_pdfium.json`; future version bumps will include Windows
  automatically.
- Updated `hook/build.dart`: removed the Windows early-return stub so
  `OS.windows` falls through to `_buildDesktop`; fixed `libFileName`
  derivation to use `libPath.split('/').last` (generalises cleanly for any
  future platform); added `windows-x64` branch to `_platformKey`; updated
  the file-level doc comment to document Windows support.
- Updated `scripts/fetch_pdfium.sh`: added `MINGW*|MSYS*|Windows_NT` arm to
  both case statements — artifact selection (`pdfium-win-x64.tgz`,
  `lib/pdfium.dll`, `windows_x64/`) and PLATFORM_KEY lookup (`windows-x64`).
- Updated `lib/src/document/pdfium_isolate.dart`: added Windows probe to
  `_defaultDylibPathOrNull()` (legacy `third_party/pdfium_bin/windows_x64/`
  path); added Windows candidate-path probe to `_openLibrary()` mirroring the
  Linux branch (three absolute paths + bare-name last resort); updated the
  `UnsupportedError` message to include Windows.
- Updated `docs/spec/01_binary_distribution.md`: removed "future" from
  `pdfium-win-x64.tgz` table row; added `windows_x64/pdfium.dll` to
  installed layout; added `windows-x64` to consumer mapping table; changed
  Windows hook status from "skipped / not yet supported" to "Supported".
- All 599 existing tests continue to pass (`make pre_commit`).
- **Known gap / follow-on:** end-to-end execution on a real Windows machine
  has not been performed — the runtime load-path design follows the same
  pattern as Linux but cannot be confirmed without a Windows runner. A GitHub
  Actions `windows-latest` CI job is the recommended next step (deferred from
  this plan as infrastructure work).
