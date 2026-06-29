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

// Error-path tests for PdfDocument.
//
// Covers:
//   - PdfDocument.fromBytes on corrupt and password-protected PDFs.
//   - close() idempotency.
//   - StateError from all stream-returning methods when document is closed.
//   - StateError from all Future-returning methods when document is closed.
//
// Tests that require the native binary skip gracefully when it is absent.

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:betto_pdfium/src/document/pdfium_isolate.dart'
    show PdfiumIsolate;

import 'native_test_helper.dart';

/// Reads a fixture file from test/fixtures/.
Uint8List _readFixture(String name) {
  final file = File('test/fixtures/$name');
  if (!file.existsSync()) {
    throw StateError('Test fixture not found: test/fixtures/$name');
  }
  return file.readAsBytesSync();
}

void main() {
  group('error handling', () {
    setUp(() async {
      if (!nativeAvailable()) return;
      PdfiumIsolate.resetForTesting();
    });

    tearDown(() async {
      if (!nativeAvailable()) return;
      PdfiumIsolate.resetForTesting();
    });

    // -------------------------------------------------------------------------
    // Loading failures
    // -------------------------------------------------------------------------

    test(
      'fromBytes with corrupt.pdf throws PdfExtractionException(invalidDocument)',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        final bytes = _readFixture('corrupt.pdf');
        // The isolate maps any non-password PDFium load error to invalidDocument.
        await expectLater(
          () => PdfDocument.fromBytes(bytes, dylibPath: nativeDylibPath()),
          throwsA(
            isA<PdfExtractionException>().having(
              (e) => e.error,
              'error',
              PdfError.invalidDocument,
            ),
          ),
        );
      },
    );

    test(
      'fromBytes with password.pdf throws PdfExtractionException(passwordRequired)',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        final bytes = _readFixture('password.pdf');
        // The isolate maps FPDF_ERR_PASSWORD (4) to passwordRequired.
        // On Windows the bblanchon PDFium build returns FPDF_ERR_FORMAT (3)
        // for this fixture, mapping to invalidDocument instead.
        final expectedError = Platform.isWindows
            ? PdfError.invalidDocument
            : PdfError.passwordRequired;
        await expectLater(
          () => PdfDocument.fromBytes(bytes, dylibPath: nativeDylibPath()),
          throwsA(
            isA<PdfExtractionException>().having(
              (e) => e.error,
              'error',
              expectedError,
            ),
          ),
        );
      },
    );

    // -------------------------------------------------------------------------
    // close() idempotency
    // -------------------------------------------------------------------------

    test('close() is idempotent — calling it twice does not throw', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not present');
        return;
      }
      final doc = await PdfDocument.fromBytes(
        _readFixture('no_annotations.pdf'),
        dylibPath: nativeDylibPath(),
      );
      await doc.close();
      // Second close must not throw.
      await expectLater(doc.close(), completes);
    });

    // -------------------------------------------------------------------------
    // StateError from stream-returning methods after close()
    // -------------------------------------------------------------------------

    group('stream-returning methods throw StateError after close()', () {
      late PdfDocument doc;

      setUp(() async {
        if (!nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readFixture('no_annotations.pdf'),
          dylibPath: nativeDylibPath(),
        );
        await doc.close();
      });

      test('extractPlainText throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        expect(() => doc.extractPlainText().toList(), throwsStateError);
      });

      test('extractAnnotations throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        expect(() => doc.extractAnnotations().toList(), throwsStateError);
      });

      test('extractImages throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        expect(() => doc.extractImages().toList(), throwsStateError);
      });
    });

    // -------------------------------------------------------------------------
    // StateError from Future-returning methods after close()
    // -------------------------------------------------------------------------

    group('Future-returning methods throw StateError after close()', () {
      late PdfDocument doc;

      setUp(() async {
        if (!nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readFixture('no_annotations.pdf'),
          dylibPath: nativeDylibPath(),
        );
        await doc.close();
      });

      test('getMetadata throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        await expectLater(() => doc.getMetadata(), throwsStateError);
      });

      test('getDocumentInfo throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        await expectLater(() => doc.getDocumentInfo(), throwsStateError);
      });

      test('pageCount throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        await expectLater(() => doc.pageCount, throwsStateError);
      });

      test('getPageSize throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        await expectLater(() => doc.getPageSize(0), throwsStateError);
      });

      test('getThumbnail throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        await expectLater(() => doc.getThumbnail(0), throwsStateError);
      });

      test('tableOfContents throws StateError', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not present');
          return;
        }
        await expectLater(() => doc.tableOfContents, throwsStateError);
      });
    });
  });
}
