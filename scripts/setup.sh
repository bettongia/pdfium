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

# checkout_android: True causes gclient to download the Linux_x64 clang package
# (DEPS condition: "(host_os=='linux' or checkout_android) and non_git_source").
# On macOS that downloads a Linux ELF binary to the same path as the Mac arm64
# clang, overwriting it — resulting in "cannot execute binary file" at compile
# time. On Linux arm64, checkout_android would download x64 Android toolchain
# binaries that cannot execute on an arm64 host. Only set True on Linux x86_64
# (where the android cross-toolchain is needed for the Android build jobs).
if [ "$(uname -s)" = "Darwin" ] || [ "$(uname -m)" = "aarch64" ]; then
    _checkout_android="False"
else
    _checkout_android="True"
fi

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
    # custom_deps: buildtools/reclient → None suppresses the CIPD download
    # of the RBE remote-execution client (infra/rbe/client/$platform).
    # That package does not exist for linux-arm64, and we never use RBE.
    # The unquoted heredoc allows ${_checkout_android} to be expanded.
    cat > "$BUILD_DIR/pdfium_checkout/.gclient" << GCLIENTEOF
solutions = [
  { "name"        : "pdfium",
    "url"         : "https://pdfium.googlesource.com/pdfium.git",
    "deps_file"   : "DEPS",
    "managed"     : False,
    "custom_deps" : {
      "buildtools/reclient": None,
    },
    "custom_vars" : {
      "checkout_v8"         : False,
      "checkout_skia"       : False,
      "checkout_android"    : ${_checkout_android},
      "checkout_reclient"   : False,
    },
  },
]
GCLIENTEOF

    # Pre-clone pdfium at the target revision before running gclient sync.
    # This lets us patch DEPS before gclient resolves the dep graph.
    # The DEPS 'condition': 'False' patch is belt-and-suspenders alongside
    # custom_deps: None above; either mechanism alone may be bypassed
    # depending on the gclient version.
    # With managed:False, gclient sync leaves the working tree untouched.
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

    # DEPS may have infra/rbe/client in a root-level packages list gated only
    # by host_os=="linux" — no checkout_reclient variable to suppress it with.
    # infra/rbe/client/linux-arm64 does not exist in CIPD; cipd ensure fails.
    # Use brace-matching to remove the { ... } dict directly from DEPS.
    # ${platform} inside the string contains matching { } that cancel in depth.
    if grep -q 'infra/rbe/client/' "$PDFIUM_SRC/DEPS" 2>/dev/null; then
        python3 - "$PDFIUM_SRC/DEPS" << 'PATCHEOF'
import sys

with open(sys.argv[1]) as f:
    text = f.read()

# Set checkout_reclient=False if it exists as a variable (belt-and-suspenders)
text = text.replace("'checkout_reclient': True,", "'checkout_reclient': False,", 1)
text = text.replace('"checkout_reclient": True,', '"checkout_reclient": False,', 1)

def remove_rbe_dict(text):
    idx = text.find("'infra/rbe/client/")
    if idx == -1:
        idx = text.find('"infra/rbe/client/')
    if idx == -1:
        return text
    # Walk backward to find opening { of the dict containing this string
    j = idx - 1
    depth = 0
    while j >= 0:
        c = text[j]
        if c == '}':
            depth += 1
        elif c == '{':
            if depth == 0:
                break
            depth -= 1
        j -= 1
    dict_start = j
    # Walk forward to find matching closing }
    j = dict_start
    depth = 0
    while j < len(text):
        c = text[j]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                break
        j += 1
    dict_end = j
    # Remove from start of the line containing dict_start through dict_end,
    # including any trailing comma
    line_start = text.rfind('\n', 0, dict_start) + 1
    after = dict_end + 1
    while after < len(text) and text[after] in ' \t':
        after += 1
    if after < len(text) and text[after] == ',':
        after += 1
    return text[:line_start] + text[after:]

for _ in range(5):
    patched = remove_rbe_dict(text)
    if patched == text:
        break
    text = patched

with open(sys.argv[1], 'w') as f:
    f.write(text)
