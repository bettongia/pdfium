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

// Stub backend for platforms where neither dart:ffi nor dart:js_interop is
// available. All operations throw [UnsupportedError] immediately.
//
// This file is selected by the conditional import in pdf_document.dart when
// neither dart.library.ffi nor dart.library.js_interop is present.

import 'dart:typed_data';

import 'pdf_types.dart';
import '../rendering/pdf_page_size.dart';

/// Stub implementation of [PdfDocument] for unsupported platforms.
///
/// All methods throw [UnsupportedError]. This class is never instantiated
/// directly — [PdfDocument.fromBytes] always reaches this stub when the
/// platform is not native or web.
class PdfDocumentImpl {
  PdfDocumentImpl._();

  /// Always throws [UnsupportedError].
  static Future<PdfDocumentImpl> fromBytes(
    Uint8List bytes, {
    String? dylibPath,
  }) async {
    throw UnsupportedError(
      'PdfDocument is not supported on this platform. '
      'Native (dart:ffi) and web (dart:js_interop) platforms are supported.',
    );
  }

  /// Always throws [UnsupportedError].
  Future<PdfMetadata> getMetadata() async {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  Future<PdfDocumentInfo> getDocumentInfo() async {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  Future<int> get pageCount async {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  ///
  /// Returns an empty stream is intentionally avoided here: an empty stream
  /// would silently appear to succeed while returning no data, masking the
  /// unsupported platform condition.
  Stream<PdfPageAnnotations> extractAnnotations({int? pageIndex}) {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  Stream<PdfPageText> extractPlainText({
    int? pageIndex,
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  Future<bool> isPlainTextExtractable({
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) async {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  Future<PdfPageSize> getPageSize(int pageIndex) async {
    throw UnsupportedError(
      'PdfDocument.getPageSize() is not supported on this platform. '
      'Native (dart:ffi) and web (dart:js_interop) platforms are supported.',
    );
  }

  /// Always throws [UnsupportedError].
  Future<({Uint8List pixels, int pixelWidth, int pixelHeight})>
  renderPageToBytes(
    int pageIndex,
    int pixelWidth,
    int pixelHeight, {
    bool renderAnnotations = true,
    bool lcdText = false,
    int backgroundColor = 0xFFFFFFFF,
  }) async {
    throw UnsupportedError(
      'PdfDocument.renderPageToBytes() is not supported on this platform. '
      'Native (dart:ffi) and web (dart:js_interop) platforms are supported.',
    );
  }

  /// Always throws [UnsupportedError].
  ///
  /// Returning an empty stream is intentionally avoided: it would silently
  /// appear to succeed while returning no data, masking the unsupported
  /// platform condition.
  Stream<PdfSearchMatch> search(
    String query, {
    Set<PdfSearchFlag> flags = const {},
    int? pageIndex,
  }) {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  Future<List<PdfTocEntry>> get tableOfContents async {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  ///
  /// Returning an empty stream is intentionally avoided: it would silently
  /// appear to succeed while returning no data, masking the unsupported
  /// platform condition.
  Stream<PdfPageImages> extractImages({
    int? pageIndex,
    bool includeBitmap = false,
  }) {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  Future<PdfImageBitmap?> renderImage(int pageIndex, int objectIndex) async {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }

  /// Always throws [UnsupportedError].
  ///
  /// Thumbnail extraction requires native PDFium (dart:ffi). The embedded
  /// thumbnail path and the fallback render path are both unavailable on
  /// unsupported platforms.
  Future<PdfThumbnail?> getThumbnail(
    int pageIndex, {
    bool generateIfAbsent = true,
    int maxDimension = 256,
  }) async {
    throw UnsupportedError(
      'PdfDocument.getThumbnail() is not supported on this platform. '
      'Native (dart:ffi) platforms are supported.',
    );
  }

  /// Always throws [UnsupportedError].
  Future<void> close() async {
    throw UnsupportedError('PdfDocument is not supported on this platform.');
  }
}
