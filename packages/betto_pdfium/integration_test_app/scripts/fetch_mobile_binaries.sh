#!/usr/bin/env bash

# Copyright 2026 The Authors. See the AUTHORS file for details.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# fetch_mobile_binaries.sh
#
# Downloads Android shared libraries from bblanchon/pdfium-binaries tarballs,
# using the URLs and SHA-256 checksums in version_pdfium.json.
#
# iOS is NOT handled here. The betto_pdfium_ios Package.swift uses a URL-based
# SPM binaryTarget, so Xcode/SPM downloads and caches the xcframework
# automatically during `flutter pub get` / `flutter test`.
#
# Installs artifacts to:
#   android/app/src/main/jniLibs/arm64-v8a/libpdfium.so
#   android/app/src/main/jniLibs/x86_64/libpdfium.so
#
# ## Download protocol
#
# bblanchon publishes `.tgz` tarballs, not bare `.so` files. This script:
#   1. Downloads the tarball to a temp directory.
#   2. Verifies SHA-256 of the tarball BEFORE extraction.
#   3. Extracts `lib/libpdfium.so` from the verified tarball.
#   4. Installs to the jniLibs destination.
#
# SHA-256 in version_pdfium.json is over the .tgz, not the extracted .so.
#
# Usage (from the integration_test_app/ directory or via make):
#   scripts/fetch_mobile_binaries.sh             # fetch Android libraries
#   scripts/fetch_mobile_binaries.sh --android-only  # same (explicit)
#
# Prerequisites:
#   - curl
#   - tar
#   - shasum (macOS) or sha256sum (Linux) — auto-detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST="$APP_DIR/../version_pdfium.json"

# Parse flags (--android-only accepted for backward compatibility; --ios-only
# is a no-op since iOS is handled by SPM via the URL binaryTarget in
# betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift).
IOS_ONLY=0
ANDROID_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --ios-only)     IOS_ONLY=1 ;;
        --android-only) ANDROID_ONLY=1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# die <message> — print to stderr and exit non-zero.
die() { echo "fetch_mobile_binaries: ERROR: $1" >&2; exit 1; }

# require <command> — assert a command is on PATH.
require() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found. Install it and retry."
}

# platform_field <file> <platform> <field> — extract nested platform field.
# Reads "platforms" → "<platform>" → "<field>" from version_pdfium.json.
# Uses awk to find the platform block, then extract the field within it.
platform_field() {
    local file="$1"
    local platform="$2"
    local field="$3"
    awk "/\"$platform\"/{found=1} found && /\"$field\"/{print; found=0}" "$file" \
        | head -1 \
        | sed 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# sha256_file <file> — print the SHA-256 hex digest of <file>.
sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        die "Neither 'shasum' nor 'sha256sum' found. Cannot verify checksums."
    fi
}