PATCHEOF
        echo "setup: removed infra/rbe/client dict from DEPS (linux-arm64 package does not exist in CIPD)"
    fi

    echo "setup: running gclient sync — this downloads several GB and may take 20-40 minutes on first run ..."
    # --force bypasses the "uncommitted changes" check for the managed:False
    # pdfium solution. For unmanaged solutions gclient does NOT reset the
    # working tree on --force; it only skips the cleanliness guard.
    cd "$BUILD_DIR/pdfium_checkout" && \
        PATH="$DEPOT_TOOLS:$PATH" gclient sync --force --revision "pdfium@$PDFIUM_REVISION"
fi

# Patch: build/config/compiler/BUILD.gn defines COMPONENT_BUILD only when
# is_component_build=true. When is_component_build=false the preprocessor
# symbol is absent, so FPDF_EXPORT expands to nothing and all PDFium public
# API symbols are hidden by -fvisibility=hidden — making dlsym fail at runtime.
# Remove the is_component_build guard to always define COMPONENT_BUILD so
# FPDF_EXPORT consistently expands to __attribute__((visibility("default"))).
COMPILER_BUILD="$PDFIUM_SRC/build/config/compiler/BUILD.gn"
if [ -f "$COMPILER_BUILD" ] && grep -qF 'if (is_component_build) {' "$COMPILER_BUILD"; then
    python3 - "$COMPILER_BUILD" << 'PATCHEOF'
import sys
with open(sys.argv[1]) as f:
    text = f.read()
text = text.replace(
    '  if (is_component_build) {\n    defines += [ "COMPONENT_BUILD" ]\n  }\n',
    '  defines += [ "COMPONENT_BUILD" ]\n',
    1,
)
with open(sys.argv[1], 'w') as f:
    f.write(text)
PATCHEOF
    echo "setup: patched compiler/BUILD.gn to always define COMPONENT_BUILD (ensures FPDF_EXPORT symbols are exported from standalone builds)"
fi

# Patch: ios_sdk.gni references ios_automatically_manage_certs in testing/test.gni
# but never declares it via declare_args. Add the declaration so iOS GN gen succeeds.
IOS_SDK_GNI="$PDFIUM_SRC/build/config/ios/ios_sdk.gni"
if [ -f "$IOS_SDK_GNI" ] && ! grep -q "ios_automatically_manage_certs" "$IOS_SDK_GNI"; then
    sed -i.bak 's/  ios_is_app_extension = false/  ios_is_app_extension = false\n\n  # Whether to use automatic certificate management for iOS test signing.\n  ios_automatically_manage_certs = false/' "$IOS_SDK_GNI"
    rm -f "$IOS_SDK_GNI.bak"
    echo "setup: patched ios_sdk.gni to declare ios_automatically_manage_certs"
fi

# Patch: -fvisibility-global-new-delete=force-hidden is incompatible with the
# iOS 26 SDK's global_new_delete.h, which declares operator new/delete with
# explicit default visibility — conflicting with the forced-hidden flag when
# using PDFium's bundled clang. Remove the flag from the two GN files that set it.
PARTITION_ALLOC_BUILD="$PDFIUM_SRC/base/allocator/partition_allocator/src/partition_alloc/BUILD.gn"
if [ -f "$PARTITION_ALLOC_BUILD" ] && grep -q 'fvisibility-global-new-delete=force-hidden' "$PARTITION_ALLOC_BUILD"; then
    sed -i.bak '/fvisibility-global-new-delete=force-hidden/d' "$PARTITION_ALLOC_BUILD"
    rm -f "$PARTITION_ALLOC_BUILD.bak"
    echo "setup: patched partition_alloc/BUILD.gn to remove fvisibility-global-new-delete"
fi

LIBCXX_BUILD="$PDFIUM_SRC/buildtools/third_party/libc++/BUILD.gn"
if [ -f "$LIBCXX_BUILD" ] && grep -q 'fvisibility-global-new-delete=force-hidden' "$LIBCXX_BUILD"; then
    sed -i.bak '/fvisibility-global-new-delete=force-hidden/d' "$LIBCXX_BUILD"
    rm -f "$LIBCXX_BUILD.bak"
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
    rm -f "$LIBJPEG_TURBO_BUILD.bak"
    echo "setup: patched libjpeg_turbo/BUILD.gn to remove use_blink assertion"
fi

