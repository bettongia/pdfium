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

// Unit tests for PdfPageSize.
//
// Covers aspectRatio, sizeForDpi, toString, equality, and hashCode.
// No native binary is required — all construction is in-process.

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // aspectRatio
  // ---------------------------------------------------------------------------

  group('PdfPageSize.aspectRatio', () {
    test('A4 portrait: 595 x 842 pt yields ~0.707', () {
      const size = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      expect(size.aspectRatio, closeTo(595.0 / 842.0, 0.001));
    });

    test('square page yields 1.0', () {
      const size = PdfPageSize(widthPt: 500.0, heightPt: 500.0);
      expect(size.aspectRatio, equals(1.0));
    });

    test('landscape page: width > height', () {
      const size = PdfPageSize(widthPt: 842.0, heightPt: 595.0);
      expect(size.aspectRatio, greaterThan(1.0));
    });

    test('zero height returns 1.0 (division-by-zero guard)', () {
      // A malformed page with zero height should not throw.
      const size = PdfPageSize(widthPt: 100.0, heightPt: 0.0);
      expect(size.aspectRatio, equals(1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // sizeForDpi
  // ---------------------------------------------------------------------------

  group('PdfPageSize.sizeForDpi', () {
    test('A4 at 150 DPI: ~1239 x 1754 px', () {
      const size = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      final px = size.sizeForDpi(150);
      // 595 * (150/72) ≈ 1239.58; 842 * (150/72) ≈ 1754.17
      expect(px.width, closeTo(1239.58, 0.5));
      expect(px.height, closeTo(1754.17, 0.5));
    });

    test('at 72 DPI the pixel size equals the point size', () {
      const size = PdfPageSize(widthPt: 300.0, heightPt: 400.0);
      final px = size.sizeForDpi(72);
      expect(px.width, closeTo(300.0, 0.001));
      expect(px.height, closeTo(400.0, 0.001));
    });

    test('zero DPI returns (0.0, 0.0)', () {
      const size = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      final px = size.sizeForDpi(0);
      expect(px.width, equals(0.0));
      expect(px.height, equals(0.0));
    });

    test('negative DPI returns (0.0, 0.0)', () {
      const size = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      final px = size.sizeForDpi(-100);
      expect(px.width, equals(0.0));
      expect(px.height, equals(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // toString
  // ---------------------------------------------------------------------------

  group('PdfPageSize.toString', () {
    test('contains widthPt and heightPt values', () {
      const size = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      final s = size.toString();
      expect(s, contains('595.0'));
      expect(s, contains('842.0'));
    });

    test('contains PdfPageSize label', () {
      const size = PdfPageSize(widthPt: 100.0, heightPt: 200.0);
      expect(size.toString(), contains('PdfPageSize'));
    });
  });

  // ---------------------------------------------------------------------------
  // Equality and hashCode
  // ---------------------------------------------------------------------------

  group('PdfPageSize equality', () {
    test('same values are equal', () {
      const a = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      const b = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      expect(a, equals(b));
    });

    test('identical object equals itself', () {
      const a = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      expect(a == a, isTrue);
    });

    test('differing width is not equal', () {
      const a = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      const b = PdfPageSize(widthPt: 500.0, heightPt: 842.0);
      expect(a, isNot(equals(b)));
    });

    test('differing height is not equal', () {
      const a = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      const b = PdfPageSize(widthPt: 595.0, heightPt: 700.0);
      expect(a, isNot(equals(b)));
    });

    test('not equal to a different type', () {
      const a = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      // ignore: unrelated_type_equality_checks
      expect(a == 'not a PdfPageSize', isFalse);
    });
  });

  group('PdfPageSize.hashCode', () {
    test('equal objects have equal hashCodes', () {
      const a = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      const b = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different objects typically have different hashCodes', () {
      const a = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      const b = PdfPageSize(widthPt: 100.0, heightPt: 200.0);
      // Not guaranteed by contract but true for these distinct values.
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });
}
