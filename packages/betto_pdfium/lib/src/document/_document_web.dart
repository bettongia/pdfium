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

// Web backend for PdfDocument — a thin `Worker` RPC client.
//
// Selected by the conditional import in pdf_document.dart when
// dart.library.js_interop is present (Flutter web / dart2wasm).
//
// Runtime notes:
//   - All PDFium work happens inside a dedicated `Worker`
//     (`_pdfium_worker_entry.dart`, compiled to `pdfium_worker.js`), not on
//     the browser main thread. `dart:isolate` is not usable on web (confirmed
//     against the Flutter/Dart docs — see the Web Worker offload plan), so
//     the worker is a hand-rolled `postMessage` RPC channel, mirroring the
//     shape (not the mechanism) of the native backend's `PdfiumIsolate`.
//   - One shared `Worker` is spawned lazily per page lifetime and reused by
//     every `PdfDocumentImpl`, multiplexing documents over it via opaque
//     integer tokens — mirroring native's one-isolate-per-process model.
//   - Every request/response crosses the boundary via a JSON string plus, for
//     large BGRA bitmap results, a parallel list of transferable
//     `ArrayBuffer`s (see `_pdfium_worker_protocol.dart` /
//     `_pdfium_worker_wire.dart` for the wire format).
//   - All requests for a given document [_token] are serialized through a
//     per-token queue (`_tokenQueues`) so a `close()` call can never race an
//     in-flight request for the same document — see `_sendForToken`.
//   - Streaming methods (extractPlainText, extractAnnotations, etc.) fetch
//     all requested pages in a single worker round trip (the worker computes
//     them synchronously in one dispatch), then yield them locally via
//     `Future.delayed(Duration.zero)` between items to preserve the public
//     Stream API's cooperative-yielding shape.
//
// Distribution:
//   - pdfium.js + pdfium.wasm + pdfium_worker.js must be placed at
//     web/assets/pdfium/ in the consumer's Flutter app. Run
//     `make fetch_wasm_assets` to download/copy them.
//   - The worker is spawned from the well-known relative URL
//     assets/pdfium/pdfium_worker.js (relative to the app origin), which in
//     turn loads assets/pdfium/pdfium.js via `importScripts()`.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../rendering/pdf_page_size.dart';
import '_pdfium_worker_protocol.dart';
import '_pdfium_worker_wire.dart';
import 'pdf_types.dart';

/// Web implementation of [PdfDocument] — a thin RPC client over a dedicated
/// PDFium `Worker`.
///
/// A single [web.Worker] is spawned lazily per page lifetime and shared
/// across all [PdfDocumentImpl] instances; documents are multiplexed over it
/// via opaque integer tokens assigned by the worker on [fromBytes]. All
/// PDFium state (the WASM module, document registry) lives inside the
/// worker — this class holds no PDFium handles directly.
///
/// Use [fromBytes] to load a document. Always call [close] when done.
/// A [Finalizer] is registered as a safety net against forgotten [close]
/// calls, but explicit [close] is preferred.
class PdfDocumentImpl {
  PdfDocumentImpl._(this._token) {
    _finalizer.attach(this, _token, detach: this);
  }

  final int _token;
  bool _closed = false;

  // ---------------------------------------------------------------------------
  // Static Worker singleton + RPC plumbing
  // ---------------------------------------------------------------------------

  /// The shared PDFium Worker. Spawned lazily on the first [fromBytes] call
  /// and held for the page lifetime. Spawning a [web.Worker] is synchronous
  /// (unlike loading the WASM module inside it), so `??=` here is safe
  /// against concurrent callers without a separate lazy-init guard.
  static web.Worker? _worker;

  /// Monotonically increasing request correlation id.
  static int _nextRequestId = 1;

  /// In-flight requests awaiting a [WorkerResponse], keyed by request id.
  ///
  /// A response whose id has no matching entry (e.g. the eventual reply to a
  /// [Finalizer]-triggered fire-and-forget `close` request) is silently
  /// ignored — see [_onMessage].
  static final Map<int, Completer<WorkerResponse>> _pending = {};

  /// Per-document request queues. Every request for a given token is
  /// chained onto the previous one via [_sendForToken], guaranteeing that a
  /// `close()` call is never processed by the worker while an earlier
  /// request for the same token is still in flight (and vice versa).
  static final Map<int, Future<void>> _tokenQueues = {};

