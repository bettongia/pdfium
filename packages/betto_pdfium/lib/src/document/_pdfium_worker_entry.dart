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

// PDFium Worker entry point — a dedicated `Worker` global-scope program that
// owns the PDFium WASM module and document registry, and dispatches
// `postMessage` requests from the main-thread `PdfDocumentImpl` RPC client
// (`_document_web.dart`) to the shared PDFium marshalling engine
// (`_pdfium_wasm_engine.dart`).
//
// This file is NOT compiled as part of a consuming app's own bundle. It is
// pre-compiled once by `betto_pdfium`'s own release process via
// `make build_wasm_worker` (`dart compile js -O2`) into the checked-in
// artifact `lib/assets/pdfium_worker.js`, which `fetch_wasm_assets.sh` copies
// into a consumer's `web/assets/pdfium/` directory alongside `pdfium.wasm`
// and `pdfium.js`. Consumers never compile or reference this Dart source
// directly.
//
// Module bootstrap in worker scope: DOM APIs (`document.createElement`, the
// `<script>`-tag injection used by `loadPdfiumModule()` in
// `_pdfium_wasm_engine.dart`) are unavailable inside a Worker's global scope.
// Workers instead load additional scripts via `importScripts()`, which is
// synchronous and executes the script in the worker's own global scope — so
// this file pre-configures `self.Module` with an `onRuntimeInitialized`
// callback before calling `importScripts('pdfium.js')`, mirroring the
// pre-configuration strategy `loadPdfiumModule()` uses on the main thread,
// but through the worker-only API.
//
// Testing note: this file's dispatch logic (`main()` and everything it calls
// directly) executes exclusively inside a spawned `Worker`, which is a
// separate Chrome DevTools Protocol target invisible to
// `dart test -p chrome --coverage` (see the plan's "Testing impact" section
// for the full analysis). It is therefore marked with
// `// coverage:ignore-start` / `-end`, consistent with the project's existing
// convention for platform-dispatch code in `pdfium_isolate.dart`. The PDFium
// marshalling logic it calls into (`_pdfium_wasm_engine.dart`) stays plain,
// directly-callable Dart and is exercised by the main-thread test suite
// instead (see Phase 4 of the Web Worker offload plan).

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../pdf_exception.dart';
import '_pdfium_js_interop.dart';
import '_pdfium_wasm_engine.dart';
import '_pdfium_worker_protocol.dart';
import '_pdfium_worker_wire.dart';
import 'pdf_types.dart';

// coverage:ignore-start

/// Mutable worker-global state: the PDFium module singleton, the document
/// registry, and the token counter. Held in a single object (rather than
/// closure-captured locals reassigned after each `await`) so that concurrent
/// in-flight requests always observe the latest state — in particular,
/// [moduleLoading] ensures `FPDF_InitLibraryWithConfig` is never triggered
/// twice even if two `load` requests for two different documents arrive
/// before the first module load completes.
class _WorkerState {
  /// The PDFium Emscripten module, once loaded. Null until the first
  /// successful `load` request completes.
  PdfiumModule? module;

  /// The in-flight module-loading [Future], if a `load` request has started
  /// (but not necessarily finished) loading the module. Guards against
  /// double-initialisation when multiple `load` requests race.
  Future<PdfiumModule>? moduleLoading;

  /// Per-document WASM heap pointers, keyed by opaque client-facing token.
  final registry = <int, ({int docPtr, int bufPtr})>{};

  /// Monotonically increasing token counter.
  int nextToken = 1;
}

/// Worker entry point. Installs the `message` listener and begins serving
/// PDFium RPC requests from the main thread.
void main() {
  final scope = globalContext as web.DedicatedWorkerGlobalScope;
  final state = _WorkerState();

  scope.addEventListener(
    'message',
    ((web.MessageEvent event) {
      final data = event.data;
      if (data == null || !data.isA<JSObject>()) return;
      final request = parseRequestMessage(data as JSObject);
      unawaited(_handleRequest(scope, request, state));
    }).toJS,
  );
}

