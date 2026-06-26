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

set -e          # Exit immediately if a command exits with a non-zero status
set -o pipefail # Catch failures inside pipelines (e.g., cmd1 | cmd2)
set -u          # Exit if an undefined variable is used

echo "configuring GN build for $PDFIUM_PLATFORM ..."

DEPOT_TOOLS_UPDATE=0
PATH="$DEPOT_TOOLS:$PATH"

LLVM_AR="$PDFIUM_SRC/third_party/llvm-build/Release+Asserts/bin/llvm-ar"

# build_slice <out_dir> <target_environment>
# Configures, builds, and merges a single iOS slice (device or simulator).
build_slice() {
    local out="$1"
    local env="$2"

    mkdir -p "$out"
    cat > "$out/args.gn" << ARGSEOF
is_debug = false
pdf_is_standalone = true
is_component_build = false
pdf_enable_xfa = false
pdf_enable_v8 = false
use_custom_libcxx = false
clang_use_chrome_plugins = false
target_cpu = "arm64"
target_os = "ios"
target_environment = "$env"
ios_deployment_target = "16.0"
ios_automatically_manage_certs = false
ios_enable_code_signing = false
ARGSEOF

    echo "Running: $GN gen $out (environment=$env)"
    cd $PDFIUM_SRC && $GN gen "$out"

    echo "Running ninja for $env ..."
    cd $PDFIUM_SRC && ninja -C "$out" pdfium -j$(sysctl -n hw.logicalcpu)

    echo "Merging static libraries into $out/libpdfium.a ..."
    # PDFium's ninja build uses LLVM thin archives (.a files that store absolute
    # paths to .o files rather than embedding them). Collect all .o files directly
    # from obj/ and pack them into a single fat archive in one llvm-ar invocation.
    local obj_files=()
    while IFS= read -r -d '' f; do
        obj_files+=("$f")
    done < <(find "$out/obj" -name "*.o" -print0)
    "$LLVM_AR" rcs "$out/libpdfium.a" "${obj_files[@]}"
}

# Build device and simulator slices.
PDFIUM_OUT_DEVICE="${PDFIUM_OUT}_device"
PDFIUM_OUT_SIM="${PDFIUM_OUT}_sim"

build_slice "$PDFIUM_OUT_DEVICE" "device"
build_slice "$PDFIUM_OUT_SIM"    "simulator"

echo "packaging xcframework ..."
# Build the xcframework directory structure manually — xcodebuild -create-xcframework
# cannot determine the platform for archives produced by the LLVM toolchain.
# The xcframework contains two slices:
#   ios-arm64           — physical device (arm64)
#   ios-arm64-simulator — Apple Silicon simulator (arm64, platform variant: simulator)
STAGE_DIR="$PDFIUM_DIST/$PDFIUM_PLATFORM"
mkdir -p "$STAGE_DIR"

XCFRAMEWORK="$STAGE_DIR/libpdfium.xcframework"
mkdir -p "$XCFRAMEWORK/ios-arm64"
mkdir -p "$XCFRAMEWORK/ios-arm64-simulator"
cp "$PDFIUM_OUT_DEVICE/libpdfium.a" "$XCFRAMEWORK/ios-arm64/"
cp "$PDFIUM_OUT_SIM/libpdfium.a"    "$XCFRAMEWORK/ios-arm64-simulator/"

cat > "$XCFRAMEWORK/Info.plist" << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
        <dict>
            <key>LibraryIdentifier</key>
            <string>ios-arm64</string>
            <key>LibraryPath</key>
            <string>libpdfium.a</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>arm64</string>
            </array>
            <key>SupportedPlatform</key>
            <string>ios</string>
        </dict>
        <dict>
            <key>LibraryIdentifier</key>
            <string>ios-arm64-simulator</string>
            <key>LibraryPath</key>
            <string>libpdfium.a</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>arm64</string>
            </array>
            <key>SupportedPlatform</key>
            <string>ios</string>
            <key>SupportedPlatformVariant</key>
            <string>simulator</string>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
PLISTEOF

cd "$STAGE_DIR" && zip -r libpdfium-ios-arm64.xcframework.zip libpdfium.xcframework
rm -rf "$XCFRAMEWORK"

echo "writing VERSION file ..."
printf "%s" \
    $(cd $PDFIUM_SRC && git rev-parse HEAD) \
    > "$STAGE_DIR/VERSION"
