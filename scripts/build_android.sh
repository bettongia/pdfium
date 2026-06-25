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

echo "Configure the build args: $PDFIUM_OUT/args.gn"
envsubst < args.gn.tmpl > $PDFIUM_OUT/args.gn
# With is_component_build=true (the template default), component("pdfium") builds
# as libpdfium.cr.so with runtime deps on 8+ other .cr.so component libs —
# not a distributable artifact. With is_component_build=false all component()
# targets become source_sets; setup.sh adds a pdfium_standalone shared_library
# that links them all into a single self-contained libpdfium.so.
echo "is_component_build = false" >> $PDFIUM_OUT/args.gn

echo "Running: $GN gen $PDFIUM_OUT"
cd $PDFIUM_SRC && $GN gen $PDFIUM_OUT

echo "Running ninja (this may take 10-30 minutes on first build) ..."
cd $PDFIUM_SRC && ninja -C $PDFIUM_OUT pdfium_standalone -j$(nproc)

echo "staging shared library to $PDFIUM_DIST/$PDFIUM_PLATFORM/ ..."
mkdir -p $PDFIUM_DIST/$PDFIUM_PLATFORM

# On Android the Chromium toolchain links the full binary to lib.unstripped/
# and writes a stripped copy to the root output dir. Use the stripped copy;
# fall back to lib.unstripped/ if the stripped file is missing or suspiciously
# small (a sign that --gc-sections removed all code due to hidden symbols).
STRIPPED="$PDFIUM_OUT/libpdfium.so"
UNSTRIPPED="$PDFIUM_OUT/lib.unstripped/libpdfium.so"
MIN_BYTES=1048576  # 1 MiB — a real PDFium .so is >5 MiB

pick_source() {
    local stripped_size=0
    local unstripped_size=0
    [ -f "$STRIPPED" ]   && stripped_size=$(stat -c %s "$STRIPPED")
    [ -f "$UNSTRIPPED" ] && unstripped_size=$(stat -c %s "$UNSTRIPPED")

    if [ "$stripped_size" -ge "$MIN_BYTES" ]; then
        echo "$STRIPPED"
    elif [ "$unstripped_size" -ge "$MIN_BYTES" ]; then
        echo "$UNSTRIPPED"
    else
        echo ""
    fi
}

SRC=$(pick_source)
if [ -z "$SRC" ]; then
    echo "ERROR: libpdfium.so is too small — COMPONENT_BUILD may not be defined." >&2
    echo "  stripped  (${STRIPPED}): $(stat -c %s "$STRIPPED" 2>/dev/null || echo missing) bytes" >&2
    echo "  unstripped (${UNSTRIPPED}): $(stat -c %s "$UNSTRIPPED" 2>/dev/null || echo missing) bytes" >&2
    echo "Check that setup.sh's COMPONENT_BUILD patch was applied to build/config/compiler/BUILD.gn." >&2
    exit 1
fi

echo "copying from $SRC ..."
cp "$SRC" $PDFIUM_DIST/$PDFIUM_PLATFORM/libpdfium.so

echo "writing VERSION file ..."
printf "%s" \
    $(cd $PDFIUM_SRC && git rev-parse HEAD) \
    > $PDFIUM_DIST/$PDFIUM_PLATFORM/VERSION
