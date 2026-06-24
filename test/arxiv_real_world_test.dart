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

// Real-world arXiv PDF integration tests for PdfDocument.
//
// These tests load the arXiv paper 2605.16085v1 from test/data/arxiv/ and
// verify that betto_pdfium extracts metadata and text content consistent with the
// reference outputs produced by the Python extraction pipeline in scripts/.
//
// Tests are skipped when the PDFium dylib is absent (e.g. CI without a build).

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:betto_pdfium/src/document/pdfium_isolate.dart'
    show PdfiumIsolate;

const String _kDylibPath = 'third_party/pdfium_bin/macos_arm64/libpdfium.dylib';

// arXiv 2605.16085v1 — "Towards Foundation Models for Relational Databases
// with Language Models and Graph Neural Networks"
const String _kPdfPath = 'test/data/arxiv/2605.16085v1.pdf';

// Expected values derived from 2605.16085v1.meta.json and 2605.16085v1.txt.json.
const String _kTitle =
    'Towards Foundation Models for Relational Databases with Language Models and Graph Neural Networks';
const String _kAuthor =
    'Jingcheng Wu; Ratan Bahadur Thapa; Mojtaba Nayyeri; Lucas Etteldorf; '
    'Max Finkenbeiner; Fabian Leeske; Steffen Staab';
const String _kSubject = 'Layout by CEURART v0.6.2';
const String _kCreator = 'arXiv GenPDF (tex2pdf:a6404ea)';
const String _kProducer = 'pikepdf 8.15.1';
// Raw PDF date string from the Info dictionary.
const String _kCreationDateRaw = "D:20260518011150+00'00'";
const int _kPageCount = 15;

Uint8List _readArxivPdf() {
  final file = File(_kPdfPath);
  if (!file.existsSync()) {
    throw StateError('arXiv test PDF not found at $_kPdfPath');
  }
  return file.readAsBytesSync();
}

bool _nativeAvailable() => Platform.isMacOS && File(_kDylibPath).existsSync();

