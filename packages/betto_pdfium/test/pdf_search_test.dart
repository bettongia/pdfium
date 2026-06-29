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

// Tests for PdfDocument.search, PdfSearchMatch, and PdfSearchFlag.
//
// Sections:
//   1. Unit tests for PdfSearchMatch (equality, hashCode, toString).
//   2. Integration tests against fixture PDFs via the native PDFium backend.
//      Skipped when the PDFium dylib is not present.
//   3. Integration tests for the --search CLI flag in bin/pdfinfo.dart.
//
// Fixture PDFs used by integration tests:
//   search_single.pdf    — Single-page PDF with "The quick brown fox..." ×3 and
//                          a unique term "xyzzy".
//   search_multipage.pdf — Three-page PDF for cross-page search scenarios.
//   scanned.pdf          — Image-only PDF with no text layer.
//   no_metadata.pdf      — Simple PDF used for close()-during-search test.
//
// Generate fixtures with:
//   python3 test/fixtures/generate/generate_fixtures.py

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:betto_pdfium/src/document/pdfium_isolate.dart'
    show PdfiumIsolate;
import 'package:test/test.dart';

import 'native_test_helper.dart';

/// Reads a fixture file from test/fixtures/.
Uint8List _readFixture(String name) {
  final file = File('test/fixtures/$name');
  if (!file.existsSync()) {
    throw StateError(
      'Test fixture not found: test/fixtures/$name. '
      'Run python3 test/fixtures/generate/generate_fixtures.py',
    );
  }
  return file.readAsBytesSync();
}

