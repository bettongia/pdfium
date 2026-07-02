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
# integration_test_app/web/assets/pdfium/). Also copies the package's own
# checked-in Worker bundle (lib/assets/pdfium_worker.js) into the same
# directory — see the Web Worker offload plan for why this file exists.
#
# Users of betto_pdfium in a Flutter web app must:
#   1. Run this script (or `make fetch_wasm_assets`) once per PDFium version
#      bump, or in CI before a web build.
#   2. Copy the extracted files to their app's web/assets/pdfium/ directory.
#   3. The _document_web.dart backend spawns a dedicated Worker from the
#      well-known relative URL assets/pdfium/pdfium_worker.js, which in turn
#      loads assets/pdfium/pdfium.js.
#
# The tarball contains lib/pdfium.wasm and lib/pdfium.js. Both files, plus
# pdfium_worker.js, must be co-located: pdfium.js loads pdfium.wasm from the
# same directory via its internal locateFile() helper, and pdfium_worker.js
# loads pdfium.js from the same directory via importScripts().
#
# Usage (from packages/betto_pdfium/):
#   scripts/fetch_wasm_assets.sh
#   # or via Make from the repo root:
#   make fetch_wasm_assets
#
# This script assumes its current working directory is the betto_pdfium
# package root (the Makefile target `cd`s there first) — like the existing
# BBLANCHON_BUILD / version_pdfium.json reads below, the pdfium_worker.js
# copy is resolved as lib/assets/pdfium_worker.js relative to that same CWD,
# i.e. relative to the package's own tree, not a source-checkout-specific
# absolute path. This holds whether the package is a local monorepo checkout
# or installed as a pub dependency, as long as the caller cds into the
# package root first (as `make fetch_wasm_assets` does).
#
# Environment variables:
#   WASM_OUTPUT_DIR  Output directory for extracted WASM assets.
#                    Default: integration_test_app/web/assets/pdfium/
#
# The bblanchon tarball download/extraction is idempotent: if the target
# directory already contains the correct build-number marker file, that part
# is skipped. The pdfium_worker.js copy is intentionally NOT gated by that
# same marker — it is betto_pdfium's own checked-in artifact, versioned
# independently of the bblanchon build number, so it must be re-copied on
# every run in case it has changed locally (e.g. after `make
# build_wasm_worker` during development) even when the bblanchon build itself
# is unchanged.

set -euo pipefail

BUILD=$(tr -d '[:space:]' < BBLANCHON_BUILD)
OUTPUT_DIR="${WASM_OUTPUT_DIR:-integration_test_app/web/assets/pdfium}"
MARKER="$OUTPUT_DIR/.bblanchon_build"

# Always (re-)copy the package's own checked-in Worker bundle alongside
# pdfium.js/.wasm, regardless of whether the tarball step below is skipped.
# This is not part of the bblanchon tarball — it is compiled and committed by
# betto_pdfium's own release process (see `make build_wasm_worker`).
if [ ! -f "lib/assets/pdfium_worker.js" ]; then
    echo "fetch_wasm_assets: lib/assets/pdfium_worker.js not found relative to \$PWD ($PWD)."
    echo "  This script must be run with the betto_pdfium package root as the"
    echo "  current working directory (e.g. via 'make fetch_wasm_assets')."
    exit 1
fi
mkdir -p "$OUTPUT_DIR"
cp "lib/assets/pdfium_worker.js" "$OUTPUT_DIR/pdfium_worker.js"

# Idempotent: skip the tarball download/extraction if already at the correct
# version (the pdfium_worker.js copy above has already happened either way).
if [ -f "$MARKER" ]; then
    INSTALLED=$(tr -d '[:space:]' < "$MARKER")
    if [ "$INSTALLED" = "$BUILD" ]; then
        echo "fetch_wasm_assets: already at bblanchon chromium/$BUILD — pdfium.wasm/.js unchanged; pdfium_worker.js refreshed."
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

# (pdfium_worker.js was already (re-)copied above, unconditionally.)

# Write the build-number marker for idempotency.
echo "$BUILD" > "$MARKER"

echo ""
echo "fetch_wasm_assets: done."
echo "  bblanchon build: chromium/$BUILD"
echo "  output dir:      $OUTPUT_DIR"
echo "  files:"
echo "    $OUTPUT_DIR/pdfium.wasm"
echo "    $OUTPUT_DIR/pdfium.js"
echo "    $OUTPUT_DIR/pdfium_worker.js"
echo ""
echo "Next steps:"
echo "  Copy $OUTPUT_DIR/ to your Flutter web app's web/assets/pdfium/ directory."
echo "  The betto_pdfium web backend spawns a Worker from"
echo "  assets/pdfium/pdfium_worker.js, which loads assets/pdfium/pdfium.js."
