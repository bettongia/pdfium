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

// Web backend stub for PdfDocument.
//
// This file is selected by the conditional import in pdf_document.dart when
// dart.library.js_interop is present (i.e. on web). The full implementation
// requires the PDFium WASM binary, which is built by
// plan_pdfium_build_infrastructure.md and is not yet available.
//
// Until the WASM binary is ready, all methods throw [UnsupportedError] with
// an actionable message. When the WASM binary is available, this file is
// replaced by the full dart:js_interop / WASM implementation.
//
// Web platform notes (for when this is implemented):
//   - PDFium WASM runs synchronously on the browser main thread in v1.
//   - For large documents, getMetadata() may block briefly — callers should
//     display a loading indicator.
//   - A Web Worker path is deferred to plan_layout_aware_reordering.md, where
//     per-character operations make offloading to a worker essential.

import 'dart:typed_data';

import 'pdf_types.dart';

/// Web backend for [PdfDocument] — currently a stub pending the PDFium WASM build.
///
/// All methods throw [UnsupportedError] until the PDFium WASM binary is
/// available. See `plan_pdfium_build_infrastructure.md` for the build plan.
class PdfDocumentImpl {
  PdfDocumentImpl._();

  /// Not yet implemented on web.
  ///
  /// Throws [UnsupportedError]. Will be implemented once the PDFium WASM
  /// binary is available from `plan_pdfium_build_infrastructure.md`.
  static Future<PdfDocumentImpl> fromBytes(
    Uint8List bytes, {
    String? dylibPath,
  }) async {
    throw UnsupportedError(
      'PdfDocument web support requires the PDFium WASM binary, which is not '
      'yet available. See plan_pdfium_build_infrastructure.md.',
    );
  }

  /// Not yet implemented on web.
  Future<PdfMetadata> getMetadata() async {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  Future<PdfDocumentInfo> getDocumentInfo() async {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  ///
  /// Will be implemented once the PDFium WASM binary is available from
  /// `plan_pdfium_build_infrastructure.md`.
  Future<int> get pageCount async {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  ///
  /// Throws [UnsupportedError]. Returning an empty stream is intentionally
  /// avoided: it would silently appear to succeed while returning no data,
  /// masking the unsupported platform condition. Follow the same pattern as
  /// [extractPlainText] on this stub.
  Stream<PdfPageAnnotations> extractAnnotations({int? pageIndex}) {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  ///
  /// Will be implemented once the PDFium WASM binary is available from
  /// `plan_pdfium_build_infrastructure.md`. On web, the stream yields to the
  /// event loop between pages via `Future.delayed(Duration.zero)` to reduce
  /// main-thread jank. Prefer `extractPlainText(pageIndex: n)` for large
  /// documents until a Web Worker path is available.
  Stream<PdfPageText> extractPlainText({
    int? pageIndex,
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  Future<bool> isPlainTextExtractable({
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) async {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  ///
  /// Throws [UnsupportedError]. Returning an empty stream is intentionally
  /// avoided: it would silently appear to succeed while returning no data,
  /// masking the unsupported platform condition.
  Stream<PdfSearchMatch> search(
    String query, {
    Set<PdfSearchFlag> flags = const {},
    int? pageIndex,
  }) {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  Future<List<PdfTocEntry>> get tableOfContents async {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  ///
  /// Throws [UnsupportedError]. Returning an empty stream is intentionally
  /// avoided: it would silently appear to succeed while returning no data,
  /// masking the unsupported platform condition.
  Stream<PdfPageImages> extractImages({
    int? pageIndex,
    bool includeBitmap = false,
  }) {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  Future<PdfImageBitmap?> renderImage(int pageIndex, int objectIndex) async {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  ///
  /// Thumbnail extraction requires native PDFium (dart:ffi). The embedded
  /// thumbnail path uses FFI directly, and the fallback render path also relies
  /// on the native rendering pipeline. Neither is available on web.
  Future<PdfThumbnail?> getThumbnail(
    int pageIndex, {
    bool generateIfAbsent = true,
    int maxDimension = 256,
  }) async {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }

  /// Not yet implemented on web.
  Future<void> close() async {
    throw UnsupportedError('PdfDocument web support is not yet implemented.');
  }
}
