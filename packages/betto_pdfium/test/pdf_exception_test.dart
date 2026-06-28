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

// Unit tests for PdfiumException, PdfExtractionException, and PdfError.
//
// These tests cover the pure-Dart exception types in lib/src/pdf_exception.dart
// and lib/src/document/pdf_types.dart. No native binary is required.

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PdfiumException
  // ---------------------------------------------------------------------------

  group('PdfiumException', () {
    test('constructor stores the message', () {
      const e = PdfiumException('native allocation failure');
      expect(e.message, equals('native allocation failure'));
    });

    test('toString returns PdfiumException: <message>', () {
      const e = PdfiumException('some message');
      expect(e.toString(), equals('PdfiumException: some message'));
    });

    test('is an Exception', () {
      const e = PdfiumException('x');
      expect(e, isA<Exception>());
    });

    test('can be thrown and caught', () {
      void throwIt() => throw const PdfiumException('thrown');
      expect(throwIt, throwsA(isA<PdfiumException>()));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfError
  // ---------------------------------------------------------------------------

  group('PdfError', () {
    test('has invalidDocument value', () {
      expect(PdfError.invalidDocument, isNotNull);
      expect(PdfError.invalidDocument.name, equals('invalidDocument'));
    });

    test('has passwordRequired value', () {
      expect(PdfError.passwordRequired, isNotNull);
      expect(PdfError.passwordRequired.name, equals('passwordRequired'));
    });

    test('has exactly two values', () {
      expect(PdfError.values, hasLength(2));
    });

    test('values are distinct', () {
      expect(
        PdfError.invalidDocument,
        isNot(equals(PdfError.passwordRequired)),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // PdfExtractionException
  // ---------------------------------------------------------------------------

  group('PdfExtractionException', () {
    test('constructor stores the error', () {
      const e = PdfExtractionException(PdfError.invalidDocument);
      expect(e.error, equals(PdfError.invalidDocument));
    });

    test('toString for invalidDocument', () {
      const e = PdfExtractionException(PdfError.invalidDocument);
      expect(e.toString(), equals('PdfExtractionException(invalidDocument)'));
    });

    test('toString for passwordRequired', () {
      const e = PdfExtractionException(PdfError.passwordRequired);
      expect(e.toString(), equals('PdfExtractionException(passwordRequired)'));
    });

    test('is an Exception', () {
      const e = PdfExtractionException(PdfError.invalidDocument);
      expect(e, isA<Exception>());
    });

    test('can be thrown and caught', () {
      void throwIt() =>
          throw const PdfExtractionException(PdfError.passwordRequired);
      expect(throwIt, throwsA(isA<PdfExtractionException>()));
    });
  });
}
