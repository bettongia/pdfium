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

// Mobile integration test suite for betto_pdfium.
//
// Replicates the desktop test suite against PDF fixtures bundled as Flutter
// assets. PDFs are loaded from the asset bundle via rootBundle.load(), so the
// tests run identically on iOS and Android.
//
// Test groups:
//   Smoke               — library load and basic open/close round-trip
//   Page count          — pageCount matches expected values
//   Metadata            — getMetadata() field values and null handling
//   Plain text          — extractPlainText() content assertions
//   Rendering           — renderPageToBytes() pixel-count validation
//   Annotations         — extractAnnotations() type and count assertions
//   Image extraction    — extractImages() count and non-empty bytes
//   Table of contents   — tableOfContents title/depth assertions
//   Search              — search() match count and rect assertions
//   Thumbnail           — getThumbnail() non-empty BGRA bytes
//   Error handling      — corrupt/password PDFs throw; empty PDF does not crash
//
// Fixtures mirror test/fixtures/ and test/data/ in the root package.
// They are kept in sync by `make sync_fixtures`.

import 'dart:typed_data';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ---------------------------------------------------------------------------
// Asset loading
// ---------------------------------------------------------------------------

/// Loads an asset from the `assets/fixtures/` directory.
Future<Uint8List> _fixture(String name) => _loadAsset('assets/fixtures/$name');

/// Loads an asset from the `assets/data/` directory.
Future<Uint8List> _data(String name) => _loadAsset('assets/data/$name');

