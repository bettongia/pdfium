#!/usr/bin/env bash

# Copyright 2026 The Authors.
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
# Downloads the iOS xcframework and Android shared libraries from the GitHub
# Release identified in ../version_pdfium.json (the same manifest consumed by
# the native-assets hook).
#
# Installs artifacts to:
#   ios/Frameworks/pdfium.xcframework/   (unzipped from .xcframework.zip)
#   android/src/main/jniLibs/arm64-v8a/libpdfium.so
#   android/src/main/jniLibs/x86_64/libpdfium.so
#
# Usage (from the integration_test_app/ directory or via make):
#   scripts/fetch_mobile_binaries.sh           # fetch all platforms
#   scripts/fetch_mobile_binaries.sh --ios-only  # fetch iOS only
#
# Prerequisites:
#   - curl
#   - unzip
#   - shasum (macOS) or sha256sum (Linux) — auto-detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST="$APP_DIR/../version_pdfium.json"

# Parse --ios-only flag.
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

# json_field <file> <key> — extract a string value from a simple JSON file
# using only grep/sed (no jq dependency).
# Only handles flat string values like "key": "value".
json_field() {
    local file="$1"
    local key="$2"
    grep "\"$key\"" "$file" | head -1 | sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# platform_field <file> <platform> <field> — extract nested platform field.
# Reads "platforms" → "<platform>" → "<field>" from version_pdfium.json.
# Uses a two-pass grep: find the platform block, then find the field within it.
platform_field() {
    local file="$1"
    local platform="$2"
    local field="$3"
    # Extract the block starting from the platform key. Stop at the next key
    # at the same level (another quoted string at column 4).
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

# download_and_verify <url> <expected_sha256> <dest_file>
# Downloads <url> to <dest_file> and verifies the SHA-256 digest.
download_and_verify() {
    local url="$1"
    local expected="$2"
    local dest="$3"

    echo "  Downloading $(basename "$dest") ..."
    curl --silent --show-error --location --fail --output "$dest" "$url"

    local actual
    actual=$(sha256_file "$dest")
    if [ "$actual" != "$expected" ]; then
        rm -f "$dest"
        die "SHA-256 mismatch for $(basename "$dest"):
  expected: $expected
  actual:   $actual
  The downloaded file has been removed. Re-run to retry."
    fi
    echo "  Verified SHA-256: $actual"
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

require curl
require unzip

[ -f "$MANIFEST" ] || die "version_pdfium.json not found at $MANIFEST"

# ---------------------------------------------------------------------------
# Read manifest
# ---------------------------------------------------------------------------

IOS_URL=$(platform_field "$MANIFEST" "ios-arm64" "url")
IOS_SHA=$(platform_field "$MANIFEST" "ios-arm64" "sha256")
ANDROID_ARM64_URL=$(platform_field "$MANIFEST" "android-arm64" "url")
ANDROID_ARM64_SHA=$(platform_field "$MANIFEST" "android-arm64" "sha256")
ANDROID_X64_URL=$(platform_field "$MANIFEST" "android-x64" "url")
ANDROID_X64_SHA=$(platform_field "$MANIFEST" "android-x64" "sha256")

[ -n "$IOS_URL" ]          || die "ios-arm64 url not found in $MANIFEST"
[ -n "$IOS_SHA" ]          || die "ios-arm64 sha256 not found in $MANIFEST"
[ -n "$ANDROID_ARM64_URL" ] || die "android-arm64 url not found in $MANIFEST"
[ -n "$ANDROID_ARM64_SHA" ] || die "android-arm64 sha256 not found in $MANIFEST"
[ -n "$ANDROID_X64_URL" ]   || die "android-x64 url not found in $MANIFEST"
[ -n "$ANDROID_X64_SHA" ]   || die "android-x64 sha256 not found in $MANIFEST"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# iOS xcframework
# ---------------------------------------------------------------------------

if [ "$ANDROID_ONLY" -eq 0 ]; then
    echo ""
    echo "fetch_mobile_binaries: fetching iOS xcframework ..."

    IOS_DEST_DIR="$APP_DIR/ios/Frameworks"
    mkdir -p "$IOS_DEST_DIR"

    XCFW_ZIP="$WORK/libpdfium-ios-arm64.xcframework.zip"
    download_and_verify "$IOS_URL" "$IOS_SHA" "$XCFW_ZIP"

    # Remove any existing xcframework before extracting to avoid stale files.
    rm -rf "$IOS_DEST_DIR/pdfium.xcframework"
    echo "  Extracting xcframework to $IOS_DEST_DIR ..."
    unzip -q "$XCFW_ZIP" -d "$WORK/xcfw_extract"

    # The zip should contain a top-level pdfium.xcframework directory.
    # Move it to ios/Frameworks/.
    if [ -d "$WORK/xcfw_extract/pdfium.xcframework" ]; then
        mv "$WORK/xcfw_extract/pdfium.xcframework" "$IOS_DEST_DIR/pdfium.xcframework"
    else
        # Fallback: find the xcframework inside the extracted tree.
        XCFW_PATH=$(find "$WORK/xcfw_extract" -name "*.xcframework" -type d | head -1)
        [ -n "$XCFW_PATH" ] || die "No .xcframework directory found inside $XCFW_ZIP"
        mv "$XCFW_PATH" "$IOS_DEST_DIR/pdfium.xcframework"
    fi

    echo "  iOS xcframework installed at ios/Frameworks/pdfium.xcframework"
fi

# ---------------------------------------------------------------------------
# Android shared libraries
# ---------------------------------------------------------------------------

if [ "$IOS_ONLY" -eq 0 ]; then
    echo ""
    echo "fetch_mobile_binaries: fetching Android shared libraries ..."

    ARM64_DIR="$APP_DIR/android/src/main/jniLibs/arm64-v8a"
    X64_DIR="$APP_DIR/android/src/main/jniLibs/x86_64"
    mkdir -p "$ARM64_DIR" "$X64_DIR"

    download_and_verify "$ANDROID_ARM64_URL" "$ANDROID_ARM64_SHA" \
        "$ARM64_DIR/libpdfium.so"
    echo "  Android arm64 library installed at android/src/main/jniLibs/arm64-v8a/libpdfium.so"

    download_and_verify "$ANDROID_X64_URL" "$ANDROID_X64_SHA" \
        "$X64_DIR/libpdfium.so"
    echo "  Android x86_64 library installed at android/src/main/jniLibs/x86_64/libpdfium.so"
fi

echo ""
echo "fetch_mobile_binaries: done."
if [ "$ANDROID_ONLY" -eq 0 ]; then
    echo ""
    echo "iOS next steps:"
    echo "  1. Enable Flutter SPM support (one-time global):"
    echo "       flutter config --enable-swift-package-manager"
    echo "  2. Open ios/Runner.xcworkspace in Xcode."
    echo "  3. File → Add Package Dependencies → Add Local →"
    echo "       select ios/LocalPackages/pdfium/"
    echo "  4. Commit the resulting project.pbxproj change."
fi
