# Releasing

## Overview

This repository contains two pub packages that must be released in lock-step:

| Package | Path | pub.dev |
| ------- | ---- | ------- |
| `betto_pdfium` | `packages/betto_pdfium/` | Published first |
| `betto_pdfium_ios` | `packages/betto_pdfium_ios/` | Published second |

`betto_pdfium_ios` declares a version constraint on `betto_pdfium` in its
`pubspec.yaml`. Always publish `betto_pdfium` first so the version is available
on pub.dev before `betto_pdfium_ios` references it.

## Bumping the PDFium version (bblanchon)

PDFium binaries are sourced from bblanchon/pdfium-binaries. To adopt a new
bblanchon release:

1. Update `packages/betto_pdfium/BBLANCHON_BUILD` with the new build number
   (e.g. `7906` → `7907`).
2. Run `make repack_ios_xcframework` — downloads bblanchon iOS device + simulator
   tarballs, repacks them into `pdfium.xcframework`, and uploads the zip to a
   new `bettongia/pdfium` GitHub Release tagged `bblanchon-chromium-<BUILD>`.
3. Run `make update_pdfium_manifest` — downloads each bblanchon tarball, computes
   SHA-256s, rewrites `version_pdfium.json` and `lib/src/pdfium_version.dart`,
   and updates `Package.swift` with the new iOS xcframework URL and checksum.
4. Run `make fetch_pdfium` to install the binary and headers locally.
5. If the PDFium public API changed: run `make ffi_bindings` to regenerate
   `lib/src/generated/pdfium_bindings.dart`.
6. Run `make pre_commit` to verify everything passes.
7. Commit `BBLANCHON_BUILD`, `version_pdfium.json`, `lib/src/pdfium_version.dart`,
   `Package.swift`, and any regenerated bindings with a message like:
   `"Bump PDFium to bblanchon chromium/<NEW_BUILD>"`.

See [PDFium Binary Distribution](01_binary_distribution.md) for the full
contract.

## Pre-release checklist

Before publishing either package:

1. All tests pass: `make pre_commit`
2. Coverage ≥ 90%: `make coverage`
3. Both packages have identical version numbers in their `pubspec.yaml` files.
4. `CHANGELOG.md` at the repo root is updated with a release entry.
5. The PDFium binary manifest `packages/betto_pdfium/version_pdfium.json` is
   committed with checksums for all platforms (see
   [PDFium Binary Distribution](01_binary_distribution.md)).

## Version numbering

Both packages use the same version number. Version numbers follow
[pub.dev versioning](https://dart.dev/tools/pub/versioning) (semantic
versioning):

- `0.x.y` — pre-stable; breaking changes allowed between minor versions.
- `1.x.y` — stable public API; breaking changes require a major version bump.

Update the version in both `pubspec.yaml` files together:

```
packages/betto_pdfium/pubspec.yaml
packages/betto_pdfium_ios/pubspec.yaml
```

## Updating betto_pdfium_ios's dependency on betto_pdfium

`packages/betto_pdfium_ios/pubspec.yaml` must declare a dependency on
`betto_pdfium` using a version constraint that matches the release:

```yaml
dependencies:
  betto_pdfium: ^<version>
```

The constraint should allow all compatible patch/minor versions, not pin to an
exact version, so that users can adopt `betto_pdfium` patch releases without
waiting for a `betto_pdfium_ios` release.

## Dry-run validation

Validate each package before publishing:

```bash
cd packages/betto_pdfium
dart pub publish --dry-run

cd packages/betto_pdfium_ios
dart pub publish --dry-run
```

Resolve any warnings before proceeding. Common issues:

- Missing `README.md` (required by pub.dev).
- `publish_to: none` still set in `pubspec.yaml` (remove before publishing).
- Files that should be excluded listed in `.pubignore`.

## Publishing order

### Step 1 — publish betto_pdfium

```bash
cd packages/betto_pdfium
dart pub publish
```

Wait for the package to appear on pub.dev before proceeding. The pub.dev
propagation delay is typically under 30 seconds but can take a few minutes.

### Step 2 — publish betto_pdfium_ios

```bash
cd packages/betto_pdfium_ios
dart pub publish
```

## Post-release

1. Tag the release in git: `git tag v<version> && git push --tags`
2. Create a GitHub Release with the tag; paste the relevant `CHANGELOG.md`
   entry as the release notes.
3. Announce in the appropriate channels.

## Staying in sync

`betto_pdfium` and `betto_pdfium_ios` are versioned together because:

- `betto_pdfium_ios` bundles the same PDFium build as `betto_pdfium`. If the
  PDFium SHA is bumped (new binary release), both packages must ship together
  so that the iOS xcframework and the Dart FFI bindings remain at the same
  upstream commit.
- The `DynamicLibrary.process()` call in `_document_native.dart` relies on
  `betto_pdfium_ios` having loaded PDFium symbols into the process. A version
  mismatch between the two packages could produce subtle ABI errors at runtime.

There is no automated enforcement of this constraint — it is the release
author's responsibility to keep versions in sync.
