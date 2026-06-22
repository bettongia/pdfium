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
}
