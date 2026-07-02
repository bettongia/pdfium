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

// Web-platform integration tests for PdfDocument.
//
// Runs exclusively under `dart test -p chrome` (make web_test). All fixture
// loading uses fetch() via the dart test local HTTP server, which serves the
// package root. Fixture files in test/fixtures/ are accessible at the relative
// URL `fixtures/{name}` from the test HTML page at /test/.
//
// There is no dart:io, dart:ffi, or dylibPath usage here. The test file is
// intentionally separate from the native suite.
//
// Coverage for this file is measured independently via `make web_coverage`
// (dart test -p chrome --coverage) and enforced at >= 90% on the web target.

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:betto_pdfium/betto_pdfium.dart';

// ---------------------------------------------------------------------------
// Fixture loading via the dart test HTTP server
// ---------------------------------------------------------------------------

/// Fetches a fixture file from `test/fixtures/{name}`.
///
/// When running under `dart test -p chrome`, the test page is served at
/// `/test/pdf_document_web_test.html`, so the relative URL `fixtures/{name}`
/// resolves to `/test/fixtures/{name}` on the local test server.
Future<Uint8List> _fetchFixture(String name) async {
  final response = await web.window.fetch('fixtures/$name'.toJS).toDart;
  if (!response.ok) {
    throw StateError(
      'Failed to fetch test fixture fixtures/$name: HTTP ${response.status}',
    );
  }
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Phase 2a: module load + document lifecycle.
  group('PdfDocument web — module load and document lifecycle', () {
    // The module is a static singleton. Once loaded it stays for the test run.
    // Each test closes its own document; the module itself is not reset.

    group('fromBytes — valid document', () {
      late PdfDocument doc;

      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {
          // Guard against tests that already closed the document.
        }
      });

      test('loads no_annotations.pdf without throwing', () async {
        final bytes = await _fetchFixture('no_annotations.pdf');
        doc = await PdfDocument.fromBytes(bytes);
        // If we reach here the module loaded, the WASM initialised, and
        // the PDF was successfully parsed.
      });

      test('pageCount returns 1 for no_annotations.pdf', () async {
        final bytes = await _fetchFixture('no_annotations.pdf');
        doc = await PdfDocument.fromBytes(bytes);
        expect(await doc.pageCount, equals(1));
      });

      test('pageCount returns 1 for full_metadata.pdf', () async {
        final bytes = await _fetchFixture('full_metadata.pdf');
        doc = await PdfDocument.fromBytes(bytes);
        expect(await doc.pageCount, equals(1));
      });

      test('multiple documents can be open simultaneously', () async {
        final bytes = await _fetchFixture('no_annotations.pdf');
        final doc2 = await PdfDocument.fromBytes(bytes);
        doc = await PdfDocument.fromBytes(bytes);
        expect(await doc.pageCount, equals(1));
        expect(await doc2.pageCount, equals(1));
        await doc2.close();
      });
    });

    group('fromBytes — password-protected document', () {
      test(
        'password.pdf throws PdfExtractionException(passwordRequired)',
        () async {
          final bytes = await _fetchFixture('password.pdf');
          await expectLater(
            () => PdfDocument.fromBytes(bytes),
            throwsA(
              isA<PdfExtractionException>().having(
                (e) => e.error,
                'error',
                PdfError.passwordRequired,
              ),
            ),
          );
        },
      );
    });

    group('fromBytes — invalid document', () {
      test(
        'corrupt.pdf throws PdfExtractionException(invalidDocument)',
        () async {
          final bytes = await _fetchFixture('corrupt.pdf');
          await expectLater(
            () => PdfDocument.fromBytes(bytes),
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
        'empty bytes throw PdfExtractionException(invalidDocument)',
        () async {
          await expectLater(
            () => PdfDocument.fromBytes(Uint8List(0)),
            throwsA(isA<PdfExtractionException>()),
          );
        },
      );

      test(
        'random bytes throw PdfExtractionException(invalidDocument)',
        () async {
          final garbage = Uint8List.fromList(List.generate(64, (i) => i));
          await expectLater(
            () => PdfDocument.fromBytes(garbage),
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
    });

    group('close()', () {
      test('close() is idempotent — calling twice does not throw', () async {
        final bytes = await _fetchFixture('no_annotations.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        await doc.close();
        await expectLater(doc.close(), completes);
      });

      test('pageCount throws StateError after close()', () async {
        final bytes = await _fetchFixture('no_annotations.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        await doc.close();
        await expectLater(() async => await doc.pageCount, throwsStateError);
      });
    });
  });

  // Phase 2b: metadata, document info, page size, text extractability.
  group('PdfDocument web — PR 2b', () {
    group('getMetadata()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('full_metadata.pdf returns all fields', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('full_metadata.pdf'),
        );
        final meta = await doc.getMetadata();
        expect(meta.title, isNotNull);
        expect(meta.author, isNotNull);
      });

      test('no_metadata.pdf returns null string fields', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_metadata.pdf'),
        );
        final meta = await doc.getMetadata();
        expect(meta.title, isNull);
        expect(meta.author, isNull);
        expect(meta.subject, isNull);
        expect(meta.keywords, isNull);
        expect(meta.creator, isNull);
        // producer and dates may be injected by the PDF generator (fpdf2); not asserted.
      });

      test('partial_metadata.pdf returns some non-null fields', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('partial_metadata.pdf'),
        );
        final meta = await doc.getMetadata();
        // At least one field should be non-null for a "partial" fixture.
        final hasAny =
            meta.title != null ||
            meta.author != null ||
            meta.subject != null ||
            meta.keywords != null ||
            meta.creator != null ||
            meta.producer != null;
        expect(hasAny, isTrue);
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(doc.getMetadata, throwsStateError);
      });
    });

    group('getDocumentInfo()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('returns fileVersion for a standard PDF', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        final info = await doc.getDocumentInfo();
        // Most PDFs have a file version between 10 (1.0) and 20 (2.0).
        if (info.fileVersion != null) {
          expect(info.fileVersion, greaterThanOrEqualTo(10));
          expect(info.fileVersion, lessThanOrEqualTo(20));
        }
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(doc.getDocumentInfo, throwsStateError);
      });
    });

    group('getPageSize()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('returns positive dimensions for a standard page', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        final size = await doc.getPageSize(0);
        expect(size.widthPt, greaterThan(0));
        expect(size.heightPt, greaterThan(0));
      });

      test('throws RangeError for negative pageIndex', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await expectLater(() => doc.getPageSize(-1), throwsRangeError);
      });

      test('throws RangeError for out-of-bounds pageIndex', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await expectLater(() => doc.getPageSize(999), throwsRangeError);
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(() => doc.getPageSize(0), throwsStateError);
      });
    });

    group('isPlainTextExtractable()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('single_column.pdf is extractable', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('single_column.pdf'),
        );
        expect(await doc.isPlainTextExtractable(), isTrue);
      });

      test('scanned.pdf is not extractable', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('scanned.pdf'));
        expect(await doc.isPlainTextExtractable(), isFalse);
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(doc.isPlainTextExtractable, throwsStateError);
      });
    });
  });

  // Phase 2c: text extraction and annotation extraction.
  group('PdfDocument web — PR 2c', () {
    group('extractPlainText()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('extracts non-empty text from single_column.pdf', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('single_column.pdf'),
        );
        final pages = await doc.extractPlainText().toList();
        expect(pages, isNotEmpty);
        expect(pages.first.hasTextLayer, isTrue);
        expect(pages.first.text, isNotEmpty);
      });

      test('yields one entry per page for multi-page PDF', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('multi_page_annotated.pdf'),
        );
        final count = await doc.pageCount;
        final pages = await doc.extractPlainText().toList();
        expect(pages.length, equals(count));
      });

      test('yields one entry for a single pageIndex', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('multi_page_annotated.pdf'),
        );
        final pages = await doc.extractPlainText(pageIndex: 0).toList();
        expect(pages.length, equals(1));
        expect(pages.first.pageIndex, equals(0));
      });

      test('scanned.pdf page has hasTextLayer == false', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('scanned.pdf'));
        final pages = await doc.extractPlainText().toList();
        expect(pages.first.hasTextLayer, isFalse);
        expect(pages.first.text, isEmpty);
      });

      test('no_annotations.pdf stream completes without error', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await expectLater(
          doc.extractPlainText(),
          emitsInOrder([isA<PdfPageText>(), emitsDone]),
        );
      });
    });

    group('extractAnnotations()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('no_annotations.pdf yields empty annotation list', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        final pages = await doc.extractAnnotations().toList();
        expect(pages, isNotEmpty);
        expect(pages.first.annotations, isEmpty);
      });

      test('annotated_text.pdf yields at least one annotation', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('annotated_text.pdf'),
        );
        final pages = await doc.extractAnnotations().toList();
        final all = pages.expand((p) => p.annotations).toList();
        expect(all, isNotEmpty);
      });

      test('annotated_shapes.pdf yields shape annotations', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('annotated_shapes.pdf'),
        );
        final pages = await doc.extractAnnotations().toList();
        final all = pages.expand((p) => p.annotations).toList();
        expect(all, isNotEmpty);
      });

      test('annotated_ink.pdf yields at least one ink annotation', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('annotated_ink.pdf'),
        );
        final pages = await doc.extractAnnotations().toList();
        final all = pages.expand((p) => p.annotations).toList();
        final inkAnnotations = all.whereType<PdfInkAnnotation>().toList();
        expect(inkAnnotations, isNotEmpty);
      });

      test('popup_annotation.pdf links popup to parent', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('popup_annotation.pdf'),
        );
        final pages = await doc.extractAnnotations().toList();
        final all = pages.expand((p) => p.annotations).toList();
        final withPopup = all.where((a) => a.popup != null).toList();
        expect(withPopup, isNotEmpty);
      });

      test(
        'popup_freetext.pdf — PdfFreeTextAnnotation has a non-null popup',
        () async {
          doc = await PdfDocument.fromBytes(
            await _fetchFixture('popup_freetext.pdf'),
          );
          final pages = await doc.extractAnnotations().toList();
          final all = pages.expand((p) => p.annotations).toList();
          final freeTextWithPopup = all
              .whereType<PdfFreeTextAnnotation>()
              .where((a) => a.popup != null)
              .toList();
          expect(freeTextWithPopup, isNotEmpty);
          // Exercise PdfFreeTextAnnotation equality/hashCode/toString directly
          // (a separate construction from the extracted one, same fields).
          final a = freeTextWithPopup.first;
          final copy = PdfFreeTextAnnotation(
            pageIndex: a.pageIndex,
            contents: a.contents,
            author: a.author,
            rect: a.rect,
            color: a.color,
            modifiedDate: a.modifiedDate,
            flags: a.flags,
            popup: a.popup,
          );
          expect(copy, equals(a));
          expect(copy.hashCode, equals(a.hashCode));
          expect(copy.toString(), contains('PdfFreeTextAnnotation'));
        },
      );

      test('popup_multi.pdf — multiple annotations have popups', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('popup_multi.pdf'),
        );
        final pages = await doc.extractAnnotations().toList();
        final all = pages.expand((p) => p.annotations).toList();
        final withPopup = all.where((a) => a.popup != null).toList();
        expect(withPopup.length, greaterThan(1));
      });

      test(
        'zero_ink_stroke.pdf — ink annotation with zero-point stroke is returned',
        () async {
          doc = await PdfDocument.fromBytes(
            await _fetchFixture('zero_ink_stroke.pdf'),
          );
          final pages = await doc.extractAnnotations().toList();
          final inkAnnots = pages
              .expand((p) => p.annotations)
              .whereType<PdfInkAnnotation>()
              .toList();
          expect(inkAnnots, isNotEmpty);
          expect(inkAnnots.first.strokes, isNotEmpty);
          expect(inkAnnots.first.strokes.first, isEmpty);
        },
      );

      test(
        'zero_polygon_vertices.pdf — polygon with empty vertices does not throw',
        () async {
          doc = await PdfDocument.fromBytes(
            await _fetchFixture('zero_polygon_vertices.pdf'),
          );
          final pages = await doc.extractAnnotations().toList();
          final polygons = pages
              .expand((p) => p.annotations)
              .whereType<PdfPolygonAnnotation>()
              .toList();
          expect(polygons, isNotEmpty);
          expect(polygons.first.vertices, isEmpty);
        },
      );

      test(
        'annotated_extra.pdf — squiggly, strikeout, stamp, freetext, polygon',
        () async {
          doc = await PdfDocument.fromBytes(
            await _fetchFixture('annotated_extra.pdf'),
          );
          final pages = await doc.extractAnnotations().toList();
          final all = pages.expand((p) => p.annotations).toList();

          final markups = all.whereType<PdfMarkupAnnotation>().toList();
          expect(
            markups.map((m) => m.subtype),
            containsAll([
              PdfAnnotationType.squiggly,
              PdfAnnotationType.strikeout,
            ]),
          );

          final stamps = all.whereType<PdfStampAnnotation>().toList();
          expect(stamps, isNotEmpty);
          final stampCopy = PdfStampAnnotation(
            pageIndex: stamps.first.pageIndex,
            contents: stamps.first.contents,
            author: stamps.first.author,
            rect: stamps.first.rect,
            color: stamps.first.color,
            modifiedDate: stamps.first.modifiedDate,
            flags: stamps.first.flags,
            popup: stamps.first.popup,
          );
          expect(stampCopy, equals(stamps.first));
          expect(stampCopy.hashCode, equals(stamps.first.hashCode));
          expect(stampCopy.toString(), contains('PdfStampAnnotation'));

          final freeTexts = all.whereType<PdfFreeTextAnnotation>().toList();
          expect(freeTexts, isNotEmpty);

          final polygons = all.whereType<PdfPolygonAnnotation>().toList();
          expect(polygons, isNotEmpty);
          expect(polygons.first.vertices, isNotEmpty);
          final polygonCopy = PdfPolygonAnnotation(
            pageIndex: polygons.first.pageIndex,
            subtype: polygons.first.subtype,
            vertices: polygons.first.vertices,
            contents: polygons.first.contents,
            author: polygons.first.author,
            rect: polygons.first.rect,
            color: polygons.first.color,
            modifiedDate: polygons.first.modifiedDate,
            flags: polygons.first.flags,
            popup: polygons.first.popup,
          );
          expect(polygonCopy, equals(polygons.first));
          expect(polygonCopy.hashCode, equals(polygons.first.hashCode));
          expect(polygonCopy.toString(), contains('PdfPolygonAnnotation'));
        },
      );

      test('yields one entry per page for multi-page PDF', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('multi_page_annotated.pdf'),
        );
        final count = await doc.pageCount;
        final pages = await doc.extractAnnotations().toList();
        expect(pages.length, equals(count));
      });

      test('yields one entry for a single pageIndex', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('multi_page_annotated.pdf'),
        );
        final pages = await doc.extractAnnotations(pageIndex: 0).toList();
        expect(pages.length, equals(1));
        expect(pages.first.pageIndex, equals(0));
      });

      test(
        'close() during active extractAnnotations stream terminates cleanly',
        () async {
          // Regression test for worker RPC timing (Phase 5): extractAnnotations
          // fetches all pages in a single worker round trip, then yields them
          // locally. close() mid-stream is routed through the same per-token
          // request queue as the original request, so it must not race or
          // corrupt the in-flight extraction.
          doc = await PdfDocument.fromBytes(
            await _fetchFixture('multi_page_annotated.pdf'),
          );
          final results = <PdfPageAnnotations>[];
          await for (final page in doc.extractAnnotations()) {
            results.add(page);
            await doc.close();
          }
          // Only the first page should have been collected before close().
          expect(results, hasLength(1));
        },
      );
    });
  });

  // Worker RPC timing: concurrency and ordering (Phase 5).
  group('PdfDocument web — Worker RPC timing', () {
    test(
      'concurrent operations on the same document are serialized correctly',
      () async {
        final doc = await PdfDocument.fromBytes(
          await _fetchFixture('multi_page_annotated.pdf'),
        );
        try {
          // Fire several requests concurrently for the same document token;
          // the per-token request queue (_sendForToken) must serialize them
          // without cross-talk or corruption.
          final results = await Future.wait([
            doc.pageCount,
            doc.getMetadata(),
            doc.pageCount,
            doc.extractAnnotations().toList(),
            doc.pageCount,
          ]);
          expect(results[0], equals(results[2]));
          expect(results[2], equals(results[4]));
        } finally {
          await doc.close();
        }
      },
    );

    test(
      'closing one document does not affect concurrent operations on another',
      () async {
        final docA = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        final docB = await PdfDocument.fromBytes(
          await _fetchFixture('full_metadata.pdf'),
        );
        try {
          final bPageCountFuture = docB.pageCount;
          await docA.close();
          // docB's in-flight request (and the document itself) must be
          // unaffected by docA's close(), since requests are only serialized
          // per-token, not globally.
          expect(await bPageCountFuture, equals(1));
          expect(await docB.pageCount, equals(1));
        } finally {
          await docB.close();
        }
      },
    );
  });

  // Phase 2d: rendering and thumbnails.
  group('PdfDocument web — PR 2d', () {
    group('renderPageToBytes()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test(
        'renders no_annotations.pdf at 100x100 — correct buffer size',
        () async {
          doc = await PdfDocument.fromBytes(
            await _fetchFixture('no_annotations.pdf'),
          );
          final result = await doc.renderPageToBytes(0, 100, 100);
          expect(result.pixelWidth, equals(100));
          expect(result.pixelHeight, equals(100));
          expect(result.pixels.length, equals(100 * 100 * 4));
        },
      );

      test('renders with renderAnnotations=false — same buffer size', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        final result = await doc.renderPageToBytes(
          0,
          50,
          50,
          renderAnnotations: false,
        );
        expect(result.pixels.length, equals(50 * 50 * 4));
      });

      test('custom backgroundColor changes first pixel', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        // Render with white background and blue background; first pixel differs.
        final white = await doc.renderPageToBytes(
          0,
          1,
          1,
          backgroundColor: 0xFFFFFFFF,
        );
        final blue = await doc.renderPageToBytes(
          0,
          1,
          1,
          backgroundColor: 0xFF0000FF,
        );
        // The first pixel (B,G,R,A) differs between renders.
        expect(white.pixels, isNot(equals(blue.pixels)));
      });

      test('throws RangeError for negative pageIndex', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await expectLater(
          () => doc.renderPageToBytes(-1, 100, 100),
          throwsRangeError,
        );
      });

      test('throws RangeError for out-of-bounds pageIndex', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await expectLater(
          () => doc.renderPageToBytes(999, 100, 100),
          throwsRangeError,
        );
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(
          () => doc.renderPageToBytes(0, 100, 100),
          throwsStateError,
        );
      });
    });

    group('getThumbnail()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test(
        'falls back to rendered thumbnail when no embedded /Thumb exists',
        () async {
          doc = await PdfDocument.fromBytes(
            await _fetchFixture('no_annotations.pdf'),
          );
          final thumb = await doc.getThumbnail(0);
          expect(thumb, isNotNull);
          expect(thumb!.source, equals(PdfThumbnailSource.rendered));
          expect(thumb.width, greaterThan(0));
          expect(thumb.height, greaterThan(0));
          expect(thumb.bgra.length, equals(thumb.width * thumb.height * 4));
        },
      );

      test(
        'returns null when generateIfAbsent=false and no embedded thumb',
        () async {
          doc = await PdfDocument.fromBytes(
            await _fetchFixture('no_annotations.pdf'),
          );
          final thumb = await doc.getThumbnail(0, generateIfAbsent: false);
          expect(thumb, isNull);
        },
      );

      test('maxDimension=64 clamps rendered dimensions', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        final thumb = await doc.getThumbnail(0, maxDimension: 64);
        expect(thumb, isNotNull);
        expect(thumb!.width, lessThanOrEqualTo(64));
        expect(thumb.height, lessThanOrEqualTo(64));
      });

      test('throws ArgumentError when maxDimension <= 0', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await expectLater(
          () => doc.getThumbnail(0, maxDimension: 0),
          throwsArgumentError,
        );
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(() => doc.getThumbnail(0), throwsStateError);
      });
    });
  });

  // Phase 2e: images, search, table of contents.
  group('PdfDocument web — PR 2e', () {
    group('extractImages()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('no_images.pdf yields empty image lists', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('no_images.pdf'));
        final pages = await doc.extractImages().toList();
        final all = pages.expand((p) => p.images).toList();
        expect(all, isEmpty);
      });

      test('single_image.pdf yields exactly one image', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('single_image.pdf'),
        );
        final pages = await doc.extractImages().toList();
        final all = pages.expand((p) => p.images).toList();
        expect(all.length, equals(1));
        expect(all.first.metadata.width, greaterThan(0));
        expect(all.first.metadata.height, greaterThan(0));
      });

      test('multi_image.pdf yields multiple images', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('multi_image.pdf'),
        );
        final pages = await doc.extractImages().toList();
        final all = pages.expand((p) => p.images).toList();
        expect(all.length, greaterThan(1));
      });

      test('includeBitmap=true populates bgra on images', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('single_image.pdf'),
        );
        final pages = await doc.extractImages(includeBitmap: true).toList();
        final all = pages.expand((p) => p.images).toList();
        expect(all, isNotEmpty);
        // At least one image should have a non-null bitmap.
        final withBitmap = all.where((img) => img.bgra != null).toList();
        expect(withBitmap, isNotEmpty);
      });

      test('includeBitmap=false (default) leaves bgra null', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('single_image.pdf'),
        );
        final pages = await doc.extractImages().toList();
        final all = pages.expand((p) => p.images).toList();
        for (final img in all) {
          expect(img.bgra, isNull);
        }
      });

      test('yields one entry per page for a single pageIndex', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('no_images.pdf'));
        final pages = await doc.extractImages(pageIndex: 0).toList();
        expect(pages.length, equals(1));
        expect(pages.first.pageIndex, equals(0));
      });
    });

    group('renderImage()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('renders the first image from single_image.pdf', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('single_image.pdf'),
        );
        // Find the first image object index via extractImages.
        final pages = await doc.extractImages().toList();
        final images = pages.expand((p) => p.images).toList();
        expect(images, isNotEmpty);

        final img = images.first;
        final bitmap = await doc.renderImage(img.pageIndex, img.objectIndex);
        expect(bitmap, isNotNull);
        expect(bitmap!.width, greaterThan(0));
        expect(bitmap.height, greaterThan(0));
        expect(bitmap.bgra.length, equals(bitmap.width * bitmap.height * 4));
      });

      test('returns null for out-of-bounds objectIndex', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('no_images.pdf'));
        final result = await doc.renderImage(0, 9999);
        expect(result, isNull);
      });

      test('throws RangeError for negative objectIndex', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('no_images.pdf'));
        await expectLater(() => doc.renderImage(0, -1), throwsRangeError);
      });

      test('throws RangeError for negative pageIndex', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('no_images.pdf'));
        await expectLater(() => doc.renderImage(-1, 0), throwsRangeError);
      });

      test('throws RangeError for out-of-bounds pageIndex', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('no_images.pdf'));
        await expectLater(() => doc.renderImage(999, 0), throwsRangeError);
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(() => doc.renderImage(0, 0), throwsStateError);
      });
    });

    group('search()', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('empty query yields no matches', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('search_single.pdf'),
        );
        final matches = await doc.search('').toList();
        expect(matches, isEmpty);
      });

      test('search_single.pdf finds the expected word', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('search_single.pdf'),
        );
        final matches = await doc.search('the').toList();
        expect(matches, isNotEmpty);
        for (final m in matches) {
          expect(m.charCount, greaterThan(0));
          expect(m.rects, isNotEmpty);
        }
      });

      test('search_multipage.pdf finds matches across pages', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('search_multipage.pdf'),
        );
        // 'gamma' appears on all three pages of search_multipage.pdf.
        final matches = await doc.search('gamma').toList();
        expect(matches, isNotEmpty);
      });

      test('pageIndex restricts search to one page', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('search_multipage.pdf'),
        );
        // 'gamma' appears on all pages; restricting to page 0 should yield only page-0 hits.
        final matches = await doc.search('gamma', pageIndex: 0).toList();
        for (final m in matches) {
          expect(m.pageIndex, equals(0));
        }
      });

      test('matchCase flag differentiates case', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('search_single.pdf'),
        );
        // A case-sensitive search for an uppercase word may yield different
        // results than a case-insensitive one. We test both complete without
        // error and that the case-sensitive set is a subset of the insensitive.
        final insensitive = await doc.search('The').toList();
        final sensitive = await doc
            .search('The', flags: {PdfSearchFlag.matchCase})
            .toList();
        expect(sensitive.length, lessThanOrEqualTo(insensitive.length));
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(() => doc.search('test').toList(), throwsStateError);
      });
    });

    group('tableOfContents', () {
      late PdfDocument doc;
      tearDown(() async {
        try {
          await doc.close();
        } catch (_) {}
      });

      test('no_toc.pdf returns an empty list', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('no_toc.pdf'));
        final toc = await doc.tableOfContents;
        expect(toc, isEmpty);
      });

      test('flat_toc.pdf returns top-level entries', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('flat_toc.pdf'));
        final toc = await doc.tableOfContents;
        expect(toc, isNotEmpty);
        for (final entry in toc) {
          expect(entry.title, isNotEmpty);
        }
      });

      test('nested_toc.pdf returns entries with children', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('nested_toc.pdf'),
        );
        final toc = await doc.tableOfContents;
        expect(toc, isNotEmpty);
        final hasChildren = toc.any((e) => e.children.isNotEmpty);
        expect(hasChildren, isTrue);
      });

      test('flat_toc.pdf entries have valid page indices', () async {
        doc = await PdfDocument.fromBytes(await _fetchFixture('flat_toc.pdf'));
        final count = await doc.pageCount;
        final toc = await doc.tableOfContents;
        for (final entry in toc) {
          if (entry.pageIndex != null) {
            expect(entry.pageIndex, greaterThanOrEqualTo(0));
            expect(entry.pageIndex, lessThan(count));
          }
        }
      });

      test('throws StateError after close()', () async {
        doc = await PdfDocument.fromBytes(
          await _fetchFixture('no_annotations.pdf'),
        );
        await doc.close();
        await expectLater(
          () async => await doc.tableOfContents,
          throwsStateError,
        );
      });
    });
  });
}
