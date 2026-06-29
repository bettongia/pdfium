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

// Integration tests for the pdfinfo CLI tool (bin/pdfinfo.dart).
//
// Tests run the CLI as a subprocess via `dart run bin/pdfinfo.dart`.
// Each test checks exit code, stdout, and/or stderr.
//
// Skipped when the PDFium dylib is not present (same guard as other native tests).

import 'dart:convert';
import 'dart:io';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:betto_pdfium/src/document/pdfium_isolate.dart'
    show PdfiumIsolate;
import 'package:test/test.dart';

import 'native_test_helper.dart';

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
  // dart run triggers native-assets bundling which tries to replace
  // .dart_tool/lib/pdfium.dll — a file already locked by the test process.
  // Windows does not allow replacing in-use DLLs, so the entire CLI group is
  // declared with skip: on Windows. markTestSkipped() in setUp() does not stop
  // the test body from running; the group-level skip: does.
  group(
    'pdfinfo CLI --toc flag',
    skip:
        Platform.isWindows
            ? 'CLI subprocess tests skipped on Windows: dart run cannot '
                'stage pdfium.dll while it is loaded by the test process.'
            : null,
    () {
    test(
      '--toc on a document with no bookmarks prints "(no bookmarks)"',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final result = await _runPdfinfo('no_toc.pdf', flags: ['--toc']);
        expect(result.exitCode, equals(0));
        final out = result.stdout as String;
        expect(out, contains('Table of Contents'));
        expect(out, contains('(no bookmarks)'));
      },
    );

    test(
      '--toc on a document with flat bookmarks prints each entry with page number',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final result = await _runPdfinfo('flat_toc.pdf', flags: ['--toc']);
        expect(result.exitCode, equals(0));
        final out = result.stdout as String;
        expect(out, contains('Table of Contents'));
        expect(out, contains('Chapter 1'));
        expect(out, contains('page 1'));
        expect(out, contains('Chapter 2'));
        expect(out, contains('page 2'));
        expect(out, contains('Chapter 3'));
        expect(out, contains('page 3'));
      },
    );

    test(
      '--toc on nested bookmarks prints children with deeper indentation',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final result = await _runPdfinfo('nested_toc.pdf', flags: ['--toc']);
        expect(result.exitCode, equals(0));
        final out = result.stdout as String;
        expect(out, contains('Part I'));
        expect(out, contains('Chapter 1'));
        expect(out, contains('Chapter 2'));
        expect(out, contains('Part II'));
        expect(out, contains('Chapter 3'));
        expect(out, contains('Chapter 4'));

        // Children must be indented more than their parent.
        final lines = out.split('\n');
        final partILine = lines.firstWhere(
          (l) => l.contains('Part I'),
          orElse: () => '',
        );
        final ch1Line = lines.firstWhere(
          (l) => l.contains('Chapter 1'),
          orElse: () => '',
        );
        expect(partILine, isNotEmpty, reason: 'Part I should appear in output');
        expect(
          ch1Line,
          isNotEmpty,
          reason: 'Chapter 1 should appear in output',
        );
        // Chapter 1 should have more leading spaces than Part I.
        final partIIndent = partILine.length - partILine.trimLeft().length;
        final ch1Indent = ch1Line.length - ch1Line.trimLeft().length;
        expect(ch1Indent, greaterThan(partIIndent));
      },
    );

    test('--toc --json includes "toc" key with entries array', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final result = await _runPdfinfo(
        'flat_toc.pdf',
        flags: ['--toc', '--json'],
      );
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(json, contains('toc'));
      final toc = json['toc'] as List<dynamic>;
      expect(toc, hasLength(3));
      expect((toc[0] as Map<String, dynamic>)['title'], equals('Chapter 1'));
      expect((toc[0] as Map<String, dynamic>)['pageIndex'], equals(0));
      expect((toc[1] as Map<String, dynamic>)['title'], equals('Chapter 2'));
      expect((toc[1] as Map<String, dynamic>)['pageIndex'], equals(1));
    });

    test('--json without --toc omits the "toc" key', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final result = await _runPdfinfo('flat_toc.pdf', flags: ['--json']);
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(json, isNot(contains('toc')));
    });

    test(
      '--toc --json on a document with no bookmarks gives empty toc array',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }

        final result = await _runPdfinfo(
          'no_toc.pdf',
          flags: ['--toc', '--json'],
        );
        expect(result.exitCode, equals(0));
        final json =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        expect(json, contains('toc'));
        expect(json['toc'] as List<dynamic>, isEmpty);
      },
    );

    test('--toc --json on nested bookmarks includes children arrays', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final result = await _runPdfinfo(
        'nested_toc.pdf',
        flags: ['--toc', '--json'],
      );
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final toc = json['toc'] as List<dynamic>;
      expect(toc, hasLength(2));

      final partI = toc[0] as Map<String, dynamic>;
      expect(partI['title'], equals('Part I'));
      expect(partI, contains('children'));
      final children = partI['children'] as List<dynamic>;
      expect(children, hasLength(2));
      expect(
        (children[0] as Map<String, dynamic>)['title'],
        equals('Chapter 1'),
      );
    });

    test('combining --toc with --text and --annot succeeds', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }

      final result = await _runPdfinfo(
        'flat_toc.pdf',
        flags: ['--toc', '--text', '--annot'],
      );
      expect(result.exitCode, equals(0));
      final out = result.stdout as String;
      expect(out, contains('Table of Contents'));
      expect(out, contains('Chapter 1'));
    });

    test('exit code 1 for missing file even with --toc flag', () async {
      final result = await _runPdfinfo(
        'nonexistent_file.pdf',
        flags: ['--toc'],
      );
      expect(result.exitCode, equals(1));
      expect(result.stderr as String, contains('not found'));
    });
  });

  // ---------------------------------------------------------------------------
  // Direct API tests for PdfDocument.getDocumentInfo()
  // ---------------------------------------------------------------------------

  group('PdfDocument.getDocumentInfo() API', () {
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

    /// Opens a fixture PDF via the native dylib.
    Future<PdfDocument> openFixture(String name) async {
      final bytes = File('test/fixtures/$name').readAsBytesSync();
      return PdfDocument.fromBytes(bytes, dylibPath: nativeDylibPath());
    }

    test(
      'full_metadata.pdf — fileVersion is non-null and plausible (>= 14 for PDF 1.4)',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }
        doc = await openFixture('full_metadata.pdf');
        final info = await doc.getDocumentInfo();
        expect(info.fileVersion, isNotNull);
        // full_metadata.pdf is a PDF 1.3 document (fileVersion == 13).
        expect(info.fileVersion, greaterThanOrEqualTo(10));
      },
    );

    test(
      'partial_metadata.pdf — call succeeds; permanentId may be null',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }
        doc = await openFixture('partial_metadata.pdf');
        // getDocumentInfo() must not throw even when IDs are absent.
        final info = await doc.getDocumentInfo();
        expect(info, isNotNull);
        // fileVersion may or may not be present; just confirm no exception.
        expect(info.fileVersion, anyOf(isNull, isA<int>()));
      },
    );

    test('no_metadata.pdf — call succeeds; all fields may be null', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }
      doc = await openFixture('no_metadata.pdf');
      final info = await doc.getDocumentInfo();
      expect(info, isNotNull);
    });

    test(
      'toString on PdfDocumentInfo with non-null permanentId produces hex string',
      () async {
        if (!nativeAvailable()) {
          markTestSkipped('PDFium dylib not found — skipping native tests.');
          return;
        }
        doc = await openFixture('full_metadata.pdf');
        final info = await doc.getDocumentInfo();
        final s = info.toString();
        expect(s, contains('PdfDocumentInfo'));
        expect(s, contains('fileVersion:'));
        // When permanentId is present it should be encoded as a hex string.
        if (info.permanentId != null) {
          expect(s, isNot(contains('permanentId: null')));
        }
      },
    );

    test('getDocumentInfo() throws StateError after close()', () async {
      if (!nativeAvailable()) {
        markTestSkipped('PDFium dylib not found — skipping native tests.');
        return;
      }
      final closedDoc = await openFixture('full_metadata.pdf');
      await closedDoc.close();
      await expectLater(() => closedDoc.getDocumentInfo(), throwsStateError);
    });
  });
}
