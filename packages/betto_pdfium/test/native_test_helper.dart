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
// before running. Tests skip gracefully when the binary is absent.
//
// Binary discovery order (first existing path wins):
//   1. Legacy developer layout: third_party/pdfium_bin/{platform}/libpdfium.*
//      (populated by `make fetch_pdfium`).
//   2. Native-assets staged location: .dart_tool/lib/libpdfium.*
//      (populated by the Dart build system when `dart test` runs the hook).
//   3. Hook cache: .dart_tool/betto_pdfium/{sha}/libpdfium.*
//      (the hook's download cache; used as a direct fallback).

import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:betto_pdfium/src/pdfium_version.dart';

/// Returns the path to the platform-appropriate PDFium shared library,
/// or `null` when no binary can be found in any known location.
String? nativeDylibPath() {
  if (!Platform.isMacOS && !Platform.isLinux) return null;

  final candidates = _dylibCandidates();
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

/// Returns true when the native PDFium binary is present for this platform.
bool nativeAvailable() => nativeDylibPath() != null;

List<String> _dylibCandidates() {
  if (Platform.isLinux) {
    final arch = Abi.current() == Abi.linuxArm64 ? 'linux_arm64' : 'linux_x64';
    final libName = 'libpdfium.so';
    return [
      'third_party/pdfium_bin/$arch/$libName',
      '.dart_tool/lib/$libName',
      '.dart_tool/betto_pdfium/$pdfiumSha/$libName',
    ];
  }
  // macOS arm64.
  const libName = 'libpdfium.dylib';
  return [
    'third_party/pdfium_bin/macos_arm64/$libName',
    '.dart_tool/lib/$libName',
    '.dart_tool/betto_pdfium/$pdfiumSha/$libName',
  ];
}
