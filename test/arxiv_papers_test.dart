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

// Real-world arXiv PDF integration tests — additional papers.
//
// Covers four papers that exercise distinct PDF production paths and layouts:
//
//   2312.17524v1  — pdfTeX / two-column IEEE-style layout, 6 pages
//   2404.16130v2  — pdfTeX / single-column, 26 pages (GraphRAG paper)
//   2605.13866v1  — arXiv GenPDF + pikepdf, 39 pages (social-science paper)
//   2605.15752v1  — arXiv GenPDF + pikepdf, 19 pages (accented author names)
//
// Reference outputs in test/data/arxiv/*.{meta,txt}.json were produced by the
// Python extraction pipeline in scripts/. PDFium-specific behaviour (density
// heuristic, Unicode mapping) may differ from those reference values and is
// documented per group.
//
// All tests are skipped when the PDFium dylib is absent.

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:betto_pdfium/src/document/pdfium_isolate.dart'
    show PdfiumIsolate;

const String _kDylibPath = 'third_party/pdfium_bin/macos_arm64/libpdfium.dylib';

Uint8List _readArxivPdf(String id) {
  final file = File('test/data/arxiv/$id.pdf');
  if (!file.existsSync()) {
    throw StateError('arXiv test PDF not found: test/data/arxiv/$id.pdf');
  }
  return file.readAsBytesSync();
}

bool _nativeAvailable() => Platform.isMacOS && File(_kDylibPath).existsSync();

