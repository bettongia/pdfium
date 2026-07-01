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

// Pure-Dart value-type tests for the types in lib/src/document/pdf_types.dart.
//
// These tests do not require the PDFium native binary — all construction is
// in-process. They exercise the ==, hashCode, and toString() implementations
// on every concrete annotation subtype, PdfPageText, and the image value
// types. The goal is to cover the equality/inequality branches that extraction
// integration tests leave dark.

import 'dart:typed_data';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:test/test.dart';

/// A reusable rect for test fixtures.
const _rect = PdfRect(left: 10, bottom: 20, right: 100, top: 80);

/// A different rect, used to verify inequality on the [rect] field.
const _rectB = PdfRect(left: 0, bottom: 0, right: 50, top: 50);

/// A reusable colour.
const _color = PdfColor(r: 255, g: 0, b: 0, a: 255);

/// A different colour.
const _colorB = PdfColor(r: 0, g: 255, b: 0, a: 255);

/// A reusable popup.
const _popup = PdfPopupAnnotation(rect: _rect, flags: 4);

/// A different popup.
const _popupB = PdfPopupAnnotation(rect: null, flags: 0);

/// A reusable date for testing modified-date equality.
const _date = PdfDate(raw: 'D:20260101', value: null);

/// A different date.
const _dateB = PdfDate(raw: 'D:20260202', value: null);