# Patch: partition_alloc — replace stack_trace_android.cc with stack_trace_linux.cc.
# stack_trace_android.cc uses _Unwind_Backtrace/_Unwind_GetIP from <unwind.h>.
# The Chromium toolchain passes --unwindlib=none to the Android linker, and
# libunwind is not in the NDK sysroot library search path when building
# standalone component shared libraries (-z defs). stack_trace_linux.cc
# provides CollectStackTrace() via frame pointers (arm64, where
# can_unwind_with_frame_pointers=true) or returns 0 (x64) — no external dep.
# OutputStackTrace() in stack_trace_posix.cc is guarded !IS_ANDROID because
# android.cc normally defines it; removing that guard re-enables the posix
# version now that android.cc is no longer compiled.
PA_BUILD="$PDFIUM_SRC/base/allocator/partition_allocator/src/partition_alloc/BUILD.gn"
PA_POSIX="$PDFIUM_SRC/base/allocator/partition_allocator/src/partition_alloc/partition_alloc_base/debug/stack_trace_posix.cc"
if [ -f "$PA_BUILD" ] && grep -q 'stack_trace_android.cc' "$PA_BUILD"; then
    python3 - "$PA_BUILD" "$PA_POSIX" << 'PATCHEOF'
import sys
build_gn, posix_cc = sys.argv[1], sys.argv[2]

with open(build_gn) as f:
    text = f.read()
text = text.replace(
    '        "partition_alloc_base/debug/stack_trace_android.cc",\n',
    '        "partition_alloc_base/debug/stack_trace_linux.cc",\n',
    1,
)
with open(build_gn, 'w') as f:
    f.write(text)

with open(posix_cc) as f:
    text = f.read()
# Remove the opening guard comment + #if line
text = text.replace(
    '// stack_trace_android.cc defines its own OutputStackTrace.\n'
    '#if !PA_BUILDFLAG(IS_ANDROID)\n',
    '',
    1,
)
# Remove the closing #endif so OutputStackTrace() is compiled on Android too
text = text.replace(
    '#endif  // !PA_BUILDFLAG(IS_ANDROID)\n\n'
    '}  // namespace partition_alloc::internal::base::debug',
    '}  // namespace partition_alloc::internal::base::debug',
    1,
)
with open(posix_cc, 'w') as f:
    f.write(text)
PATCHEOF
    echo "setup: patched partition_alloc to use stack_trace_linux.cc for Android (no _Unwind_Backtrace)"
fi

# Patch: add pdfium_standalone target to BUILD.gn for all non-component builds.
# With is_component_build=false, component("pdfium") becomes a source_set with
# no binary output. pdfium_standalone wraps it in a shared_library so all PDFium
# code (and its transitive source_set deps) is linked into a single binary.
# Applies to macOS, Linux, and Android; iOS uses a separate static-lib path.
#
# Guard checks for the new platform-agnostic condition; if only the old
# Android-specific block is present (stale cache), the python3 script removes
# it and appends the new universal block.
ROOT_BUILD="$PDFIUM_SRC/BUILD.gn"
if [ -f "$ROOT_BUILD" ] && ! grep -qF 'if (!is_component_build) {' "$ROOT_BUILD"; then
    python3 - "$ROOT_BUILD" << 'PATCHEOF'
import sys
with open(sys.argv[1]) as f:
    text = f.read()
# Remove old Android-only block if present (upgrade to platform-agnostic)
old = (
    '\n# Single self-contained libpdfium.so for Android distribution.\n'
    '# With is_component_build=false all component() targets become source_sets;\n'
    '# this shared_library links them all in to produce one distributable .so.\n'
    'if (is_android && !is_component_build) {\n'
    '  shared_library("pdfium_standalone") {\n'
    '    output_name = "pdfium"\n'
    '    deps = [ ":pdfium" ]\n'
    '  }\n'
    '}\n'
)
text = text.replace(old, '')
text = text.rstrip() + '''

# Single self-contained distributable binary for non-component builds.
# With is_component_build=false all component() targets become source_sets;
# this shared_library links them all into one distributable binary
# (macOS dylib, Linux .so, Android .so).
if (!is_component_build) {
  shared_library("pdfium_standalone") {
    output_name = "pdfium"
    deps = [ ":pdfium" ]
  }
}
'''
with open(sys.argv[1], 'w') as f:
    f.write(text)
PATCHEOF
    echo "setup: patched BUILD.gn to add pdfium_standalone distribution target (macOS/Linux/Android)"
fi

echo "setup: gclient sync complete. PDFium source is at $PDFIUM_SRC"
