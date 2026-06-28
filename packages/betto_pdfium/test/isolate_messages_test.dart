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

// Unit tests for the PdfiumIsolate message protocol types.
//
// These tests exercise the command and response constructors that are only
// reachable through the four previously-untested API methods:
//   - PdfiumExtractPageAnnotationsCommand / PdfiumExtractPageAnnotationsResponse
//   - PdfiumGetDocumentInfoCommand       / PdfiumGetDocumentInfoResponse
//   - PdfiumRenderPageCommand            / PdfiumRenderPageResponse
//   - PdfiumGetPageSizeCommand           / PdfiumGetPageSizeResponse
//
// No native binary is required — the tests construct message objects in-process
// and inspect their fields directly.

import 'dart:isolate';
import 'dart:typed_data';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:betto_pdfium/src/document/isolate_messages.dart';
import 'package:test/test.dart';

void main() {
  // A ReceivePort whose SendPort can be used to construct command objects.
  // The port is never actually sent to; it just provides a valid SendPort.
  late RawReceivePort dummyPort;
  late SendPort dummySendPort;

  setUp(() {
    dummyPort = RawReceivePort();
    dummySendPort = dummyPort.sendPort;
  });

  tearDown(() {
    dummyPort.close();
  });

  // ---------------------------------------------------------------------------
  // PdfiumExtractPageAnnotationsCommand
  // ---------------------------------------------------------------------------

  group('PdfiumExtractPageAnnotationsCommand', () {
    test('stores token and pageIndex', () {
      final cmd = PdfiumExtractPageAnnotationsCommand(dummySendPort, 42, 3);
      expect(cmd.token, equals(42));
      expect(cmd.pageIndex, equals(3));
      expect(cmd.replyPort, equals(dummySendPort));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumExtractPageAnnotationsResponse
  // ---------------------------------------------------------------------------

  group('PdfiumExtractPageAnnotationsResponse', () {
    test('success: isSuccess is true and annotations is accessible', () {
      final annots = <PdfAnnotation>[
        const PdfTextAnnotation(pageIndex: 0, flags: 0),
      ];
      final resp = PdfiumExtractPageAnnotationsResponse.success(
        pageIndex: 0,
        annotations: annots,
      );
      expect(resp.isSuccess, isTrue);
      expect(resp.pageIndex, equals(0));
      expect(resp.annotations, equals(annots));
      expect(resp.error, isNull);
    });

    test('failure: isSuccess is false and error is accessible', () {
      const resp = PdfiumExtractPageAnnotationsResponse.failure(
        PdfError.invalidDocument,
        1,
      );
      expect(resp.isSuccess, isFalse);
      expect(resp.pageIndex, equals(1));
      expect(resp.error, equals(PdfError.invalidDocument));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumGetDocumentInfoCommand
  // ---------------------------------------------------------------------------

  group('PdfiumGetDocumentInfoCommand', () {
    test('stores token', () {
      final cmd = PdfiumGetDocumentInfoCommand(dummySendPort, 99);
      expect(cmd.token, equals(99));
      expect(cmd.replyPort, equals(dummySendPort));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumGetDocumentInfoResponse
  // ---------------------------------------------------------------------------

  group('PdfiumGetDocumentInfoResponse', () {
    test('success: info is accessible', () {
      const info = PdfDocumentInfo(fileVersion: 17);
      const resp = PdfiumGetDocumentInfoResponse.success(info);
      expect(resp.info, equals(info));
      expect(resp.error, isNull);
    });

    test('failure: error is accessible', () {
      const resp = PdfiumGetDocumentInfoResponse.failure(
        PdfError.invalidDocument,
      );
      expect(resp.info, isNull);
      expect(resp.error, equals(PdfError.invalidDocument));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumRenderPageCommand
  // ---------------------------------------------------------------------------

  group('PdfiumRenderPageCommand', () {
    test('stores all fields', () {
      final cmd = PdfiumRenderPageCommand(
        dummySendPort,
        7, // token
        0, // pageIndex
        100, // pixelWidth
        200, // pixelHeight
        4, // renderFlags (FPDF_ANNOT)
        0xFFFFFFFF, // backgroundColor
      );
      expect(cmd.token, equals(7));
      expect(cmd.pageIndex, equals(0));
      expect(cmd.pixelWidth, equals(100));
      expect(cmd.pixelHeight, equals(200));
      expect(cmd.renderFlags, equals(4));
      expect(cmd.backgroundColor, equals(0xFFFFFFFF));
      expect(cmd.replyPort, equals(dummySendPort));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumRenderPageResponse
  // ---------------------------------------------------------------------------

  group('PdfiumRenderPageResponse', () {
    test('success: pixels and dimensions are accessible', () {
      final pixels = Uint8List(100 * 100 * 4);
      final resp = PdfiumRenderPageResponse.success(
        pixels: pixels,
        pixelWidth: 100,
        pixelHeight: 100,
      );
      expect(resp.isSuccess, isTrue);
      expect(resp.pixelWidth, equals(100));
      expect(resp.pixelHeight, equals(100));
      expect(resp.pixels.length, equals(100 * 100 * 4));
    });

    test('failure: errorMessage is accessible', () {
      const resp = PdfiumRenderPageResponse.failure('bitmap alloc failed');
      expect(resp.isSuccess, isFalse);
      expect(resp.errorMessage, equals('bitmap alloc failed'));
      expect(resp.pixelWidth, equals(0));
      expect(resp.pixelHeight, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumGetPageSizeCommand
  // ---------------------------------------------------------------------------

  group('PdfiumGetPageSizeCommand', () {
    test('stores token and pageIndex', () {
      final cmd = PdfiumGetPageSizeCommand(dummySendPort, 5, 2);
      expect(cmd.token, equals(5));
      expect(cmd.pageIndex, equals(2));
      expect(cmd.replyPort, equals(dummySendPort));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumGetPageSizeResponse
  // ---------------------------------------------------------------------------

  group('PdfiumGetPageSizeResponse', () {
    test('success: pageSize is accessible and isSuccess is true', () {
      const size = PdfPageSize(widthPt: 595.0, heightPt: 842.0);
      const resp = PdfiumGetPageSizeResponse.success(size);
      expect(resp.isSuccess, isTrue);
      expect(resp.pageSize, equals(size));
      expect(resp.error, isNull);
    });

    test('failure: error is accessible and isSuccess is false', () {
      const resp = PdfiumGetPageSizeResponse.failure(PdfError.invalidDocument);
      expect(resp.isSuccess, isFalse);
      expect(resp.pageSize, isNull);
      expect(resp.error, equals(PdfError.invalidDocument));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumInitFailedResponse
  // ---------------------------------------------------------------------------

  group('PdfiumInitFailedResponse', () {
    test('stores message', () {
      const resp = PdfiumInitFailedResponse('cannot load dylib');
      expect(resp.message, equals('cannot load dylib'));
    });
  });

  // ---------------------------------------------------------------------------
  // PdfiumHandlerErrorResponse
  // ---------------------------------------------------------------------------

  group('PdfiumHandlerErrorResponse', () {
    test('stores error and stack', () {
      const resp = PdfiumHandlerErrorResponse('some error', 'stack trace here');
      expect(resp.error, equals('some error'));
      expect(resp.stack, equals('stack trace here'));
    });
  });

  // ---------------------------------------------------------------------------
  // Failure constructor coverage for remaining response types
  // ---------------------------------------------------------------------------

  group('PdfiumGetMetadataResponse.failure', () {
    test('is not successful and carries error', () {
      const resp = PdfiumGetMetadataResponse.failure(PdfError.invalidDocument);
      expect(resp.metadata, isNull);
      expect(resp.error, equals(PdfError.invalidDocument));
    });
  });

  group('PdfiumGetPageCountResponse.failure', () {
    test('is not successful and carries error', () {
      const resp = PdfiumGetPageCountResponse.failure(PdfError.invalidDocument);
      expect(resp.pageCount, isNull);
      expect(resp.error, equals(PdfError.invalidDocument));
    });
  });

  group('PdfiumGetTocResponse.failure', () {
    test('is not successful and carries error', () {
      const resp = PdfiumGetTocResponse.failure(PdfError.invalidDocument);
      expect(resp.entries, isNull);
      expect(resp.isSuccess, isFalse);
      expect(resp.error, equals(PdfError.invalidDocument));
    });
  });

  group('PdfiumExtractPageImagesResponse.failure', () {
    test('is not successful and carries error and pageIndex', () {
      const resp = PdfiumExtractPageImagesResponse.failure(
        PdfError.invalidDocument,
        2,
      );
      expect(resp.isSuccess, isFalse);
      expect(resp.error, equals(PdfError.invalidDocument));
      expect(resp.pageIndex, equals(2));
    });
  });

  group('PdfiumRenderImageResponse.failure', () {
    test('is not successful and carries error', () {
      const resp = PdfiumRenderImageResponse.failure(PdfError.invalidDocument);
      expect(resp.isSuccess, isFalse);
      expect(resp.error, equals(PdfError.invalidDocument));
      expect(resp.bitmap, isNull);
    });
  });

  group('PdfiumSearchPageResponse.failure', () {
    test('is not successful and carries error and pageIndex', () {
      const resp = PdfiumSearchPageResponse.failure(
        PdfError.invalidDocument,
        3,
      );
      expect(resp.isSuccess, isFalse);
      expect(resp.error, equals(PdfError.invalidDocument));
      expect(resp.pageIndex, equals(3));
    });
  });

  group('PdfiumGetPageThumbnailResponse.failure', () {
    test('is not successful and carries error message', () {
      const resp = PdfiumGetPageThumbnailResponse.failure('load page failed');
      expect(resp.isSuccess, isFalse);
      expect(resp.errorMessage, equals('load page failed'));
      expect(resp.bgra, isNull);
      expect(resp.width, equals(0));
      expect(resp.height, equals(0));
    });
  });

  group('PdfiumExtractPageTextResponse.failure', () {
    test('is not successful and carries error and pageIndex', () {
      const resp = PdfiumExtractPageTextResponse.failure(
        PdfError.invalidDocument,
        4,
      );
      expect(resp.isSuccess, isFalse);
      expect(resp.error, equals(PdfError.invalidDocument));
      expect(resp.pageIndex, equals(4));
    });
  });
}
