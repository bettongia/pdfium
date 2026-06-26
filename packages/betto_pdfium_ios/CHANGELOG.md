## 0.0.1

- Initial version. Carries the PDFium static xcframework as an SPM binary
  target so that `DynamicLibrary.process()` can resolve FPDF_* symbols in
  Flutter iOS apps using `betto_pdfium`.
