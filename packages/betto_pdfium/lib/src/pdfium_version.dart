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

// PDFium version constants used by the native-assets hook and runtime loader.
//
// Update these alongside BBLANCHON_BUILD and version_pdfium.json whenever the
// bblanchon/pdfium-binaries release is bumped.

/// Human-readable PDFium release identifier, matching the bblanchon tag.
///
/// This is the `chromium/NNNN` string used in log messages and documentation.
/// It is **not** safe to use as a filesystem path segment — the slash would
/// create an unintended nested directory. Use [bblanchonBuild] for paths.
const pdfiumVersion = 'chromium/7906';

/// Slash-free bblanchon build number used as a filesystem path segment.
///
/// Used at runtime to locate the hook's binary cache directory
/// (`.dart_tool/betto_pdfium/{bblanchonBuild}/`) as a fallback when the
/// build system has not staged the library to the standard
/// adjacent-to-executable location (e.g. during `dart run` in JIT mode).
///
/// Using the plain build number (e.g. `'7906'`) avoids the nested-directory
/// problem that a `chromium/7906` path segment would silently create.
///
/// Update this alongside [pdfiumVersion] and `BBLANCHON_BUILD` when bumping
/// the bblanchon release.
const bblanchonBuild = '7906';
