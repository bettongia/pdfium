# betto_pdfium_ios

## 0.1.0

First stable release. No functional changes since `0.1.0-dev.4`.

## 0.1.0-dev.4

- **Dart 3.13 support.** SDK constraint raised to `^3.13.0`. No API changes.

## 0.1.0-dev.3 - 2026-07-03

Version bump — no API changes.

## 0.1.0-dev.2

Version bump — no API changes.

## 0.1.0-dev.1

- Initial version. Carries the PDFium static xcframework as an SPM binary target
  so that `DynamicLibrary.process()` can resolve FPDF\_\* symbols in Flutter iOS
  apps using `betto_pdfium`.
