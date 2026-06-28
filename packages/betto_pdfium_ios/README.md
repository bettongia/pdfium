# betto_pdfium_ios

Flutter iOS companion plugin for [`betto_pdfium`](https://pub.dev/packages/betto_pdfium).

## What this package does

`betto_pdfium` loads PDFium via `DynamicLibrary.process()` on iOS, which
requires PDFium's symbols to already be present in the process. iOS apps link
libraries statically via the Swift Package Manager (SPM) — there is no
`dlopen` at runtime. This package carries the PDFium static xcframework as an
SPM binary target so that Flutter wires it into the app at link time.

Without this package, `DynamicLibrary.process()` will fail to resolve any
`FPDF_*` symbols on iOS.

## Usage

Add both packages to your Flutter app's `pubspec.yaml`:

```yaml
dependencies:
  betto_pdfium: ^0.1.0-dev.1
  betto_pdfium_ios: ^0.1.0-dev.1
```

No additional setup is required. Flutter auto-discovers `betto_pdfium_ios` as a
plugin and wires it into `FlutterGeneratedPluginSwiftPackage` automatically when
Swift Package Manager integration is enabled.

**One-time global Flutter setup (required):**

```bash
flutter config --enable-swift-package-manager
```

## SPM dependency chain

```
FlutterGeneratedPluginSwiftPackage
  └── betto-pdfium-ios  (product from betto_pdfium_ios Package.swift)
        └── PdfiumIos   (Swift plugin stub — BettoPdfiumIosPlugin)
              └── PdfiumAnchor  (C target with __attribute__((used)) anchor)
                    └── pdfium_binary  (xcframework binaryTarget)
```

The C anchor file references `FPDF_InitLibraryWithConfig` with
`__attribute__((used))`, which prevents the linker from dead-stripping the
xcframework and ensures all PDFium symbols are present in the process image.

## Platform support

This package provides iOS support only. On other platforms, `betto_pdfium`
loads PDFium via native-assets (`dart:ffi` / `DynamicLibrary.open`) and does
not require this companion package.

## Versioning

`betto_pdfium_ios` is versioned in lock-step with `betto_pdfium`. Both packages
bundle the same PDFium build. Always use matching versions:

```yaml
dependencies:
  betto_pdfium: ^0.1.0-dev.1
  betto_pdfium_ios: ^0.1.0-dev.1
```

A version mismatch between the two packages could cause runtime symbol
resolution failures if the xcframework and the Dart FFI bindings are at
different PDFium upstream commits.

## License

Apache 2.0 — see [LICENSE](../../LICENSE).
