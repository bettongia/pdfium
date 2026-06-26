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

# update_pdfium_manifest.sh
#
# Rewrites version_pdfium.json and lib/src/pdfium_version.dart to match the
# SHA in PDFIUM_VERSION, pulling SHA-256 digests from the checksums.sha256
# file published in the corresponding GitHub Release.
#
# Run this AFTER the CI pipeline has published the release for PDFIUM_VERSION.
# The SHA-256s are not known until the binaries have been built and uploaded.
#
# Usage (from the repo root):
#   make update_pdfium_manifest
#   # or directly:
#   scripts/update_pdfium_manifest.sh
#
# After running, commit the changes and any regenerated FFI bindings:
#   make fetch_pdfium          # install binary + headers locally
#   make ffi_bindings          # if the PDFium public API changed
#   git add version_pdfium.json lib/src/pdfium_version.dart lib/src/generated/
#   git commit -m "Bump PDFium to <sha>"

set -euo pipefail

REPO="bettongia/pdfium"
SHA=$(tr -d '[:space:]' < PDFIUM_VERSION)
TAG="pdfium-$SHA"
BASE_URL="https://github.com/$REPO/releases/download/$TAG"

# Require gh CLI.
if ! command -v gh >/dev/null 2>&1; then
    echo "update_pdfium_manifest: 'gh' (GitHub CLI) is required. Install from https://cli.github.com/"
    exit 1
fi

# Verify the release exists before attempting to download anything.
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "update_pdfium_manifest: Release '$TAG' not found in $REPO."
    echo "  Push PDFIUM_VERSION to main, wait for CI to publish the release, then re-run."
    exit 1
fi

# Download checksums.sha256 to a temp directory.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "update_pdfium_manifest: fetching checksums for $TAG ..."
gh release download "$TAG" \
    --repo "$REPO" \
    --pattern "checksums.sha256" \
    --dir "$WORK"

# Extract the SHA-256 for a named release artifact.
# Matches the filename anchored to the end of the line so that e.g.
# libpdfium-linux-arm64.so does not accidentally match a longer name.
_sha_for() {
    local result
    result=$(grep "[[:space:]]$1$" "$WORK/checksums.sha256" | awk '{print $1}')
    if [ -z "$result" ]; then
        echo "update_pdfium_manifest: '$1' not found in checksums.sha256" >&2
        exit 1
    fi
    echo "$result"
}

MACOS_ARM64_SHA=$(_sha_for "libpdfium-macos-arm64.dylib")
LINUX_ARM64_SHA=$(_sha_for "libpdfium-linux-arm64.so")
LINUX_X64_SHA=$(_sha_for "libpdfium-linux-x86_64.so")
IOS_ARM64_SHA=$(_sha_for "libpdfium-ios-arm64.xcframework.zip")
ANDROID_ARM64_SHA=$(_sha_for "libpdfium-android-arm64.so")
ANDROID_X64_SHA=$(_sha_for "libpdfium-android-x86_64.so")

# Write version_pdfium.json.
# The manifest contains both hook-consumed entries (macos-arm64, linux-arm64,
# linux-x64) and mobile-only entries consumed exclusively by
# integration_test_app/scripts/fetch_mobile_binaries.sh:
#   - ios-arm64:     static xcframework for the iOS integration test app
#   - android-arm64: shared library for the Android integration test app
#   - android-x64:   shared library for the Android integration test app (x86_64)
#
# The native-assets hook (hook/build.dart) ignores ios-arm64, android-arm64,
# and android-x64 entries — it only reads the three hook-supported platforms.
cat > version_pdfium.json <<EOF
{
  "pdfium_sha": "$SHA",
  "platforms": {
    "macos-arm64": {
      "url": "$BASE_URL/libpdfium-macos-arm64.dylib",
      "sha256": "$MACOS_ARM64_SHA"
    },
    "linux-arm64": {
      "url": "$BASE_URL/libpdfium-linux-arm64.so",
      "sha256": "$LINUX_ARM64_SHA"
    },
    "linux-x64": {
      "url": "$BASE_URL/libpdfium-linux-x86_64.so",
      "sha256": "$LINUX_X64_SHA"
    },
    "ios-arm64": {
      "url": "$BASE_URL/libpdfium-ios-arm64.xcframework.zip",
      "sha256": "$IOS_ARM64_SHA"
    },
    "android-arm64": {
      "url": "$BASE_URL/libpdfium-android-arm64.so",
      "sha256": "$ANDROID_ARM64_SHA"
    },
    "android-x64": {
      "url": "$BASE_URL/libpdfium-android-x86_64.so",
      "sha256": "$ANDROID_X64_SHA"
    }
  }
}
EOF

# Rewrite lib/src/pdfium_version.dart with the updated SHA.
# Written wholesale (the file is a single constant) to avoid cross-platform
# sed differences between macOS and Linux.
cat > lib/src/pdfium_version.dart <<EOF
// Copyright 2026 The Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// PDFium version constant used by the native-assets hook and runtime loader.
//
// Update this alongside PDFIUM_VERSION and version_pdfium.json whenever the
// upstream PDFium commit SHA is bumped.

/// The PDFium commit SHA that this package is built against.
///
/// Used at runtime to locate the hook's binary cache directory
/// (\`.dart_tool/betto_pdfium/{pdfiumSha}/\`) as a fallback when the build
/// system has not staged the library to the standard adjacent-to-executable
/// location (e.g. during \`dart run\` in JIT mode).
const pdfiumSha = '$SHA';
EOF

echo "update_pdfium_manifest: done."
echo "  SHA:                    $SHA"
echo "  macos-arm64 sha256:     $MACOS_ARM64_SHA"
echo "  linux-arm64 sha256:     $LINUX_ARM64_SHA"
echo "  linux-x64   sha256:     $LINUX_X64_SHA"
echo "  ios-arm64   sha256:     $IOS_ARM64_SHA"
echo "  android-arm64 sha256:   $ANDROID_ARM64_SHA"
echo "  android-x64   sha256:   $ANDROID_X64_SHA"
echo ""
echo "Next steps:"
echo "  make fetch_pdfium          # install binary + headers locally"
echo "  make ffi_bindings          # if the PDFium public API changed"
echo "  git add version_pdfium.json lib/src/pdfium_version.dart lib/src/generated/"
echo "  git commit -m 'Bump PDFium to $SHA'"
