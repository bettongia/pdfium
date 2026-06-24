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

echo BUILD_DIR=$BUILD_DIR
echo PDFIUM_SRC=$PDFIUM_SRC
echo PDFIUM_OUT=${PDFIUM_OUT:-"(not set — run a build target)"}
echo DEPOT_TOOLS=$DEPOT_TOOLS
echo PDFIUM_REVISION=$PDFIUM_REVISION
echo BASE_DIR=$BASE_DIR
echo HOST_OS=$HOST_OS
