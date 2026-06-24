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
    mkdir -p "$BUILD_DIR/pdfium_checkout"

    # Write .gclient with managed:False so that gclient sync never resets
    # our manually-cloned pdfium working tree (or any DEPS patches on it).
    cat > "$BUILD_DIR/pdfium_checkout/.gclient" << 'GCLIENTEOF'
solutions = [
  { "name"        : "pdfium",
    "url"         : "https://pdfium.googlesource.com/pdfium.git",
    "deps_file"   : "DEPS",
    "managed"     : False,
    "custom_vars" : {
      "checkout_v8"       : False,
      "checkout_skia"     : False,
      "checkout_android"  : True,
    },
  },
]
GCLIENTEOF

    # Pre-clone pdfium at the target revision before running gclient sync.
    # This lets us patch DEPS (see below) before gclient resolves the dep
    # graph. The buildtools/reclient dep in DEPS has no condition guard, so
    # gclient tries to download infra/rbe/client/linux-arm64 — a package
    # that does not exist in CIPD. Setting custom_deps:None does not reliably
    # suppress CIPD packages in modern gclient; patching DEPS is required.
    # With managed:False, gclient sync leaves the working tree (and our patch)
    # untouched.
    echo "setup: cloning pdfium at $PDFIUM_REVISION ..."
    git clone https://pdfium.googlesource.com/pdfium.git "$PDFIUM_SRC"
    git -C "$PDFIUM_SRC" checkout "$PDFIUM_REVISION"

    # Patch DEPS: add condition=False to buildtools/reclient so that gclient
    # skips the infra/rbe/client CIPD package entirely on all platforms.
    # RBE (Remote Build Execution) is a Google-internal distributed compile
    # service; we never use it and its linux-arm64 package does not exist.
    # Remove the .bak file immediately — untracked files cause gclient to
    # report "uncommitted changes" and refuse to sync.
    sed -i.bak "s|'buildtools/reclient': {|'buildtools/reclient': {\n    'condition': 'False',|" \
        "$PDFIUM_SRC/DEPS"
    rm -f "$PDFIUM_SRC/DEPS.bak"
    echo "setup: patched DEPS to skip reclient CIPD download"

    echo "setup: running gclient sync — this downloads several GB and may take 20-40 minutes on first run ..."
    # --force bypasses the "uncommitted changes" check for the managed:False
    # pdfium solution. For unmanaged solutions gclient does NOT reset the
    # working tree on --force; it only skips the cleanliness guard.
    cd "$BUILD_DIR/pdfium_checkout" && \
        PATH="$DEPOT_TOOLS:$PATH" gclient sync --force --revision "pdfium@$PDFIUM_REVISION"
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
