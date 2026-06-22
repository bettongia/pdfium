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

// Tests for PdfDocument.getThumbnail, PdfThumbnail, and PdfThumbnailSource.
//
// Sections:
//   1. Unit tests for PdfThumbnailSource enum.
//   2. Unit tests for PdfThumbnail value type (equality, hashCode, toString).
//   3. Integration tests against test/data/thumbnail_fixture.pdf via the
//      native PDFium backend. Skipped when the PDFium dylib is not present.
//
// Fixture:
//   test/data/thumbnail_fixture.pdf — two-page PDF where page 0 has an
//   embedded /Thumb stream (8×8 px, known BGRA content) and page 1 has none.
//   Created by test/fixtures/generate/generate_thumbnail_fixture.py.

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:betto_pdfium/src/document/pdfium_isolate.dart';

/// Path to the PDFium dylib.
const String _kDylibPath = 'third_party/pdfium_bin/macos_arm64/libpdfium.dylib';

/// Path to the thumbnail fixture PDF (committed binary).
const String _kFixturePath = 'test/data/thumbnail_fixture.pdf';

/// Returns true when the native PDFium dylib is present and we are on macOS.
bool _nativeAvailable() => Platform.isMacOS && File(_kDylibPath).existsSync();

/// Reads the thumbnail fixture PDF bytes.
Uint8List _readThumbnailFixture() {
  final file = File(_kFixturePath);
  if (!file.existsSync()) {
    throw StateError(
      'Thumbnail fixture not found: $_kFixturePath. '
      'Ensure test/data/thumbnail_fixture.pdf is committed.',
    );
  }
  return file.readAsBytesSync();
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. Unit tests for PdfThumbnailSource
  // ---------------------------------------------------------------------------

  group('PdfThumbnailSource', () {
    test('has exactly two values', () {
      expect(PdfThumbnailSource.values, hasLength(2));
    });

    test('embedded and rendered values exist', () {
      expect(PdfThumbnailSource.embedded, isNotNull);
      expect(PdfThumbnailSource.rendered, isNotNull);
    });

    test('embedded and rendered are distinct', () {
      expect(PdfThumbnailSource.embedded, isNot(PdfThumbnailSource.rendered));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Unit tests for PdfThumbnail value type
  // ---------------------------------------------------------------------------

  group('PdfThumbnail', () {
    // Uint8List.fromList is not a const expression, so these must be `final`.
    final bgra2x1 = Uint8List.fromList([0, 0, 255, 255, 255, 255, 0, 255]);

    late PdfThumbnail thumb;

    setUp(() {
      thumb = PdfThumbnail(
        bgra: bgra2x1,
        width: 2,
        height: 1,
        source: PdfThumbnailSource.embedded,
      );
    });

    test('width, height, source are set correctly', () {
      expect(thumb.width, equals(2));
      expect(thumb.height, equals(1));
      expect(thumb.source, equals(PdfThumbnailSource.embedded));
    });

    test('bgra length matches width * height * 4', () {
      expect(thumb.bgra.length, equals(thumb.width * thumb.height * 4));
    });

    test('equality: same dimensions and source are equal', () {
      // bgra is intentionally excluded from equality to avoid large comparisons.
      final other = PdfThumbnail(
        bgra: Uint8List.fromList([99, 99, 99, 99, 99, 99, 99, 99]),
        width: 2,
        height: 1,
        source: PdfThumbnailSource.embedded,
      );
      expect(thumb, equals(other));
    });

    test('equality: different width is not equal', () {
      final other = PdfThumbnail(
        bgra: bgra2x1,
        width: 1,
        height: 1,
        source: PdfThumbnailSource.embedded,
      );
      expect(thumb, isNot(equals(other)));
    });

    test('equality: different height is not equal', () {
      final other = PdfThumbnail(
        bgra: bgra2x1,
        width: 2,
        height: 2,
        source: PdfThumbnailSource.embedded,
      );
      expect(thumb, isNot(equals(other)));
    });

    test('equality: different source is not equal', () {
      final other = PdfThumbnail(
        bgra: bgra2x1,
        width: 2,
        height: 1,
        source: PdfThumbnailSource.rendered,
      );
      expect(thumb, isNot(equals(other)));
    });

    test('hashCode: same dimensions and source produce same hash', () {
      final other = PdfThumbnail(
        bgra: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        width: 2,
        height: 1,
        source: PdfThumbnailSource.embedded,
      );
      expect(thumb.hashCode, equals(other.hashCode));
    });

    test('toString contains key fields', () {
      final s = thumb.toString();
      expect(s, contains('width: 2'));
      expect(s, contains('height: 1'));
      expect(s, contains('embedded'));
      expect(s, contains('bgra'));
    });

    test('identical instances are equal', () {
      // Exercise the identical() fast-path in operator==.
      expect(thumb, equals(thumb));
    });

    test('equality against non-PdfThumbnail returns false', () {
      // ignore: unrelated_type_equality_checks
      expect(thumb == 'not a thumbnail', isFalse);
    });

    test('bgra field is accessible and matches construction value', () {
      expect(thumb.bgra, isNotNull);
      expect(thumb.bgra, equals(bgra2x1));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Integration tests (require native PDFium dylib)
  // ---------------------------------------------------------------------------

  group('getThumbnail integration', () {
    late PdfDocument doc;

    setUp(() async {
      if (!_nativeAvailable()) return;
      // Reset isolate state between tests to avoid cross-test pollution.
      PdfiumIsolate.resetForTesting();
      doc = await PdfDocument.fromBytes(
        _readThumbnailFixture(),
        dylibPath: _kDylibPath,
      );
    });

    tearDown(() async {
      if (!_nativeAvailable()) return;
      try {
        await doc.close();
      } catch (_) {
        // Already closed in some tests; ignore.
      }
      PdfiumIsolate.resetForTesting();
    });

    // -------------------------------------------------------------------------
    // Embedded thumbnail (page 0)
    // -------------------------------------------------------------------------

    test('page 0 returns PdfThumbnail with source: embedded', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final thumb = await doc.getThumbnail(0);
      expect(thumb, isNotNull);
      expect(thumb!.source, equals(PdfThumbnailSource.embedded));
    });

    test('embedded thumbnail bgra length equals width * height * 4', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final thumb = await doc.getThumbnail(0);
      expect(thumb, isNotNull);
      expect(thumb!.bgra.length, equals(thumb.width * thumb.height * 4));
    });

    test('embedded thumbnail has positive width and height', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final thumb = await doc.getThumbnail(0);
      expect(thumb, isNotNull);
      expect(thumb!.width, greaterThan(0));
      expect(thumb.height, greaterThan(0));
    });

    test('embedded thumbnail BGRA bytes are non-trivially non-zero', () async {
      // At least one pixel should have a non-zero blue, green, or red
      // channel — an all-zero bitmap would indicate a read failure.
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final thumb = await doc.getThumbnail(0);
      expect(thumb, isNotNull);
      // Check that the pixel buffer is not entirely zero.
      final hasNonZero = thumb!.bgra.any((b) => b != 0);
      expect(
        hasNonZero,
        isTrue,
        reason: 'BGRA bytes were all zero — thumbnail data was not read',
      );
    });

    // -------------------------------------------------------------------------
    // No embedded thumbnail, generateIfAbsent: true (page 1)
    // -------------------------------------------------------------------------

    test(
      'page 1 with no thumbnail, generateIfAbsent: true returns rendered',
      () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        final thumb = await doc.getThumbnail(1);
        expect(thumb, isNotNull);
        expect(thumb!.source, equals(PdfThumbnailSource.rendered));
      },
    );

    test('rendered fallback bgra length equals width * height * 4', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final thumb = await doc.getThumbnail(1);
      expect(thumb, isNotNull);
      expect(thumb!.bgra.length, equals(thumb.width * thumb.height * 4));
    });

    test(
      'rendered fallback dimensions are at most maxDimension on longest edge',
      () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        const maxDim = 256;
        final thumb = await doc.getThumbnail(1, maxDimension: maxDim);
        expect(thumb, isNotNull);
        expect(thumb!.width, lessThanOrEqualTo(maxDim));
        expect(thumb.height, lessThanOrEqualTo(maxDim));
        // At least one edge should equal the maxDimension.
        expect(
          thumb.width == maxDim || thumb.height == maxDim,
          isTrue,
          reason:
              'Neither edge equals maxDimension $maxDim; '
              'got ${thumb.width}×${thumb.height}',
        );
      },
    );

    // -------------------------------------------------------------------------
    // No embedded thumbnail, generateIfAbsent: false (page 1)
    // -------------------------------------------------------------------------

    test('page 1 with generateIfAbsent: false returns null', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final thumb = await doc.getThumbnail(1, generateIfAbsent: false);
      expect(thumb, isNull);
    });

    // -------------------------------------------------------------------------
    // Custom maxDimension
    // -------------------------------------------------------------------------

    test('custom maxDimension is respected by fallback render path', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      // Use a small maxDimension to confirm the fallback respects it.
      const maxDim = 64;
      final thumb = await doc.getThumbnail(1, maxDimension: maxDim);
      expect(thumb, isNotNull);
      expect(thumb!.width, lessThanOrEqualTo(maxDim));
      expect(thumb.height, lessThanOrEqualTo(maxDim));
    });

    test(
      'larger maxDimension produces larger rendered output than smaller',
      () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        final small = await doc.getThumbnail(1, maxDimension: 32);
        final large = await doc.getThumbnail(1, maxDimension: 256);
        expect(small, isNotNull);
        expect(large, isNotNull);
        // The larger maxDimension should produce more pixels in at least one
        // dimension.
        expect(
          large!.width >= small!.width && large.height >= small.height,
          isTrue,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Error conditions
    // -------------------------------------------------------------------------

    test('negative page index throws RangeError', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      await expectLater(doc.getThumbnail(-1), throwsA(isA<RangeError>()));
    });

    test('page index >= pageCount throws RangeError', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final count = await doc.pageCount;
      await expectLater(doc.getThumbnail(count), throwsA(isA<RangeError>()));
    });

    test('maxDimension of 0 throws ArgumentError', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      await expectLater(
        doc.getThumbnail(0, maxDimension: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('maxDimension of -1 throws ArgumentError', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      await expectLater(
        doc.getThumbnail(0, maxDimension: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getThumbnail on a closed document throws StateError', () async {
      if (!_nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      await doc.close();
      await expectLater(doc.getThumbnail(0), throwsA(isA<StateError>()));
    });
  });
}
