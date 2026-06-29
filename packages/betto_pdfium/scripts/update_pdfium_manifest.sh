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
# bblanchon build number in BBLANCHON_BUILD, computing SHA-256 digests from
# the bblanchon/pdfium-binaries GitHub Release tarballs.
#
# bblanchon does not publish separate .sha256 sidecar files — we download each
# tarball and compute the checksum ourselves.
#
# For iOS, this script also repacks the xcframework from the two bblanchon
# iOS tarballs (device + simulator), uploads it to the bettongia/pdfium
# GitHub Release, and updates Package.swift with the new URL and checksum.
# Run `make repack_ios_xcframework` first to verify the repack succeeds before
# calling this script.
#
# Usage (from packages/betto_pdfium/):
#   make update_pdfium_manifest
#   # or directly:
#   scripts/update_pdfium_manifest.sh
#
# After running, commit the changes:
#   make fetch_pdfium          # install binary + headers locally
#   make ffi_bindings          # if the PDFium public API changed
#   git add version_pdfium.json lib/src/pdfium_version.dart
#   git add ../betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift
#   git add lib/src/generated/
#   git commit -m "Bump PDFium to bblanchon chromium/<BUILD>"

set -euo pipefail

BUILD=$(tr -d '[:space:]' < BBLANCHON_BUILD)
BBLANCHON_BASE="https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F${BUILD}"
BETTONGIA_REPO="bettongia/pdfium"
BETTONGIA_TAG="bblanchon-chromium-${BUILD}"
BETTONGIA_RELEASE_URL="https://github.com/${BETTONGIA_REPO}/releases/download/${BETTONGIA_TAG}"

echo "update_pdfium_manifest: computing SHA-256s for bblanchon chromium/$BUILD ..."

