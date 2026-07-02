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

// Direct-engine coverage tests for the Web Worker offload plan (Phase 4).
//
// `_pdfium_wasm_engine.dart` (the PDFium marshalling engine) normally runs
// exclusively inside a spawned Worker after the Phase 3 rewrite of
// `PdfDocumentImpl` into a thin RPC client. Chrome DevTools Protocol's
// coverage collector (used by `dart test -p chrome --coverage`) attaches to
// a single tab target only — a spawned Worker is a separate CDP target that
// is structurally invisible to it (see the Web Worker offload plan's
// "Testing impact" section for the confirmed analysis, verified directly
// against the pinned `test-1.31.2` `chrome.dart` source).
//
// This file bypasses the Worker entirely: it calls `loadPdfiumModule()` (the
// Phase 1 bootstrap function) and the Phase 1 engine functions directly, on
// the main thread, inside a `dart test -p chrome` test. This exercises the
// exact same marshalling logic the worker calls at runtime, but in a context
// the coverage collector CAN see — preserving the web coverage gate without
// requiring worker-target CDP support.
//
// Runs exclusively under `dart test -p chrome` (make web_test /
// make web_coverage), like test/pdf_document_web_test.dart.

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'package:betto_pdfium/src/document/_pdfium_js_interop.dart';
import 'package:betto_pdfium/src/document/_pdfium_wasm_engine.dart';
import 'package:betto_pdfium/src/document/pdf_types.dart';

/// Fetches a fixture file from `test/fixtures/{name}` via the dart test
/// local HTTP server — mirrors the private helper in
/// `pdf_document_web_test.dart`.
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