  /// Safety-net Finalizer: if a [PdfDocumentImpl] is GC'd without [close]
  /// being called, this callback posts a fire-and-forget `close` request for
  /// its token to the worker, which performs the actual PDFium cleanup
  /// there (the WASM heap lives in the worker, not on the main thread, so
  /// this callback cannot free anything directly).
  // coverage:ignore-start
  // Finalizer callbacks are non-deterministic and cannot be reliably
  // triggered in a test suite.
  static final Finalizer<int> _finalizer = Finalizer<int>((token) {
    final worker = _worker;
    if (worker == null) return;
    final request = WorkerRequest(
      id: _nextRequestId++,
      op: WorkerOp.close,
      args: {'token': token},
    );
    final wire = buildRequestMessage(request);
    worker.postMessage(wire.message, wire.transfer.cast<JSAny>().toJS);
    // No completer is registered for this request id — the eventual
    // response is silently ignored by _onMessage.
  });
  // coverage:ignore-end

  static web.Worker _getWorker() {
    final existing = _worker;
    if (existing != null) return existing;

    final worker = web.Worker('assets/pdfium/pdfium_worker.js'.toJS);
    worker.onmessage = _onMessage.toJS;
    _worker = worker;
    return worker;
  }

  static void _onMessage(web.MessageEvent event) {
    final data = event.data;
    if (data == null || !data.isA<JSObject>()) return;
    final response = parseResponseMessage(data as JSObject);
    _pending.remove(response.id)?.complete(response);
  }

  /// Sends a request and awaits its response, throwing a reconstructed
  /// exception when the worker reports failure.
  static Future<WorkerResponse> _send(
    String op,
    Map<String, dynamic> args, {
    List<Uint8List> buffers = const [],
  }) async {
    final worker = _getWorker();
    final id = _nextRequestId++;
    final completer = Completer<WorkerResponse>();
    _pending[id] = completer;

    final request = WorkerRequest(id: id, op: op, args: args, buffers: buffers);
    final wire = buildRequestMessage(request);
    worker.postMessage(wire.message, wire.transfer.cast<JSAny>().toJS);

    final response = await completer.future;
    if (!response.ok) {
      throw reconstructError(response.errorType, response.errorMessage);
    }
    return response;
  }

