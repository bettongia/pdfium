#!/usr/bin/env bash

# Copyright 2026 The Authors. See the AUTHORS file for details.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# fetch_wasm_assets.sh
#
# Downloads the PDFium WASM + JS assets from the bblanchon/pdfium-binaries
# release identified in version_pdfium.json, verifies the SHA-256 checksum,
# and extracts them to a target directory (default:
# integration_test_app/web/assets/pdfium/).
#
# Users of betto_pdfium in a Flutter web app must:
#   1. Run this script (or `make fetch_wasm_assets`) once per PDFium version
#      bump, or in CI before a web build.
#   2. Copy the extracted files to their app's web/assets/pdfium/ directory.
#   3. The _document_web.dart backend loads the module from the well-known
#      relative URL assets/pdfium/pdfium.js.
#
# The tarball contains lib/pdfium.wasm and lib/pdfium.js. Both files must be
# co-located; pdfium.js loads pdfium.wasm from the same directory via its
# internal locateFile() helper.
#
# Usage (from packages/betto_pdfium/):
#   scripts/fetch_wasm_assets.sh
#   # or via Make from the repo root:
#   make fetch_wasm_assets
#
# Environment variables:
#   WASM_OUTPUT_DIR  Output directory for extracted WASM assets.
#                    Default: integration_test_app/web/assets/pdfium/
#
# The script is idempotent: if the target directory already contains the
# correct build-number marker file, extraction is skipped.

set -euo pipefail

BUILD=$(tr -d '[:space:]' < BBLANCHON_BUILD)
OUTPUT_DIR="${WASM_OUTPUT_DIR:-integration_test_app/web/assets/pdfium}"
MARKER="$OUTPUT_DIR/.bblanchon_build"

# Idempotent: skip if already at the correct version.
if [ -f "$MARKER" ]; then
    INSTALLED=$(tr -d '[:space:]' < "$MARKER")
    if [ "$INSTALLED" = "$BUILD" ]; then
        echo "fetch_wasm_assets: already at bblanchon chromium/$BUILD — nothing to do."
        exit 0
    fi
fi

# Checksum helper (works on both macOS shasum and Linux sha256sum).
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Read URL and expected SHA-256 from version_pdfium.json.
read -r WASM_URL EXPECTED_SHA <<< "$(python3 -c "
import json
with open('version_pdfium.json') as f:
    m = json.load(f)
w = m['platforms']['wasm']
print(w['url'], w['sha256'])
")"

ARTIFACT="pdfium-wasm.tgz"

echo "fetch_wasm_assets: downloading $ARTIFACT from bblanchon chromium/$BUILD ..."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

curl -fsSL -o "$WORK/$ARTIFACT" "$WASM_URL"

# Verify SHA-256 of the tarball BEFORE extraction.
echo "fetch_wasm_assets: verifying $ARTIFACT checksum ..."
ACTUAL=$(_sha256 "$WORK/$ARTIFACT")
if [ "$EXPECTED_SHA" != "$ACTUAL" ]; then
    echo "fetch_wasm_assets: checksum mismatch for $ARTIFACT"
    echo "  expected: $EXPECTED_SHA"
    echo "  actual:   $ACTUAL"
    exit 1
fi
echo "fetch_wasm_assets: checksum verified."

# Extract lib/pdfium.wasm and lib/pdfium.js from the verified tarball.
echo "fetch_wasm_assets: extracting WASM assets ..."
mkdir -p "$OUTPUT_DIR"
tar -xzf "$WORK/$ARTIFACT" -C "$WORK" lib/pdfium.wasm lib/pdfium.js

cp "$WORK/lib/pdfium.wasm" "$OUTPUT_DIR/pdfium.wasm"
cp "$WORK/lib/pdfium.js"   "$OUTPUT_DIR/pdfium.js"

# Write the build-number marker for idempotency.
echo "$BUILD" > "$MARKER"

echo ""
echo "fetch_wasm_assets: done."
echo "  bblanchon build: chromium/$BUILD"
echo "  output dir:      $OUTPUT_DIR"
echo "  files:"
echo "    $OUTPUT_DIR/pdfium.wasm"
echo "    $OUTPUT_DIR/pdfium.js"
echo ""
echo "Next steps:"
echo "  Copy $OUTPUT_DIR/ to your Flutter web app's web/assets/pdfium/ directory."
echo "  The betto_pdfium web backend loads the module from assets/pdfium/pdfium.js."
