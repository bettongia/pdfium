// Copyright 2026 The Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// PDFium version constant used by the native-assets hook and runtime loader.
//
// Update this alongside PDFIUM_VERSION and version_pdfium.json whenever the
// upstream PDFium commit SHA is bumped.

/// The PDFium commit SHA that this package is built against.
///
/// Used at runtime to locate the hook's binary cache directory
/// (`.dart_tool/betto_pdfium/{pdfiumSha}/`) as a fallback when the build
/// system has not staged the library to the standard adjacent-to-executable
/// location (e.g. during `dart run` in JIT mode).
const pdfiumSha = '75ea0a73e1cb08beabb2800b0ba3f5c931d2cdef';
