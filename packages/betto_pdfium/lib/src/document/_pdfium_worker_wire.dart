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

// JS message envelope encode/decode for the PDFium Worker `postMessage`
// protocol.
//
// This is the `dart:js_interop`-dependent counterpart to
// `_pdfium_worker_protocol.dart`, which defines the pure-Dart [WorkerRequest]
// / [WorkerResponse] envelope types and deliberately stays free of
// `dart:js_interop` so it can be unit tested directly (VM or browser) without
// a real `Worker`. This file translates those pure-Dart envelopes to/from the
// plain `JSObject` shape actually sent over `postMessage`, and is imported by
// both the main-thread RPC client (`_document_web.dart`) and the worker-side
// dispatch shell (`_pdfium_worker_entry.dart`).
//
// Wire shape (both request and response messages):
//   {
//     id: number,              // correlation id
//     op: string,              // request only — one of the WorkerOp constants
//     json: string,            // JSON-encoded args (request) or result (response)
//     buffers: ArrayBuffer[],  // large binary payloads referenced from `json`
//                              // via integer `bufIndex` fields
//     ok: boolean,             // response only
//     errorType: string?,      // response only, present when ok is false
//     errorMessage: string?,   // response only, present when ok is false
//   }
//
// `buffers` entries are also passed as the `transfer` argument to
// `postMessage`, so they move (rather than copy) across the Worker boundary —
// this matters for the multi-megabyte BGRA bitmaps returned by render/
// thumbnail/image operations. A transferred `ArrayBuffer` is neutered on the
// sender side after the call; callers must not reuse `request.buffers` /
// `response.buffers` entries after building a wire message from them.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '_pdfium_worker_protocol.dart';

/// Builds the `JSObject` message payload for [request], plus the parallel
/// list of [JSArrayBuffer]s to pass as the `transfer` argument to
/// `postMessage`.
({JSObject message, List<JSArrayBuffer> transfer}) buildRequestMessage(
  WorkerRequest request,
) {
  final buffers = request.buffers.map((b) => b.buffer.toJS).toList();
  final obj = JSObject();
  obj.setProperty('id'.toJS, request.id.toJS);
  obj.setProperty('op'.toJS, request.op.toJS);
  obj.setProperty('json'.toJS, request.encodeArgs().toJS);
  obj.setProperty('buffers'.toJS, buffers.toJS);
  // When transferBuffers is false (WorkerOp.load — see WorkerRequest's doc
  // comment), the transfer list is empty: postMessage still delivers
  // `buffers` via structured-clone copy, but the caller's own ArrayBuffer is
  // left intact rather than neutered.
  return (message: obj, transfer: request.transferBuffers ? buffers : const []);
}

/// Parses a raw `JSObject` message (received worker-side) back into a
/// [WorkerRequest].
WorkerRequest parseRequestMessage(JSObject data) {
  final id = data.getProperty<JSNumber>('id'.toJS).toDartInt;
  final op = data.getProperty<JSString>('op'.toJS).toDart;
  final json = data.getProperty<JSString>('json'.toJS).toDart;
  return WorkerRequest.decode(
    id: id,
    op: op,
    argsJson: json,
    buffers: _readBuffers(data),
  );
}

/// Builds the `JSObject` message payload for [response], plus the parallel
/// list of [JSArrayBuffer]s to pass as the `transfer` argument to
/// `postMessage`.
({JSObject message, List<JSArrayBuffer> transfer}) buildResponseMessage(
  WorkerResponse response,
) {
  final buffers = response.buffers.map((b) => b.buffer.toJS).toList();
  final obj = JSObject();
  obj.setProperty('id'.toJS, response.id.toJS);
  obj.setProperty('ok'.toJS, response.ok.toJS);
  obj.setProperty('json'.toJS, response.encodeResult().toJS);
  obj.setProperty('buffers'.toJS, buffers.toJS);
  if (response.errorType != null) {
    obj.setProperty('errorType'.toJS, response.errorType!.toJS);
  }
  if (response.errorMessage != null) {
    obj.setProperty('errorMessage'.toJS, response.errorMessage!.toJS);
  }
  return (message: obj, transfer: buffers);
}

/// Parses a raw `JSObject` message (received client-side) back into a
/// [WorkerResponse].
WorkerResponse parseResponseMessage(JSObject data) {
  final id = data.getProperty<JSNumber>('id'.toJS).toDartInt;
  final ok = data.getProperty<JSBoolean>('ok'.toJS).toDart;
  final json = data.getProperty<JSString>('json'.toJS).toDart;
  final errorType = data.getProperty<JSAny?>('errorType'.toJS) as JSString?;
  final errorMessage =
      data.getProperty<JSAny?>('errorMessage'.toJS) as JSString?;
  return WorkerResponse.decode(
    id: id,
    ok: ok,
    resultJson: json,
    errorType: errorType?.toDart,
    errorMessage: errorMessage?.toDart,
    buffers: _readBuffers(data),
  );
}

/// Reads the `buffers` array of a wire message back into a list of
/// [Uint8List]s.
List<Uint8List> _readBuffers(JSObject data) {
  final arr = data.getProperty<JSArray<JSAny?>>('buffers'.toJS).toDart;
  return arr.map((b) => (b! as JSArrayBuffer).toDart.asUint8List()).toList();
}
