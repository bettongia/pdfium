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

DEPOT_TOOLS_UPDATE=0

mkdir -p $BUILD_DIR


if [ ! -d "$DEPOT_TOOLS" ]; then
    echo "setup: cloning depot_tools into $DEPOT_TOOLS ..."
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git $DEPOT_TOOLS
fi

if [ ! -d "$PDFIUM_SRC" ]; then
    PATH="$DEPOT_TOOLS:$PATH"
    mkdir -p $BUILD_DIR/pdfium_checkout

    # Write .gclient directly rather than using `gclient config` so we can set
    # checkout_rbe_client=False. The RBE (Remote Build Execution) client is a
    # Google-internal distributed compile tool; its linux-arm64 CIPD package
    # does not exist, and it is never needed for local or container builds.
    cat > "$BUILD_DIR/pdfium_checkout/.gclient" << 'GCLIENTEOF'
solutions = [
  { "name"        : "pdfium",
    "url"         : "https://pdfium.googlesource.com/pdfium.git",
    "deps_file"   : "DEPS",
    "managed"     : False,
    "custom_deps" : {
      "pdfium/buildtools/reclient" : None,
    },
    "custom_vars" : {
      "checkout_v8"   : False,
      "checkout_skia" : False,
    },
  },
]
GCLIENTEOF

    echo "setup: running gclient sync (rev $PDFIUM_REVISION) — this downloads several GB and may take 20-40 minutes on first run ..."
    cd "$BUILD_DIR/pdfium_checkout" && \
        gclient sync --revision $PDFIUM_REVISION
fi

# Patch: ios_sdk.gni references ios_automatically_manage_certs in testing/test.gni
# but never declares it via declare_args. Add the declaration so iOS GN gen succeeds.
IOS_SDK_GNI="$PDFIUM_SRC/build/config/ios/ios_sdk.gni"
if [ -f "$IOS_SDK_GNI" ] && ! grep -q "ios_automatically_manage_certs" "$IOS_SDK_GNI"; then
    sed -i.bak 's/  ios_is_app_extension = false/  ios_is_app_extension = false\n\n  # Whether to use automatic certificate management for iOS test signing.\n  ios_automatically_manage_certs = false/' "$IOS_SDK_GNI"
    echo "setup: patched ios_sdk.gni to declare ios_automatically_manage_certs"
fi

# Patch: -fvisibility-global-new-delete=force-hidden is incompatible with the
# iOS 26 SDK's global_new_delete.h, which declares operator new/delete with
# explicit default visibility — conflicting with the forced-hidden flag when
# using PDFium's bundled clang. Remove the flag from the two GN files that set it.
PARTITION_ALLOC_BUILD="$PDFIUM_SRC/base/allocator/partition_allocator/src/partition_alloc/BUILD.gn"
if [ -f "$PARTITION_ALLOC_BUILD" ] && grep -q 'fvisibility-global-new-delete=force-hidden' "$PARTITION_ALLOC_BUILD"; then
    sed -i.bak '/fvisibility-global-new-delete=force-hidden/d' "$PARTITION_ALLOC_BUILD"
    echo "setup: patched partition_alloc/BUILD.gn to remove fvisibility-global-new-delete"
fi

LIBCXX_BUILD="$PDFIUM_SRC/buildtools/third_party/libc++/BUILD.gn"
if [ -f "$LIBCXX_BUILD" ] && grep -q 'fvisibility-global-new-delete=force-hidden' "$LIBCXX_BUILD"; then
    sed -i.bak '/fvisibility-global-new-delete=force-hidden/d' "$LIBCXX_BUILD"
    echo "setup: patched libc++/BUILD.gn to remove fvisibility-global-new-delete"
fi

# Patch: libjpeg_turbo/BUILD.gn asserts use_blink to guard against accidental
# inclusion in non-Blink builds, but PDFium explicitly depends on it regardless
# of use_blink. Remove the assertion so iOS and other standalone builds succeed.
LIBJPEG_TURBO_BUILD="$PDFIUM_SRC/third_party/libjpeg_turbo/BUILD.gn"
if [ -f "$LIBJPEG_TURBO_BUILD" ] && grep -q 'use_blink' "$LIBJPEG_TURBO_BUILD"; then
    # The assert block spans 3 lines: assert(\n    use_blink,\n    "message")
    # BSD sed (macOS) requires N to read additional lines before deleting.
    sed -i.bak -e '/^assert(/{N;N;d;}' "$LIBJPEG_TURBO_BUILD"
    echo "setup: patched libjpeg_turbo/BUILD.gn to remove use_blink assertion"
fi

echo "setup: gclient sync complete. PDFium source is at $PDFIUM_SRC"