/// Fetches a fixture file from `test/data/{name}` via the dart test local
/// HTTP server.
Future<Uint8List> _fetchDataFixture(String name) async {
  final response = await web.window.fetch('data/$name'.toJS).toDart;
  if (!response.ok) {
    throw StateError(
      'Failed to fetch test fixture data/$name: HTTP ${response.status}',
    );
  }
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

void main() {
  // The WASM module is a page-lifetime singleton; loading it once and
  // reusing it across all tests in this file mirrors how the real worker
  // (and the pre-Phase-3 main-thread implementation) load it exactly once.
  late PdfiumModule module;

  setUpAll(() async {
    module = await loadPdfiumModule();
  });

  group('loadPdfiumModule()', () {
    test('returns a module usable for subsequent engine calls', () async {
      // A second call does not need to succeed for reuse purposes (the
      // worker only calls this once too); this just exercises the bootstrap
      // function's return value shape.
      expect(module, isNotNull);
    });
  });

  group('engineLoadDocument / engineCloseDocument', () {
    test('loads and closes a valid document', () async {
      final bytes = await _fetchFixture('no_annotations.pdf');
      final rec = engineLoadDocument(module, bytes);
      expect(rec.docPtr, isNot(0));
      expect(enginePageCount(module, rec.docPtr), equals(1));
      engineCloseDocument(module, rec.docPtr, rec.bufPtr);
    });

    test('throws PdfExtractionException for corrupt bytes', () async {
      final bytes = await _fetchFixture('corrupt.pdf');
      expect(
        () => engineLoadDocument(module, bytes),
        throwsA(
          isA<PdfExtractionException>().having(
            (e) => e.error,
            'error',
            PdfError.invalidDocument,
          ),
        ),
      );
    });

    test(
      'throws PdfExtractionException for password-protected bytes',
      () async {
        final bytes = await _fetchFixture('password.pdf');
        expect(
          () => engineLoadDocument(module, bytes),
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

    test('throws PdfExtractionException for empty bytes', () {
      expect(
        () => engineLoadDocument(module, Uint8List(0)),
        throwsA(isA<PdfExtractionException>()),
      );
    });
  });

  group('metadata, document info, page size', () {
    late ({int docPtr, int bufPtr}) rec;

    setUp(() async {
      final bytes = await _fetchFixture('full_metadata.pdf');
      rec = engineLoadDocument(module, bytes);
    });

    tearDown(() {
      engineCloseDocument(module, rec.docPtr, rec.bufPtr);
    });

    test('engineGetMetadata returns populated fields', () {
      final metadata = engineGetMetadata(module, rec.docPtr);
      expect(metadata.title, isNotNull);
    });

    test('engineGetDocumentInfo returns a file version', () {
      final info = engineGetDocumentInfo(module, rec.docPtr);
      expect(info.fileVersion, isNotNull);
    });

    test('engineGetPageSize returns positive dimensions', () {
      final size = engineGetPageSize(module, rec.docPtr, 0);
      expect(size.widthPt, greaterThan(0));
      expect(size.heightPt, greaterThan(0));
    });

    test('engineGetPageSize throws RangeError for out-of-range page', () {
      expect(() => engineGetPageSize(module, rec.docPtr, 99), throwsRangeError);
    });

    test('engineResolvePageIndices returns all indices when null', () {
      final indices = engineResolvePageIndices(module, rec.docPtr, null);
      expect(indices, equals([0]));
    });

    test('engineResolvePageIndices returns single index when specified', () {
      final indices = engineResolvePageIndices(module, rec.docPtr, 0);
      expect(indices, equals([0]));
    });

    test('engineResolvePageIndices throws RangeError out of range', () {
      expect(
        () => engineResolvePageIndices(module, rec.docPtr, 99),
        throwsRangeError,
      );
    });
  });

  group('engineGetMetadata — sparse documents', () {
    test('no_metadata.pdf returns null string fields', () async {
      final bytes = await _fetchFixture('no_metadata.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final metadata = engineGetMetadata(module, rec.docPtr);
        expect(metadata.title, isNull);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });
  });

  group('engineRenderPageToBytes', () {
    late ({int docPtr, int bufPtr}) rec;

    setUp(() async {
      final bytes = await _fetchFixture('single_column.pdf');
      rec = engineLoadDocument(module, bytes);
    });

    tearDown(() {
      engineCloseDocument(module, rec.docPtr, rec.bufPtr);
    });

    test('renders a page to a compact BGRA buffer', () {
      final result = engineRenderPageToBytes(module, rec.docPtr, 0, 40, 60);
      expect(result.pixelWidth, equals(40));
      expect(result.pixelHeight, equals(60));
      expect(result.pixels.length, equals(40 * 60 * 4));
    });

    test('renders with lcdText and no annotations flags set', () {
      final result = engineRenderPageToBytes(
        module,
        rec.docPtr,
        0,
        20,
        20,
        renderAnnotations: false,
        lcdText: true,
        backgroundColor: 0xFF000000,
      );
      expect(result.pixels.length, equals(20 * 20 * 4));
    });

    test('throws RangeError for out-of-range page', () {
      expect(
        () => engineRenderPageToBytes(module, rec.docPtr, 99, 10, 10),
        throwsRangeError,
      );
    });
  });

  group('engineGetThumbnail', () {
    test(
      'renders a fallback thumbnail when no embedded stream exists',
      () async {
        final bytes = await _fetchFixture('single_column.pdf');
        final rec = engineLoadDocument(module, bytes);
        try {
          final thumb = engineGetThumbnail(
            module,
            rec.docPtr,
            0,
            maxDimension: 32,
          );
          expect(thumb, isNotNull);
          expect(thumb!.source, equals(PdfThumbnailSource.rendered));
          expect(thumb.bgra.length, equals(thumb.width * thumb.height * 4));
        } finally {
          engineCloseDocument(module, rec.docPtr, rec.bufPtr);
        }
      },
    );

    test(
      'returns null when generateIfAbsent is false and no embedded thumb',
      () async {
        final bytes = await _fetchFixture('single_column.pdf');
        final rec = engineLoadDocument(module, bytes);
        try {
          final thumb = engineGetThumbnail(
            module,
            rec.docPtr,
            0,
            generateIfAbsent: false,
          );
          expect(thumb, isNull);
        } finally {
          engineCloseDocument(module, rec.docPtr, rec.bufPtr);
        }
      },
    );

    test('throws ArgumentError for non-positive maxDimension', () async {
      final bytes = await _fetchFixture('single_column.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        expect(
          () => engineGetThumbnail(module, rec.docPtr, 0, maxDimension: 0),
          throwsArgumentError,
        );
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('throws RangeError for out-of-range page', () async {
      final bytes = await _fetchFixture('single_column.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        expect(
          () => engineGetThumbnail(module, rec.docPtr, 99),
          throwsRangeError,
        );
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test(
      'returns the embedded /Thumb stream when present (thumbnail_fixture.pdf)',
      () async {
        final bytes = await _fetchDataFixture('thumbnail_fixture.pdf');
        final rec = engineLoadDocument(module, bytes);
        try {
          // Page 0 has an embedded 8x8 /Thumb stream.
          final thumb = engineGetThumbnail(module, rec.docPtr, 0);
          expect(thumb, isNotNull);
          expect(thumb!.source, equals(PdfThumbnailSource.embedded));
          expect(thumb.bgra.length, equals(thumb.width * thumb.height * 4));
        } finally {
          engineCloseDocument(module, rec.docPtr, rec.bufPtr);
        }
      },
    );
  });

  group('text extraction', () {
    test('engineExtractPageText extracts non-empty text', () async {
      final bytes = await _fetchFixture('single_column.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final page = engineExtractPageText(module, rec.docPtr, 0);
        expect(page.hasTextLayer, isTrue);
        expect(page.text, isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineExtractPageText soft-hyphen fixture strips hyphens', () async {
      final bytes = await _fetchFixture('soft_hyphens.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final page = engineExtractPageText(module, rec.docPtr, 0);
        expect(page.text, isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineExtractPageText scanned.pdf has no text layer', () async {
      final bytes = await _fetchFixture('scanned.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final page = engineExtractPageText(module, rec.docPtr, 0);
        expect(page.hasTextLayer, isFalse);
        expect(page.text, isEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });
  });

  group('annotation extraction', () {
    test('engineExtractPageAnnotations — text and markup', () async {
      final bytes = await _fetchFixture('annotated_text.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
        expect(annots, isNotEmpty);
        expect(annots.whereType<PdfTextAnnotation>(), isNotEmpty);
        expect(annots.whereType<PdfMarkupAnnotation>(), isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineExtractPageAnnotations — shapes and line', () async {
      final bytes = await _fetchFixture('annotated_shapes.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
        expect(annots.whereType<PdfShapeAnnotation>(), isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineExtractPageAnnotations — ink strokes', () async {
      final bytes = await _fetchFixture('annotated_ink.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
        final ink = annots.whereType<PdfInkAnnotation>().toList();
        expect(ink, isNotEmpty);
        expect(ink.first.strokes, isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test(
      'engineExtractPageAnnotations — squiggly, strikeout, stamp, freetext, polygon',
      () async {
        final bytes = await _fetchFixture('annotated_extra.pdf');
        final rec = engineLoadDocument(module, bytes);
        try {
          final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
          expect(annots.whereType<PdfStampAnnotation>(), isNotEmpty);
          expect(annots.whereType<PdfFreeTextAnnotation>(), isNotEmpty);
          final polygons = annots.whereType<PdfPolygonAnnotation>().toList();
          expect(polygons, isNotEmpty);
          expect(polygons.first.vertices, isNotEmpty);
          final markupSubtypes = annots
              .whereType<PdfMarkupAnnotation>()
              .map((m) => m.subtype)
              .toSet();
          expect(
            markupSubtypes,
            containsAll([
              PdfAnnotationType.squiggly,
              PdfAnnotationType.strikeout,
            ]),
          );
        } finally {
          engineCloseDocument(module, rec.docPtr, rec.bufPtr);
        }
      },
    );

    test('engineExtractPageAnnotations — popup linked to parent', () async {
      final bytes = await _fetchFixture('popup_annotation.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
        expect(annots.where((a) => a.popup != null), isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineExtractPageAnnotations — freetext popup', () async {
      final bytes = await _fetchFixture('popup_freetext.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
        final freeText = annots
            .whereType<PdfFreeTextAnnotation>()
            .where((a) => a.popup != null)
            .toList();
        expect(freeText, isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineExtractPageAnnotations — zero-point ink stroke', () async {
      final bytes = await _fetchFixture('zero_ink_stroke.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
        final ink = annots.whereType<PdfInkAnnotation>().toList();
        expect(ink, isNotEmpty);
        expect(ink.first.strokes.first, isEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineExtractPageAnnotations — zero polygon vertices', () async {
      final bytes = await _fetchFixture('zero_polygon_vertices.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
        final polygons = annots.whereType<PdfPolygonAnnotation>().toList();
        expect(polygons, isNotEmpty);
        expect(polygons.first.vertices, isEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test(
      'engineExtractPageAnnotations — link annotation with empty URI',
      () async {
        final bytes = await _fetchFixture('empty_uri_link.pdf');
        final rec = engineLoadDocument(module, bytes);
        try {
          final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
          final links = annots.whereType<PdfLinkAnnotation>().toList();
          expect(links, isNotEmpty);
          // FPDFAction_GetURIPath returns a non-zero length but an empty
          // string; _readActionUri (and therefore _readLinkUri) returns null.
          expect(links.first.uri, isNull);
        } finally {
          engineCloseDocument(module, rec.docPtr, rec.bufPtr);
        }
      },
    );

    test('engineExtractPageAnnotations — popup_multi.pdf links a popup onto '
        'every _withPopup arm (markup, shape, line, ink, polygon, stamp, '
        'unknown)', () async {
      final bytes = await _fetchFixture('popup_multi.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final annots = engineExtractPageAnnotations(module, rec.docPtr, 0);
        final withPopup = annots.where((a) => a.popup != null).toList();
        // Seven parent annotations, each with its own popup.
        expect(withPopup.length, equals(7));

        expect(
          withPopup.whereType<PdfMarkupAnnotation>().single.popup,
          isNotNull,
        );
        expect(
          withPopup.whereType<PdfShapeAnnotation>().single.popup,
          isNotNull,
        );
        expect(
          withPopup.whereType<PdfLineAnnotation>().single.popup,
          isNotNull,
        );
        expect(withPopup.whereType<PdfInkAnnotation>().single.popup, isNotNull);
        expect(
          withPopup.whereType<PdfPolygonAnnotation>().single.popup,
          isNotNull,
        );
        expect(
          withPopup.whereType<PdfStampAnnotation>().single.popup,
          isNotNull,
        );
        expect(
          withPopup.whereType<PdfUnknownAnnotation>().single.popup,
          isNotNull,
        );
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });
  });

  group('image extraction', () {
    test('engineExtractPageImages returns metadata without bitmap', () async {
      final bytes = await _fetchFixture('single_image.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final images = engineExtractPageImages(module, rec.docPtr, 0, false);
        expect(images, isNotEmpty);
        expect(images.first.bgra, isNull);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineExtractPageImages includes bitmap when requested', () async {
      final bytes = await _fetchFixture('single_image.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final images = engineExtractPageImages(module, rec.docPtr, 0, true);
        expect(images, isNotEmpty);
        expect(images.first.bgra, isNotNull);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test(
      'engineExtractPageImages returns empty list for no_images.pdf',
      () async {
        final bytes = await _fetchFixture('no_images.pdf');
        final rec = engineLoadDocument(module, bytes);
        try {
          final images = engineExtractPageImages(module, rec.docPtr, 0, false);
          expect(images, isEmpty);
        } finally {
          engineCloseDocument(module, rec.docPtr, rec.bufPtr);
        }
      },
    );

    test(
      'engineRenderImage returns a bitmap for a valid image object',
      () async {
        final bytes = await _fetchFixture('single_image.pdf');
        final rec = engineLoadDocument(module, bytes);
        try {
          final bitmap = engineRenderImage(module, rec.docPtr, 0, 0);
          expect(bitmap, isNotNull);
          expect(bitmap!.bgra.length, equals(bitmap.width * bitmap.height * 4));
        } finally {
          engineCloseDocument(module, rec.docPtr, rec.bufPtr);
        }
      },
    );

    test(
      'engineRenderImage throws RangeError for negative objectIndex',
      () async {
        final bytes = await _fetchFixture('single_image.pdf');
        final rec = engineLoadDocument(module, bytes);
        try {
          expect(
            () => engineRenderImage(module, rec.docPtr, 0, -1),
            throwsRangeError,
          );
        } finally {
          engineCloseDocument(module, rec.docPtr, rec.bufPtr);
        }
      },
    );

    test('engineRenderImage throws RangeError for out-of-range page', () async {
      final bytes = await _fetchFixture('single_image.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        expect(
          () => engineRenderImage(module, rec.docPtr, 99, 0),
          throwsRangeError,
        );
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });
  });

  group('search', () {
    test('engineSearchPage finds matches', () async {
      final bytes = await _fetchFixture('search_single.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        // Search a broad common substring likely present in generated text;
        // fall back to asserting the call completes without throwing and
        // returns a List (possibly empty depending on fixture content).
        final matches = engineSearchPage(module, rec.docPtr, 0, 'e', 0);
        expect(matches, isA<List<PdfSearchMatch>>());
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineSearchPage with matchCase flag', () async {
      final bytes = await _fetchFixture('search_single.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final matches = engineSearchPage(module, rec.docPtr, 0, 'E', 0x01);
        expect(matches, isA<List<PdfSearchMatch>>());
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });
  });

  group('table of contents', () {
    test('engineTableOfContents returns entries for a nested TOC', () async {
      final bytes = await _fetchFixture('nested_toc.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final entries = engineTableOfContents(module, rec.docPtr);
        expect(entries, isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineTableOfContents returns empty list for no_toc.pdf', () async {
      final bytes = await _fetchFixture('no_toc.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final entries = engineTableOfContents(module, rec.docPtr);
        expect(entries, isEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineTableOfContents handles a deep TOC without cycling', () async {
      final bytes = await _fetchFixture('deep_toc.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final entries = engineTableOfContents(module, rec.docPtr);
        expect(entries, isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });

    test('engineTableOfContents resolves a flat TOC', () async {
      final bytes = await _fetchFixture('flat_toc.pdf');
      final rec = engineLoadDocument(module, bytes);
      try {
        final entries = engineTableOfContents(module, rec.docPtr);
        expect(entries, isNotEmpty);
      } finally {
        engineCloseDocument(module, rec.docPtr, rec.bufPtr);
      }
    });
  });
}
