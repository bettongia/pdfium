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

# fetch_pdfium.sh
#
# Downloads the PDFium binary and public headers for the current platform
# from bblanchon/pdfium-binaries into third_party/pdfium_bin/ and
# third_party/pdfium/public/.
#
# Uses the bblanchon build number from BBLANCHON_BUILD and the per-platform
# tarball URLs + SHA-256 checksums from version_pdfium.json.
#
# Usage (from packages/betto_pdfium/):
#   scripts/fetch_pdfium.sh
#   # or via Make from the repo root:
#   make fetch_pdfium

set -e
set -o pipefail
set -u

PDFIUM_BIN="third_party/pdfium_bin"
BUILD=$(tr -d '[:space:]' < BBLANCHON_BUILD)
BBLANCHON_BASE="https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F${BUILD}"

# Idempotent: skip if the correct version is already installed (binary + headers).
if [ -f "$PDFIUM_BIN/VERSION" ] && [ -d "third_party/pdfium/public" ]; then
    INSTALLED=$(tr -d '[:space:]' < "$PDFIUM_BIN/VERSION")
    if [ "$INSTALLED" = "$BUILD" ]; then
        echo "fetch_pdfium: already at bblanchon chromium/$BUILD — nothing to do."
        exit 0
    fi
fi

# Platform detection.
OS=$(uname -s)
ARCH=$(uname -m)
case "$OS" in
    Darwin)
        ARTIFACT="pdfium-mac-arm64.tgz"
        LIB_IN_TGZ="lib/libpdfium.dylib"
        INSTALL_DIR="$PDFIUM_BIN/macos_arm64"
        INSTALL_NAME="libpdfium.dylib"
        ;;
    Linux)
        case "$ARCH" in
            x86_64)  ARTIFACT="pdfium-linux-x64.tgz";  INSTALL_DIR="$PDFIUM_BIN/linux_x64" ;;
            aarch64) ARTIFACT="pdfium-linux-arm64.tgz"; INSTALL_DIR="$PDFIUM_BIN/linux_arm64" ;;
            *) echo "fetch_pdfium: unsupported architecture: $ARCH"; exit 1 ;;
        esac
        LIB_IN_TGZ="lib/libpdfium.so"
        INSTALL_NAME="libpdfium.so"
        ;;
    *) echo "fetch_pdfium: unsupported OS: $OS"; exit 1 ;;
esac

# Checksum helper (works on both macOS shasum and Linux sha256sum).
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Derive platform key for version_pdfium.json lookup.
case "$OS" in
    Darwin)  PLATFORM_KEY="macos-arm64" ;;
    Linux)
        case "$ARCH" in
            x86_64)  PLATFORM_KEY="linux-x64" ;;
            aarch64) PLATFORM_KEY="linux-arm64" ;;
        esac
        ;;
esac

# Read expected checksum from version_pdfium.json.
EXPECTED_SHA=$(python3 -c "
import json
with open('version_pdfium.json') as f:
    m = json.load(f)
print(m['platforms']['${PLATFORM_KEY}']['sha256'])
")

# Download tarball to a temp directory.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "fetch_pdfium: downloading $ARTIFACT from bblanchon chromium/$BUILD ..."
curl -fsSL -o "$WORK/$ARTIFACT" "$BBLANCHON_BASE/$ARTIFACT"

# Verify checksum of the tarball BEFORE extraction.
echo "fetch_pdfium: verifying $ARTIFACT checksum ..."
ACTUAL=$(_sha256 "$WORK/$ARTIFACT")
if [ "$EXPECTED_SHA" != "$ACTUAL" ]; then
    echo "fetch_pdfium: checksum mismatch for $ARTIFACT"
    echo "  expected: $EXPECTED_SHA"
    echo "  actual:   $ACTUAL"
    exit 1
fi

# Extract shared library from the verified tarball.
echo "fetch_pdfium: extracting $LIB_IN_TGZ ..."
STRIP_COMPONENTS=$(echo "$LIB_IN_TGZ" | tr -cd '/' | wc -c | tr -d '[:space:]')
mkdir -p "$WORK/extract"
tar -xzf "$WORK/$ARTIFACT" -C "$WORK/extract" --strip-components="$STRIP_COMPONENTS" "$LIB_IN_TGZ"

# Install binary.
mkdir -p "$INSTALL_DIR"
cp "$WORK/extract/$INSTALL_NAME" "$INSTALL_DIR/$INSTALL_NAME"

# Ad-hoc sign on macOS so dlopen() succeeds without quarantine errors.
if [ "$OS" = "Darwin" ]; then
    codesign --force --sign - "$INSTALL_DIR/$INSTALL_NAME"
fi

# Install public headers by extracting the include/ directory from the tarball.
# bblanchon tarballs contain include/*.h alongside the library.
echo "fetch_pdfium: extracting public headers to third_party/pdfium/public/ ..."
rm -rf third_party/pdfium
mkdir -p third_party/pdfium/public

# Extract include/ directory (bblanchon layout: include/<header>.h at depth 1).
mkdir -p "$WORK/headers"
tar -xzf "$WORK/$ARTIFACT" -C "$WORK/headers" --strip-components=1 \
    $(tar -tzf "$WORK/$ARTIFACT" | grep '^include/' | head -1 | cut -d/ -f1 || echo "include") \
    2>/dev/null || tar -xzf "$WORK/$ARTIFACT" -C "$WORK/headers" 2>/dev/null

# Copy only the include/ contents into third_party/pdfium/public/.
if [ -d "$WORK/headers/include" ]; then
    cp -r "$WORK/headers/include/." "third_party/pdfium/public/"
elif [ -f "$WORK/headers/fpdf_view.h" ]; then
    # Stripped one level: headers are directly in $WORK/headers.
    cp "$WORK/headers/"*.h "third_party/pdfium/public/" 2>/dev/null || true
fi

echo "$BUILD" > "$PDFIUM_BIN/VERSION"

echo "fetch_pdfium: installed PDFium bblanchon chromium/$BUILD"
echo "  binary:  $INSTALL_DIR/$INSTALL_NAME"
echo "  headers: third_party/pdfium/public/"
