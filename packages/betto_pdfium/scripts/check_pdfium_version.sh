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

set -e
set -o pipefail
set -u

PDFIUM_BIN="third_party/pdfium_bin"
EXPECTED=$(tr -d '[:space:]' < BBLANCHON_BUILD)

if [ ! -f "$PDFIUM_BIN/VERSION" ]; then
    echo "check_pdfium_version: $PDFIUM_BIN/VERSION not found."
    echo "  Run 'make fetch_pdfium' to install the PDFium binary and headers."
    exit 1
fi

INSTALLED=$(tr -d '[:space:]' < "$PDFIUM_BIN/VERSION")

if [ "$EXPECTED" != "$INSTALLED" ]; then
    echo "check_pdfium_version: PDFium version mismatch."
    echo "  expected:  chromium/$EXPECTED  (BBLANCHON_BUILD)"
    echo "  installed: chromium/$INSTALLED (third_party/pdfium_bin/VERSION)"
    echo "  Run 'make fetch_pdfium' to update."
    exit 1
fi

if [ ! -d "third_party/pdfium/public" ]; then
    echo "check_pdfium_version: third_party/pdfium/public/ not found."
    echo "  Run 'make fetch_pdfium' to install the PDFium headers."
    exit 1
fi

echo "check_pdfium_version: OK (bblanchon chromium/$INSTALLED)"