/// Handles a single [request] against the shared [state] and posts the
/// resulting [WorkerResponse] back to [scope].
Future<void> _handleRequest(
  web.DedicatedWorkerGlobalScope scope,
  WorkerRequest request,
  _WorkerState state,
) async {
  try {
    switch (request.op) {
      case WorkerOp.load:
        // `moduleLoading ??= ...` is assigned synchronously (before any
        // `await` in this call), so a second concurrent 'load' request —
        // which can only be dispatched after this synchronous segment
        // yields back to the event loop — always observes the same
        // in-flight Future rather than triggering a second module load.
        state.moduleLoading ??= _loadWorkerModule(scope);
        final module = state.module ??= await state.moduleLoading!;
        final bytes = request.buffers[0];
        final rec = engineLoadDocument(module, bytes);
        final token = state.nextToken++;
        state.registry[token] = rec;
        _respond(scope, WorkerResponse.success(request.id, {'token': token}));

      case WorkerOp.close:
        final token = request.args['token'] as int;
        final rec = state.registry.remove(token);
        if (rec != null && state.module != null) {
          engineCloseDocument(state.module!, rec.docPtr, rec.bufPtr);
        }
        _respond(scope, WorkerResponse.success(request.id, const {}));

      case WorkerOp.pageCount:
        final docPtr = _docPtr(state.registry, request);
        final count = enginePageCount(state.module!, docPtr);
        _respond(scope, WorkerResponse.success(request.id, {'count': count}));

      case WorkerOp.metadata:
        final docPtr = _docPtr(state.registry, request);
        final metadata = engineGetMetadata(state.module!, docPtr);
        _respond(
          scope,
          WorkerResponse.success(request.id, encodeMetadata(metadata)),
        );

      case WorkerOp.documentInfo:
        final docPtr = _docPtr(state.registry, request);
        final info = engineGetDocumentInfo(state.module!, docPtr);
        _respond(
          scope,
          WorkerResponse.success(request.id, encodeDocumentInfo(info)),
        );

      case WorkerOp.pageSize:
        final docPtr = _docPtr(state.registry, request);
        final pageIndex = request.args['pageIndex'] as int;
        final size = engineGetPageSize(state.module!, docPtr, pageIndex);
        _respond(
          scope,
          WorkerResponse.success(request.id, encodePageSize(size)),
        );

      case WorkerOp.render:
        final docPtr = _docPtr(state.registry, request);
        final args = request.args;
        final result = engineRenderPageToBytes(
          state.module!,
          docPtr,
          args['pageIndex'] as int,
          args['pixelWidth'] as int,
          args['pixelHeight'] as int,
          renderAnnotations: args['renderAnnotations'] as bool,
          lcdText: args['lcdText'] as bool,
          backgroundColor: args['backgroundColor'] as int,
        );
        final buffers = <Uint8List>[];
        _respond(
          scope,
          WorkerResponse.success(
            request.id,
            encodeRenderResult(result, buffers),
            buffers: buffers,
          ),
        );

      case WorkerOp.thumbnail:
        final docPtr = _docPtr(state.registry, request);
        final args = request.args;
        final thumb = engineGetThumbnail(
          state.module!,
          docPtr,
          args['pageIndex'] as int,
          generateIfAbsent: args['generateIfAbsent'] as bool,
          maxDimension: args['maxDimension'] as int,
        );
        if (thumb == null) {
          _respond(
            scope,
            WorkerResponse.success(request.id, const {'thumbnail': null}),
          );
        } else {
          final buffers = <Uint8List>[];
          _respond(
            scope,
            WorkerResponse.success(request.id, {
              'thumbnail': encodeThumbnail(thumb, buffers),
            }, buffers: buffers),
          );
        }

      case WorkerOp.extractText:
        final docPtr = _docPtr(state.registry, request);
        final pageIndex = request.args['pageIndex'] as int?;
        final indices = engineResolvePageIndices(
          state.module!,
          docPtr,
          pageIndex,
        );
        final pages = indices
            .map(
              (i) => encodePageText(
                engineExtractPageText(state.module!, docPtr, i),
              ),
            )
            .toList();
        _respond(scope, WorkerResponse.success(request.id, {'pages': pages}));

      case WorkerOp.extractAnnotations:
        final docPtr = _docPtr(state.registry, request);
        final pageIndex = request.args['pageIndex'] as int?;
        final indices = engineResolvePageIndices(
          state.module!,
          docPtr,
          pageIndex,
        );
        final pages = indices
            .map(
              (i) => encodePageAnnotations(
                PdfPageAnnotations(
                  pageIndex: i,
                  annotations: engineExtractPageAnnotations(
                    state.module!,
                    docPtr,
                    i,
                  ),
                ),
              ),
            )
            .toList();
        _respond(scope, WorkerResponse.success(request.id, {'pages': pages}));

      case WorkerOp.extractImages:
        final docPtr = _docPtr(state.registry, request);
        final args = request.args;
        final pageIndex = args['pageIndex'] as int?;
        final includeBitmap = args['includeBitmap'] as bool;
        final indices = engineResolvePageIndices(
          state.module!,
          docPtr,
          pageIndex,
        );
        final buffers = <Uint8List>[];
        final pages = indices.map((i) {
          final images = engineExtractPageImages(
            state.module!,
            docPtr,
            i,
            includeBitmap,
          );
          return encodePageImages(
            PdfPageImages(pageIndex: i, images: images),
            buffers,
          );
        }).toList();
        _respond(
          scope,
          WorkerResponse.success(request.id, {
            'pages': pages,
          }, buffers: buffers),
        );

      case WorkerOp.renderImage:
        final docPtr = _docPtr(state.registry, request);
        final args = request.args;
        final bitmap = engineRenderImage(
          state.module!,
          docPtr,
          args['pageIndex'] as int,
          args['objectIndex'] as int,
        );
        if (bitmap == null) {
          _respond(
            scope,
            WorkerResponse.success(request.id, const {'bitmap': null}),
          );
        } else {
          final buffers = <Uint8List>[];
          _respond(
            scope,
            WorkerResponse.success(request.id, {
              'bitmap': encodeImageBitmap(bitmap, buffers),
            }, buffers: buffers),
          );
        }

      case WorkerOp.search:
        final docPtr = _docPtr(state.registry, request);
        final args = request.args;
        final query = args['query'] as String;
        final flagsMask = args['flagsMask'] as int;
        final pageIndex = args['pageIndex'] as int?;
        final matches = <Map<String, dynamic>>[];
        if (query.isNotEmpty) {
          final indices = engineResolvePageIndices(
            state.module!,
            docPtr,
            pageIndex,
          );
          for (final i in indices) {
            for (final m in engineSearchPage(
              state.module!,
              docPtr,
              i,
              query,
              flagsMask,
            )) {
              matches.add(encodeSearchMatch(m));
            }
          }
        }
        _respond(
          scope,
          WorkerResponse.success(request.id, {'matches': matches}),
        );

      case WorkerOp.toc:
        final docPtr = _docPtr(state.registry, request);
        final entries = engineTableOfContents(state.module!, docPtr);
        _respond(
          scope,
          WorkerResponse.success(request.id, {
            'entries': entries.map(encodeTocEntry).toList(),
          }),
        );

      default:
        _respond(
          scope,
          WorkerResponse.failure(
            request.id,
            PdfiumException('Unknown worker op: ${request.op}'),
          ),
        );
    }
  } catch (error) {
    _respond(scope, WorkerResponse.failure(request.id, error));
  }
}

