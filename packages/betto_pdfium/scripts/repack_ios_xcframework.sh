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

# repack_ios_xcframework.sh
#
# Downloads the bblanchon iOS device (arm64) and iOS simulator (arm64) tarballs,
# repacks them as a dynamic pdfium.xcframework, and uploads it to the
# bettongia/pdfium GitHub Release tagged bblanchon-chromium-<BUILD>.
#
# ## Why this step is needed
#
# bblanchon/pdfium-binaries provides separate tarballs for the iOS device and
# simulator slices. Each contains a raw dylib with install name
# `./libpdfium.dylib`. To embed in an iOS app, we must:
#   1. Rename the dylib to `pdfium` (remove lib prefix + extension).
#   2. Patch the install name to `@rpath/pdfium.framework/pdfium`.
#   3. Wrap each in a minimal .framework bundle (Info.plist + binary).
#   4. Combine device + simulator frameworks into one .xcframework.
#   5. Zip and upload to bettongia/pdfium Releases for SPM to consume.
#
# ## Usage
#
#   cd packages/betto_pdfium
#   scripts/repack_ios_xcframework.sh
#   # or via Make from the repo root:
#   make repack_ios_xcframework
#
# ## Output
#
# Prints the SHA-256 of pdfium.xcframework.zip.
# Use that checksum in Package.swift after running update_pdfium_manifest.

set -e
set -o pipefail
set -u

BUILD=$(tr -d '[:space:]' < BBLANCHON_BUILD)
BBLANCHON_BASE="https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F${BUILD}"
BETTONGIA_REPO="bettongia/pdfium"
BETTONGIA_TAG="bblanchon-chromium-${BUILD}"

# Checksum helper.
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Require gh CLI for upload.
if ! command -v gh >/dev/null 2>&1; then
    echo "repack_ios_xcframework: 'gh' (GitHub CLI) is required. Install from https://cli.github.com/"
    exit 1
fi

# Must run on macOS — xcodebuild and install_name_tool are macOS-only.
if [ "$(uname -s)" != "Darwin" ]; then
    echo "repack_ios_xcframework: must run on macOS (requires xcodebuild and install_name_tool)."
    exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "repack_ios_xcframework: downloading iOS tarballs for bblanchon chromium/$BUILD ..."
curl -fsSL -o "$WORK/ios-device.tgz"    "$BBLANCHON_BASE/pdfium-ios-device-arm64.tgz"
curl -fsSL -o "$WORK/ios-simulator.tgz" "$BBLANCHON_BASE/pdfium-ios-simulator-arm64.tgz"

# ── Build device framework ────────────────────────────────────────────────────

echo "repack_ios_xcframework: building device pdfium.framework ..."
mkdir -p "$WORK/device/pdfium.framework"

# Extract the dylib from the device tarball.
tar -xzf "$WORK/ios-device.tgz" -C "$WORK/device" --strip-components=1 "lib/libpdfium.dylib"

# Rename to `pdfium` (the binary name that iOS frameworks use).
cp "$WORK/device/libpdfium.dylib" "$WORK/device/pdfium.framework/pdfium"

# Patch the install name to the canonical xcframework rpath.
install_name_tool -id "@rpath/pdfium.framework/pdfium" "$WORK/device/pdfium.framework/pdfium"

# Read MinimumOSVersion from LC_BUILD_VERSION in the dylib.
DEVICE_MIN_OS=$(otool -l "$WORK/device/pdfium.framework/pdfium" 2>/dev/null | \
    awk '/LC_BUILD_VERSION/{found=1} found && /minos/{print $2; exit}' || echo "12.0")
DEVICE_MIN_OS=${DEVICE_MIN_OS:-12.0}

# Write the framework Info.plist.
cat > "$WORK/device/pdfium.framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>pdfium</string>
    <key>CFBundleIdentifier</key>
    <string>io.bettongia.pdfium</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.0</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>MinimumOSVersion</key>
    <string>$DEVICE_MIN_OS</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
</dict>
</plist>
PLIST

# ── Build simulator framework ─────────────────────────────────────────────────

echo "repack_ios_xcframework: building simulator pdfium.framework ..."
mkdir -p "$WORK/simulator/pdfium.framework"

tar -xzf "$WORK/ios-simulator.tgz" -C "$WORK/simulator" --strip-components=1 "lib/libpdfium.dylib"
cp "$WORK/simulator/libpdfium.dylib" "$WORK/simulator/pdfium.framework/pdfium"
install_name_tool -id "@rpath/pdfium.framework/pdfium" "$WORK/simulator/pdfium.framework/pdfium"

SIM_MIN_OS=$(otool -l "$WORK/simulator/pdfium.framework/pdfium" 2>/dev/null | \
    awk '/LC_BUILD_VERSION/{found=1} found && /minos/{print $2; exit}' || echo "12.0")
SIM_MIN_OS=${SIM_MIN_OS:-12.0}

cat > "$WORK/simulator/pdfium.framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>pdfium</string>
    <key>CFBundleIdentifier</key>
    <string>io.bettongia.pdfium</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.0</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>MinimumOSVersion</key>
    <string>$SIM_MIN_OS</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneSimulator</string>
    </array>
</dict>
</plist>
PLIST

# ── Create xcframework ────────────────────────────────────────────────────────

echo "repack_ios_xcframework: creating pdfium.xcframework ..."
XCFW="$WORK/pdfium.xcframework"
rm -rf "$XCFW"

xcodebuild -create-xcframework \
    -framework "$WORK/device/pdfium.framework" \
    -framework "$WORK/simulator/pdfium.framework" \
    -output "$XCFW"

# ── Zip and compute checksum ──────────────────────────────────────────────────

echo "repack_ios_xcframework: zipping xcframework ..."
ZIP="$WORK/pdfium.xcframework.zip"
(cd "$WORK" && zip -qr "$ZIP" "pdfium.xcframework")

ZIP_SHA=$(_sha256 "$ZIP")
echo ""
echo "repack_ios_xcframework: pdfium.xcframework.zip SHA-256: $ZIP_SHA"

# ── Upload to bettongia/pdfium GitHub Release ─────────────────────────────────

echo "repack_ios_xcframework: uploading to $BETTONGIA_TAG ..."

# Create the release if it doesn't exist yet.
if ! gh release view "$BETTONGIA_TAG" --repo "$BETTONGIA_REPO" >/dev/null 2>&1; then
    echo "  creating release $BETTONGIA_TAG ..."
    gh release create "$BETTONGIA_TAG" \
        --repo "$BETTONGIA_REPO" \
        --title "bblanchon chromium/$BUILD (iOS xcframework)" \
        --notes "Repacked iOS xcframework from bblanchon/pdfium-binaries chromium/$BUILD.

Source tarballs:
- pdfium-ios-device-arm64.tgz
- pdfium-ios-simulator-arm64.tgz

SHA-256 of pdfium.xcframework.zip: $ZIP_SHA"
fi

gh release upload "$BETTONGIA_TAG" \
    --repo "$BETTONGIA_REPO" \
    --clobber \
    "$ZIP"

echo ""
echo "repack_ios_xcframework: done."
echo "  tag:    $BETTONGIA_TAG"
echo "  sha256: $ZIP_SHA"
echo ""
echo "Next: run 'make update_pdfium_manifest' to update version_pdfium.json"
echo "and Package.swift with the new xcframework URL and checksum."
