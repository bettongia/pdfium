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

echo "Create the output directory: $PDFIUM_OUT"
mkdir -p $PDFIUM_OUT

echo "Configure the build args: $PDFIUM_OUT/args.gn"

envsubst < args.gn.tmpl > $PDFIUM_OUT/args.gn
# is_component_build=true (the template default) produces libpdfium.dylib with
# @rpath dependencies on sibling component dylibs — not a distributable
# artifact. With is_component_build=false all component() targets become
# source_sets; setup.sh adds pdfium_standalone which links them into a single
# self-contained libpdfium.dylib with no external PDFium runtime dependencies.
echo "is_component_build = false" >> $PDFIUM_OUT/args.gn

# Reserve 32 KB of Mach-O header space for install_name_tool rewrites.
# PDFium inherits Chromium's build system but does not expose extra_ldflags as
# a GN declare_args variable, so we patch the toolchain source directly.
# Approach from https://github.com/bblanchon/pdfium-binaries
TOOLCHAIN_GNI="$PDFIUM_SRC/build/toolchain/apple/toolchain.gni"
python3 - "$TOOLCHAIN_GNI" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
marker = 'otool = "${prefix}llvm-otool"'
patch_line = '      linker_driver_args += " -Wl,-headerpad_max_install_names"'
if 'headerpad_max_install_names' not in content:
    content = content.replace(marker, marker + '\n' + patch_line, 1)
    with open(path, 'w') as f:
        f.write(content)
    print(f'  patched {path}')
else:
    print(f'  {path} already patched')
PYEOF

echo "Running: $GN gen $PDFIUM_OUT"
cd $PDFIUM_SRC && $GN gen $PDFIUM_OUT

echo "Running ninja (this may take 10-30 minutes on first build) ..."
cd $PDFIUM_SRC &&  ninja -C $PDFIUM_OUT pdfium_standalone -j$(sysctl -n hw.logicalcpu)

echo "staging dylib to $PDFIUM_DIST/$PDFIUM_PLATFORM/ ..."
mkdir -p $PDFIUM_DIST/$PDFIUM_PLATFORM

cp $PDFIUM_OUT/libpdfium.dylib $PDFIUM_DIST/$PDFIUM_PLATFORM/
install_name_tool -id @rpath/libpdfium.dylib $PDFIUM_DIST/$PDFIUM_PLATFORM/libpdfium.dylib

echo "writing VERSION file ..."
printf "%s" \
    $(cd $PDFIUM_SRC && git rev-parse HEAD) \
    > $PDFIUM_DIST/$PDFIUM_PLATFORM/VERSION

echo "Done. Binary at $PDFIUM_DIST/$PDFIUM_PLATFORM/libpdfium.dylib"
echo ""
echo "Note: a locally-built dylib is never assigned the com.apple.quarantine"
echo "xattr, so Gatekeeper does not apply and dlopen() loads it without signing."
echo "Ad-hoc codesigning is deferred to plan_pdfium_build_pipeline.md, where"
echo "pipeline-fetched binaries are downloaded and will be quarantined."
