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

// Unit tests for dartToolLibCandidates — the native-library path walk-up that
// makes PDFium loadable from a Pub-workspace member package, where `dart test`
// stages the bundled library to the workspace ROOT `.dart_tool/lib/` rather
// than the package's own. Probing only the current directory (the pre-fix
// behaviour) missed that staging and broke consumers such as kmdb under Dart
// 3.13.

import 'dart:io';

import 'package:betto_pdfium/src/document/pdfium_isolate.dart'
    show dartToolLibCandidates;
import 'package:test/test.dart';

void main() {
  group('dartToolLibCandidates', () {
    test('probes the start directory first (nearest-first order)', () {
      final tmp = Directory.systemTemp.createTempSync('pdfium_cand_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final pkg = Directory('${tmp.path}/workspace/packages/kmdb_cli')
        ..createSync(recursive: true);

      final candidates = dartToolLibCandidates(pkg.path, 'libpdfium.so');

      expect(
        candidates.first,
        endsWith('kmdb_cli/.dart_tool/lib/libpdfium.so'),
        reason: 'the current directory must be tried before any ancestor',
      );
    });

    test('includes each ancestor directory, up to the filesystem root', () {
      final tmp = Directory.systemTemp.createTempSync('pdfium_cand_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final pkg = Directory('${tmp.path}/workspace/packages/kmdb_cli')
        ..createSync(recursive: true);

      final candidates = dartToolLibCandidates(pkg.path, 'libpdfium.so');

      // The workspace-root staging location (`{workspace}/.dart_tool/lib/`)
      // is the one the old single-cwd probe missed — it MUST be present.
      expect(
        candidates.any(
          (c) => c.endsWith('workspace/.dart_tool/lib/libpdfium.so'),
        ),
        isTrue,
        reason: 'the Pub-workspace root is an ancestor and must be probed',
      );
      // The `packages/` intermediate ancestor is present too.
      expect(
        candidates.any(
          (c) => c.endsWith('packages/.dart_tool/lib/libpdfium.so'),
        ),
        isTrue,
      );
    });

    test('terminates at the filesystem root without looping', () {
      // A path already at (or near) the root must still produce a finite list
      // whose final entry is the root's `.dart_tool/lib/` path — the
      // Directory.parent-of-root fixed point is the loop's exit condition.
      final candidates = dartToolLibCandidates(
        Directory.current.path,
        'libpdfium.so',
      );

      expect(candidates, isNotEmpty);
      final root = Directory.current;
      var top = root.absolute;
      while (top.parent.path != top.path) {
        top = top.parent;
      }
      expect(
        candidates.last,
        equals('${top.path}/.dart_tool/lib/libpdfium.so'),
      );
    });

    test('embeds the requested library name verbatim', () {
      final candidates = dartToolLibCandidates(
        Directory.current.path,
        'pdfium.dll',
      );

      expect(candidates, everyElement(endsWith('/.dart_tool/lib/pdfium.dll')));
    });
  });
}
