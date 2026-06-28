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

// Integration tests for PdfDocument.renderPageToBytes and PdfDocument.getPageSize.
//
// These tests require the native PDFium dylib. They are skipped gracefully when
// the binary is absent (same pattern as image_extraction_test.dart).

import 'dart:io';
import 'dart:typed_data';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:betto_pdfium/src/document/pdfium_isolate.dart'
    show PdfiumIsolate;
import 'package:test/test.dart';

import 'native_test_helper.dart';

/// Reads a file from test/data/ or test/fixtures/.
Uint8List _readData(String name) {
  final file = File('test/data/$name');
  if (file.existsSync()) return file.readAsBytesSync();
  final fixture = File('test/fixtures/$name');
  if (fixture.existsSync()) return fixture.readAsBytesSync();
  throw StateError('Test file not found: $name');
}

void main() {
  group('rendering integration', () {
    late PdfDocument doc;

    setUp(() async {
      if (!nativeAvailable()) return;
      PdfiumIsolate.resetForTesting();
    });

    tearDown(() async {
      if (!nativeAvailable()) return;
      try {
        await doc.close();
      } catch (_) {
        // Already closed in some tests; ignore.
      }
      PdfiumIsolate.resetForTesting();
    });

    /// Opens a document by reading test/data/<name>.
    Future<PdfDocument> openData(String name) async {
      return PdfDocument.fromBytes(
        _readData(name),
        dylibPath: nativeDylibPath(),
      );
    }

    // -------------------------------------------------------------------------
    // getPageSize
    // -------------------------------------------------------------------------

    test(
      'getPageSize(0) on 01_basic.pdf returns positive dimensions',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        final size = await doc.getPageSize(0);
        expect(size.widthPt, greaterThan(0));
        expect(size.heightPt, greaterThan(0));
      },
    );

    test(
      'getPageSize returns a PdfPageSize with plausible A4-like dimensions',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        final size = await doc.getPageSize(0);
        // PDF user units (points). A4 is ~595 x 842 pt.
        // We allow a wide range to accommodate different fixture sizes.
        expect(size.widthPt, greaterThan(10));
        expect(size.heightPt, greaterThan(10));
        expect(size.aspectRatio, greaterThan(0));
      },
    );

    test('getPageSize throws RangeError for out-of-range page index', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      doc = await openData('01_basic.pdf');
      await expectLater(() => doc.getPageSize(9999), throwsRangeError);
    });

    test('getPageSize throws StateError after close()', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final closedDoc = await openData('01_basic.pdf');
      await closedDoc.close();
      await expectLater(() => closedDoc.getPageSize(0), throwsStateError);
    });

    // -------------------------------------------------------------------------
    // renderPageToBytes
    // -------------------------------------------------------------------------

    test(
      'renderPageToBytes(0, 100, 100) returns correct pixel dimensions',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        final result = await doc.renderPageToBytes(0, 100, 100);
        expect(result.pixelWidth, equals(100));
        expect(result.pixelHeight, equals(100));
      },
    );

    test(
      'renderPageToBytes result.pixels length equals pixelWidth * pixelHeight * 4 (BGRA)',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        final result = await doc.renderPageToBytes(0, 100, 100);
        expect(result.pixels.length, equals(100 * 100 * 4));
      },
    );

    test(
      'renderPageToBytes result.pixels is not all-zero for a text page',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        final result = await doc.renderPageToBytes(0, 100, 100);
        // A rendered text-on-white page will have non-zero bytes (the white
        // background produces 0xFF in the alpha byte of every BGRA pixel).
        final allZero = result.pixels.every((b) => b == 0);
        expect(allZero, isFalse);
      },
    );

    test(
      'renderPageToBytes with different sizes produces correct pixel counts',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        final small = await doc.renderPageToBytes(0, 50, 75);
        expect(small.pixels.length, equals(50 * 75 * 4));
        expect(small.pixelWidth, equals(50));
        expect(small.pixelHeight, equals(75));
      },
    );

    test(
      'renderPageToBytes throws RangeError for out-of-range page index',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        await expectLater(
          () => doc.renderPageToBytes(9999, 100, 100),
          throwsRangeError,
        );
      },
    );

    test(
      'renderPageToBytes with zero width throws (PdfiumException from native alloc)',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        // PDFium's FPDFBitmap_Create returns null for a 0-pixel dimension;
        // the isolate converts this to a PdfiumException rather than a RangeError.
        await expectLater(
          () => doc.renderPageToBytes(0, 0, 100),
          throwsA(isA<PdfiumException>()),
        );
      },
    );

    test(
      'renderPageToBytes with zero height throws (PdfiumException from native alloc)',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        await expectLater(
          () => doc.renderPageToBytes(0, 100, 0),
          throwsA(isA<PdfiumException>()),
        );
      },
    );

    test('renderPageToBytes throws StateError after close()', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final closedDoc = await openData('01_basic.pdf');
      await closedDoc.close();
      await expectLater(
        () => closedDoc.renderPageToBytes(0, 100, 100),
        throwsStateError,
      );
    });

    // -------------------------------------------------------------------------
    // getPageSize + renderPageToBytes round-trip
    // -------------------------------------------------------------------------

    test(
      'sizeForDpi from getPageSize produces valid render dimensions',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        final size = await doc.getPageSize(0);
        final px = size.sizeForDpi(72); // 1:1 with point size at 72 DPI
        final w = px.width.round().clamp(1, 4096);
        final h = px.height.round().clamp(1, 4096);
        final result = await doc.renderPageToBytes(0, w, h);
        expect(result.pixels.length, equals(w * h * 4));
      },
    );

    // -------------------------------------------------------------------------
    // lcdText flag — exercises the lcdText branch (line 361 in _document_native.dart)
    // -------------------------------------------------------------------------

    test(
      'renderPageToBytes with lcdText:true produces a valid pixel buffer',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await openData('01_basic.pdf');
        // Setting lcdText: true hits the `if (lcdText) flags |= 0x02` branch.
        final result = await doc.renderPageToBytes(0, 100, 100, lcdText: true);
        expect(result.pixels.length, equals(100 * 100 * 4));
      },
    );
  });

  // -------------------------------------------------------------------------
  // extractPlainText out-of-range page index (line 184 in _document_native.dart)
  // -------------------------------------------------------------------------

  group('extractPlainText error paths', () {
    late PdfDocument doc;

    setUp(() async {
      if (!nativeAvailable()) return;
      PdfiumIsolate.resetForTesting();
    });

    tearDown(() async {
      if (!nativeAvailable()) return;
      try {
        await doc.close();
      } catch (_) {}
      PdfiumIsolate.resetForTesting();
    });

    test(
      'extractPlainText throws RangeError for out-of-range pageIndex',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        doc = await PdfDocument.fromBytes(
          File('test/data/01_basic.pdf').readAsBytesSync(),
          dylibPath: nativeDylibPath(),
        );
        await expectLater(
          () => doc.extractPlainText(pageIndex: 9999).toList(),
          throwsRangeError,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Init-failure path — covers PdfiumInitFailedResponse (pdfium_isolate ~line 103)
  // -------------------------------------------------------------------------

  group('PdfiumIsolate init failure', () {
    setUp(() => PdfiumIsolate.resetForTesting());
    tearDown(() => PdfiumIsolate.resetForTesting());

    test(
      'ensureInitialised with a non-existent dylib path throws StateError',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        // A path that definitely does not exist causes the spawned isolate to
        // send PdfiumInitFailedResponse, which the main isolate converts to a
        // StateError.
        await expectLater(
          () => PdfiumIsolate.ensureInitialised(
            dylibPath: '/nonexistent/path/libpdfium.dylib',
          ),
          throwsStateError,
        );
      },
    );
  });
}
