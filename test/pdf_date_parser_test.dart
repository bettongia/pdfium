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

// Unit tests for PdfDateParser.
//
// The parser must handle the full PDF date format plus a range of real-world
// deviations: missing D: prefix, truncation, Z for UTC, and malformed strings.

import 'package:betto_pdfium/src/document/pdf_date_parser.dart'
    show PdfDateParser;
import 'package:test/test.dart';

import 'package:betto_pdfium/betto_pdfium.dart';

void main() {
  group('PdfDateParser.parse', () {
    group('returns null for absent input', () {
      test('null input returns null', () {
        expect(PdfDateParser.parse(null), isNull);
      });

      test('empty string returns null', () {
        expect(PdfDateParser.parse(''), isNull);
      });
    });

    group('full format with D: prefix', () {
      test('UTC offset Z', () {
        final result = PdfDateParser.parse("D:20230315120000Z");
        expect(result, isNotNull);
        expect(result!.raw, equals("D:20230315120000Z"));
        expect(result.value, isNotNull);
        // 2023-03-15 12:00:00 UTC
        expect(result.value, equals(DateTime.utc(2023, 3, 15, 12, 0, 0)));
      });

      test('positive UTC offset +05\'30\'', () {
        // D:20230315120000+05'30' means 12:00:00 in UTC+5:30 = 06:30:00 UTC
        final result = PdfDateParser.parse("D:20230315120000+05'30'");
        expect(result, isNotNull);
        expect(result!.value, isNotNull);
        expect(result.value, equals(DateTime.utc(2023, 3, 15, 6, 30, 0)));
      });

      test('negative UTC offset -08\'00\'', () {
        // D:20230315120000-08'00' means 12:00:00 in UTC-8 = 20:00:00 UTC
        final result = PdfDateParser.parse("D:20230315120000-08'00'");
        expect(result, isNotNull);
        expect(result!.value, isNotNull);
        expect(result.value, equals(DateTime.utc(2023, 3, 15, 20, 0, 0)));
      });

      test('zero offset +00\'00\'', () {
        final result = PdfDateParser.parse("D:20230315120000+00'00'");
        expect(result, isNotNull);
        expect(result!.value, equals(DateTime.utc(2023, 3, 15, 12, 0, 0)));
      });
    });

    group('D: prefix omitted', () {
      test('parses date without D: prefix', () {
        final result = PdfDateParser.parse("20230315120000Z");
        expect(result, isNotNull);
        expect(result!.raw, equals("20230315120000Z"));
        expect(result.value, isNotNull);
        expect(result.value, equals(DateTime.utc(2023, 3, 15, 12, 0, 0)));
      });

      test('date-only without D: prefix', () {
        final result = PdfDateParser.parse("20230315");
        expect(result, isNotNull);
        expect(result!.value, isNotNull);
        // No time component — defaults to midnight UTC.
        expect(result.value, equals(DateTime.utc(2023, 3, 15, 0, 0, 0)));
      });
    });

    group('truncated formats', () {
      test('year only', () {
        final result = PdfDateParser.parse("D:2023");
        expect(result, isNotNull);
        expect(result!.value, isNotNull);
        expect(result.value, equals(DateTime.utc(2023, 1, 1, 0, 0, 0)));
      });

      test('year and month', () {
        final result = PdfDateParser.parse("D:202303");
        expect(result, isNotNull);
        expect(result!.value, equals(DateTime.utc(2023, 3, 1, 0, 0, 0)));
      });

      test('date only (no time)', () {
        final result = PdfDateParser.parse("D:20230315");
        expect(result, isNotNull);
        expect(result!.value, equals(DateTime.utc(2023, 3, 15, 0, 0, 0)));
      });

      test('date and hours only', () {
        final result = PdfDateParser.parse("D:2023031512");
        expect(result, isNotNull);
        expect(result!.value, equals(DateTime.utc(2023, 3, 15, 12, 0, 0)));
      });
    });

    group('colon separator in offset', () {
      test('offset with colon separator', () {
        // Some tools use HH:mm instead of HH'mm' for the offset.
        final result = PdfDateParser.parse("D:20230315120000+05:30");
        expect(result, isNotNull);
        expect(result!.value, equals(DateTime.utc(2023, 3, 15, 6, 30, 0)));
      });
    });

    group('raw string preserved', () {
      test('raw string is the original input', () {
        const raw = "D:20230315120000Z";
        final result = PdfDateParser.parse(raw);
        expect(result!.raw, equals(raw));
      });

      test('raw string preserved when parsing fails', () {
        const bad = "D:not-a-date";
        final result = PdfDateParser.parse(bad);
        expect(result, isNotNull);
        expect(result!.raw, equals(bad));
        expect(result.value, isNull);
      });
    });

    group('malformed strings return PdfDate with null value', () {
      test('too short — only 3 chars — returns PdfDate with null value', () {
        // "D:2" strips the prefix to "2" (1 digit), too short for a year.
        // parse() returns a PdfDate (not null) with value == null, preserving
        // the raw string. parse() only returns null for empty/null input.
        final result = PdfDateParser.parse("D:2");
        expect(result, isNotNull);
        expect(result!.value, isNull);
        expect(result.raw, equals("D:2"));
      });

      test('invalid month returns null value', () {
        final result = PdfDateParser.parse("D:20231315");
        // Month 13 is invalid.
        expect(result, isNotNull);
        expect(result!.value, isNull);
      });

      test('invalid day returns null value', () {
        final result = PdfDateParser.parse("D:20230132");
        // Day 32 is invalid.
        expect(result, isNotNull);
        expect(result!.value, isNull);
      });

      test('invalid hour returns null value', () {
        final result = PdfDateParser.parse("D:2023031525");
        // Hour 25 is invalid.
        expect(result, isNotNull);
        expect(result!.value, isNull);
      });

      test('non-numeric year returns null value', () {
        final result = PdfDateParser.parse("D:YYYY0315");
        expect(result, isNotNull);
        expect(result!.value, isNull);
      });

      test('completely invalid string returns PdfDate with null value', () {
        final result = PdfDateParser.parse("D:not-a-date");
        expect(result, isNotNull);
        expect(result!.value, isNull);
        expect(result.raw, equals("D:not-a-date"));
      });
    });

    group('edge cases from real-world PDFs', () {
      test('trailing whitespace is handled', () {
        final result = PdfDateParser.parse("D:20230315120000Z  ");
        expect(result, isNotNull);
        expect(result!.value, isNotNull);
      });

      test('lowercase d: prefix', () {
        final result = PdfDateParser.parse("d:20230315120000Z");
        expect(result, isNotNull);
        expect(result!.value, equals(DateTime.utc(2023, 3, 15, 12, 0, 0)));
      });
    });
  });

  group('PdfDate equality', () {
    test('equal PdfDate instances are ==', () {
      final a = PdfDate(raw: 'D:20230315', value: DateTime.utc(2023, 3, 15));
      final b = PdfDate(raw: 'D:20230315', value: DateTime.utc(2023, 3, 15));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('PdfDate with different raw strings are not ==', () {
      final a = PdfDate(raw: 'D:20230315', value: DateTime.utc(2023, 3, 15));
      final b = PdfDate(raw: 'D:20230316', value: DateTime.utc(2023, 3, 15));
      expect(a, isNot(equals(b)));
    });
  });
}
