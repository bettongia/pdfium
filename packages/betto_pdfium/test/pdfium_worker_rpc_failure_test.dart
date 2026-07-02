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

// Regression tests for the Web Worker offload plan's Phase 9 blocker fix:
// a broken/crashed Worker must fail every in-flight request with a
// PdfiumException instead of hanging them forever, and must not leave
// dangling entries in the RPC client's pending-request map.
//
// A real Worker `error`/`messageerror` event can't be triggered
// deterministically from `dart test -p chrome` without test-only plumbing to
// swap the hardcoded worker URL — see the "Test-only hooks" section of
// _document_web.dart. These tests instead call the same
// `_failAllPending` logic those event handlers delegate to, via
// `@visibleForTesting` hooks, against a fake in-flight request that never
// touches a real worker. This directly exercises the leak-prevention
// behavior under test without depending on real Worker failure timing.
//
// Runs exclusively under `dart test -p chrome` (make web_test /
// make web_coverage), like test/pdf_document_web_test.dart.

@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';

import 'package:betto_pdfium/src/document/_document_web.dart';
import 'package:betto_pdfium/src/pdf_exception.dart';

void main() {
  group('PdfDocumentImpl worker-failure handling', () {
    test('a simulated worker failure fails a pending request with '
        'PdfiumException instead of hanging it', () async {
      final (:id, :future) = PdfDocumentImpl.debugRegisterPendingRequest();
      expect(PdfDocumentImpl.debugHasPending(id), isTrue);

      PdfDocumentImpl.debugFailAllPending('simulated worker crash');

      await expectLater(future, throwsA(isA<PdfiumException>()));
    });

    test('a simulated worker failure removes the request from the pending '
        'map — it does not leak', () async {
      final (:id, :future) = PdfDocumentImpl.debugRegisterPendingRequest();

      PdfDocumentImpl.debugFailAllPending('simulated worker crash');
      // Swallow the expected error — this test only cares about the
      // pending-map bookkeeping, covered by the assertion below.
      unawaited(future.then((_) {}, onError: (_) {}));

      expect(PdfDocumentImpl.debugHasPending(id), isFalse);
    });

    test('a simulated worker failure fails every pending request, not just '
        'the first', () async {
      final requests = List.generate(
        3,
        (_) => PdfDocumentImpl.debugRegisterPendingRequest(),
      );
      for (final r in requests) {
        expect(PdfDocumentImpl.debugHasPending(r.id), isTrue);
      }

      PdfDocumentImpl.debugFailAllPending('simulated worker crash');

      for (final r in requests) {
        await expectLater(r.future, throwsA(isA<PdfiumException>()));
        expect(PdfDocumentImpl.debugHasPending(r.id), isFalse);
      }
    });
  });
}
