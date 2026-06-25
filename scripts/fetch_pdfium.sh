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

set -e
set -o pipefail
set -u

REPO="bettongia/pdfium"
PDFIUM_BIN="third_party/pdfium_bin"
SHA=$(tr -d '[:space:]' < PDFIUM_VERSION)
TAG="pdfium-$SHA"

# Idempotent: skip if the correct version is already installed (binary + headers).
if [ -f "$PDFIUM_BIN/VERSION" ] && [ -d "third_party/pdfium/public" ]; then
    INSTALLED=$(tr -d '[:space:]' < "$PDFIUM_BIN/VERSION")
    if [ "$INSTALLED" = "$SHA" ]; then
        echo "fetch_pdfium: already at $SHA — nothing to do."
        exit 0
    fi
fi

# Platform detection.
OS=$(uname -s)
ARCH=$(uname -m)
case "$OS" in
    Darwin)
        ARTIFACT="libpdfium-macos-arm64.dylib"
        INSTALL_DIR="$PDFIUM_BIN/macos_arm64"
        INSTALL_NAME="libpdfium.dylib"
        ;;
    Linux)
        case "$ARCH" in
            x86_64)  ARTIFACT="libpdfium-linux-x86_64.so"; INSTALL_DIR="$PDFIUM_BIN/linux_x64" ;;
            aarch64) ARTIFACT="libpdfium-linux-arm64.so";  INSTALL_DIR="$PDFIUM_BIN/linux_arm64" ;;
            *) echo "fetch_pdfium: unsupported architecture: $ARCH"; exit 1 ;;
        esac
        INSTALL_NAME="libpdfium.so"
        ;;
    *) echo "fetch_pdfium: unsupported OS: $OS"; exit 1 ;;
esac

# Require gh CLI.
if ! command -v gh >/dev/null 2>&1; then
    echo "fetch_pdfium: 'gh' (GitHub CLI) is required. Install from https://cli.github.com/"
    exit 1
fi

# Verify the release exists before downloading.
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "fetch_pdfium: GitHub Release '$TAG' not found in $REPO."
    echo "  Push a change to PDFIUM_VERSION on main to trigger a CI build,"
    echo "  or wait for an in-progress build to finish."
    exit 1
fi

# Download binary + headers + checksums to a temp directory.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "fetch_pdfium: downloading $ARTIFACT and pdfium-headers.zip from $TAG ..."
gh release download "$TAG" \
    --repo "$REPO" \
    --pattern "$ARTIFACT" \
    --pattern "pdfium-headers.zip" \
    --pattern "checksums.sha256" \
    --dir "$WORK"

# Checksum helper (works on both macOS shasum and Linux sha256sum).
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Verify binary checksum.
echo "fetch_pdfium: verifying $ARTIFACT checksum ..."
EXPECTED=$(grep "$ARTIFACT" "$WORK/checksums.sha256" | awk '{print $1}')
ACTUAL=$(_sha256 "$WORK/$ARTIFACT")
if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "fetch_pdfium: checksum mismatch for $ARTIFACT"
    echo "  expected: $EXPECTED"
    echo "  actual:   $ACTUAL"
    exit 1
fi

# Verify headers checksum.
echo "fetch_pdfium: verifying pdfium-headers.zip checksum ..."
EXPECTED_H=$(grep "pdfium-headers.zip" "$WORK/checksums.sha256" | awk '{print $1}')
ACTUAL_H=$(_sha256 "$WORK/pdfium-headers.zip")
if [ "$EXPECTED_H" != "$ACTUAL_H" ]; then
    echo "fetch_pdfium: checksum mismatch for pdfium-headers.zip"
    echo "  expected: $EXPECTED_H"
    echo "  actual:   $ACTUAL_H"
    exit 1
fi

# Install binary.
mkdir -p "$INSTALL_DIR"
cp "$WORK/$ARTIFACT" "$INSTALL_DIR/$INSTALL_NAME"

# Ad-hoc sign on macOS so dlopen() succeeds without quarantine errors.
if [ "$OS" = "Darwin" ]; then
    codesign --force --sign - "$INSTALL_DIR/$INSTALL_NAME"
fi

# Install public headers (extracted from pdfium-headers.zip → third_party/pdfium/public/).
echo "fetch_pdfium: extracting public headers to third_party/pdfium/ ..."
rm -rf third_party/pdfium
mkdir -p third_party/pdfium
unzip -q "$WORK/pdfium-headers.zip" -d third_party/pdfium

echo "$SHA" > "$PDFIUM_BIN/VERSION"

echo "fetch_pdfium: installed PDFium $SHA"
echo "  binary:  $INSTALL_DIR/$INSTALL_NAME"
echo "  headers: third_party/pdfium/public/"
