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

echo "Running: $GN gen $PDFIUM_OUT"
cd $PDFIUM_SRC && $GN gen $PDFIUM_OUT

echo "Running ninja (this may take 10-30 minutes on first build) ..."
cd $PDFIUM_SRC && ninja -C $PDFIUM_OUT pdfium -j$(nproc)

echo "staging shared library to $PDFIUM_DIST/$PDFIUM_PLATFORM/ ..."
mkdir -p $PDFIUM_DIST/$PDFIUM_PLATFORM

cp $PDFIUM_OUT/*.so $PDFIUM_DIST/$PDFIUM_PLATFORM/

echo "writing VERSION file ..."
printf "%s" \
    $(cd $PDFIUM_SRC && git rev-parse HEAD) \
    > $PDFIUM_DIST/$PDFIUM_PLATFORM/VERSION
