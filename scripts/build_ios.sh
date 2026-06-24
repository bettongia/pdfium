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

mkdir -p $PDFIUM_OUT

# iOS requires a static library; is_component_build=true (shared) is not
# supported on iOS. Args written directly rather than via args.gn.tmpl.
cat > $PDFIUM_OUT/args.gn << 'ARGSEOF'
is_debug = false
pdf_is_standalone = true
is_component_build = false
pdf_enable_xfa = false
pdf_enable_v8 = false
use_custom_libcxx = false
clang_use_chrome_plugins = false
target_cpu = "arm64"
target_os = "ios"
target_environment = "device"
ios_deployment_target = "16.0"
ios_automatically_manage_certs = false
ARGSEOF

echo "Running: $GN gen $PDFIUM_OUT"
cd $PDFIUM_SRC && $GN gen $PDFIUM_OUT

echo "Running ninja (this may take 10-30 minutes on first build) ..."
cd $PDFIUM_SRC && ninja -C $PDFIUM_OUT pdfium -j$(sysctl -n hw.logicalcpu)

echo "merging static libraries into libpdfium.a ..."
# PDFium's ninja build uses LLVM thin archives (.a files that store absolute
# paths to .o files rather than embedding them). Collect all .o files directly
# from obj/ and pack them into a single fat archive in one llvm-ar invocation.
LLVM_AR="$PDFIUM_SRC/third_party/llvm-build/Release+Asserts/bin/llvm-ar"
OBJ_FILES=()
while IFS= read -r -d '' f; do
    OBJ_FILES+=("$f")
done < <(find "$PDFIUM_OUT/obj" -name "*.o" -print0)
"$LLVM_AR" rcs "$PDFIUM_OUT/libpdfium.a" "${OBJ_FILES[@]}"

echo "packaging xcframework ..."
# Build the xcframework directory structure manually — xcodebuild -create-xcframework
# cannot determine the platform for archives produced by LLVM toolchain.
STAGE_DIR="$PDFIUM_DIST/$PDFIUM_PLATFORM"
mkdir -p "$STAGE_DIR"

XCFRAMEWORK="$STAGE_DIR/libpdfium.xcframework"
LIB_ID="ios-arm64"
mkdir -p "$XCFRAMEWORK/$LIB_ID"
cp "$PDFIUM_OUT/libpdfium.a" "$XCFRAMEWORK/$LIB_ID/"

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
