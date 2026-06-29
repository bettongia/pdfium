# PDFium WASM Assets

This directory holds the PDFium WebAssembly assets used by the `betto_pdfium`
web backend:

- `pdfium.js` — Emscripten glue (global `Module` pattern, auto-runs on load)
- `pdfium.wasm` — Compiled PDFium WebAssembly binary

These files are **not committed** — they are downloaded by `make fetch_wasm_assets`
from the bblanchon/pdfium-binaries GitHub release identified in
`version_pdfium.json`.

## Setup

From the repo root:

```bash
make fetch_wasm_assets
```

This downloads `pdfium-wasm.tgz`, verifies its SHA-256, and extracts
`pdfium.js` and `pdfium.wasm` here.

## In your Flutter web app

Copy these two files to your app's `web/assets/pdfium/` directory. The
`betto_pdfium` web backend loads the module from the URL
`assets/pdfium/pdfium.js` relative to the app origin.

Both files must be co-located: `pdfium.js` loads `pdfium.wasm` from the same
directory via its internal `locateFile()` helper.