  /// Sends a per-document request, serialized against every other request
  /// for [token] via [_tokenQueues] — see the class-level doc comment on
  /// [_tokenQueues] for why this ordering matters.
  static Future<WorkerResponse> _sendForToken(
    int token,
    String op,
    Map<String, dynamic> args, {
    List<Uint8List> buffers = const [],
  }) {
    final previous = _tokenQueues[token] ?? Future<void>.value();
    final completer = Completer<WorkerResponse>();
    final chained = previous.then((_) async {
      try {
        completer.complete(
          await _send(op, {'token': token, ...args}, buffers: buffers),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _tokenQueues[token] = chained;
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Public API — document lifecycle
  // ---------------------------------------------------------------------------

  /// Loads a PDF document from raw [bytes].
  ///
  /// [bytes] is transferred (not copied) to the worker, which allocates a
  /// WASM heap buffer, copies the bytes in, and calls
  /// `FPDF_LoadMemDocument64`. The worker-side buffer is kept alive until
  /// [close].
  ///
  /// [dylibPath] is accepted for API compatibility with the native backend
  /// but is ignored on web — the WASM module is loaded from a fixed URL.
  ///
  /// Throws [PdfExtractionException] if the document is invalid or
  /// password-protected.
  static Future<PdfDocumentImpl> fromBytes(
    Uint8List bytes, {
    String? dylibPath,
  }) async {
    final response = await _send(WorkerOp.load, const {}, buffers: [bytes]);
    final token = response.result!['token'] as int;
    return PdfDocumentImpl._(token);
  }

  /// Releases the PDFium document handle and frees the worker-side WASM heap
  /// buffer.
  ///
  /// Calling [close] multiple times is safe (subsequent calls are no-ops).
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _finalizer.detach(this);
    await _sendForToken(_token, WorkerOp.close, const {});
  }

  /// Returns the total number of pages in this document.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<int> get pageCount async {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.pageCount, const {});
    return response.result!['count'] as int;
  }

  // ---------------------------------------------------------------------------
  // Metadata, document info, page size, text extractability
  // ---------------------------------------------------------------------------

  /// Returns the Info dictionary metadata for this document.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfMetadata> getMetadata() async {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.metadata, const {});
    return decodeMetadata(response.result!);
  }

  /// Returns file-level information for this document.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<PdfDocumentInfo> getDocumentInfo() async {
    _checkNotClosed();
    final response = await _sendForToken(
      _token,
      WorkerOp.documentInfo,
      const {},
    );
    return decodeDocumentInfo(response.result!);
  }

  /// Returns the intrinsic size of [pageIndex] in PDF points (1 pt = 1/72 in).
  ///
  /// Throws [StateError] if [close] has already been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Future<PdfPageSize> getPageSize(int pageIndex) async {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.pageSize, {
      'pageIndex': pageIndex,
    });
    return decodePageSize(response.result!);
  }

  /// Returns true when the document has a text layer on most pages.
  ///
  /// Runs [extractPlainText] to completion and counts pages where
  /// [PdfPageText.hasTextLayer] is false. Returns false when the proportion
  /// of scanned pages meets or exceeds [config.scannedPageRatio].
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<bool> isPlainTextExtractable({
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) async {
    var totalPages = 0;
    var noTextLayerPages = 0;

    await for (final page in extractPlainText(config: config)) {
      totalPages++;
      if (!page.hasTextLayer) noTextLayerPages++;
    }

    if (totalPages == 0) return false;

    final scannedRatio = noTextLayerPages / totalPages;
    return scannedRatio < config.scannedPageRatio;
  }

  // ---------------------------------------------------------------------------
  // Text extraction and annotation extraction
  // ---------------------------------------------------------------------------

  /// Streams [PdfPageText] for each page, or a single page when [pageIndex]
  /// is specified.
  ///
  /// Fetches all requested pages in a single worker round trip, then yields
  /// them locally via `Future.delayed(Duration.zero)` between pages to
  /// reduce main-thread jank while consuming the stream.
  ///
  /// Throws [StateError] if [close] has already been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Stream<PdfPageText> extractPlainText({
    int? pageIndex,
    PdfTextExtractorConfig config = const PdfTextExtractorConfig(),
  }) {
    return _extractPlainTextImpl(pageIndex: pageIndex);
  }

  Stream<PdfPageText> _extractPlainTextImpl({int? pageIndex}) async* {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.extractText, {
      'pageIndex': pageIndex,
    });
    final pages = (response.result!['pages'] as List)
        .map((e) => decodePageText((e as Map).cast()))
        .toList();

    for (final page in pages) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;
      yield page;
    }
  }

  /// Streams [PdfPageAnnotations] for each page, or a single page when
  /// [pageIndex] is specified.
  ///
  /// Throws [StateError] if [close] has already been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Stream<PdfPageAnnotations> extractAnnotations({int? pageIndex}) {
    return _extractAnnotationsImpl(pageIndex: pageIndex);
  }

  Stream<PdfPageAnnotations> _extractAnnotationsImpl({int? pageIndex}) async* {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.extractAnnotations, {
      'pageIndex': pageIndex,
    });
    final pages = (response.result!['pages'] as List)
        .map((e) => decodePageAnnotations((e as Map).cast()))
        .toList();

    for (final page in pages) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;
      yield page;
    }
  }

  // ---------------------------------------------------------------------------
  // Rendering and thumbnails
  // ---------------------------------------------------------------------------

  /// Renders page [pageIndex] to a BGRA pixel buffer.
  ///
  /// Returns a record with [pixels] (compact BGRA bytes), [pixelWidth], and
  /// [pixelHeight]. The pixel buffer is transferred (not copied) back from
  /// the worker.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [PdfiumException] if a native PDFium call fails.
  Future<({Uint8List pixels, int pixelWidth, int pixelHeight})>
  renderPageToBytes(
    int pageIndex,
    int pixelWidth,
    int pixelHeight, {
    bool renderAnnotations = true,
    bool lcdText = false,
    int backgroundColor = 0xFFFFFFFF,
  }) async {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.render, {
      'pageIndex': pageIndex,
      'pixelWidth': pixelWidth,
      'pixelHeight': pixelHeight,
      'renderAnnotations': renderAnnotations,
      'lcdText': lcdText,
      'backgroundColor': backgroundColor,
    });
    return decodeRenderResult(response.result!, response.buffers);
  }

  /// Returns the thumbnail for page [pageIndex].
  ///
  /// Tries the embedded /Thumb stream first. If absent and [generateIfAbsent]
  /// is true (default), renders the page scaled to [maxDimension] pixels on
  /// the longest edge and returns a [PdfThumbnailSource.rendered] thumbnail.
  ///
  /// Returns null when no embedded thumbnail exists and [generateIfAbsent] is
  /// false.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [ArgumentError] if [maxDimension] ≤ 0.
  Future<PdfThumbnail?> getThumbnail(
    int pageIndex, {
    bool generateIfAbsent = true,
    int maxDimension = 256,
  }) async {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.thumbnail, {
      'pageIndex': pageIndex,
      'generateIfAbsent': generateIfAbsent,
      'maxDimension': maxDimension,
    });
    final thumbnailJson = response.result!['thumbnail'];
    if (thumbnailJson == null) return null;
    return decodeThumbnail((thumbnailJson as Map).cast(), response.buffers);
  }

  // ---------------------------------------------------------------------------
  // Images, search, table of contents
  // ---------------------------------------------------------------------------

  /// Streams [PdfPageImages] for each page, or a single page when [pageIndex]
  /// is specified.
  ///
  /// When [includeBitmap] is false (default), [PdfImage.bgra] is null.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Stream<PdfPageImages> extractImages({
    int? pageIndex,
    bool includeBitmap = false,
  }) {
    return _extractImagesImpl(
      pageIndex: pageIndex,
      includeBitmap: includeBitmap,
    );
  }

  Stream<PdfPageImages> _extractImagesImpl({
    int? pageIndex,
    required bool includeBitmap,
  }) async* {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.extractImages, {
      'pageIndex': pageIndex,
      'includeBitmap': includeBitmap,
    });
    final pages = (response.result!['pages'] as List)
        .map((e) => decodePageImages((e as Map).cast(), response.buffers))
        .toList();

    for (final page in pages) {
      if (_closed) return;
      await Future<void>.delayed(Duration.zero);
      if (_closed) return;
      yield page;
    }
  }

  /// Returns the BGRA bitmap for image object [objectIndex] on page
  /// [pageIndex], or null when the object has no renderable bitmap.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range or [objectIndex] is
  /// negative.
  Future<PdfImageBitmap?> renderImage(int pageIndex, int objectIndex) async {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.renderImage, {
      'pageIndex': pageIndex,
      'objectIndex': objectIndex,
    });
    final bitmapJson = response.result!['bitmap'];
    if (bitmapJson == null) return null;
    return decodeImageBitmap((bitmapJson as Map).cast(), response.buffers);
  }

  /// Streams [PdfSearchMatch] for all matches of [query] across the document,
  /// or across a single [pageIndex] when specified.
  ///
  /// An empty [query] yields nothing. [flags] controls case sensitivity and
  /// word-boundary matching. All matches are fetched in a single worker
  /// round trip; the client then yields them locally, inserting a
  /// cooperative delay whenever the source page changes, approximating the
  /// native backend's per-page yield cadence.
  ///
  /// Throws [StateError] if [close] has been called.
  /// Throws [RangeError] if [pageIndex] is out of range.
  Stream<PdfSearchMatch> search(
    String query, {
    Set<PdfSearchFlag> flags = const {},
    int? pageIndex,
  }) {
    return _searchImpl(query, flags: flags, pageIndex: pageIndex);
  }

  Stream<PdfSearchMatch> _searchImpl(
    String query, {
    required Set<PdfSearchFlag> flags,
    int? pageIndex,
  }) async* {
    if (query.isEmpty) return;
    _checkNotClosed();

    var flagsMask = 0;
    if (flags.contains(PdfSearchFlag.matchCase)) flagsMask |= 0x01;
    if (flags.contains(PdfSearchFlag.matchWholeWord)) flagsMask |= 0x02;
    if (flags.contains(PdfSearchFlag.consecutive)) flagsMask |= 0x04;

    final response = await _sendForToken(_token, WorkerOp.search, {
      'query': query,
      'flagsMask': flagsMask,
      'pageIndex': pageIndex,
    });
    final matches = (response.result!['matches'] as List)
        .map((e) => decodeSearchMatch((e as Map).cast()))
        .toList();

    int? lastPageIndex;
    for (final match in matches) {
      if (_closed) return;
      if (match.pageIndex != lastPageIndex) {
        await Future<void>.delayed(Duration.zero);
        if (_closed) return;
        lastPageIndex = match.pageIndex;
      }
      yield match;
    }
  }

  /// Returns the complete Table of Contents (bookmark/outline tree).
  ///
  /// Returns an empty list when the document has no bookmarks.
  ///
  /// Throws [StateError] if [close] has already been called.
  Future<List<PdfTocEntry>> get tableOfContents async {
    _checkNotClosed();
    final response = await _sendForToken(_token, WorkerOp.toc, const {});
    return (response.result!['entries'] as List)
        .map((e) => decodeTocEntry((e as Map).cast()))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _checkNotClosed() {
    if (_closed) {
      throw StateError('PdfDocument has already been closed.');
    }
  }
}