/// Resolves the `docPtr` for the document token carried in [request.args].
///
/// Throws [StateError] if the token is not present in [registry] (e.g. the
/// document was already closed) — this becomes a wire error response.
int _docPtr(
  Map<int, ({int docPtr, int bufPtr})> registry,
  WorkerRequest request,
) {
  final token = request.args['token'] as int;
  final rec = registry[token];
  if (rec == null) {
    throw StateError('PdfDocument has already been closed.');
  }
  return rec.docPtr;
}

/// Posts [response] back to the main thread, transferring any large binary
/// buffers rather than copying them.
void _respond(web.DedicatedWorkerGlobalScope scope, WorkerResponse response) {
  final wire = buildResponseMessage(response);
  // Note: do NOT insert a `.cast<JSAny>()` step here — `List.cast()` returns
  // a lazy `CastList` view rather than a real JS-backed list, and `.toJS`
  // on a `CastList` produces a JSArray that fails runtime type checks under
  // stricter compile modes (observed under `dart test --coverage-path`,
  // which surfaced a `CastList is not a subtype of JSArray` TypeError that
  // the default test compile mode did not catch). `wire.transfer` is
  // already typed `List<JSArrayBuffer>`, which satisfies `.toJS`'s
  // `List<T extends JSAny?>` bound directly.
  scope.postMessage(wire.message, wire.transfer.toJS);
}

/// Loads pdfium.js and initialises the PDFium WASM module from within the
/// worker's global scope.
///
/// DOM APIs are unavailable here, so unlike `loadPdfiumModule()` in
/// `_pdfium_wasm_engine.dart` (which injects a `<script>` tag), this loads
/// the script via `importScripts()`, which is synchronous and executes in the
/// worker's own global scope. `pdfium.js` is a non-MODULARIZE Emscripten
/// build that merges a pre-configured global `Module` object, so `self` is
/// pre-populated with an `onRuntimeInitialized` callback before the script is
/// imported — mirroring the main-thread `window.Module` pre-configuration
/// strategy through the worker-only API.
Future<PdfiumModule> _loadWorkerModule(
  web.DedicatedWorkerGlobalScope scope,
) async {
  final completer = Completer<void>();

  final config = JSObject();
  config.setProperty(
    'onRuntimeInitialized'.toJS,
    (() {
      if (!completer.isCompleted) completer.complete();
    }).toJS,
  );
  scope.setProperty('Module'.toJS, config);

  scope.importScripts('pdfium.js'.toJS);

  try {
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw PdfiumException(
        'PDFium WASM module failed to initialise within 30 seconds inside '
        'the PDFium Worker. Ensure pdfium.js and pdfium.wasm are present at '
        'assets/pdfium/ relative to the app origin, alongside '
        'pdfium_worker.js (run `make fetch_wasm_assets`).',
      ),
    );
  } catch (e) {
    if (e is PdfiumException) rethrow;
    throw PdfiumException(
      'PDFium WASM module failed to initialise inside the PDFium Worker: $e',
    );
  }

  final module = scope.getProperty<PdfiumModule>('Module'.toJS);
  module.fpdfInitLibraryWithConfig(0);

  return module;
}

// coverage:ignore-end
