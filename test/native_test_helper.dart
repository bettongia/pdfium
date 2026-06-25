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

// Shared helpers for native PDFium integration tests.
//
// Tests that exercise the native PDFium backend import this file to obtain the
// platform-appropriate dylib path and to check whether the binary is present
// before running. Tests skip gracefully when the binary is absent (e.g. fresh
// checkout before `make fetch_pdfium` has been run).

import 'dart:ffi' show Abi;
import 'dart:io';

/// Returns the path to the platform-appropriate PDFium shared library.
///
/// Resolves against the package root (the directory where `dart test` runs).
/// Returns the macOS arm64 dylib on macOS, or the appropriate Linux .so based
/// on the current CPU architecture.
String nativeDylibPath() {
  if (Platform.isLinux) {
    final arch = Abi.current() == Abi.linuxArm64 ? 'linux_arm64' : 'linux_x64';
    return 'third_party/pdfium_bin/$arch/libpdfium.so';
  }
  return 'third_party/pdfium_bin/macos_arm64/libpdfium.dylib';
}

/// Returns true when the native PDFium binary is present for this platform.
///
/// Returns false on unsupported platforms (Windows, web) or when the binary
/// has not yet been fetched via `make fetch_pdfium`.
bool nativeAvailable() =>
    (Platform.isMacOS || Platform.isLinux) &&
    File(nativeDylibPath()).existsSync();