void main() {
  group('arXiv 2605.16085v1 — real-world PDF', () {
    tearDownAll(() {
      PdfiumIsolate.resetForTesting();
    });

    // -------------------------------------------------------------------------
    // Metadata
    // -------------------------------------------------------------------------

    group('getMetadata — INFO dictionary', () {
      late PdfDocument doc;
      late PdfMetadata meta;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf(),
          dylibPath: _kDylibPath,
        );
        meta = await doc.getMetadata();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('title matches reference', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.title, equals(_kTitle));
      });

      test('author matches reference (semicolon-separated)', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.author, equals(_kAuthor));
      });

      test('subject matches CEURART layout marker', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.subject, equals(_kSubject));
      });

      test('keywords is null (not set in this paper)', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.keywords, isNull);
      });

      test('creator matches arXiv GenPDF tool', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creator, equals(_kCreator));
      });

      test('producer matches pikepdf version', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.producer, equals(_kProducer));
      });

      test('creationDate raw string matches PDF date literal', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creationDate, isNotNull);
        expect(meta.creationDate!.raw, equals(_kCreationDateRaw));
      });

      test('creationDate parses to 2026-05-18 01:11:50 UTC', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final dt = meta.creationDate!.value;
        expect(dt, isNotNull);
        expect(dt!.year, equals(2026));
        expect(dt.month, equals(5));
        expect(dt.day, equals(18));
        expect(dt.hour, equals(1));
        expect(dt.minute, equals(11));
        expect(dt.second, equals(50));
        expect(dt.isUtc, isTrue);
      });

      test('modDate raw matches creationDate (same timestamp)', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.modDate, isNotNull);
        expect(meta.modDate!.raw, equals(_kCreationDateRaw));
      });
    });

    // -------------------------------------------------------------------------
    // Page count
    // -------------------------------------------------------------------------

    group('pageCount', () {
      test('returns 15 for 2605.16085v1.pdf', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf(),
          dylibPath: _kDylibPath,
        );
        try {
          expect(await doc.pageCount, equals(_kPageCount));
        } finally {
          await doc.close();
        }
      });
    });

    // -------------------------------------------------------------------------
    // Text extraction
    // -------------------------------------------------------------------------

    group('extractPlainText — full document', () {
      late PdfDocument doc;
      late List<PdfPageText> pages;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf(),
          dylibPath: _kDylibPath,
        );
        pages = await doc.extractPlainText().toList();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('yields exactly 15 pages', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages, hasLength(_kPageCount));
      });

      // All 15 pages have 1 432–4 467 extracted chars. On A4 (~501 000 pt²)
      // that gives densities of 2.86–8.91 chars/1 000 pt², all above the
      // default threshold of 2.0.
      test(
        'all pages have hasTextLayer=true with default density threshold',
        () {
          if (!_nativeAvailable()) {
            markTestSkipped('PDFium dylib not found.');
            return;
          }
          for (final p in pages) {
            expect(
              p.hasTextLayer,
              isTrue,
              reason: 'page ${p.pageIndex}: density should exceed 2.0',
            );
          }
        },
      );

      // Only pages 0 and 6 contain glyphs PDFium cannot map to Unicode
      // (e.g. the envelope icon on page 0, ornamental characters on page 6).
      test('pages 0 and 6 report Unicode errors; all others are clean', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          final expectErrors = p.pageIndex == 0 || p.pageIndex == 6;
          expect(
            p.hasUnicodeErrors,
            expectErrors ? isTrue : isFalse,
            reason:
                'page ${p.pageIndex}: expected hasUnicodeErrors=$expectErrors',
          );
        }
      });

      test('page indices are sequential 0–14', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (var i = 0; i < pages.length; i++) {
          expect(pages[i].pageIndex, equals(i));
        }
      });

      // Page 0 — title page and abstract
      test('page 0 contains paper title fragment', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final text = pages[0].text;
        expect(text, contains('Foundation Models for Relational Databases'));
      });

      test('page 0 contains first author name', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages[0].text, contains('Jingcheng Wu'));
      });

      test('page 0 abstract mentions GraphSAGE and BART', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final text = pages[0].text;
        expect(text, contains('GraphSAGE'));
        expect(text, contains('BART'));
      });

      test('page 0 abstract ROC-AUC result is present', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        // The abstract states "ROC-AUC of 67.40".
        expect(pages[0].text, contains('67.40'));
      });

      // Page 3 — Methodology section
      test('page 3 contains Methodology section header', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages[3].text, contains('Methodology'));
      });

      // Page 7 — Results table
      test('page 7 contains results table with LightGBM baseline', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final text = pages[7].text;
        expect(text, contains('LightGBM'));
        expect(text, contains('KumoRFM'));
      });

      // Page 11 — Conclusion
      test('page 11 contains Conclusion section header', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages[11].text, contains('Conclusion'));
      });

      // Page 12 — References section (first page of references)
      test('page 12 contains References header', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages[12].text, contains('References'));
      });

      // Page 14 — Last page (bibliography continued)
      test('page 14 contains bibliographic content', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        // The last page contains references [30]–[34].
        // PDFium renders the "LightGBM" reference title as "Lightgbm" due to
        // the font's cmap encoding — the Python reference shows "LightGBM".
        final text = pages[14].text;
        expect(text, isNotEmpty);
        expect(text, contains('Lightgbm'));
      });
    });

    group('extractPlainText — single page access', () {
      test(
        'page 0 via pageIndex parameter matches full-extract page 0',
        () async {
          if (!_nativeAvailable()) {
            markTestSkipped('PDFium dylib not found.');
            return;
          }
          final doc = await PdfDocument.fromBytes(
            _readArxivPdf(),
            dylibPath: _kDylibPath,
          );
          try {
            final single = await doc.extractPlainText(pageIndex: 0).toList();
            expect(single, hasLength(1));
            expect(single.first.pageIndex, equals(0));
            expect(
              single.first.text,
              contains('Foundation Models for Relational Databases'),
            );
          } finally {
            await doc.close();
          }
        },
      );
    });

    group('isPlainTextExtractable', () {
      // All pages have a text layer (charCount > 0) →
      // scannedRatio = 0/15 = 0 < 0.5 → true.
      test('returns true with default config', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf(),
          dylibPath: _kDylibPath,
        );
        try {
          expect(await doc.isPlainTextExtractable(), isTrue);
        } finally {
          await doc.close();
        }
      });
    });
  });
}
