# Testing

## Overview

`betto_pdfium` has three testing surfaces:

| Surface | Tool | When to run |
| ------- | ---- | ----------- |
| Dart unit + integration tests | `dart test` | Always — primary gate |
| iOS on-device / simulator | `flutter test integration_test/` | Before mobile releases |
| Android on-device / emulator | `flutter test integration_test/` | Before mobile releases |

All `make` commands run from the **repo root**.

## Dart test suite

The Dart test suite in `packages/betto_pdfium/test/` covers all public API
surfaces on the native FFI backend. The native-assets hook downloads the
platform binary automatically on the first run — no manual setup required.

```bash
make test          # dart test (all files)
make coverage      # dart test --coverage + genhtml → site/coverage/
```

To run a single file:

```bash
dart test packages/betto_pdfium/test/pdf_types_test.dart
```

### Coverage

Coverage is measured with `make coverage`. The generated HTML report is written
to `site/coverage/`. The `*/generated/*` path (auto-generated FFI bindings) is
excluded from the lcov report by the Makefile `--remove` step.

Minimum required coverage: **90%**. Check after every implementation step.

## Mobile integration test app

`packages/betto_pdfium/integration_test_app/` is a Flutter app that runs the
same test suite on a connected iOS or Android device or simulator. Tests load
PDF fixtures from the Flutter asset bundle rather than the filesystem, which is
why a separate Flutter app is needed.

### iOS

iOS support requires `packages/betto_pdfium_ios/` — a companion Flutter plugin
that links the PDFium static xcframework. Flutter auto-discovers it via the
integration test app's `pubspec.yaml` path dependency and wires it into
`FlutterGeneratedPluginSwiftPackage` automatically. No manual Xcode steps are
required.

The xcframework is declared as a **URL-based SPM binary target** in
`betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift`. SPM downloads and caches
it directly from the GitHub Release during `flutter pub get` — no manual binary
fetch is needed for iOS.

**One-time global setup:**

```bash
flutter config --enable-swift-package-manager
```

**Run tests on the default iOS simulator:**

```bash
make ios_test
```

This target runs `sync_fixtures` (copies test fixtures into the asset bundle),
`flutter pub get` (which triggers SPM to download the xcframework), and
`flutter test integration_test/` on the simulator named by `$EMULATOR_IOS`
(default: `ios-emulator`).

**Create the simulator (one-time):**

```bash
make emulator_ios_create
```

**Environment variables:**

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `EMULATOR_IOS` | `ios-emulator` | Simulator name |
| `EMULATOR_IOS_DEVICE` | `iPhone 17` | Simulator device type |
| `EMULATOR_IOS_RUNTIME` | `iOS26.5` | Simulator runtime |

**Run tests manually on a specific device:**

```bash
cd packages/betto_pdfium/integration_test_app
flutter test integration_test/ -d <device-id>
```

### Android

**Run tests on the default Android emulator:**

```bash
make android_test
```

This target runs `sync_fixtures`, `fetch_mobile_binaries`, and
`flutter test integration_test/` on the AVD named by `$EMULATOR_ANDROID`
(default: `android-emulator`).

**Create the AVD (one-time):**

```bash
make emulator_android_create
```

**Environment variables:**

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `EMULATOR_ANDROID` | `android-emulator` | AVD name |
| `ADB_BINARY_PATH` | `~/Library/Android/sdk/platform-tools` | Path to `adb` |

**Stop all emulators:**

```bash
make emulators_stop
```

## CI

The `cicd.yml` workflow runs `make cicd` (format check, analyze, license check,
test, and doc site) on Ubuntu. A separate `test` matrix job runs
`dart test` on macOS arm64 and Linux arm64 after a successful build, verifying
platform binary downloads on real native runners.

Mobile integration tests are not run in CI — they require a connected device or
simulator and are intended for pre-release validation on a developer machine.