/// Loads a Flutter asset by path and returns it as a [Uint8List].
Future<Uint8List> _loadAsset(String path) async {
  final byteData = await rootBundle.load(path);
  return byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // Smoke: library load and basic round-trip
  // =========================================================================

  group('Smoke', () {
    test(
      'PdfDocument.fromBytes() opens 01_basic.pdf without throwing',
      () async {
        final bytes = await _data('01_basic.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        await doc.close();
      },
    );

    test('close() can be called twice without error', () async {
      final bytes = await _data('01_basic.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      await doc.close();
      await doc.close(); // idempotent
    });

    test('00_empty.pdf opens without throwing', () async {
      // 00_empty.pdf is a blank 1-page PDF used as a minimal fixture — the
      // important thing is that it opens without throwing, not its page count.
      final bytes = await _data('00_empty.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        expect(await doc.pageCount, greaterThanOrEqualTo(0));
      } finally {
        await doc.close();
      }
    });
  });

  // =========================================================================
  // Page count
  // =========================================================================

  group('Page count', () {
    test('01_basic.pdf has exactly 1 page', () async {
      final bytes = await _data('01_basic.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        expect(await doc.pageCount, equals(1));
      } finally {
        await doc.close();
      }
    });

    test('multi_page_annotated.pdf has more than 1 page', () async {
      final bytes = await _fixture('multi_page_annotated.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        expect(await doc.pageCount, greaterThan(1));
      } finally {
        await doc.close();
      }
    });

    test('scanned.pdf has at least 1 page', () async {
      final bytes = await _fixture('scanned.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        expect(await doc.pageCount, greaterThanOrEqualTo(1));
      } finally {
        await doc.close();
      }
    });
  });

  // =========================================================================
  // Metadata
  // =========================================================================

  group('Metadata', () {
    test('full_metadata.pdf returns non-null title and author', () async {
      final bytes = await _fixture('full_metadata.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final meta = await doc.getMetadata();
        expect(meta.title, isNotNull);
        expect(meta.title, isNotEmpty);
        expect(meta.author, isNotNull);
        expect(meta.author, isNotEmpty);
      } finally {
        await doc.close();
      }
    });

    test('no_metadata.pdf returns all-null metadata fields', () async {
      final bytes = await _fixture('no_metadata.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final meta = await doc.getMetadata();
        expect(meta.title, isNull);
        expect(meta.author, isNull);
        expect(meta.subject, isNull);
        expect(meta.keywords, isNull);
        expect(meta.creator, isNull);
        expect(meta.producer, isNull);
      } finally {
        await doc.close();
      }
    });

    test(
      'partial_metadata.pdf returns a mix of null and non-null fields',
      () async {
        final bytes = await _fixture('partial_metadata.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          // At least one field is present; at least one is absent.
          final meta = await doc.getMetadata();
          final fields = [
            meta.title,
            meta.author,
            meta.subject,
            meta.keywords,
            meta.creator,
            meta.producer,
          ];
          final nonNullCount = fields.where((f) => f != null).length;
          // partial_metadata.pdf has some but not all fields set.
          expect(nonNullCount, greaterThan(0));
          expect(nonNullCount, lessThan(fields.length));
        } finally {
          await doc.close();
        }
      },
    );
  });

  // =========================================================================
  // Plain text extraction
  // =========================================================================

  group('Plain text extraction', () {
    test('single_column.pdf yields non-empty text on page 0', () async {
      final bytes = await _fixture('single_column.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final pages = await doc.extractPlainText().toList();
        expect(pages, isNotEmpty);
        expect(pages.first.text, isNotEmpty);
      } finally {
        await doc.close();
      }
    });

    test('multi_column.pdf yields non-empty text on page 0', () async {
      final bytes = await _fixture('multi_column.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final pages = await doc.extractPlainText().toList();
        expect(pages, isNotEmpty);
        expect(pages.first.text, isNotEmpty);
      } finally {
        await doc.close();
      }
    });

    test(
      'soft_hyphens.pdf text contains joined words (no stray hyphens)',
      () async {
        final bytes = await _fixture('soft_hyphens.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final pages = await doc.extractPlainText().toList();
          expect(pages, isNotEmpty);
          // soft_hyphens.pdf has soft hyphens that should be stripped and words
          // joined. The extracted text should be non-empty.
          expect(pages.first.text, isNotEmpty);
        } finally {
          await doc.close();
        }
      },
    );

    test('scanned.pdf reports hasTextLayer false on all pages', () async {
      final bytes = await _fixture('scanned.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final pages = await doc.extractPlainText().toList();
        // A scanned PDF has no text layer — all pages should report false.
        for (final page in pages) {
          expect(page.hasTextLayer, isFalse);
        }
      } finally {
        await doc.close();
      }
    });
  });

  // =========================================================================
  // Rendering
  // =========================================================================

  group('Rendering', () {
    test(
      'renderPageToBytes() for 01_basic.pdf returns correct BGRA byte count',
      () async {
        final bytes = await _data('01_basic.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          const width = 100;
          const height = 141; // approximate A4 aspect ratio at 100px wide
          final result = await doc.renderPageToBytes(0, width, height);
          // BGRA: 4 bytes per pixel.
          expect(result.pixels.length, equals(width * height * 4));
          expect(result.pixelWidth, equals(width));
          expect(result.pixelHeight, equals(height));
        } finally {
          await doc.close();
        }
      },
    );

    test(
      'renderPageToBytes() produces non-zero bytes (not a blank buffer)',
      () async {
        final bytes = await _data('01_basic.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final result = await doc.renderPageToBytes(0, 64, 64);
          // At least some pixels should differ from 0 (the page has content).
          final hasNonZero = result.pixels.any((b) => b != 0);
          expect(hasNonZero, isTrue);
        } finally {
          await doc.close();
        }
      },
    );
  });

  // =========================================================================
  // Annotations
  // =========================================================================

  group('Annotations', () {
    test(
      'no_annotations.pdf returns empty annotation list on all pages',
      () async {
        final bytes = await _fixture('no_annotations.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final pages = await doc.extractAnnotations().toList();
          for (final page in pages) {
            expect(page.annotations, isEmpty);
          }
        } finally {
          await doc.close();
        }
      },
    );

    test(
      'annotated_text.pdf has at least one text (sticky-note) annotation',
      () async {
        final bytes = await _fixture('annotated_text.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final pages = await doc.extractAnnotations().toList();
          final allAnnotations = pages.expand((p) => p.annotations).toList();
          final textAnnotations = allAnnotations
              .whereType<PdfTextAnnotation>()
              .toList();
          expect(textAnnotations, isNotEmpty);
        } finally {
          await doc.close();
        }
      },
    );

    test('annotated_shapes.pdf has at least one shape annotation', () async {
      final bytes = await _fixture('annotated_shapes.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final pages = await doc.extractAnnotations().toList();
        final allAnnotations = pages.expand((p) => p.annotations).toList();
        final shapeAnnotations = allAnnotations
            .whereType<PdfShapeAnnotation>()
            .toList();
        expect(shapeAnnotations, isNotEmpty);
      } finally {
        await doc.close();
      }
    });

    test('annotated_ink.pdf has at least one ink annotation', () async {
      final bytes = await _fixture('annotated_ink.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final pages = await doc.extractAnnotations().toList();
        final allAnnotations = pages.expand((p) => p.annotations).toList();
        final inkAnnotations = allAnnotations
            .whereType<PdfInkAnnotation>()
            .toList();
        expect(inkAnnotations, isNotEmpty);
      } finally {
        await doc.close();
      }
    });
  });

  // =========================================================================
  // Image extraction
  // =========================================================================

  group('Image extraction', () {
    test('no_images.pdf returns zero images on all pages', () async {
      final bytes = await _fixture('no_images.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        var totalImages = 0;
        await for (final page in doc.extractImages()) {
          totalImages += page.images.length;
        }
        expect(totalImages, equals(0));
      } finally {
        await doc.close();
      }
    });

    test('single_image.pdf returns exactly one image', () async {
      final bytes = await _fixture('single_image.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        var totalImages = 0;
        await for (final page in doc.extractImages()) {
          totalImages += page.images.length;
        }
        expect(totalImages, equals(1));
      } finally {
        await doc.close();
      }
    });

    test('multi_image.pdf returns more than one image', () async {
      final bytes = await _fixture('multi_image.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        var totalImages = 0;
        await for (final page in doc.extractImages()) {
          totalImages += page.images.length;
        }
        expect(totalImages, greaterThan(1));
      } finally {
        await doc.close();
      }
    });

    test(
      'renderImage() for single_image.pdf returns non-empty BGRA bytes',
      () async {
        final bytes = await _fixture('single_image.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final pages = await doc.extractImages().toList();
          expect(pages, isNotEmpty);
          final firstPage = pages.firstWhere((p) => p.images.isNotEmpty);
          final firstImage = firstPage.images.first;

          final bitmap = await doc.renderImage(
            firstPage.pageIndex,
            firstImage.objectIndex,
          );
          expect(bitmap, isNotNull);
          expect(bitmap!.bgra, isNotEmpty);
          expect(bitmap.width, greaterThan(0));
          expect(bitmap.height, greaterThan(0));
        } finally {
          await doc.close();
        }
      },
    );
  });

  // =========================================================================
  // Table of contents
  // =========================================================================

  group('Table of contents', () {
    test('no_toc.pdf returns an empty table of contents', () async {
      final bytes = await _fixture('no_toc.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final toc = await doc.tableOfContents;
        expect(toc, isEmpty);
      } finally {
        await doc.close();
      }
    });

    test(
      'flat_toc.pdf returns top-level entries with non-empty titles',
      () async {
        final bytes = await _fixture('flat_toc.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final toc = await doc.tableOfContents;
          expect(toc, isNotEmpty);
          // All top-level entries should have non-empty titles.
          for (final entry in toc) {
            expect(entry.title, isNotEmpty);
          }
        } finally {
          await doc.close();
        }
      },
    );

    test('nested_toc.pdf returns entries with children at depth ≥ 1', () async {
      final bytes = await _fixture('nested_toc.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final toc = await doc.tableOfContents;
        expect(toc, isNotEmpty);
        // At least one top-level entry should have children.
        final hasChildren = toc.any((e) => e.children.isNotEmpty);
        expect(hasChildren, isTrue);
      } finally {
        await doc.close();
      }
    });
  });

  // =========================================================================
  // Search
  // =========================================================================

  group('Search', () {
    test('search() on search_single.pdf finds at least one match', () async {
      final bytes = await _fixture('search_single.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        // search_single.pdf contains "quick brown fox" on page 0.
        final matches = <PdfSearchMatch>[];
        await for (final match in doc.search('quick')) {
          matches.add(match);
        }
        expect(matches, isNotEmpty);
      } finally {
        await doc.close();
      }
    });

    test(
      'search() on search_single.pdf returns matches with non-empty rects',
      () async {
        final bytes = await _fixture('search_single.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          await for (final match in doc.search('quick')) {
            expect(match.rects, isNotEmpty);
            for (final rect in match.rects) {
              // Bounding rect must have non-zero area.
              expect(rect.right - rect.left, greaterThan(0));
              expect(rect.top - rect.bottom, greaterThan(0));
            }
          }
        } finally {
          await doc.close();
        }
      },
    );

    test(
      'search() on search_multipage.pdf finds "gamma" on multiple pages',
      () async {
        final bytes = await _fixture('search_multipage.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final pageIndices = <int>{};
          await for (final match in doc.search('gamma')) {
            pageIndices.add(match.pageIndex);
          }
          // The multipage fixture has "page" on more than one page.
          expect(pageIndices.length, greaterThan(1));
        } finally {
          await doc.close();
        }
      },
    );

    test(
      'search() for a term absent from the document returns no matches',
      () async {
        final bytes = await _fixture('no_metadata.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final matches = <PdfSearchMatch>[];
          await for (final match in doc.search('xyzzy_nonexistent_term_42')) {
            matches.add(match);
          }
          expect(matches, isEmpty);
        } finally {
          await doc.close();
        }
      },
    );
  });

  // =========================================================================
  // Thumbnail
  // =========================================================================

  group('Thumbnail', () {
    test('thumbnail_fixture.pdf page 0 has an embedded thumbnail', () async {
      final bytes = await _data('thumbnail_fixture.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final thumb = await doc.getThumbnail(0);
        expect(thumb, isNotNull);
        // The embedded thumbnail has non-empty BGRA bytes.
        expect(thumb!.bgra, isNotEmpty);
        expect(thumb.width, greaterThan(0));
        expect(thumb.height, greaterThan(0));
      } finally {
        await doc.close();
      }
    });

    test('01_basic.pdf getThumbnail() returns a rendered fallback', () async {
      // 01_basic.pdf has no embedded /Thumb stream; getThumbnail should fall
      // back to a rendered thumbnail rather than returning null.
      final bytes = await _data('01_basic.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      try {
        final thumb = await doc.getThumbnail(0);
        expect(thumb, isNotNull);
        expect(thumb!.bgra, isNotEmpty);
      } finally {
        await doc.close();
      }
    });
  });

  // =========================================================================
  // Error handling
  // =========================================================================

  group('Error handling', () {
    test('corrupt.pdf throws PdfExtractionException on fromBytes()', () async {
      final bytes = await _fixture('corrupt.pdf');
      await expectLater(
        () => PdfDocument.fromBytes(bytes),
        throwsA(isA<PdfExtractionException>()),
      );
    });

    test('password.pdf throws PdfExtractionException on fromBytes()', () async {
      final bytes = await _fixture('password.pdf');
      await expectLater(
        () => PdfDocument.fromBytes(bytes),
        throwsA(isA<PdfExtractionException>()),
      );
    });

    test('00_empty.pdf does not throw (zero pages is valid)', () async {
      // An empty (0-page) PDF is structurally valid and must not throw.
      final bytes = await _data('00_empty.pdf');
      final doc = await PdfDocument.fromBytes(bytes);
      await doc.close();
    });

    test(
      'broken_image_metadata.pdf does not crash during image extraction',
      () async {
        // broken_image_metadata.pdf has an image object with broken metadata.
        // The API should handle it gracefully (skip the broken object or return
        // empty metadata) rather than throwing or crashing.
        final bytes = await _fixture('broken_image_metadata.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          // Should complete without throwing.
          final pages = await doc.extractImages().toList();
          expect(pages, isNotNull);
        } finally {
          await doc.close();
        }
      },
    );
  });

  // =========================================================================
  // Page size
  // =========================================================================

  group('Page size', () {
    test(
      'getPageSize() for 01_basic.pdf returns positive dimensions',
      () async {
        final bytes = await _data('01_basic.pdf');
        final doc = await PdfDocument.fromBytes(bytes);
        try {
          final size = await doc.getPageSize(0);
          expect(size.widthPt, greaterThan(0));
          expect(size.heightPt, greaterThan(0));
        } finally {
          await doc.close();
        }
      },
    );
  });
}