# Checksum helper.
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Download a bblanchon tarball and return its SHA-256.
_fetch_sha() {
    local artifact="$1"
    local dest="$2"
    echo "  downloading $artifact ..." >&2
    curl -fsSL -o "$dest" "$BBLANCHON_BASE/$artifact"
    _sha256 "$dest"
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

MACOS_ARM64_SHA=$(_fetch_sha "pdfium-mac-arm64.tgz" "$WORK/mac-arm64.tgz")
LINUX_X64_SHA=$(_fetch_sha "pdfium-linux-x64.tgz" "$WORK/linux-x64.tgz")
LINUX_ARM64_SHA=$(_fetch_sha "pdfium-linux-arm64.tgz" "$WORK/linux-arm64.tgz")
ANDROID_ARM64_SHA=$(_fetch_sha "pdfium-android-arm64.tgz" "$WORK/android-arm64.tgz")
ANDROID_X64_SHA=$(_fetch_sha "pdfium-android-x64.tgz" "$WORK/android-x64.tgz")
WINDOWS_X64_SHA=$(_fetch_sha "pdfium-win-x64.tgz" "$WORK/win-x64.tgz")
WASM_SHA=$(_fetch_sha "pdfium-wasm.tgz" "$WORK/wasm.tgz")

# Compute iOS xcframework checksum from the bettongia/pdfium release.
# Run `make repack_ios_xcframework` first to upload the xcframework.
if command -v gh >/dev/null 2>&1 && gh release view "$BETTONGIA_TAG" --repo "$BETTONGIA_REPO" >/dev/null 2>&1; then
    echo "  downloading pdfium.xcframework.zip from $BETTONGIA_TAG ..." >&2
    gh release download "$BETTONGIA_TAG" \
        --repo "$BETTONGIA_REPO" \
        --pattern "pdfium.xcframework.zip" \
        --dir "$WORK"
    IOS_XCFRAMEWORK_SHA=$(_sha256 "$WORK/pdfium.xcframework.zip")
    IOS_XCFRAMEWORK_URL="$BETTONGIA_RELEASE_URL/pdfium.xcframework.zip"
else
    echo "  warning: $BETTONGIA_TAG not found — run 'make repack_ios_xcframework' first." >&2
    echo "  iOS Package.swift will not be updated." >&2
    IOS_XCFRAMEWORK_SHA=""
    IOS_XCFRAMEWORK_URL=""
fi

# Write version_pdfium.json with the new bblanchon schema.
# iOS is excluded from the manifest — the xcframework is referenced only
# from Package.swift (downloaded by SPM, not by the hook).
cat > version_pdfium.json <<EOF
{
  "bblanchon_build": "$BUILD",
  "platforms": {
    "macos-arm64": {
      "url": "$BBLANCHON_BASE/pdfium-mac-arm64.tgz",
      "lib_path": "lib/libpdfium.dylib",
      "sha256": "$MACOS_ARM64_SHA"
    },
    "linux-x64": {
      "url": "$BBLANCHON_BASE/pdfium-linux-x64.tgz",
      "lib_path": "lib/libpdfium.so",
      "sha256": "$LINUX_X64_SHA"
    },
    "linux-arm64": {
      "url": "$BBLANCHON_BASE/pdfium-linux-arm64.tgz",
      "lib_path": "lib/libpdfium.so",
      "sha256": "$LINUX_ARM64_SHA"
    },
    "android-arm64": {
      "url": "$BBLANCHON_BASE/pdfium-android-arm64.tgz",
      "lib_path": "lib/libpdfium.so",
      "sha256": "$ANDROID_ARM64_SHA"
    },
    "android-x64": {
      "url": "$BBLANCHON_BASE/pdfium-android-x64.tgz",
      "lib_path": "lib/libpdfium.so",
      "sha256": "$ANDROID_X64_SHA"
    },
    "windows-x64": {
      "url": "$BBLANCHON_BASE/pdfium-win-x64.tgz",
      "lib_path": "bin/pdfium.dll",
      "sha256": "$WINDOWS_X64_SHA"
    },
    "wasm": {
      "url": "$BBLANCHON_BASE/pdfium-wasm.tgz",
      "lib_paths": ["lib/pdfium.wasm", "lib/pdfium.js"],
      "sha256": "$WASM_SHA"
    }
  }
}
EOF

# Rewrite lib/src/pdfium_version.dart with the updated build constants.
cat > lib/src/pdfium_version.dart <<'DARTEOF'
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

// PDFium version constants used by the native-assets hook and runtime loader.
//
// Update these alongside BBLANCHON_BUILD and version_pdfium.json whenever the
// bblanchon/pdfium-binaries release is bumped.
DARTEOF

# Append the build-specific constants (BUILD is a shell variable).
cat >> lib/src/pdfium_version.dart <<EOF
/// Human-readable PDFium release identifier, matching the bblanchon tag.
///
/// This is the \`chromium/NNNN\` string used in log messages and documentation.
/// It is **not** safe to use as a filesystem path segment — the slash would
/// create an unintended nested directory. Use [bblanchonBuild] for paths.
const pdfiumVersion = 'chromium/$BUILD';

/// Slash-free bblanchon build number used as a filesystem path segment.
///
/// Used at runtime to locate the hook's binary cache directory
/// (\`.dart_tool/betto_pdfium/{bblanchonBuild}/\`) as a fallback when the
/// build system has not staged the library to the standard
/// adjacent-to-executable location (e.g. during \`dart run\` in JIT mode).
///
/// Using the plain build number (e.g. \`'$BUILD'\`) avoids the nested-directory
/// problem that a \`chromium/$BUILD\` path segment would silently create.
///
/// Update this alongside [pdfiumVersion] and \`BBLANCHON_BUILD\` when bumping
/// the bblanchon release.
const bblanchonBuild = '$BUILD';
EOF

# Update Package.swift binaryTarget with the new xcframework URL and checksum.
if [ -n "$IOS_XCFRAMEWORK_SHA" ]; then
    PACKAGE_SWIFT="../betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift"
    python3 - "$PACKAGE_SWIFT" "$IOS_XCFRAMEWORK_URL" "$IOS_XCFRAMEWORK_SHA" <<'PYEOF'
import sys, re
path, url, checksum = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    content = f.read()
content = re.sub(r'url:\s*"[^"]*"', f'url: "{url}"', content)
content = re.sub(r'checksum:\s*"[^"]*"', f'checksum: "{checksum}"', content)
with open(path, 'w') as f:
    f.write(content)
print(f'  updated {path}')
PYEOF
fi

echo ""
echo "update_pdfium_manifest: done."
echo "  bblanchon build:        chromium/$BUILD"
echo "  macos-arm64 sha256:     $MACOS_ARM64_SHA"
echo "  linux-x64   sha256:     $LINUX_X64_SHA"
echo "  linux-arm64 sha256:     $LINUX_ARM64_SHA"
echo "  android-arm64 sha256:   $ANDROID_ARM64_SHA"
echo "  android-x64   sha256:   $ANDROID_X64_SHA"
echo "  windows-x64   sha256:   $WINDOWS_X64_SHA"
echo "  wasm        sha256:     $WASM_SHA"
if [ -n "$IOS_XCFRAMEWORK_SHA" ]; then
echo "  ios xcfw sha256:        $IOS_XCFRAMEWORK_SHA"
fi
echo ""
echo "Next steps:"
echo "  make fetch_pdfium          # install binary + headers locally"
echo "  make ffi_bindings          # if the PDFium public API changed"
echo "  git add version_pdfium.json lib/src/pdfium_version.dart"
echo "  git add ../betto_pdfium_ios/ios/betto_pdfium_ios/Package.swift"
echo "  git add lib/src/generated/"
echo "  git commit -m 'Bump PDFium to bblanchon chromium/$BUILD'"