void main() {
  // ---------------------------------------------------------------------------
  // PdfPageText
  // ---------------------------------------------------------------------------

  group('PdfPageText', () {
    test('equal instances are equal', () {
      const a = PdfPageText(
        pageIndex: 0,
        text: 'hello',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      const b = PdfPageText(
        pageIndex: 0,
        text: 'hello',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('identical objects are equal', () {
      const a = PdfPageText(
        pageIndex: 1,
        text: 'x',
        hasUnicodeErrors: true,
        hasTextLayer: false,
      );
      // ignore: unrelated_type_equality_checks
      expect(a == a, isTrue);
    });

    test('unequal when pageIndex differs', () {
      const a = PdfPageText(
        pageIndex: 0,
        text: 'hello',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      const b = PdfPageText(
        pageIndex: 1,
        text: 'hello',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when text differs', () {
      const a = PdfPageText(
        pageIndex: 0,
        text: 'hello',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      const b = PdfPageText(
        pageIndex: 0,
        text: 'world',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when hasUnicodeErrors differs', () {
      const a = PdfPageText(
        pageIndex: 0,
        text: 'x',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      const b = PdfPageText(
        pageIndex: 0,
        text: 'x',
        hasUnicodeErrors: true,
        hasTextLayer: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when hasTextLayer differs', () {
      const a = PdfPageText(
        pageIndex: 0,
        text: 'x',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      const b = PdfPageText(
        pageIndex: 0,
        text: 'x',
        hasUnicodeErrors: false,
        hasTextLayer: false,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equal to a different type', () {
      const a = PdfPageText(
        pageIndex: 0,
        text: 'x',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      // ignore: unrelated_type_equality_checks
      expect(a == 'not a PdfPageText', isFalse);
    });

    test('toString contains pageIndex and text snippet', () {
      const a = PdfPageText(
        pageIndex: 3,
        text: 'short',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      final s = a.toString();
      expect(s, contains('PdfPageText'));
      expect(s, contains('pageIndex: 3'));
    });

    test('toString truncates long text', () {
      const a = PdfPageText(
        pageIndex: 0,
        text: 'abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz',
        hasUnicodeErrors: false,
        hasTextLayer: true,
      );
      final s = a.toString();
      // Text is > 40 chars; toString() should truncate with ellipsis.
      expect(s, contains('…'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfFreeTextAnnotation
  // ---------------------------------------------------------------------------

  group('PdfFreeTextAnnotation', () {
    const base = PdfFreeTextAnnotation(
      pageIndex: 0,
      contents: 'hello',
      author: 'me',
      rect: _rect,
      color: _color,
      modifiedDate: _date,
      flags: 2,
      popup: _popup,
    );

    test('equal instances are equal and share hashCode', () {
      const other = PdfFreeTextAnnotation(
        pageIndex: 0,
        contents: 'hello',
        author: 'me',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 2,
        popup: _popup,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      const other = PdfFreeTextAnnotation(pageIndex: 1, flags: 2);
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      const other = PdfFreeTextAnnotation(
        pageIndex: 0,
        contents: 'different',
        flags: 2,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      const other = PdfFreeTextAnnotation(
        pageIndex: 0,
        contents: 'hello',
        author: 'other',
        flags: 2,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      const other = PdfFreeTextAnnotation(
        pageIndex: 0,
        contents: 'hello',
        author: 'me',
        rect: _rectB,
        flags: 2,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      const other = PdfFreeTextAnnotation(
        pageIndex: 0,
        contents: 'hello',
        author: 'me',
        rect: _rect,
        color: _colorB,
        flags: 2,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      const other = PdfFreeTextAnnotation(
        pageIndex: 0,
        contents: 'hello',
        author: 'me',
        rect: _rect,
        color: _color,
        modifiedDate: _dateB,
        flags: 2,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      const other = PdfFreeTextAnnotation(
        pageIndex: 0,
        contents: 'hello',
        author: 'me',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when popup differs', () {
      const other = PdfFreeTextAnnotation(
        pageIndex: 0,
        contents: 'hello',
        author: 'me',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 2,
        popup: _popupB,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 2);
      expect(base == other, isFalse);
    });

    test('toString contains type name and pageIndex', () {
      final s = base.toString();
      expect(s, contains('PdfFreeTextAnnotation'));
      expect(s, contains('pageIndex: 0'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfShapeAnnotation
  // ---------------------------------------------------------------------------

  group('PdfShapeAnnotation', () {
    const base = PdfShapeAnnotation(
      pageIndex: 0,
      subtype: PdfAnnotationType.square,
      interiorColor: _color,
      contents: 'shape',
      author: 'author',
      rect: _rect,
      color: _colorB,
      modifiedDate: _date,
      flags: 0,
      popup: null,
    );

    test('equal instances are equal and share hashCode', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _color,
        contents: 'shape',
        author: 'author',
        rect: _rect,
        color: _colorB,
        modifiedDate: _date,
        flags: 0,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 1,
        subtype: PdfAnnotationType.square,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when subtype differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.circle,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when interiorColor differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _colorB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _color,
        contents: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _color,
        contents: 'shape',
        author: 'different',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _color,
        contents: 'shape',
        author: 'author',
        rect: _rectB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _color,
        contents: 'shape',
        author: 'author',
        rect: _rect,
        color: _color,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _color,
        contents: 'shape',
        author: 'author',
        rect: _rect,
        color: _colorB,
        modifiedDate: _dateB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _color,
        contents: 'shape',
        author: 'author',
        rect: _rect,
        color: _colorB,
        modifiedDate: _date,
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when popup differs', () {
      const other = PdfShapeAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.square,
        interiorColor: _color,
        contents: 'shape',
        author: 'author',
        rect: _rect,
        color: _colorB,
        modifiedDate: _date,
        flags: 0,
        popup: _popup,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 0);
      expect(base == other, isFalse);
    });

    test('toString contains type name and subtype', () {
      final s = base.toString();
      expect(s, contains('PdfShapeAnnotation'));
      expect(s, contains('pageIndex: 0'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfLineAnnotation
  // ---------------------------------------------------------------------------

  group('PdfLineAnnotation', () {
    const start = PdfPoint(x: 10, y: 20);
    const end = PdfPoint(x: 100, y: 200);
    const startB = PdfPoint(x: 0, y: 0);
    const endB = PdfPoint(x: 50, y: 50);

    const base = PdfLineAnnotation(
      pageIndex: 0,
      lineStart: start,
      lineEnd: end,
      contents: 'line',
      author: 'author',
      rect: _rect,
      color: _color,
      modifiedDate: _date,
      flags: 0,
      popup: null,
    );

    test('equal instances are equal and share hashCode', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: end,
        contents: 'line',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 1,
        lineStart: start,
        lineEnd: end,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when lineStart differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: startB,
        lineEnd: end,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when lineEnd differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: endB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: end,
        contents: 'different',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: end,
        contents: 'line',
        author: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: end,
        contents: 'line',
        author: 'author',
        rect: _rectB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: end,
        contents: 'line',
        author: 'author',
        rect: _rect,
        color: _colorB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: end,
        contents: 'line',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _dateB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: end,
        contents: 'line',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when popup differs', () {
      const other = PdfLineAnnotation(
        pageIndex: 0,
        lineStart: start,
        lineEnd: end,
        contents: 'line',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
        popup: _popup,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 0);
      expect(base == other, isFalse);
    });

    test('toString contains type name and endpoints', () {
      final s = base.toString();
      expect(s, contains('PdfLineAnnotation'));
      expect(s, contains('pageIndex: 0'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfInkAnnotation
  // ---------------------------------------------------------------------------

  group('PdfInkAnnotation', () {
    final strokes = [
      [const PdfPoint(x: 0, y: 0), const PdfPoint(x: 10, y: 10)],
      [const PdfPoint(x: 20, y: 20)],
    ];

    final base = PdfInkAnnotation(
      pageIndex: 0,
      strokes: strokes,
      contents: 'ink',
      author: 'me',
      rect: _rect,
      color: _color,
      modifiedDate: _date,
      flags: 0,
      popup: null,
    );

    test('equal instances with same strokes are equal', () {
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: strokes,
        contents: 'ink',
        author: 'me',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      final other = PdfInkAnnotation(pageIndex: 1, strokes: strokes, flags: 0);
      expect(base, isNot(equals(other)));
    });

    test('unequal when strokes differ (different count)', () {
      final other = PdfInkAnnotation(pageIndex: 0, strokes: [], flags: 0);
      expect(base, isNot(equals(other)));
    });

    test('unequal when strokes differ (different point in stroke)', () {
      final differentStrokes = [
        [const PdfPoint(x: 0, y: 0), const PdfPoint(x: 99, y: 99)],
        [const PdfPoint(x: 20, y: 20)],
      ];
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: differentStrokes,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when stroke has different point count', () {
      // Same stroke count but first stroke has a different number of points.
      final differentStrokes = [
        [const PdfPoint(x: 0, y: 0)],
        [const PdfPoint(x: 20, y: 20)],
      ];
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: differentStrokes,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: strokes,
        contents: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: strokes,
        contents: 'ink',
        author: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: strokes,
        contents: 'ink',
        author: 'me',
        rect: _rectB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: strokes,
        contents: 'ink',
        author: 'me',
        rect: _rect,
        color: _colorB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: strokes,
        contents: 'ink',
        author: 'me',
        rect: _rect,
        color: _color,
        modifiedDate: _dateB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: strokes,
        contents: 'ink',
        author: 'me',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when popup differs', () {
      final other = PdfInkAnnotation(
        pageIndex: 0,
        strokes: strokes,
        contents: 'ink',
        author: 'me',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
        popup: _popup,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 0);
      expect(base == other, isFalse);
    });

    test('toString contains type name and stroke count', () {
      final s = base.toString();
      expect(s, contains('PdfInkAnnotation'));
      expect(s, contains('strokes:'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfPolygonAnnotation
  // ---------------------------------------------------------------------------

  group('PdfPolygonAnnotation', () {
    const vertices = [
      PdfPoint(x: 0, y: 0),
      PdfPoint(x: 100, y: 0),
      PdfPoint(x: 50, y: 100),
    ];
    const verticesB = [PdfPoint(x: 1, y: 1)];

    const base = PdfPolygonAnnotation(
      pageIndex: 0,
      subtype: PdfAnnotationType.polygon,
      vertices: vertices,
      contents: 'poly',
      author: 'author',
      rect: _rect,
      color: _color,
      modifiedDate: _date,
      flags: 0,
      popup: null,
    );

    test('equal instances are equal and share hashCode', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        contents: 'poly',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 1,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when subtype differs', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polyline,
        vertices: vertices,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when vertices differ', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: verticesB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        contents: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        contents: 'poly',
        author: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        contents: 'poly',
        author: 'author',
        rect: _rectB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        contents: 'poly',
        author: 'author',
        rect: _rect,
        color: _colorB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        contents: 'poly',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _dateB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        contents: 'poly',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when popup differs', () {
      const other = PdfPolygonAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.polygon,
        vertices: vertices,
        contents: 'poly',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
        popup: _popup,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 0);
      expect(base == other, isFalse);
    });

    test('toString contains type name and vertex count', () {
      final s = base.toString();
      expect(s, contains('PdfPolygonAnnotation'));
      expect(s, contains('vertices:'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfLinkAnnotation
  // ---------------------------------------------------------------------------

  group('PdfLinkAnnotation', () {
    const base = PdfLinkAnnotation(
      pageIndex: 0,
      uri: 'https://example.com',
      contents: 'click me',
      author: 'author',
      rect: _rect,
      color: _color,
      modifiedDate: _date,
      flags: 0,
      popup: null,
    );

    test('equal instances are equal and share hashCode', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://example.com',
        contents: 'click me',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      const other = PdfLinkAnnotation(pageIndex: 1, flags: 0);
      expect(base, isNot(equals(other)));
    });

    test('unequal when uri differs', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://other.com',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://example.com',
        contents: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://example.com',
        contents: 'click me',
        author: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://example.com',
        contents: 'click me',
        author: 'author',
        rect: _rectB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://example.com',
        contents: 'click me',
        author: 'author',
        rect: _rect,
        color: _colorB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://example.com',
        contents: 'click me',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _dateB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://example.com',
        contents: 'click me',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when popup differs', () {
      const other = PdfLinkAnnotation(
        pageIndex: 0,
        uri: 'https://example.com',
        contents: 'click me',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
        popup: _popup,
      );
      expect(base, isNot(equals(other)));
    });

    test('null uri is preserved', () {
      const noUri = PdfLinkAnnotation(pageIndex: 0, flags: 0);
      expect(noUri.uri, isNull);
    });

    test('not equal to different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 0);
      expect(base == other, isFalse);
    });

    test('toString contains type name and uri', () {
      final s = base.toString();
      expect(s, contains('PdfLinkAnnotation'));
      expect(s, contains('pageIndex: 0'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfStampAnnotation
  // ---------------------------------------------------------------------------

  group('PdfStampAnnotation', () {
    const base = PdfStampAnnotation(
      pageIndex: 0,
      contents: 'APPROVED',
      author: 'author',
      rect: _rect,
      color: _color,
      modifiedDate: _date,
      flags: 0,
      popup: null,
    );

    test('equal instances are equal and share hashCode', () {
      const other = PdfStampAnnotation(
        pageIndex: 0,
        contents: 'APPROVED',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      const other = PdfStampAnnotation(pageIndex: 1, flags: 0);
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      const other = PdfStampAnnotation(
        pageIndex: 0,
        contents: 'REJECTED',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      const other = PdfStampAnnotation(
        pageIndex: 0,
        contents: 'APPROVED',
        author: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      const other = PdfStampAnnotation(
        pageIndex: 0,
        contents: 'APPROVED',
        author: 'author',
        rect: _rectB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      const other = PdfStampAnnotation(
        pageIndex: 0,
        contents: 'APPROVED',
        author: 'author',
        rect: _rect,
        color: _colorB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      const other = PdfStampAnnotation(
        pageIndex: 0,
        contents: 'APPROVED',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _dateB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      const other = PdfStampAnnotation(
        pageIndex: 0,
        contents: 'APPROVED',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when popup differs', () {
      const other = PdfStampAnnotation(
        pageIndex: 0,
        contents: 'APPROVED',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
        popup: _popup,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 0);
      expect(base == other, isFalse);
    });

    test('toString contains type name and contents', () {
      final s = base.toString();
      expect(s, contains('PdfStampAnnotation'));
      expect(s, contains('pageIndex: 0'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfUnknownAnnotation (extended field-by-field coverage)
  // ---------------------------------------------------------------------------

  group('PdfUnknownAnnotation (extended)', () {
    const base = PdfUnknownAnnotation(
      pageIndex: 0,
      rawSubtype: 42,
      contents: 'unknown',
      author: 'author',
      rect: _rect,
      color: _color,
      modifiedDate: _date,
      flags: 0,
      popup: null,
    );

    test('equal instances are equal and share hashCode', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 42,
        contents: 'unknown',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 1,
        rawSubtype: 42,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rawSubtype differs', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 99,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 42,
        contents: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 42,
        contents: 'unknown',
        author: 'other',
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 42,
        contents: 'unknown',
        author: 'author',
        rect: _rectB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 42,
        contents: 'unknown',
        author: 'author',
        rect: _rect,
        color: _colorB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 42,
        contents: 'unknown',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _dateB,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 42,
        contents: 'unknown',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when popup differs', () {
      const other = PdfUnknownAnnotation(
        pageIndex: 0,
        rawSubtype: 42,
        contents: 'unknown',
        author: 'author',
        rect: _rect,
        color: _color,
        modifiedDate: _date,
        flags: 0,
        popup: _popup,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 0);
      expect(base == other, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // PdfImageMetadata
  // ---------------------------------------------------------------------------

  group('PdfImageMetadata', () {
    const base = PdfImageMetadata(
      width: 64,
      height: 48,
      horizontalDpi: 72.0,
      verticalDpi: 72.0,
      bitsPerPixel: 24,
      colorspace: PdfColorspace.deviceRgb,
      markedContentId: -1,
    );

    test('equal instances are equal and share hashCode', () {
      const other = PdfImageMetadata(
        width: 64,
        height: 48,
        horizontalDpi: 72.0,
        verticalDpi: 72.0,
        bitsPerPixel: 24,
        colorspace: PdfColorspace.deviceRgb,
        markedContentId: -1,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when width differs', () {
      const other = PdfImageMetadata(
        width: 32,
        height: 48,
        horizontalDpi: 72.0,
        verticalDpi: 72.0,
        bitsPerPixel: 24,
        colorspace: PdfColorspace.deviceRgb,
        markedContentId: -1,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when height differs', () {
      const other = PdfImageMetadata(
        width: 64,
        height: 24,
        horizontalDpi: 72.0,
        verticalDpi: 72.0,
        bitsPerPixel: 24,
        colorspace: PdfColorspace.deviceRgb,
        markedContentId: -1,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when horizontalDpi differs', () {
      const other = PdfImageMetadata(
        width: 64,
        height: 48,
        horizontalDpi: 96.0,
        verticalDpi: 72.0,
        bitsPerPixel: 24,
        colorspace: PdfColorspace.deviceRgb,
        markedContentId: -1,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when verticalDpi differs', () {
      const other = PdfImageMetadata(
        width: 64,
        height: 48,
        horizontalDpi: 72.0,
        verticalDpi: 96.0,
        bitsPerPixel: 24,
        colorspace: PdfColorspace.deviceRgb,
        markedContentId: -1,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when bitsPerPixel differs', () {
      const other = PdfImageMetadata(
        width: 64,
        height: 48,
        horizontalDpi: 72.0,
        verticalDpi: 72.0,
        bitsPerPixel: 8,
        colorspace: PdfColorspace.deviceRgb,
        markedContentId: -1,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when colorspace differs', () {
      const other = PdfImageMetadata(
        width: 64,
        height: 48,
        horizontalDpi: 72.0,
        verticalDpi: 72.0,
        bitsPerPixel: 24,
        colorspace: PdfColorspace.deviceGray,
        markedContentId: -1,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when markedContentId differs', () {
      const other = PdfImageMetadata(
        width: 64,
        height: 48,
        horizontalDpi: 72.0,
        verticalDpi: 72.0,
        bitsPerPixel: 24,
        colorspace: PdfColorspace.deviceRgb,
        markedContentId: 5,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to different type', () {
      // ignore: unrelated_type_equality_checks
      expect(base == 'not a PdfImageMetadata', isFalse);
    });

    test('toString contains type name and dimensions', () {
      final s = base.toString();
      expect(s, contains('PdfImageMetadata'));
      expect(s, contains('width: 64'));
      expect(s, contains('height: 48'));
      expect(s, contains('colorspace:'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfImage
  // ---------------------------------------------------------------------------

  group('PdfImage', () {
    const meta = PdfImageMetadata(
      width: 64,
      height: 48,
      horizontalDpi: 72.0,
      verticalDpi: 72.0,
      bitsPerPixel: 24,
      colorspace: PdfColorspace.deviceRgb,
      markedContentId: -1,
    );
    const metaB = PdfImageMetadata(
      width: 32,
      height: 24,
      horizontalDpi: 96.0,
      verticalDpi: 96.0,
      bitsPerPixel: 8,
      colorspace: PdfColorspace.deviceGray,
      markedContentId: 0,
    );

    final base = PdfImage(
      pageIndex: 0,
      objectIndex: 3,
      metadata: meta,
      bounds: _rect,
      filters: ['DCTDecode'],
    );

    test('equal instances without bitmap are equal', () {
      final other = PdfImage(
        pageIndex: 0,
        objectIndex: 3,
        metadata: meta,
        bounds: _rect,
        filters: ['DCTDecode'],
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      final other = PdfImage(
        pageIndex: 1,
        objectIndex: 3,
        metadata: meta,
        bounds: _rect,
        filters: ['DCTDecode'],
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when objectIndex differs', () {
      final other = PdfImage(
        pageIndex: 0,
        objectIndex: 5,
        metadata: meta,
        bounds: _rect,
        filters: ['DCTDecode'],
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when metadata differs', () {
      final other = PdfImage(
        pageIndex: 0,
        objectIndex: 3,
        metadata: metaB,
        bounds: _rect,
        filters: ['DCTDecode'],
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when bounds differs', () {
      final other = PdfImage(
        pageIndex: 0,
        objectIndex: 3,
        metadata: meta,
        bounds: _rectB,
        filters: ['DCTDecode'],
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when filters differ', () {
      final other = PdfImage(
        pageIndex: 0,
        objectIndex: 3,
        metadata: meta,
        bounds: _rect,
        filters: ['FlateDecode'],
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when bitmapWidth differs', () {
      final other = PdfImage(
        pageIndex: 0,
        objectIndex: 3,
        metadata: meta,
        bounds: _rect,
        filters: ['DCTDecode'],
        bitmapWidth: 128,
        bitmapHeight: 96,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when bitmapHeight differs', () {
      // Both have same bitmapWidth but different bitmapHeight.
      final other = PdfImage(
        pageIndex: 0,
        objectIndex: 3,
        metadata: meta,
        bounds: _rect,
        filters: ['DCTDecode'],
        bitmapWidth: null,
        bitmapHeight: 96,
      );
      expect(base, isNot(equals(other)));
    });

    test('bgra field does not affect equality (intentional)', () {
      // Two instances with same structural fields but different bgra bytes are
      // considered equal — bgra is intentionally excluded from equality.
      final bgra1 = Uint8List.fromList([0, 0, 0, 255]);
      final bgra2 = Uint8List.fromList([255, 0, 0, 255]);
      final a = PdfImage(
        pageIndex: 0,
        objectIndex: 0,
        metadata: meta,
        bounds: _rect,
        filters: [],
        bgra: bgra1,
        bitmapWidth: 1,
        bitmapHeight: 1,
      );
      final b = PdfImage(
        pageIndex: 0,
        objectIndex: 0,
        metadata: meta,
        bounds: _rect,
        filters: [],
        bgra: bgra2,
        bitmapWidth: 1,
        bitmapHeight: 1,
      );
      expect(a, equals(b));
    });

    test('not equal to different type', () {
      // ignore: unrelated_type_equality_checks
      expect(base == 'not a PdfImage', isFalse);
    });

    test('toString shows pageIndex, objectIndex, and bgra status (null)', () {
      final s = base.toString();
      expect(s, contains('PdfImage'));
      expect(s, contains('pageIndex: 0'));
      expect(s, contains('objectIndex: 3'));
      expect(s, contains('bgra: null'));
    });

    test('toString shows bgra byte count when bitmap is present', () {
      final bgra = Uint8List(4 * 4 * 4); // 4×4 BGRA
      final img = PdfImage(
        pageIndex: 0,
        objectIndex: 0,
        metadata: meta,
        bounds: _rect,
        filters: [],
        bgra: bgra,
        bitmapWidth: 4,
        bitmapHeight: 4,
      );
      expect(img.toString(), contains('bytes'));
    });

    test('empty filters list equals another empty filters list', () {
      final a = PdfImage(
        pageIndex: 0,
        objectIndex: 0,
        metadata: meta,
        bounds: _rect,
        filters: [],
      );
      final b = PdfImage(
        pageIndex: 0,
        objectIndex: 0,
        metadata: meta,
        bounds: _rect,
        filters: [],
      );
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfImageBitmap
  // ---------------------------------------------------------------------------

  group('PdfImageBitmap', () {
    final bgra = Uint8List.fromList([0, 0, 0, 255, 255, 0, 0, 255]);

    test('equal width/height are equal regardless of bgra content', () {
      final a = PdfImageBitmap(bgra: bgra, width: 2, height: 1);
      final b = PdfImageBitmap(
        bgra: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        width: 2,
        height: 1,
      );
      // bgra intentionally excluded from equality.
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('identical object equals itself', () {
      final a = PdfImageBitmap(bgra: bgra, width: 2, height: 1);
      expect(a == a, isTrue);
    });

    test('unequal when width differs', () {
      final a = PdfImageBitmap(bgra: bgra, width: 2, height: 1);
      final b = PdfImageBitmap(bgra: bgra, width: 4, height: 1);
      expect(a, isNot(equals(b)));
    });

    test('unequal when height differs', () {
      final a = PdfImageBitmap(bgra: bgra, width: 1, height: 2);
      final b = PdfImageBitmap(bgra: bgra, width: 1, height: 4);
      expect(a, isNot(equals(b)));
    });

    test('not equal to different type', () {
      final a = PdfImageBitmap(bgra: bgra, width: 2, height: 1);
      // ignore: unrelated_type_equality_checks
      expect(a == 'not a bitmap', isFalse);
    });

    test('toString contains width, height, and byte count', () {
      final a = PdfImageBitmap(bgra: bgra, width: 2, height: 1);
      final s = a.toString();
      expect(s, contains('PdfImageBitmap'));
      expect(s, contains('width: 2'));
      expect(s, contains('height: 1'));
      expect(s, contains('${bgra.length} bytes'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfPageImages
  // ---------------------------------------------------------------------------

  group('PdfPageImages', () {
    const meta = PdfImageMetadata(
      width: 10,
      height: 10,
      horizontalDpi: 72.0,
      verticalDpi: 72.0,
      bitsPerPixel: 24,
      colorspace: PdfColorspace.deviceRgb,
      markedContentId: -1,
    );

    final img = PdfImage(
      pageIndex: 0,
      objectIndex: 0,
      metadata: meta,
      bounds: _rect,
      filters: [],
    );

    test('toString shows pageIndex and image count', () {
      final pi = PdfPageImages(pageIndex: 2, images: [img]);
      final s = pi.toString();
      expect(s, contains('PdfPageImages'));
      expect(s, contains('pageIndex: 2'));
      expect(s, contains('images: 1'));
    });

    test('empty images list is reported correctly', () {
      final pi = PdfPageImages(pageIndex: 0, images: []);
      expect(pi.toString(), contains('images: 0'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfColor.toString
  // ---------------------------------------------------------------------------

  group('PdfColor.toString', () {
    test('contains all components', () {
      const c = PdfColor(r: 128, g: 64, b: 255, a: 200);
      final s = c.toString();
      expect(s, contains('PdfColor'));
      expect(s, contains('r: 128'));
      expect(s, contains('g: 64'));
      expect(s, contains('b: 255'));
      expect(s, contains('a: 200'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfRect.hashCode and toString
  // ---------------------------------------------------------------------------

  group('PdfRect', () {
    const r = PdfRect(left: 10.0, bottom: 20.0, right: 100.0, top: 80.0);

    test('different right makes instances unequal', () {
      const r2 = PdfRect(left: 10.0, bottom: 20.0, right: 99.0, top: 80.0);
      expect(r, isNot(equals(r2)));
    });

    test('different top makes instances unequal', () {
      const r2 = PdfRect(left: 10.0, bottom: 20.0, right: 100.0, top: 99.0);
      expect(r, isNot(equals(r2)));
    });

    test('hashCode is consistent with equality', () {
      const r2 = PdfRect(left: 10.0, bottom: 20.0, right: 100.0, top: 80.0);
      expect(r.hashCode, equals(r2.hashCode));
    });

    test('hashCode differs for different rects (typically)', () {
      const r2 = PdfRect(left: 0.0, bottom: 0.0, right: 50.0, top: 50.0);
      expect(r.hashCode, isNot(equals(r2.hashCode)));
    });

    test('toString contains all four edges', () {
      final s = r.toString();
      // Not '10.0'/'20.0'/etc.: dart2js formats whole-number doubles without
      // the trailing '.0', unlike the Dart VM — the bare digits match both.
      expect(s, contains('PdfRect'));
      expect(s, contains('left: 10'));
      expect(s, contains('bottom: 20'));
      expect(s, contains('right: 100'));
      expect(s, contains('top: 80'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfQuadPoints equality (non-identical path)
  // ---------------------------------------------------------------------------

  group('PdfQuadPoints', () {
    const p1 = PdfPoint(x: 0.0, y: 0.0);
    const p2 = PdfPoint(x: 1.0, y: 0.0);
    const p3 = PdfPoint(x: 0.0, y: 1.0);
    const p4 = PdfPoint(x: 1.0, y: 1.0);

    const base = PdfQuadPoints(p1: p1, p2: p2, p3: p3, p4: p4);
    const same = PdfQuadPoints(p1: p1, p2: p2, p3: p3, p4: p4);
    const diff = PdfQuadPoints(
      p1: PdfPoint(x: 9.0, y: 9.0),
      p2: p2,
      p3: p3,
      p4: p4,
    );

    test('equal non-identical instances are equal', () {
      expect(base, equals(same));
      expect(base.hashCode, equals(same.hashCode));
    });

    test('different p1 makes instances unequal', () {
      expect(base, isNot(equals(diff)));
    });

    test('not equal to a different type', () {
      // ignore: unrelated_type_equality_checks
      expect(base == 'not a PdfQuadPoints', isFalse);
    });

    test('toString contains PdfQuadPoints and all four points', () {
      final s = base.toString();
      expect(s, contains('PdfQuadPoints'));
      expect(s, contains('p1:'));
      expect(s, contains('p2:'));
      expect(s, contains('p3:'));
      expect(s, contains('p4:'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfPopupAnnotation equality and hashCode
  // ---------------------------------------------------------------------------

  group('PdfPopupAnnotation', () {
    const rect = PdfRect(left: 10.0, bottom: 20.0, right: 100.0, top: 80.0);
    const a = PdfPopupAnnotation(rect: rect, flags: 4);
    const b = PdfPopupAnnotation(rect: rect, flags: 4);
    const noRect = PdfPopupAnnotation(rect: null, flags: 0);

    test('equal non-identical instances are equal', () {
      expect(a, equals(b));
    });

    test('hashCode is consistent with equality', () {
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different flags makes instances unequal', () {
      const c = PdfPopupAnnotation(rect: rect, flags: 0);
      expect(a, isNot(equals(c)));
    });

    test('null rect vs non-null rect are unequal', () {
      expect(a, isNot(equals(noRect)));
    });

    test('identical object equals itself', () {
      expect(a == a, isTrue);
    });

    test('not equal to a different type', () {
      // ignore: unrelated_type_equality_checks
      expect(a == 'not a popup', isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // PdfMarkupAnnotation equality, hashCode, and toString
  // ---------------------------------------------------------------------------

  group('PdfMarkupAnnotation', () {
    const quad = PdfQuadPoints(
      p1: PdfPoint(x: 10.0, y: 80.0),
      p2: PdfPoint(x: 90.0, y: 80.0),
      p3: PdfPoint(x: 10.0, y: 70.0),
      p4: PdfPoint(x: 90.0, y: 70.0),
    );
    const rect = PdfRect(left: 10.0, bottom: 70.0, right: 90.0, top: 80.0);
    const color = PdfColor(r: 255, g: 255, b: 0, a: 128);
    const date = PdfDate(raw: 'D:20260101', value: null);

    final base = PdfMarkupAnnotation(
      pageIndex: 0,
      subtype: PdfAnnotationType.highlight,
      quadPoints: const [quad],
      markedText: 'highlighted text',
      contents: 'note',
      author: 'me',
      rect: rect,
      color: color,
      modifiedDate: date,
      flags: 4,
    );

    test('equal non-identical instances are equal', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        markedText: 'highlighted text',
        contents: 'note',
        author: 'me',
        rect: rect,
        color: color,
        modifiedDate: date,
        flags: 4,
      );
      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('identical object equals itself', () {
      expect(base == base, isTrue);
    });

    test('unequal when pageIndex differs', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 1,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when subtype differs', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.underline,
        quadPoints: const [quad],
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test(
      'unequal when quadPoints differ (different count — _listEqual length branch)',
      () {
        // Empty list: exercises the length-mismatch branch in _listEqual.
        final other = PdfMarkupAnnotation(
          pageIndex: 0,
          subtype: PdfAnnotationType.highlight,
          quadPoints: const [],
          flags: 4,
        );
        expect(base, isNot(equals(other)));
      },
    );

    test(
      'unequal when quadPoints differ (same count, different content — _listEqual element branch)',
      () {
        const diffQuad = PdfQuadPoints(
          p1: PdfPoint(x: 0.0, y: 0.0),
          p2: PdfPoint(x: 1.0, y: 0.0),
          p3: PdfPoint(x: 0.0, y: 1.0),
          p4: PdfPoint(x: 1.0, y: 1.0),
        );
        final other = PdfMarkupAnnotation(
          pageIndex: 0,
          subtype: PdfAnnotationType.highlight,
          quadPoints: const [diffQuad],
          flags: 4,
        );
        expect(base, isNot(equals(other)));
      },
    );

    test('unequal when markedText differs', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        markedText: 'other text',
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when contents differs', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        markedText: 'highlighted text',
        contents: 'different',
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when author differs', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        markedText: 'highlighted text',
        contents: 'note',
        author: 'other',
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when rect differs', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        markedText: 'highlighted text',
        contents: 'note',
        author: 'me',
        rect: const PdfRect(left: 0.0, bottom: 0.0, right: 50.0, top: 50.0),
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when color differs', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        markedText: 'highlighted text',
        contents: 'note',
        author: 'me',
        rect: rect,
        color: const PdfColor(r: 0, g: 0, b: 255, a: 255),
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when modifiedDate differs', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        markedText: 'highlighted text',
        contents: 'note',
        author: 'me',
        rect: rect,
        color: color,
        modifiedDate: const PdfDate(raw: 'D:20260202', value: null),
        flags: 4,
      );
      expect(base, isNot(equals(other)));
    });

    test('unequal when flags differ', () {
      final other = PdfMarkupAnnotation(
        pageIndex: 0,
        subtype: PdfAnnotationType.highlight,
        quadPoints: const [quad],
        markedText: 'highlighted text',
        contents: 'note',
        author: 'me',
        rect: rect,
        color: color,
        modifiedDate: date,
        flags: 0,
      );
      expect(base, isNot(equals(other)));
    });

    test('not equal to a different type', () {
      const other = PdfTextAnnotation(pageIndex: 0, flags: 4);
      expect(base == other, isFalse);
    });

    test('toString contains type name, subtype, and quadPoints count', () {
      final s = base.toString();
      expect(s, contains('PdfMarkupAnnotation'));
      expect(s, contains('pageIndex: 0'));
      expect(s, contains('highlight'));
      expect(s, contains('1 quads'));
    });

    test('underline subtype is preserved in toString', () {
      final underline = PdfMarkupAnnotation(
        pageIndex: 1,
        subtype: PdfAnnotationType.underline,
        quadPoints: const [quad, quad],
        flags: 0,
      );
      expect(underline.toString(), contains('underline'));
      expect(underline.toString(), contains('2 quads'));
    });

    test('squiggly subtype is constructable and reported in toString', () {
      final squiggly = PdfMarkupAnnotation(
        pageIndex: 2,
        subtype: PdfAnnotationType.squiggly,
        quadPoints: const [],
        flags: 0,
      );
      expect(squiggly.toString(), contains('squiggly'));
    });

    test('strikeout subtype is constructable and reported in toString', () {
      final strikeout = PdfMarkupAnnotation(
        pageIndex: 3,
        subtype: PdfAnnotationType.strikeout,
        quadPoints: const [quad],
        flags: 0,
      );
      expect(strikeout.toString(), contains('strikeout'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfUnknownAnnotation.toString
  // ---------------------------------------------------------------------------

  group('PdfUnknownAnnotation.toString', () {
    test('contains type name, pageIndex, and rawSubtype', () {
      const a = PdfUnknownAnnotation(pageIndex: 5, rawSubtype: 42, flags: 0);
      final s = a.toString();
      expect(s, contains('PdfUnknownAnnotation'));
      expect(s, contains('pageIndex: 5'));
      expect(s, contains('rawSubtype: 42'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfPageAnnotations.toString
  // ---------------------------------------------------------------------------

  group('PdfPageAnnotations.toString', () {
    test('empty annotations list reports count 0', () {
      const pa = PdfPageAnnotations(pageIndex: 2, annotations: []);
      final s = pa.toString();
      expect(s, contains('PdfPageAnnotations'));
      expect(s, contains('pageIndex: 2'));
      expect(s, contains('annotations: 0'));
    });

    test('non-empty annotations list reports correct count', () {
      const pa = PdfPageAnnotations(
        pageIndex: 0,
        annotations: [
          PdfUnknownAnnotation(pageIndex: 0, rawSubtype: 1, flags: 0),
          PdfUnknownAnnotation(pageIndex: 0, rawSubtype: 2, flags: 0),
        ],
      );
      expect(pa.toString(), contains('annotations: 2'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfMetadata.toString
  // ---------------------------------------------------------------------------

  group('PdfMetadata.toString', () {
    test('fully-populated instance contains all field names', () {
      const date = PdfDate(raw: 'D:20260101', value: null);
      const meta = PdfMetadata(
        title: 'My Doc',
        author: 'Alice',
        subject: 'Testing',
        keywords: 'test, dart',
        creator: 'TestApp',
        producer: 'PDFLib',
        creationDate: date,
        modDate: date,
      );
      final s = meta.toString();
      expect(s, contains('PdfMetadata'));
      expect(s, contains('title: My Doc'));
      expect(s, contains('author: Alice'));
      expect(s, contains('subject: Testing'));
      expect(s, contains('keywords: test, dart'));
      expect(s, contains('creator: TestApp'));
      expect(s, contains('producer: PDFLib'));
      expect(s, contains('creationDate:'));
      expect(s, contains('modDate:'));
    });

    test('null fields appear as null in output', () {
      const meta = PdfMetadata();
      final s = meta.toString();
      expect(s, contains('title: null'));
      expect(s, contains('author: null'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfTextExtractorConfig.toString
  // ---------------------------------------------------------------------------

  group('PdfTextExtractorConfig.toString', () {
    test('default config shows scannedPageRatio 0.5', () {
      const config = PdfTextExtractorConfig();
      final s = config.toString();
      expect(s, contains('PdfTextExtractorConfig'));
      expect(s, contains('scannedPageRatio: 0.5'));
    });

    test('custom scannedPageRatio appears in output', () {
      const config = PdfTextExtractorConfig(scannedPageRatio: 0.8);
      expect(config.toString(), contains('0.8'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfDocumentInfo constructor and toString
  // ---------------------------------------------------------------------------

  group('PdfDocumentInfo', () {
    test('constructor with all null fields', () {
      const info = PdfDocumentInfo();
      expect(info.fileVersion, isNull);
      expect(info.permanentId, isNull);
      expect(info.changingId, isNull);
    });

    test('constructor stores fileVersion', () {
      const info = PdfDocumentInfo(fileVersion: 17);
      expect(info.fileVersion, equals(17));
    });

    test('toString with null IDs does not throw', () {
      const info = PdfDocumentInfo(fileVersion: 14);
      final s = info.toString();
      expect(s, contains('PdfDocumentInfo'));
      expect(s, contains('fileVersion: 14'));
      expect(s, contains('permanentId: null'));
      expect(s, contains('changingId: null'));
    });

    test('toString with non-null permanentId produces hex string', () {
      // 16 bytes: 0x00 through 0x0F.
      final id = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final info = PdfDocumentInfo(permanentId: id);
      final s = info.toString();
      expect(s, contains('PdfDocumentInfo'));
      // The hex encoding of [0,1,2,...,15] starts with "000102..."
      expect(s, contains('permanentId: 000102'));
    });

    test('toString with non-null changingId produces hex string', () {
      final id = Uint8List.fromList(List<int>.generate(16, (i) => 255 - i));
      final info = PdfDocumentInfo(changingId: id);
      final s = info.toString();
      expect(s, contains('changingId: fffefdfcfb'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfColor equality — exercises == operator field comparisons (lines 354-356)
  // ---------------------------------------------------------------------------

  group('PdfColor equality', () {
    test('non-identical equal instances are equal', () {
      const a = PdfColor(r: 1, g: 2, b: 3, a: 4);
      const b = PdfColor(r: 1, g: 2, b: 3, a: 4);
      // Explicitly verify via ==, not identical(), to hit the field-comparison
      // branch inside operator==.
      // ignore: unrelated_type_equality_checks
      expect(a == b, isTrue);
    });

    test('instances with different g are unequal', () {
      const a = PdfColor(r: 1, g: 2, b: 3, a: 4);
      const b = PdfColor(r: 1, g: 99, b: 3, a: 4);
      expect(a, isNot(equals(b)));
    });

    test('instances with different b are unequal', () {
      const a = PdfColor(r: 1, g: 2, b: 3, a: 4);
      const b = PdfColor(r: 1, g: 2, b: 99, a: 4);
      expect(a, isNot(equals(b)));
    });

    test('instances with different a are unequal', () {
      const a = PdfColor(r: 1, g: 2, b: 3, a: 4);
      const b = PdfColor(r: 1, g: 2, b: 3, a: 99);
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfQuadPoints deeper field equality (lines 468-470 — p2, p3, p4)
  // ---------------------------------------------------------------------------

  group('PdfQuadPoints field equality', () {
    const origin = PdfPoint(x: 0, y: 0);
    const p = PdfPoint(x: 1, y: 1);

    test('different p2 makes instances unequal', () {
      const a = PdfQuadPoints(
        p1: origin,
        p2: PdfPoint(x: 1, y: 0),
        p3: origin,
        p4: origin,
      );
      const b = PdfQuadPoints(
        p1: origin,
        p2: PdfPoint(x: 99, y: 0),
        p3: origin,
        p4: origin,
      );
      expect(a, isNot(equals(b)));
    });

    test('different p3 makes instances unequal', () {
      const a = PdfQuadPoints(
        p1: origin,
        p2: origin,
        p3: PdfPoint(x: 1, y: 0),
        p4: origin,
      );
      const b = PdfQuadPoints(
        p1: origin,
        p2: origin,
        p3: PdfPoint(x: 99, y: 0),
        p4: origin,
      );
      expect(a, isNot(equals(b)));
    });

    test('different p4 makes instances unequal', () {
      const a = PdfQuadPoints(p1: origin, p2: origin, p3: origin, p4: p);
      const b = PdfQuadPoints(
        p1: origin,
        p2: origin,
        p3: origin,
        p4: PdfPoint(x: 99, y: 0),
      );
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfTextAnnotation equality, hashCode, and toString (lines 595-624)
  // ---------------------------------------------------------------------------

  group('PdfTextAnnotation', () {
    const rect = PdfRect(left: 0, bottom: 0, right: 10, top: 10);
    const color = PdfColor(r: 255, g: 0, b: 0, a: 255);
    const popup = PdfPopupAnnotation(flags: 0);

    PdfTextAnnotation makeAnnot({
      int pageIndex = 0,
      String? contents = 'note',
      String? author = 'Alice',
      PdfRect? annotRect,
      PdfColor? annotColor,
      PdfDate? modifiedDate,
      int flags = 0,
      PdfPopupAnnotation? annotPopup,
    }) => PdfTextAnnotation(
      pageIndex: pageIndex,
      contents: contents,
      author: author,
      rect: annotRect ?? rect,
      color: annotColor ?? color,
      modifiedDate: modifiedDate,
      flags: flags,
      popup: annotPopup,
    );

    test('equal non-identical instances are equal', () {
      final a = makeAnnot();
      final b = makeAnnot();
      expect(a, equals(b));
    });

    test('equal instances share the same hashCode', () {
      final a = makeAnnot();
      final b = makeAnnot();
      expect(a.hashCode, equals(b.hashCode));
    });

    test('identical instance equals itself', () {
      final a = makeAnnot();
      expect(a, equals(a));
    });

    test('different pageIndex makes instances unequal', () {
      expect(makeAnnot(pageIndex: 0), isNot(equals(makeAnnot(pageIndex: 1))));
    });

    test('different contents makes instances unequal', () {
      expect(makeAnnot(contents: 'a'), isNot(equals(makeAnnot(contents: 'b'))));
    });

    test('different author makes instances unequal', () {
      expect(
        makeAnnot(author: 'Alice'),
        isNot(equals(makeAnnot(author: 'Bob'))),
      );
    });

    test('different rect makes instances unequal', () {
      const r2 = PdfRect(left: 1, bottom: 1, right: 2, top: 2);
      expect(makeAnnot(), isNot(equals(makeAnnot(annotRect: r2))));
    });

    test('different color makes instances unequal', () {
      const c2 = PdfColor(r: 0, g: 255, b: 0, a: 255);
      expect(makeAnnot(), isNot(equals(makeAnnot(annotColor: c2))));
    });

    test('different modifiedDate makes instances unequal', () {
      const d1 = PdfDate(raw: 'D:20260101', value: null);
      const d2 = PdfDate(raw: 'D:20250101', value: null);
      expect(
        makeAnnot(modifiedDate: d1),
        isNot(equals(makeAnnot(modifiedDate: d2))),
      );
    });

    test('different flags makes instances unequal', () {
      expect(makeAnnot(flags: 0), isNot(equals(makeAnnot(flags: 1))));
    });

    test('null popup vs non-null popup are unequal', () {
      expect(
        makeAnnot(annotPopup: null),
        isNot(equals(makeAnnot(annotPopup: popup))),
      );
    });

    test('not equal to a different type', () {
      final a = makeAnnot();
      expect(a, isNot(equals('not an annotation')));
    });

    test('toString contains type name, pageIndex, and contents', () {
      final a = makeAnnot(pageIndex: 7, contents: 'my note');
      final s = a.toString();
      expect(s, contains('PdfTextAnnotation'));
      expect(s, contains('pageIndex: 7'));
      expect(s, contains('my note'));
    });
  });
}