# download_tgz_and_extract <url> <expected_sha256> <lib_path_in_tgz> <dest_file>
#
# Downloads the .tgz at <url>, verifies SHA-256 of the tarball (not the
# extracted file), extracts <lib_path_in_tgz> from the tarball, and installs
# it at <dest_file>.
download_tgz_and_extract() {
    local url="$1"
    local expected="$2"
    local lib_path="$3"
    local dest="$4"

    local tgz_name
    tgz_name=$(basename "$url")

    echo "  Downloading $tgz_name ..."
    curl --silent --show-error --location --fail --output "$WORK/$tgz_name" "$url"

    # Verify checksum of the tarball BEFORE extraction.
    local actual
    actual=$(sha256_file "$WORK/$tgz_name")
    if [ "$actual" != "$expected" ]; then
        rm -f "$WORK/$tgz_name"
        die "SHA-256 mismatch for $tgz_name:
  expected: $expected
  actual:   $actual
  The downloaded file has been removed. Re-run to retry."
    fi
    echo "  Verified SHA-256: $actual"

    # Extract the shared library from the verified tarball.
    local strip_components
    strip_components=$(echo "$lib_path" | tr -cd '/' | wc -c | tr -d '[:space:]')
    local lib_name
    lib_name=$(basename "$lib_path")

    mkdir -p "$WORK/extract_$$"
    tar -xzf "$WORK/$tgz_name" -C "$WORK/extract_$$" \
        --strip-components="$strip_components" "$lib_path"

    # Install extracted library to the destination.
    mkdir -p "$(dirname "$dest")"
    mv "$WORK/extract_$$/$lib_name" "$dest"
    rm -rf "$WORK/extract_$$"

    echo "  Installed: $dest"
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

require curl
require tar

[ -f "$MANIFEST" ] || die "version_pdfium.json not found at $MANIFEST"

# ---------------------------------------------------------------------------
# Read manifest
# ---------------------------------------------------------------------------

ANDROID_ARM64_URL=$(platform_field "$MANIFEST" "android-arm64" "url")
ANDROID_ARM64_SHA=$(platform_field "$MANIFEST" "android-arm64" "sha256")
ANDROID_ARM64_LIB=$(platform_field "$MANIFEST" "android-arm64" "lib_path")
ANDROID_X64_URL=$(platform_field "$MANIFEST" "android-x64" "url")
ANDROID_X64_SHA=$(platform_field "$MANIFEST" "android-x64" "sha256")
ANDROID_X64_LIB=$(platform_field "$MANIFEST" "android-x64" "lib_path")

[ -n "$ANDROID_ARM64_URL" ] || die "android-arm64 url not found in $MANIFEST"
[ -n "$ANDROID_ARM64_SHA" ] || die "android-arm64 sha256 not found in $MANIFEST"
[ -n "$ANDROID_ARM64_LIB" ] || die "android-arm64 lib_path not found in $MANIFEST"
[ -n "$ANDROID_X64_URL" ]   || die "android-x64 url not found in $MANIFEST"
[ -n "$ANDROID_X64_SHA" ]   || die "android-x64 sha256 not found in $MANIFEST"
[ -n "$ANDROID_X64_LIB" ]   || die "android-x64 lib_path not found in $MANIFEST"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# iOS note
# ---------------------------------------------------------------------------

if [ "$IOS_ONLY" -eq 1 ]; then
    echo ""
    echo "fetch_mobile_binaries: iOS is handled by SPM — no download needed."
    echo "  The betto_pdfium_ios Package.swift uses a URL binaryTarget;"
    echo "  Xcode/SPM downloads and caches the xcframework automatically"
    echo "  during 'flutter pub get' or 'flutter test'."
    echo ""
    echo "fetch_mobile_binaries: done."
    exit 0
fi

# ---------------------------------------------------------------------------
# Android shared libraries
# ---------------------------------------------------------------------------

if [ "$IOS_ONLY" -eq 0 ]; then
    echo ""
    echo "fetch_mobile_binaries: fetching Android shared libraries from bblanchon ..."

    ARM64_DIR="$APP_DIR/android/app/src/main/jniLibs/arm64-v8a"
    X64_DIR="$APP_DIR/android/app/src/main/jniLibs/x86_64"

    download_tgz_and_extract "$ANDROID_ARM64_URL" "$ANDROID_ARM64_SHA" "$ANDROID_ARM64_LIB" \
        "$ARM64_DIR/libpdfium.so"
    echo "  Android arm64 library installed at android/app/src/main/jniLibs/arm64-v8a/libpdfium.so"

    download_tgz_and_extract "$ANDROID_X64_URL" "$ANDROID_X64_SHA" "$ANDROID_X64_LIB" \
        "$X64_DIR/libpdfium.so"
    echo "  Android x86_64 library installed at android/app/src/main/jniLibs/x86_64/libpdfium.so"
fi

echo ""
echo "fetch_mobile_binaries: done."
echo ""
echo "iOS next steps (SPM handles the xcframework automatically):"
echo "  1. Enable Flutter SPM support (one-time global):"
echo "       flutter config --enable-swift-package-manager"
echo "  2. Run 'flutter pub get' from integration_test_app/ — Flutter"
echo "       discovers betto_pdfium_ios and SPM downloads the xcframework."
echo "  3. Run 'make ios_test'."
