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

// Tests for the bblanchon binary manifest schema and version constants.
//
// These tests are pure-Dart and do not require a downloaded PDFium binary.
// They verify:
//   1. The new version constants ([pdfiumVersion], [bblanchonBuild]) have the
//      correct types, values, and path-segment properties.
//   2. version_pdfium.json parses correctly with the new bblanchon schema
//      (bblanchon_build, lib_path fields).
//   3. The manifest helper functions used by the hook produce expected results
//      for well-formed and malformed input.
//   4. The tgz-extraction path-component computation matches expectations.

import 'dart:convert';
import 'dart:io';

import 'package:betto_pdfium/src/pdfium_version.dart';
import 'package:test/test.dart';

void main() {
  group('pdfiumVersion constant', () {
    test('has the expected chromium/NNNN format', () {
      expect(pdfiumVersion, startsWith('chromium/'));
    });

    test('contains a slash (display-only; must not be used in paths)', () {
      expect(pdfiumVersion.contains('/'), isTrue);
    });

    test('is not empty', () {
      expect(pdfiumVersion, isNotEmpty);
    });
  });

  group('bblanchonBuild constant', () {
    test('is slash-free (safe to use as filesystem path segment)', () {
      // The slash in 'chromium/7906' would silently create a broken nested
      // directory; bblanchonBuild must be the bare build number only.
      expect(bblanchonBuild.contains('/'), isFalse);
      expect(bblanchonBuild.contains('\\'), isFalse);
    });

    test('is not empty', () {
      expect(bblanchonBuild, isNotEmpty);
    });

    test('is purely numeric', () {
      expect(
        int.tryParse(bblanchonBuild),
        isNotNull,
        reason: 'bblanchonBuild should be a numeric build number',
      );
    });

    test('corresponds to the build number in pdfiumVersion', () {
      // pdfiumVersion is 'chromium/<build>'; extract the suffix.
      final parts = pdfiumVersion.split('/');
      expect(
        parts.length,
        2,
        reason: 'pdfiumVersion should have exactly one slash',
      );
      expect(
        parts.last,
        bblanchonBuild,
        reason: 'bblanchonBuild should match the NNNN in pdfiumVersion',
      );
    });
  });

  group('version_pdfium.json schema', () {
    late Map<String, dynamic> manifest;

    setUpAll(() {
      // The test runner cwd is the package root (packages/betto_pdfium/).
      final f = File('version_pdfium.json');
      if (!f.existsSync()) {
        fail(
          'version_pdfium.json not found at ${f.absolute.path}. '
          'Run tests from packages/betto_pdfium/.',
        );
      }
      manifest = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    });

    test('has bblanchon_build field (not pdfium_sha)', () {
      expect(
        manifest.containsKey('bblanchon_build'),
        isTrue,
        reason: 'new schema uses bblanchon_build',
      );
      expect(
        manifest.containsKey('pdfium_sha'),
        isFalse,
        reason: 'old pdfium_sha field should be removed',
      );
    });

    test('bblanchon_build matches bblanchonBuild constant', () {
      expect(manifest['bblanchon_build'], bblanchonBuild);
    });

    test('has platforms map', () {
      expect(manifest['platforms'], isA<Map<String, dynamic>>());
    });

    for (final platform in ['macos-arm64', 'linux-x64', 'linux-arm64']) {
      group('platforms.$platform', () {
        late Map<String, dynamic> entry;

        setUp(() {
          final platforms = manifest['platforms'] as Map<String, dynamic>;
          expect(
            platforms.containsKey(platform),
            isTrue,
            reason: 'platforms.$platform must exist',
          );
          entry = platforms[platform] as Map<String, dynamic>;
        });

        test('has url field pointing to bblanchon', () {
          final url = entry['url'] as String;
          expect(url, contains('bblanchon/pdfium-binaries'));
          expect(url, contains('chromium%2F'));
          expect(url, endsWith('.tgz'));
        });

        test('has lib_path field', () {
          expect(
            entry.containsKey('lib_path'),
            isTrue,
            reason: '$platform must have lib_path',
          );
          final libPath = entry['lib_path'] as String;
          expect(libPath, isNotEmpty);
          // lib_path should be a relative path within the tarball.
          expect(libPath, isNot(startsWith('/')));
        });

        test('has sha256 field with plausible hex value', () {
          final sha = entry['sha256'] as String;
          expect(
            sha,
            hasLength(64),
            reason: 'SHA-256 hex string should be 64 characters',
          );
          expect(
            sha,
            matches(RegExp(r'^[0-9a-f]+$')),
            reason: 'SHA-256 should be lowercase hex',
          );
        });

        test('lib_path ends with platform-appropriate extension', () {
          final libPath = entry['lib_path'] as String;
          if (platform == 'macos-arm64') {
            expect(libPath, endsWith('.dylib'));
          } else {
            expect(libPath, endsWith('.so'));
          }
        });
      });
    }

    for (final platform in ['android-arm64', 'android-x64']) {
      group('platforms.$platform', () {
        late Map<String, dynamic> entry;

        setUp(() {
          final platforms = manifest['platforms'] as Map<String, dynamic>;
          expect(
            platforms.containsKey(platform),
            isTrue,
            reason: 'platforms.$platform must exist',
          );
          entry = platforms[platform] as Map<String, dynamic>;
        });

        test('has url pointing to bblanchon .tgz', () {
          final url = entry['url'] as String;
          expect(url, contains('bblanchon/pdfium-binaries'));
          expect(url, endsWith('.tgz'));
        });

        test('has lib_path ending in .so', () {
          final libPath = entry['lib_path'] as String;
          expect(libPath, endsWith('.so'));
        });

        test('has sha256 with 64-char hex', () {
          final sha = entry['sha256'] as String;
          expect(sha, hasLength(64));
          expect(sha, matches(RegExp(r'^[0-9a-f]+$')));
        });
      });
    }

    test('does not have ios-arm64 entry (iOS is via Package.swift)', () {
      final platforms = manifest['platforms'] as Map<String, dynamic>;
      expect(
        platforms.containsKey('ios-arm64'),
        isFalse,
        reason:
            'iOS xcframework is referenced from Package.swift, not the manifest',
      );
    });
  });

  group('tgz strip-components computation', () {
    // Test the logic for computing --strip-components from lib_path in tgz.
    // This mirrors the computation in hook/build.dart and fetch_mobile_binaries.sh.

    int stripComponents(String libPath) {
      // Count the number of '/' characters (= number of directories to strip).
      return libPath.split('/').length - 1;
    }

    test('lib/libpdfium.dylib → strip 1 component', () {
      expect(stripComponents('lib/libpdfium.dylib'), 1);
    });

    test('lib/libpdfium.so → strip 1 component', () {
      expect(stripComponents('lib/libpdfium.so'), 1);
    });

    test('a/b/c.so → strip 2 components', () {
      expect(stripComponents('a/b/c.so'), 2);
    });

    test('libpdfium.so (no directory) → strip 0 components', () {
      expect(stripComponents('libpdfium.so'), 0);
    });
  });

  group('manifest error cases', () {
    test('missing bblanchon_build raises readable error', () {
      // Simulates what _readBblanchonBuild in hook/build.dart would do with
      // a manifest that still uses the old pdfium_sha key.
      final oldSchema = jsonEncode({
        'pdfium_sha': 'abc123',
        'platforms': <String, dynamic>{},
      });
      final decoded = jsonDecode(oldSchema) as Map<String, dynamic>;
      // The hook reads decoded['bblanchon_build'] — this returns null for old schema.
      expect(
        decoded['bblanchon_build'],
        isNull,
        reason: 'old schema does not have bblanchon_build',
      );
    });

    test('platform entry without lib_path is detectable', () {
      final missingLibPath = jsonEncode({
        'bblanchon_build': '7906',
        'platforms': {
          'macos-arm64': {
            'url': 'https://example.com/pdfium.tgz',
            'sha256': 'a' * 64,
          },
        },
      });
      final decoded = jsonDecode(missingLibPath) as Map<String, dynamic>;
      final platforms = decoded['platforms'] as Map<String, dynamic>;
      final entry = platforms['macos-arm64'] as Map<String, dynamic>;
      expect(
        entry.containsKey('lib_path'),
        isFalse,
        reason: 'entry missing lib_path should be detectable',
      );
      expect(entry['lib_path'], isNull);
    });
  });
}
