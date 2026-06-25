# Mobile integration test app (iOS and Android)

**Status**: Investigated

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
        Package.swift            # local SPM binary target referencing ../Frameworks/pdfium.xcframework
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

A local SPM package vends the xcframework as a binary target:

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
        .binaryTarget(
            name: "pdfium",
            path: "../../Frameworks/pdfium.xcframework"
        ),
    ]
)
```

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

Downloads from the same release tag as `PDFIUM_VERSION` in the root of the
project. Verifies checksums against `checksums.sha256`. Places files at:
- `android/src/main/jniLibs/arm64-v8a/libpdfium.so`
- `android/src/main/jniLibs/x86_64/libpdfium.so`
- `ios/Frameworks/pdfium.xcframework/` (unzipped from `.xcframework.zip`)

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
- `integration_test_app/ios/pdfium.podspec`
- `integration_test_app/.gitignore`
- All PDF assets copied from `test/fixtures/` and `test/data/`

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

- [ ] **`fetch_mobile_binaries.sh`** — script that reads `../PDFIUM_VERSION`,
      downloads the corresponding release artifacts, verifies checksums, and
      installs into `android/src/main/jniLibs/` and `ios/Frameworks/`.

- [ ] **Flutter app scaffold** — `lib/main.dart` and `pubspec.yaml` (with asset
      declarations for all PDFs in `assets/`).

- [ ] **Copy PDF fixtures** — mirror `test/fixtures/` and `test/data/` into
      `integration_test_app/assets/`.

- [ ] **`ios/LocalPackages/pdfium/Package.swift`** — local SPM binary target
      referencing the xcframework. Enable Flutter SPM support with
      `flutter config --enable-swift-package-manager`. Add the local package to
      the Xcode project (one-time manual step); commit the `project.pbxproj`
      change so the reference is version-controlled.

- [ ] **`.gitignore`** — exclude `android/src/main/jniLibs/` and
      `ios/Frameworks/`.

- [ ] **`integration_test/pdfium_test.dart`** — full test suite covering all
      groups in the table above. Use `rootBundle.load()` for PDF bytes.

- [ ] **Verify on iOS simulator** — run `scripts/fetch_mobile_binaries.sh` then
      `flutter test integration_test/ -d <simulator-id>`; confirm all tests pass.

- [ ] **Verify on Android emulator** — same but with an Android device/emulator.

- [ ] **Update `CLAUDE.md`** — document the `integration_test_app/` and how to
      run it.

## Reviews

_None yet._

## Summary

_To be filled in once implementation is complete._