/// Runs `dart run bin/pdfinfo.dart [args...] <fixturePath>` and returns the
/// [ProcessResult].
Future<ProcessResult> _runPdfinfo(
  String fixtureName, {
  List<String> flags = const [],
}) async {
  final fixturePath = 'test/fixtures/$fixtureName';
  return Process.run('dart', [
    'run',
    'bin/pdfinfo.dart',
    ...flags,
    fixturePath,
  ]);
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. Unit tests for PdfSearchMatch
  // ---------------------------------------------------------------------------

  group('PdfSearchMatch', () {
    const rect1 = PdfRect(left: 10, bottom: 20, right: 100, top: 40);
    const rect2 = PdfRect(left: 10, bottom: 10, right: 80, top: 30);

    test('equality: identical values are equal', () {
      const a = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 3,
        rects: [rect1],
      );
      const b = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 3,
        rects: [rect1],
      );
      expect(a, equals(b));
    });

    test('equality: different pageIndex is not equal', () {
      const a = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 3,
        rects: [rect1],
      );
      const b = PdfSearchMatch(
        pageIndex: 1,
        charIndex: 5,
        charCount: 3,
        rects: [rect1],
      );
      expect(a, isNot(equals(b)));
    });

    test('equality: different charIndex is not equal', () {
      const a = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 3,
        rects: [rect1],
      );
      const b = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 6,
        charCount: 3,
        rects: [rect1],
      );
      expect(a, isNot(equals(b)));
    });

    test('equality: different charCount is not equal', () {
      const a = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 3,
        rects: [rect1],
      );
      const b = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 4,
        rects: [rect1],
      );
      expect(a, isNot(equals(b)));
    });

    test('equality: different rects list is not equal', () {
      const a = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 3,
        rects: [rect1],
      );
      const b = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 3,
        rects: [rect2],
      );
      expect(a, isNot(equals(b)));
    });

    test('equality: empty rects matches empty rects', () {
      const a = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 0,
        charCount: 1,
        rects: [],
      );
      const b = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 0,
        charCount: 1,
        rects: [],
      );
      expect(a, equals(b));
    });

    test('equality: multi-rect match with same rects is equal', () {
      const a = PdfSearchMatch(
        pageIndex: 2,
        charIndex: 10,
        charCount: 5,
        rects: [rect1, rect2],
      );
      const b = PdfSearchMatch(
        pageIndex: 2,
        charIndex: 10,
        charCount: 5,
        rects: [rect1, rect2],
      );
      expect(a, equals(b));
    });

    test(
      'equality: multi-rect match with rects in different order is not equal',
      () {
        const a = PdfSearchMatch(
          pageIndex: 0,
          charIndex: 0,
          charCount: 5,
          rects: [rect1, rect2],
        );
        const b = PdfSearchMatch(
          pageIndex: 0,
          charIndex: 0,
          charCount: 5,
          rects: [rect2, rect1],
        );
        expect(a, isNot(equals(b)));
      },
    );

    test('hashCode: equal objects have equal hashCodes', () {
      const a = PdfSearchMatch(
        pageIndex: 1,
        charIndex: 3,
        charCount: 7,
        rects: [rect1, rect2],
      );
      const b = PdfSearchMatch(
        pageIndex: 1,
        charIndex: 3,
        charCount: 7,
        rects: [rect1, rect2],
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes all fields', () {
      const m = PdfSearchMatch(
        pageIndex: 2,
        charIndex: 10,
        charCount: 5,
        rects: [rect1, rect2],
      );
      final s = m.toString();
      expect(s, contains('2')); // pageIndex
      expect(s, contains('10')); // charIndex
      expect(s, contains('5')); // charCount
      expect(s, contains('2')); // rects length
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Integration tests (native PDFium backend)
  // ---------------------------------------------------------------------------

  group('PdfDocument.search (native backend)', () {
    tearDownAll(() {
      // Reset the PdfiumIsolate singleton after this group so subsequent test
      // files do not conflict with a still-running isolate.
      PdfiumIsolate.resetForTesting();
    });

    // -------------------------------------------------------------------------
    // Golden-path tests using search_single.pdf
    // -------------------------------------------------------------------------

    test('empty query returns empty stream immediately', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_single.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('').toList();
        expect(results, isEmpty);
      } finally {
        await doc.close();
      }
    });

    test(
      '"fox" case-insensitive finds 3 matches on the single-page fixture',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final bytes = _readFixture('search_single.pdf');
        final doc = await PdfDocument.fromBytes(
          bytes,
          dylibPath: nativeDylibPath(),
        );
        try {
          final results = await doc.search('fox').toList();
          // The fixture has "The quick brown fox..." repeated 3 times.
          expect(results, hasLength(3));
          for (final m in results) {
            expect(m.pageIndex, equals(0));
            expect(m.charCount, equals(3)); // "fox" is 3 characters
            expect(m.rects, isNotEmpty);
          }
        } finally {
          await doc.close();
        }
      },
    );

    test(
      '"FOX" with matchCase flag finds 0 matches (no uppercase in fixture)',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final bytes = _readFixture('search_single.pdf');
        final doc = await PdfDocument.fromBytes(
          bytes,
          dylibPath: nativeDylibPath(),
        );
        try {
          final results = await doc
              .search('FOX', flags: {PdfSearchFlag.matchCase})
              .toList();
          expect(results, isEmpty);
        } finally {
          await doc.close();
        }
      },
    );

    test('"fox" case-insensitive finds matches regardless of case', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_single.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        // Without matchCase, "FOX" should still match "fox" in the fixture.
        final results = await doc.search('FOX').toList();
        expect(results, hasLength(3));
      } finally {
        await doc.close();
      }
    });

    test('"xyzzy" unique term finds exactly 1 match', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_single.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('xyzzy').toList();
        expect(results, hasLength(1));
        expect(results[0].pageIndex, equals(0));
        expect(results[0].charCount, equals(5)); // "xyzzy" is 5 characters
        expect(results[0].rects, isNotEmpty);
      } finally {
        await doc.close();
      }
    });

    test(
      '"zzz_not_in_doc" query that does not appear returns empty stream',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final bytes = _readFixture('search_single.pdf');
        final doc = await PdfDocument.fromBytes(
          bytes,
          dylibPath: nativeDylibPath(),
        );
        try {
          final results = await doc
              .search('zzz_not_in_document_at_all')
              .toList();
          expect(results, isEmpty);
        } finally {
          await doc.close();
        }
      },
    );

    test('each match has non-empty rects with positive dimensions', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_single.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('fox').toList();
        expect(results, isNotEmpty);
        for (final m in results) {
          expect(m.rects, isNotEmpty);
          for (final r in m.rects) {
            expect(r.right, greaterThan(r.left));
            expect(r.top, greaterThan(r.bottom));
          }
        }
      } finally {
        await doc.close();
      }
    });

    // -------------------------------------------------------------------------
    // Multi-page search tests using search_multipage.pdf
    // -------------------------------------------------------------------------

    test('"gamma" in multipage fixture appears on pages 0, 1, and 2', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_multipage.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('gamma').toList();
        expect(results, hasLength(3));
        expect(results[0].pageIndex, equals(0));
        expect(results[1].pageIndex, equals(1));
        expect(results[2].pageIndex, equals(2));
      } finally {
        await doc.close();
      }
    });

    test('"beta" in multipage fixture appears on pages 0 and 1 only', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_multipage.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('beta').toList();
        expect(results, hasLength(2));
        expect(results[0].pageIndex, equals(0));
        expect(results[1].pageIndex, equals(1));
      } finally {
        await doc.close();
      }
    });

    test('"alpha" in multipage fixture appears only on page 0', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_multipage.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('alpha').toList();
        expect(results, hasLength(1));
        expect(results[0].pageIndex, equals(0));
      } finally {
        await doc.close();
      }
    });

    test('"zeta" in multipage fixture appears only on page 2', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_multipage.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('zeta').toList();
        expect(results, hasLength(1));
        expect(results[0].pageIndex, equals(2));
      } finally {
        await doc.close();
      }
    });

    test('results are yielded in ascending page order', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_multipage.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('delta').toList();
        expect(results, hasLength(3));
        // Verify ascending page order.
        for (var i = 1; i < results.length; i++) {
          expect(
            results[i].pageIndex,
            greaterThanOrEqualTo(results[i - 1].pageIndex),
          );
        }
      } finally {
        await doc.close();
      }
    });

    // -------------------------------------------------------------------------
    // Single-page restriction (pageIndex parameter)
    // -------------------------------------------------------------------------

    test('pageIndex restricts search to a single page', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      // "delta" appears on all three pages of the multipage fixture.
      // Restricting to page 1 should yield only 1 match.
      final bytes = _readFixture('search_multipage.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('delta', pageIndex: 1).toList();
        expect(results, hasLength(1));
        expect(results[0].pageIndex, equals(1));
      } finally {
        await doc.close();
      }
    });

    test(
      'pageIndex restricts to page 0: results contain only page 0 matches',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final bytes = _readFixture('search_multipage.pdf');
        final doc = await PdfDocument.fromBytes(
          bytes,
          dylibPath: nativeDylibPath(),
        );
        try {
          // "alpha" only exists on page 0; restrict to page 0 → 1 result.
          final results = await doc.search('alpha', pageIndex: 0).toList();
          expect(results, hasLength(1));
          expect(results[0].pageIndex, equals(0));

          // "zeta" only exists on page 2; restrict to page 0 → 0 results.
          final noResults = await doc.search('zeta', pageIndex: 0).toList();
          expect(noResults, isEmpty);
        } finally {
          await doc.close();
        }
      },
    );

    test(
      'out-of-range pageIndex throws RangeError before any PDFium calls',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final bytes = _readFixture('search_multipage.pdf');
        final doc = await PdfDocument.fromBytes(
          bytes,
          dylibPath: nativeDylibPath(),
        );
        try {
          // Fixture has 3 pages (indices 0–2). Index 3 is out of range.
          // search() returns a lazy stream; RangeError is thrown when listened.
          await expectLater(
            doc.search('gamma', pageIndex: 3),
            emitsError(isRangeError),
          );
          // Negative index is also out of range.
          await expectLater(
            doc.search('gamma', pageIndex: -1),
            emitsError(isRangeError),
          );
        } finally {
          await doc.close();
        }
      },
    );

    // -------------------------------------------------------------------------
    // Search flags: matchWholeWord
    // -------------------------------------------------------------------------

    test('matchWholeWord flag excludes substring matches', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      // search_single.pdf contains "The quick brown fox..." — "fox" and "the".
      // "the" appears as part of "The" and "the" (6 times total without whole
      // word). With whole word it still matches all 6 because they are all
      // standalone words.
      final bytes = _readFixture('search_single.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        // "fox" is a complete word — should still match 3 times.
        final foxMatches = await doc
            .search('fox', flags: {PdfSearchFlag.matchWholeWord})
            .toList();
        expect(foxMatches, hasLength(3));

        // "fo" is a prefix of "fox" — whole-word should exclude it.
        final foMatches = await doc
            .search('fo', flags: {PdfSearchFlag.matchWholeWord})
            .toList();
        expect(foMatches, isEmpty);
      } finally {
        await doc.close();
      }
    });

    // -------------------------------------------------------------------------
    // Scanned (image-only) PDF — no text layer
    // -------------------------------------------------------------------------

    test('search on scanned PDF returns empty stream', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('scanned.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final results = await doc.search('the').toList();
        expect(results, isEmpty);
      } finally {
        await doc.close();
      }
    });

    // -------------------------------------------------------------------------
    // close() called during active stream
    // -------------------------------------------------------------------------

    test(
      'close() before stream listen causes stream to emit StateError',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        // Close the document before subscribing; the stream should emit a
        // StateError (the _closed guard fires on first listen).
        final bytes = _readFixture('search_multipage.pdf');
        final doc = await PdfDocument.fromBytes(
          bytes,
          dylibPath: nativeDylibPath(),
        );
        await doc.close();

        await expectLater(doc.search('delta'), emitsError(isA<StateError>()));
      },
    );

    test(
      'close() called while stream is processing terminates stream cleanly',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        // Use a multi-page document so there is more work to interrupt.
        final bytes = _readFixture('search_multipage.pdf');
        final doc = await PdfDocument.fromBytes(
          bytes,
          dylibPath: nativeDylibPath(),
        );

        final received = <PdfSearchMatch>[];
        // Start the stream and collect results; cancel after the first yield.
        var subscriptionCancelled = false;
        late StreamSubscription<PdfSearchMatch> sub;
        sub = doc
            .search('delta')
            .listen(
              (m) async {
                received.add(m);
                if (!subscriptionCancelled) {
                  subscriptionCancelled = true;
                  // Cancel subscription and close concurrently — tests that
                  // neither leaks handles nor crashes.
                  await sub.cancel();
                  await doc.close();
                }
              },
              onError: (_) {
                // Swallow any StateError that races with close().
              },
            );
        // Wait for the stream to settle.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Received 1 or more results before cancel/close.
        expect(received, isNotEmpty);
      },
    );

    test('search() after close() emits a StateError on listen', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_single.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      await doc.close();
      // search() returns a lazy Stream; StateError is emitted when listened.
      await expectLater(doc.search('fox'), emitsError(isA<StateError>()));
    });

    // -------------------------------------------------------------------------
    // Stream cancellation
    // -------------------------------------------------------------------------

    test('cancelling stream subscription stops processing', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final bytes = _readFixture('search_multipage.pdf');
      final doc = await PdfDocument.fromBytes(
        bytes,
        dylibPath: nativeDylibPath(),
      );
      try {
        final received = <PdfSearchMatch>[];
        // "delta" appears on every page; cancel after the first result.
        await doc
            .search('delta')
            .forEach((m) {
              received.add(m);
              throw Exception('cancel'); // break out of forEach
            })
            .catchError((_) {});

        // We should have received at most 1 result before cancelling.
        expect(received.length, lessThanOrEqualTo(1));
      } finally {
        await doc.close();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. CLI integration tests: bin/pdfinfo.dart --search flag
  // ---------------------------------------------------------------------------

  // dart run triggers native-assets bundling which tries to replace
  // .dart_tool/lib/pdfium.dll — a file already locked by the test process.
  // Windows does not allow replacing in-use DLLs, so the entire CLI group is
  // declared with skip: on Windows. markTestSkipped() in setUp() does not stop
  // the test body from running; the group-level skip: does.
  group(
    'pdfinfo CLI --search flag',
    skip: Platform.isWindows
        ? 'CLI subprocess tests skipped on Windows: dart run cannot '
              'stage pdfium.dll while it is loaded by the test process.'
        : null,
    () {
      test('--search with a matching query prints results to stdout', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final result = await _runPdfinfo(
          'search_single.pdf',
          flags: ['--search', 'fox'],
        );
        expect(result.exitCode, equals(0));
        final stdout = result.stdout as String;
        // Should contain page and match info.
        expect(stdout.toLowerCase(), contains('fox'));
      });

      test(
        '--search with no matches prints "(no matches)" or similar',
        () async {
          if (!nativeAvailable()) {
            markTestSkipped('PDFium dylib not found — skipping native tests.');
            return;
          }

          final result = await _runPdfinfo(
            'search_single.pdf',
            flags: ['--search', 'zzz_not_in_document'],
          );
          expect(result.exitCode, equals(0));
          final stdout = result.stdout as String;
          expect(stdout, contains('no matches'));
        },
      );

      test('--search --json includes "search" key with match array', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final result = await _runPdfinfo(
          'search_single.pdf',
          flags: ['--search', 'fox', '--json'],
        );
        expect(result.exitCode, equals(0));
        final json =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        expect(json, contains('search'));
        final matches = json['search'] as List<dynamic>;
        expect(matches, hasLength(3));
        final first = matches[0] as Map<String, dynamic>;
        expect(first, contains('pageIndex'));
        expect(first, contains('charIndex'));
        expect(first, contains('charCount'));
        expect(first, contains('rects'));
        expect(first['pageIndex'], equals(0));
      });

      test('--json without --search omits the "search" key', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final result = await _runPdfinfo(
          'search_single.pdf',
          flags: ['--json'],
        );
        expect(result.exitCode, equals(0));
        final json =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        expect(json, isNot(contains('search')));
      });

      test(
        '--search --json on multipage fixture includes matches from all pages',
        () async {
          if (!nativeAvailable()) {
            markTestSkipped('PDFium dylib not found — skipping native tests.');
            return;
          }

          final result = await _runPdfinfo(
            'search_multipage.pdf',
            flags: ['--search', 'gamma', '--json'],
          );
          expect(result.exitCode, equals(0));
          final json =
              jsonDecode(result.stdout as String) as Map<String, dynamic>;
          final matches = json['search'] as List<dynamic>;
          // "gamma" appears on all three pages.
          expect(matches, hasLength(3));
          final pageIndices = matches
              .map((m) => (m as Map<String, dynamic>)['pageIndex'])
              .toList();
          expect(pageIndices, containsAll([0, 1, 2]));
        },
      );

      test('--search can be combined with --text flag', () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final result = await _runPdfinfo(
          'search_single.pdf',
          flags: ['--search', 'fox', '--text'],
        );
        expect(result.exitCode, equals(0));
        final stdout = result.stdout as String;
        // Both text and search output should be present.
        expect(stdout.toLowerCase(), contains('fox'));
        expect(stdout.toLowerCase(), contains('text'));
      });
    },
  );
}