void main() {
  tearDownAll(() {
    PdfiumIsolate.resetForTesting();
  });

  // ---------------------------------------------------------------------------
  // 2312.17524v1 — two-column IEEE-style layout, produced by pdfTeX
  // ---------------------------------------------------------------------------

  group('arXiv 2312.17524v1 — two-column, pdfTeX, 6 pages', () {
    group('getMetadata — empty Info fields become null', () {
      late PdfDocument doc;
      late PdfMetadata meta;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf('2312.17524v1'),
          dylibPath: _kDylibPath,
        );
        meta = await doc.getMetadata();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      // pdfTeX / LaTeX papers often omit Info-dict metadata; the PDF stores
      // empty strings for title/author/subject/keywords. PDFium maps those to
      // null, matching the intent of "not present".
      test('title is null (empty string in Info dict)', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.title, isNull);
      });

      test('author is null (empty string in Info dict)', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.author, isNull);
      });

      test('subject is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.subject, isNull);
      });

      test('keywords is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.keywords, isNull);
      });

      test('creator is LaTeX with hyperref', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creator, equals('LaTeX with hyperref'));
      });

      test('producer is pdfTeX-1.40.25', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.producer, equals('pdfTeX-1.40.25'));
      });

      test('creationDate raw is D:20240101013745Z', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creationDate?.raw, equals('D:20240101013745Z'));
      });

      test('creationDate parses to 2024-01-01 01:37:45 UTC', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final dt = meta.creationDate!.value!;
        expect(dt.year, equals(2024));
        expect(dt.month, equals(1));
        expect(dt.day, equals(1));
        expect(dt.isUtc, isTrue);
      });
    });

    group('pageCount', () {
      test('returns 6', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf('2312.17524v1'),
          dylibPath: _kDylibPath,
        );
        try {
          expect(await doc.pageCount, equals(6));
        } finally {
          await doc.close();
        }
      });
    });

    group('extractPlainText — two-column layout', () {
      late PdfDocument doc;
      late List<PdfPageText> pages;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf('2312.17524v1'),
          dylibPath: _kDylibPath,
        );
        pages = await doc.extractPlainText().toList();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('yields 6 pages', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages, hasLength(6));
      });

      // All 6 pages have at least 3 987 chars on a US Letter page (~485 000 pt²),
      // giving densities of 8.2–16.3, all above the default threshold of 2.0.
      test('all pages have hasTextLayer=true', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          expect(
            p.hasTextLayer,
            isTrue,
            reason: 'page ${p.pageIndex} should pass the density threshold',
          );
        }
      });

      test('no pages have Unicode errors', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          expect(
            p.hasUnicodeErrors,
            isFalse,
            reason: 'page ${p.pageIndex} should have no Unicode errors',
          );
        }
      });

      // PDFium reads two-column layout in reading order (left column top→bottom,
      // then right column top→bottom), so both columns' text appears on page 0.
      test('page 0 title is extracted', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(
          pages[0].text,
          contains('Performance of Distributed File Systems'),
        );
      });

      test('page 0 contains abstract from left column', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        // The abstract begins in the left column on page 0.
        expect(pages[0].text, contains('small-file'));
      });

      test('page 0 contains content from right column', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        // The right column of page 0 contains the introduction body text.
        expect(pages[0].text, contains('machine learning'));
      });
    });

    group('isPlainTextExtractable', () {
      // 0/6 pages fall below the density threshold → scannedRatio = 0 < 0.5
      test('returns true with default config', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf('2312.17524v1'),
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

  // ---------------------------------------------------------------------------
  // 2404.16130v2 — GraphRAG paper, pdfTeX, 26 pages
  // ---------------------------------------------------------------------------

  group('arXiv 2404.16130v2 — GraphRAG, pdfTeX, 26 pages', () {
    group('getMetadata', () {
      late PdfDocument doc;
      late PdfMetadata meta;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf('2404.16130v2'),
          dylibPath: _kDylibPath,
        );
        meta = await doc.getMetadata();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('title is null (empty in Info dict)', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.title, isNull);
      });

      test('author is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.author, isNull);
      });

      test('creator is LaTeX with hyperref', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creator, equals('LaTeX with hyperref'));
      });

      test('producer is pdfTeX-1.40.25', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.producer, equals('pdfTeX-1.40.25'));
      });

      test('creationDate raw is D:20250220013802Z', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creationDate?.raw, equals('D:20250220013802Z'));
      });
    });

    group('pageCount', () {
      test('returns 26', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf('2404.16130v2'),
          dylibPath: _kDylibPath,
        );
        try {
          expect(await doc.pageCount, equals(26));
        } finally {
          await doc.close();
        }
      });
    });

    group('extractPlainText', () {
      late PdfDocument doc;
      late List<PdfPageText> pages;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf('2404.16130v2'),
          dylibPath: _kDylibPath,
        );
        pages = await doc.extractPlainText().toList();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('yields 26 pages', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages, hasLength(26));
      });

      // All pages (including page 16 which has only 775 chars) have a text
      // layer — PDFium extracts at least one character from every page.
      test('all pages have hasTextLayer=true', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          expect(p.hasTextLayer, isTrue, reason: 'page ${p.pageIndex}');
        }
      });

      test('no pages have Unicode errors', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          expect(p.hasUnicodeErrors, isFalse, reason: 'page ${p.pageIndex}');
        }
      });

      // Although title/author are absent from the Info dict, the paper body
      // text is fully extractable.
      test('page 0 contains title text from body', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages[0].text, contains('GraphRAG'));
        expect(pages[0].text, contains('Query-Focused Summarization'));
      });

      test('page 0 contains Microsoft author affiliations', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages[0].text, contains('Microsoft Research'));
      });
    });

    group('isPlainTextExtractable', () {
      // 1/26 pages below threshold → scannedRatio = 0.038 < 0.5 → true.
      test(
        'returns true with default config (only page 16 below threshold)',
        () async {
          if (!_nativeAvailable()) {
            markTestSkipped('PDFium dylib not found.');
            return;
          }
          final doc = await PdfDocument.fromBytes(
            _readArxivPdf('2404.16130v2'),
            dylibPath: _kDylibPath,
          );
          try {
            expect(await doc.isPlainTextExtractable(), isTrue);
          } finally {
            await doc.close();
          }
        },
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 2605.13866v1 — AI Alignment paper, arXiv GenPDF + pikepdf, 39 pages
  // ---------------------------------------------------------------------------

  group('arXiv 2605.13866v1 — AI Alignment, arXiv GenPDF, 39 pages', () {
    group('getMetadata', () {
      late PdfDocument doc;
      late PdfMetadata meta;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf('2605.13866v1'),
          dylibPath: _kDylibPath,
        );
        meta = await doc.getMetadata();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('title matches paper title', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(
          meta.title,
          equals(
            'AI Alignment Amplifies the Role of Race, Gender, and Disability in Hiring Decisions',
          ),
        );
      });

      test('author contains all three authors (semicolon-separated)', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.author, equals('Ze Wang; Guobin Shen; Michael Thaler'));
      });

      test('subject is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.subject, isNull);
      });

      test('keywords is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.keywords, isNull);
      });

      test('creator is arXiv GenPDF', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creator, equals('arXiv GenPDF (tex2pdf:a6404ea)'));
      });

      test('producer is pikepdf 8.15.1', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.producer, equals('pikepdf 8.15.1'));
      });

      // This paper's Info dict has no creation or modification date.
      test('creationDate is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creationDate, isNull);
      });

      test('modDate is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.modDate, isNull);
      });
    });

    group('pageCount', () {
      test('returns 39', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf('2605.13866v1'),
          dylibPath: _kDylibPath,
        );
        try {
          expect(await doc.pageCount, equals(39));
        } finally {
          await doc.close();
        }
      });
    });

    group('extractPlainText', () {
      late PdfDocument doc;
      late List<PdfPageText> pages;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf('2605.13866v1'),
          dylibPath: _kDylibPath,
        );
        pages = await doc.extractPlainText().toList();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('yields 39 pages', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages, hasLength(39));
      });

      // All pages have a text layer — pages 11, 27, 28, 29 are sparse
      // (figure captions, section headers) but PDFium still extracts characters
      // from them, so hasTextLayer is true for every page.
      test('all pages have hasTextLayer=true', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          expect(p.hasTextLayer, isTrue, reason: 'page ${p.pageIndex}');
        }
      });

      test('no pages have Unicode errors', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          expect(p.hasUnicodeErrors, isFalse, reason: 'page ${p.pageIndex}');
        }
      });

      test('page 0 contains title and lead author', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final text = pages[0].text;
        expect(text, contains('AI Alignment'));
        expect(text, contains('Ze Wang'));
      });

      test('page 1 body mentions race and gender', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages[1].text, contains('alignment'));
      });
    });

    group('isPlainTextExtractable', () {
      // 4/39 pages below threshold → scannedRatio = 0.103 < 0.5 → true.
      test('returns true with default config', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf('2605.13866v1'),
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

  // ---------------------------------------------------------------------------
  // 2605.15752v1 — Space weather paper, arXiv GenPDF + pikepdf, 19 pages
  //               Exercises accented author names and mid-document Unicode errors
  // ---------------------------------------------------------------------------

  group('arXiv 2605.15752v1 — space weather, arXiv GenPDF, 19 pages', () {
    group('getMetadata — accented author names', () {
      late PdfDocument doc;
      late PdfMetadata meta;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf('2605.15752v1'),
          dylibPath: _kDylibPath,
        );
        meta = await doc.getMetadata();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('title matches paper title', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(
          meta.title,
          equals(
            "Forecasting megaelectron-volt electron flux in the Earth's outer radiation belt "
            'using supervised machine learning algorithms and a timeseries foundation model',
          ),
        );
      });

      // Author string includes a French accented name (François) — PDFium must
      // correctly decode the UTF-16LE Info dict value.
      test('author field contains accented name François Ginisty', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.author, contains('François Ginisty'));
      });

      test('author contains all four authors (semicolon-separated)', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(
          meta.author,
          equals(
            'Rungployphan Kieokaew; Ryad Guezzi; François Ginisty; Hadrien Mariaccia',
          ),
        );
      });

      test('subject is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.subject, isNull);
      });

      test('creator is arXiv GenPDF', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creator, equals('arXiv GenPDF (tex2pdf:a6404ea)'));
      });

      test('producer is pikepdf 8.15.1', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.producer, equals('pikepdf 8.15.1'));
      });

      test('creationDate is null', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(meta.creationDate, isNull);
      });
    });

    group('pageCount', () {
      test('returns 19', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf('2605.15752v1'),
          dylibPath: _kDylibPath,
        );
        try {
          expect(await doc.pageCount, equals(19));
        } finally {
          await doc.close();
        }
      });
    });

    group('extractPlainText', () {
      late PdfDocument doc;
      late List<PdfPageText> pages;

      setUpAll(() async {
        if (!_nativeAvailable()) return;
        doc = await PdfDocument.fromBytes(
          _readArxivPdf('2605.15752v1'),
          dylibPath: _kDylibPath,
        );
        pages = await doc.extractPlainText().toList();
      });

      tearDownAll(() async {
        if (!_nativeAvailable()) return;
        await doc.close();
      });

      test('yields 19 pages', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages, hasLength(19));
      });

      // All pages have a text layer — pages 3 and 11 are figure-caption pages
      // with few characters but PDFium still extracts them, so hasTextLayer is
      // true for every page.
      test('all pages have hasTextLayer=true', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          expect(p.hasTextLayer, isTrue, reason: 'page ${p.pageIndex}');
        }
      });

      // Pages 7 and 9 contain mathematical notation with glyphs that PDFium
      // cannot map to Unicode (Greek letters via non-standard font encoding).
      test('pages 7 and 9 have Unicode errors; all others are clean', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        for (final p in pages) {
          final expectErrors = p.pageIndex == 7 || p.pageIndex == 9;
          expect(
            p.hasUnicodeErrors,
            expectErrors ? isTrue : isFalse,
            reason:
                'page ${p.pageIndex}: expected hasUnicodeErrors=$expectErrors',
          );
        }
      });

      test('page 0 contains title and lead author', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final text = pages[0].text;
        expect(text, contains('MEGAELECTRON-VOLT'));
        expect(text, contains('Rungployphan Kieokaew'));
      });

      test('page 1 body references radiation belt science', () {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        expect(pages[1].text, contains('radiation'));
      });
    });

    group('isPlainTextExtractable', () {
      // 2/19 pages below threshold → scannedRatio = 0.105 < 0.5 → true.
      test('returns true with default config', () async {
        if (!_nativeAvailable()) {
          markTestSkipped('PDFium dylib not found.');
          return;
        }
        final doc = await PdfDocument.fromBytes(
          _readArxivPdf('2605.15752v1'),
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
