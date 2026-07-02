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

// Wire protocol shared between the main-thread PdfDocumentImpl RPC client
// (_document_web.dart) and the dedicated PDFium Worker
// (_pdfium_worker_entry.dart).
//
// This file is imported by BOTH sides of the Worker boundary, but each side
// is compiled into a SEPARATE JavaScript bundle: the main-thread client is
// compiled as part of whatever build produces the consuming app (dart2js or
// dart2wasm), while the worker entry point is compiled independently via
// `dart compile js` (see `make build_wasm_worker`). Sharing this Dart source
// file (rather than duplicating the wire format by hand on both sides) is
// safe and intentional — it does not create a shared *runtime* dependency
// between the two bundles; each compiles its own copy of this logic.
//
// Design notes:
//   - Every request/response crosses the Worker boundary via `postMessage`,
//     which requires structured-clone-compatible JS values. Rather than
//     hand-building JSObject property trees for every operation, each side
//     encodes its payload as a plain JSON string (via `dart:convert`, no
//     `dart:js_interop` dependency in this file at all — it is safe to unit
//     test directly on the Dart VM or under `dart test -p chrome` without a
//     real Worker).
//   - Large binary payloads (rendered BGRA bitmaps) are NOT embedded in the
//     JSON string — encoding megabytes of pixel data as a JSON array of
//     integers would be slow and bloat the message. Instead, such payloads
//     are appended to a side `List<Uint8List>` ("buffers") that travels
//     alongside the JSON string and is transferred (not copied) via
//     `postMessage`'s transfer-list parameter. The JSON payload carries only
//     an integer index (`bufIndex`) referencing the matching entry.
//   - `WorkerRequest.id` / `WorkerResponse.id` provide the request/response
//     correlation that `SendPort`/`ReceivePort` gives for free to the native
//     isolate backend (`pdfium_isolate.dart`) — the hand-rolled Worker
//     protocol must replicate this explicitly.

import 'dart:convert';
import 'dart:typed_data';

import '../pdf_exception.dart';
import '../rendering/pdf_page_size.dart';
import 'pdf_types.dart';

// =============================================================================
// Operation codes
// =============================================================================

/// Operation codes for the PDFium Worker RPC protocol. One per PDFium
/// operation exposed by [PdfDocumentImpl].
abstract final class WorkerOp {
  /// Loads a document from raw bytes (transferred via [WorkerRequest.buffers]).
  static const String load = 'load';

  /// Closes a document and frees its WASM heap buffers.
  ///
  /// Also used by the main-thread [Finalizer] safety net to request cleanup
  /// for a garbage-collected [PdfDocumentImpl] that was never explicitly
  /// closed — there is no separate "free" operation.
  static const String close = 'close';

  /// Returns the page count of a document.
  static const String pageCount = 'pageCount';

  /// Returns the Info dictionary metadata of a document.
  static const String metadata = 'metadata';

  /// Returns file-level document info (version, file identifiers).
  static const String documentInfo = 'documentInfo';

  /// Returns the intrinsic size of a single page.
  static const String pageSize = 'pageSize';

  /// Renders a page to a BGRA pixel buffer.
  static const String render = 'render';

  /// Returns the thumbnail for a page (embedded or rendered fallback).
  static const String thumbnail = 'thumbnail';

  /// Extracts plain text for one or all pages.
  static const String extractText = 'extractText';

  /// Extracts annotations for one or all pages.
  static const String extractAnnotations = 'extractAnnotations';

  /// Extracts image objects for one or all pages.
  static const String extractImages = 'extractImages';

  /// Renders a single image object to a BGRA bitmap.
  static const String renderImage = 'renderImage';

  /// Searches for text matches across one or all pages.
  static const String search = 'search';

  /// Returns the table of contents (bookmark tree).
  static const String toc = 'toc';
}

// =============================================================================
// Request / response envelopes
// =============================================================================

/// A request sent from the main-thread RPC client to the worker.
///
/// [id] is a monotonically increasing correlation id used to match the
/// eventual [WorkerResponse]. [op] is one of the [WorkerOp] constants. [args]
/// is a JSON-safe map of operation-specific parameters. [buffers] carries any
/// large binary payloads (currently only used by [WorkerOp.load], for the raw
/// PDF bytes).
///
/// [transferBuffers] controls whether [buffers] are moved (via
/// `postMessage`'s transfer list) or structured-clone-copied. This defaults
/// to true, but [WorkerOp.load] must set it to false: [buffers] there is the
/// *caller's own* PDF byte buffer, which the caller may reasonably expect to
/// still be usable after `fromBytes()` returns (e.g. to load the same bytes
/// into a second document, or simply because they own the buffer). A
/// transferred `ArrayBuffer` is neutered on the sender side immediately, so
/// transferring caller-supplied input would silently break any such reuse —
/// unlike worker-*generated* output buffers (rendered bitmaps), which are
/// always freshly allocated per response and safe to move.
class WorkerRequest {
  /// Creates a [WorkerRequest].
  const WorkerRequest({
    required this.id,
    required this.op,
    required this.args,
    this.buffers = const [],
    this.transferBuffers = true,
  });

  /// Correlation id matching the eventual [WorkerResponse.id].
  final int id;

  /// The operation to perform — one of the [WorkerOp] constants.
  final String op;

  /// JSON-safe operation-specific parameters.
  final Map<String, dynamic> args;

  /// Large binary payloads referenced from [args] via integer `bufIndex`
  /// fields (see file-level doc comment).
  final List<Uint8List> buffers;

  /// Whether [buffers] should be moved (transferred) rather than copied. See
  /// the class-level doc comment for why [WorkerOp.load] must set this false.
  final bool transferBuffers;

  /// Encodes [args] as a JSON string. [buffers] travels out-of-band.
  String encodeArgs() => jsonEncode(args);

  /// Decodes a [WorkerRequest] from its wire fields.
  static WorkerRequest decode({
    required int id,
    required String op,
    required String argsJson,
    List<Uint8List> buffers = const [],
  }) {
    final decoded = jsonDecode(argsJson) as Map;
    return WorkerRequest(
      id: id,
      op: op,
      args: decoded.cast<String, dynamic>(),
      buffers: buffers,
    );
  }
}

/// A response sent from the worker back to the main-thread RPC client.
///
/// [ok] is false when the worker-side call threw; in that case [errorType]
/// and [errorMessage] describe the failure so the client can reconstruct an
/// equivalent Dart exception via [reconstructError]. [result] is a JSON-safe
/// map of operation-specific results when [ok] is true. [buffers] carries
/// large binary payloads (e.g. rendered BGRA bitmaps) that travel as
/// transferable `ArrayBuffer`s rather than embedded JSON.
class WorkerResponse {
  /// Creates a [WorkerResponse].
  const WorkerResponse({
    required this.id,
    required this.ok,
    this.result,
    this.errorType,
    this.errorMessage,
    this.buffers = const [],
  });

  /// Builds a successful [WorkerResponse].
  factory WorkerResponse.success(
    int id,
    Map<String, dynamic> result, {
    List<Uint8List> buffers = const [],
  }) => WorkerResponse(id: id, ok: true, result: result, buffers: buffers);

  /// Builds a failure [WorkerResponse] from a caught [error].
  factory WorkerResponse.failure(int id, Object error) {
    final classified = classifyError(error);
    return WorkerResponse(
      id: id,
      ok: false,
      errorType: classified.type,
      errorMessage: classified.message,
    );
  }

  /// Correlation id matching the originating [WorkerRequest.id].
  final int id;

  /// True when the worker-side call succeeded.
  final bool ok;

  /// JSON-safe operation-specific result, present when [ok] is true.
  final Map<String, dynamic>? result;

  /// The Dart exception/error type name, present when [ok] is false.
  final String? errorType;

  /// A human-readable error message, present when [ok] is false.
  final String? errorMessage;

  /// Large binary payloads referenced from [result] via integer `bufIndex`
  /// fields (see file-level doc comment).
  final List<Uint8List> buffers;

  /// Encodes [result] as a JSON string. [buffers] travels out-of-band.
  String encodeResult() => jsonEncode(result ?? const <String, dynamic>{});

  /// Decodes a [WorkerResponse] from its wire fields.
  static WorkerResponse decode({
    required int id,
    required bool ok,
    String? resultJson,
    String? errorType,
    String? errorMessage,
    List<Uint8List> buffers = const [],
  }) {
    final result = resultJson == null
        ? null
        : (jsonDecode(resultJson) as Map).cast<String, dynamic>();
    return WorkerResponse(
      id: id,
      ok: ok,
      result: result,
      errorType: errorType,
      errorMessage: errorMessage,
      buffers: buffers,
    );
  }
}

// =============================================================================
// Error classification (worker → client)
// =============================================================================

/// Classifies [error] into a `(type, message)` pair suitable for wire
/// transport, so the client can reconstruct an equivalent exception via
/// [reconstructError].
({String type, String message}) classifyError(Object error) {
  return switch (error) {
    RangeError e => (
      type: 'RangeError',
      message: e.message?.toString() ?? e.toString(),
    ),
    ArgumentError e => (
      type: 'ArgumentError',
      message: e.message?.toString() ?? e.toString(),
    ),
    StateError e => (type: 'StateError', message: e.message),
    PdfExtractionException e => (
      type: 'PdfExtractionException',
      message: e.error.name,
    ),
    PdfiumException e => (type: 'PdfiumException', message: e.message),
    _ => (type: 'Exception', message: error.toString()),
  };
}

/// Reconstructs a client-side Dart exception/error from a failed
/// [WorkerResponse]'s [WorkerResponse.errorType] / [WorkerResponse.errorMessage].
Object reconstructError(String? errorType, String? errorMessage) {
  final message = errorMessage ?? '';
  return switch (errorType) {
    'RangeError' => RangeError(message),
    'ArgumentError' => ArgumentError(message),
    'StateError' => StateError(message),
    'PdfExtractionException' => PdfExtractionException(
      message == PdfError.passwordRequired.name
          ? PdfError.passwordRequired
          : PdfError.invalidDocument,
    ),
    'PdfiumException' => PdfiumException(message),
    _ => Exception(message),
  };
}

// =============================================================================
// Value (de)serialisation — small JSON-safe types
// =============================================================================

/// Encodes a [PdfDate] to a JSON-safe map, or null.
Map<String, dynamic>? encodeDate(PdfDate? d) =>
    d == null ? null : {'raw': d.raw, 'value': d.value?.toIso8601String()};

/// Decodes a [PdfDate] from its wire map, or null.
PdfDate? decodeDate(dynamic j) {
  if (j == null) return null;
  final m = (j as Map).cast<String, dynamic>();
  final valueStr = m['value'] as String?;
  return PdfDate(
    raw: m['raw'] as String,
    value: valueStr == null ? null : DateTime.parse(valueStr),
  );
}

/// Encodes a [PdfRect] to a JSON-safe map.
Map<String, dynamic> encodeRect(PdfRect r) => {
  'left': r.left,
  'bottom': r.bottom,
  'right': r.right,
  'top': r.top,
};

/// Decodes a [PdfRect] from its wire map.
PdfRect decodeRect(Map<String, dynamic> j) => PdfRect(
  left: (j['left'] as num).toDouble(),
  bottom: (j['bottom'] as num).toDouble(),
  right: (j['right'] as num).toDouble(),
  top: (j['top'] as num).toDouble(),
);

/// Encodes a [PdfColor] to a JSON-safe map.
Map<String, dynamic> encodeColor(PdfColor c) => {
  'r': c.r,
  'g': c.g,
  'b': c.b,
  'a': c.a,
};

/// Decodes a [PdfColor] from its wire map.
PdfColor decodeColor(Map<String, dynamic> j) => PdfColor(
  r: j['r'] as int,
  g: j['g'] as int,
  b: j['b'] as int,
  a: j['a'] as int,
);

/// Encodes a [PdfPoint] to a JSON-safe map.
Map<String, dynamic> encodePoint(PdfPoint p) => {'x': p.x, 'y': p.y};

/// Decodes a [PdfPoint] from its wire map.
PdfPoint decodePoint(Map<String, dynamic> j) =>
    PdfPoint(x: (j['x'] as num).toDouble(), y: (j['y'] as num).toDouble());

/// Encodes a [PdfQuadPoints] to a JSON-safe map.
Map<String, dynamic> encodeQuadPoints(PdfQuadPoints q) => {
  'p1': encodePoint(q.p1),
  'p2': encodePoint(q.p2),
  'p3': encodePoint(q.p3),
  'p4': encodePoint(q.p4),
};

/// Decodes a [PdfQuadPoints] from its wire map.
PdfQuadPoints decodeQuadPoints(Map<String, dynamic> j) => PdfQuadPoints(
  p1: decodePoint((j['p1'] as Map).cast()),
  p2: decodePoint((j['p2'] as Map).cast()),
  p3: decodePoint((j['p3'] as Map).cast()),
  p4: decodePoint((j['p4'] as Map).cast()),
);

/// Encodes a [PdfPopupAnnotation] to a JSON-safe map.
Map<String, dynamic> encodePopup(PdfPopupAnnotation p) => {
  'rect': p.rect == null ? null : encodeRect(p.rect!),
  'flags': p.flags,
};

/// Decodes a [PdfPopupAnnotation] from its wire map.
PdfPopupAnnotation decodePopup(Map<String, dynamic> j) => PdfPopupAnnotation(
  rect: j['rect'] == null ? null : decodeRect((j['rect'] as Map).cast()),
  flags: j['flags'] as int,
);

/// Encodes a [PdfMetadata] to a JSON-safe map.
Map<String, dynamic> encodeMetadata(PdfMetadata m) => {
  'title': m.title,
  'author': m.author,
  'subject': m.subject,
  'keywords': m.keywords,
  'creator': m.creator,
  'producer': m.producer,
  'creationDate': encodeDate(m.creationDate),
  'modDate': encodeDate(m.modDate),
};

/// Decodes a [PdfMetadata] from its wire map.
PdfMetadata decodeMetadata(Map<String, dynamic> j) => PdfMetadata(
  title: j['title'] as String?,
  author: j['author'] as String?,
  subject: j['subject'] as String?,
  keywords: j['keywords'] as String?,
  creator: j['creator'] as String?,
  producer: j['producer'] as String?,
  creationDate: decodeDate(j['creationDate']),
  modDate: decodeDate(j['modDate']),
);

/// Encodes a [PdfDocumentInfo] to a JSON-safe map.
///
/// File identifiers are typically 16 bytes, small enough to encode as plain
/// JSON integer arrays directly (unlike the multi-megabyte bitmap payloads
/// elsewhere in this file, which use the out-of-band buffer-index scheme).
Map<String, dynamic> encodeDocumentInfo(PdfDocumentInfo d) => {
  'fileVersion': d.fileVersion,
  'permanentId': d.permanentId,
  'changingId': d.changingId,
};

/// Decodes a [PdfDocumentInfo] from its wire map.
PdfDocumentInfo decodeDocumentInfo(Map<String, dynamic> j) => PdfDocumentInfo(
  fileVersion: j['fileVersion'] as int?,
  permanentId: j['permanentId'] == null
      ? null
      : Uint8List.fromList((j['permanentId'] as List).cast<int>()),
  changingId: j['changingId'] == null
      ? null
      : Uint8List.fromList((j['changingId'] as List).cast<int>()),
);

/// Encodes a [PdfPageSize] to a JSON-safe map.
Map<String, dynamic> encodePageSize(PdfPageSize s) => {
  'widthPt': s.widthPt,
  'heightPt': s.heightPt,
};

/// Decodes a [PdfPageSize] from its wire map.
PdfPageSize decodePageSize(Map<String, dynamic> j) => PdfPageSize(
  widthPt: (j['widthPt'] as num).toDouble(),
  heightPt: (j['heightPt'] as num).toDouble(),
);

/// Encodes a [PdfPageText] to a JSON-safe map.
Map<String, dynamic> encodePageText(PdfPageText t) => {
  'pageIndex': t.pageIndex,
  'text': t.text,
  'hasUnicodeErrors': t.hasUnicodeErrors,
  'hasTextLayer': t.hasTextLayer,
};

/// Decodes a [PdfPageText] from its wire map.
PdfPageText decodePageText(Map<String, dynamic> j) => PdfPageText(
  pageIndex: j['pageIndex'] as int,
  text: j['text'] as String,
  hasUnicodeErrors: j['hasUnicodeErrors'] as bool,
  hasTextLayer: j['hasTextLayer'] as bool,
);

/// Encodes a [PdfSearchMatch] to a JSON-safe map.
Map<String, dynamic> encodeSearchMatch(PdfSearchMatch m) => {
  'pageIndex': m.pageIndex,
  'charIndex': m.charIndex,
  'charCount': m.charCount,
  'rects': m.rects.map(encodeRect).toList(),
};

/// Decodes a [PdfSearchMatch] from its wire map.
PdfSearchMatch decodeSearchMatch(Map<String, dynamic> j) => PdfSearchMatch(
  pageIndex: j['pageIndex'] as int,
  charIndex: j['charIndex'] as int,
  charCount: j['charCount'] as int,
  rects: (j['rects'] as List)
      .map((e) => decodeRect((e as Map).cast()))
      .toList(),
);

/// Encodes a [PdfTocEntry] (recursively) to a JSON-safe map.
Map<String, dynamic> encodeTocEntry(PdfTocEntry e) => {
  'title': e.title,
  'pageIndex': e.pageIndex,
  'uri': e.uri,
  'scrollPosition': e.scrollPosition == null
      ? null
      : encodePoint(e.scrollPosition!),
  'children': e.children.map(encodeTocEntry).toList(),
};

/// Decodes a [PdfTocEntry] (recursively) from its wire map.
PdfTocEntry decodeTocEntry(Map<String, dynamic> j) => PdfTocEntry(
  title: j['title'] as String,
  pageIndex: j['pageIndex'] as int?,
  uri: j['uri'] as String?,
  scrollPosition: j['scrollPosition'] == null
      ? null
      : decodePoint((j['scrollPosition'] as Map).cast()),
  children: (j['children'] as List)
      .map((e) => decodeTocEntry((e as Map).cast()))
      .toList(),
);

/// Encodes a [PdfImageMetadata] to a JSON-safe map.
Map<String, dynamic> encodeImageMetadata(PdfImageMetadata m) => {
  'width': m.width,
  'height': m.height,
  'horizontalDpi': m.horizontalDpi,
  'verticalDpi': m.verticalDpi,
  'bitsPerPixel': m.bitsPerPixel,
  'colorspace': m.colorspace.name,
  'markedContentId': m.markedContentId,
};

/// Decodes a [PdfImageMetadata] from its wire map.
PdfImageMetadata decodeImageMetadata(Map<String, dynamic> j) =>
    PdfImageMetadata(
      width: j['width'] as int,
      height: j['height'] as int,
      horizontalDpi: (j['horizontalDpi'] as num).toDouble(),
      verticalDpi: (j['verticalDpi'] as num).toDouble(),
      bitsPerPixel: j['bitsPerPixel'] as int,
      colorspace: PdfColorspace.values.byName(j['colorspace'] as String),
      markedContentId: j['markedContentId'] as int,
    );

// =============================================================================
// Annotation (de)serialisation — sealed hierarchy with a `kind` discriminator
// =============================================================================

Map<String, dynamic> _commonAnnotationFields(PdfAnnotation a) => {
  'pageIndex': a.pageIndex,
  'contents': a.contents,
  'author': a.author,
  'rect': a.rect == null ? null : encodeRect(a.rect!),
  'color': a.color == null ? null : encodeColor(a.color!),
  'modifiedDate': encodeDate(a.modifiedDate),
  'flags': a.flags,
  'popup': a.popup == null ? null : encodePopup(a.popup!),
};

({
  int pageIndex,
  String? contents,
  String? author,
  PdfRect? rect,
  PdfColor? color,
  PdfDate? modifiedDate,
  int flags,
  PdfPopupAnnotation? popup,
})
_decodeCommonAnnotationFields(Map<String, dynamic> j) => (
  pageIndex: j['pageIndex'] as int,
  contents: j['contents'] as String?,
  author: j['author'] as String?,
  rect: j['rect'] == null ? null : decodeRect((j['rect'] as Map).cast()),
  color: j['color'] == null ? null : decodeColor((j['color'] as Map).cast()),
  modifiedDate: decodeDate(j['modifiedDate']),
  flags: j['flags'] as int,
  popup: j['popup'] == null ? null : decodePopup((j['popup'] as Map).cast()),
);

/// Encodes a [PdfAnnotation] (any concrete subtype) to a JSON-safe map.
///
/// A `kind` discriminator field identifies the concrete subtype so
/// [decodeAnnotation] can reconstruct it.
Map<String, dynamic> encodeAnnotation(PdfAnnotation a) {
  final common = _commonAnnotationFields(a);
  return switch (a) {
    PdfTextAnnotation() => {...common, 'kind': 'text'},
    PdfFreeTextAnnotation() => {...common, 'kind': 'freeText'},
    PdfMarkupAnnotation m => {
      ...common,
      'kind': 'markup',
      'subtype': m.subtype.name,
      'quadPoints': m.quadPoints.map(encodeQuadPoints).toList(),
      'markedText': m.markedText,
    },
    PdfShapeAnnotation s => {
      ...common,
      'kind': 'shape',
      'subtype': s.subtype.name,
      'interiorColor': s.interiorColor == null
          ? null
          : encodeColor(s.interiorColor!),
    },
    PdfLineAnnotation l => {
      ...common,
      'kind': 'line',
      'lineStart': encodePoint(l.lineStart),
      'lineEnd': encodePoint(l.lineEnd),
    },
    PdfInkAnnotation ink => {
      ...common,
      'kind': 'ink',
      'strokes': ink.strokes
          .map((stroke) => stroke.map(encodePoint).toList())
          .toList(),
    },
    PdfPolygonAnnotation p => {
      ...common,
      'kind': 'polygon',
      'subtype': p.subtype.name,
      'vertices': p.vertices.map(encodePoint).toList(),
    },
    PdfLinkAnnotation l => {...common, 'kind': 'link', 'uri': l.uri},
    PdfStampAnnotation() => {...common, 'kind': 'stamp'},
    PdfUnknownAnnotation u => {
      ...common,
      'kind': 'unknown',
      'rawSubtype': u.rawSubtype,
    },
  };
}

/// Decodes a [PdfAnnotation] from its wire map, dispatching on the `kind`
/// discriminator written by [encodeAnnotation].
PdfAnnotation decodeAnnotation(Map<String, dynamic> j) {
  final c = _decodeCommonAnnotationFields(j);
  switch (j['kind'] as String) {
    case 'text':
      return PdfTextAnnotation(
        pageIndex: c.pageIndex,
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'freeText':
      return PdfFreeTextAnnotation(
        pageIndex: c.pageIndex,
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'markup':
      return PdfMarkupAnnotation(
        pageIndex: c.pageIndex,
        subtype: PdfAnnotationType.values.byName(j['subtype'] as String),
        quadPoints: (j['quadPoints'] as List)
            .map((e) => decodeQuadPoints((e as Map).cast()))
            .toList(),
        markedText: j['markedText'] as String?,
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'shape':
      return PdfShapeAnnotation(
        pageIndex: c.pageIndex,
        subtype: PdfAnnotationType.values.byName(j['subtype'] as String),
        interiorColor: j['interiorColor'] == null
            ? null
            : decodeColor((j['interiorColor'] as Map).cast()),
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'line':
      return PdfLineAnnotation(
        pageIndex: c.pageIndex,
        lineStart: decodePoint((j['lineStart'] as Map).cast()),
        lineEnd: decodePoint((j['lineEnd'] as Map).cast()),
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'ink':
      return PdfInkAnnotation(
        pageIndex: c.pageIndex,
        strokes: (j['strokes'] as List)
            .map(
              (stroke) => (stroke as List)
                  .map((p) => decodePoint((p as Map).cast()))
                  .toList(),
            )
            .toList(),
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'polygon':
      return PdfPolygonAnnotation(
        pageIndex: c.pageIndex,
        subtype: PdfAnnotationType.values.byName(j['subtype'] as String),
        vertices: (j['vertices'] as List)
            .map((e) => decodePoint((e as Map).cast()))
            .toList(),
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'link':
      return PdfLinkAnnotation(
        pageIndex: c.pageIndex,
        uri: j['uri'] as String?,
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'stamp':
      return PdfStampAnnotation(
        pageIndex: c.pageIndex,
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    case 'unknown':
      return PdfUnknownAnnotation(
        pageIndex: c.pageIndex,
        rawSubtype: j['rawSubtype'] as int,
        contents: c.contents,
        author: c.author,
        rect: c.rect,
        color: c.color,
        modifiedDate: c.modifiedDate,
        flags: c.flags,
        popup: c.popup,
      );
    default:
      throw PdfiumException('Unknown wire annotation kind: ${j['kind']}');
  }
}

/// Encodes a [PdfPageAnnotations] to a JSON-safe map.
Map<String, dynamic> encodePageAnnotations(PdfPageAnnotations pa) => {
  'pageIndex': pa.pageIndex,
  'annotations': pa.annotations.map(encodeAnnotation).toList(),
};

/// Decodes a [PdfPageAnnotations] from its wire map.
PdfPageAnnotations decodePageAnnotations(Map<String, dynamic> j) =>
    PdfPageAnnotations(
      pageIndex: j['pageIndex'] as int,
      annotations: (j['annotations'] as List)
          .map((e) => decodeAnnotation((e as Map).cast()))
          .toList(),
    );

// =============================================================================
// Buffer-bearing (de)serialisation — bitmaps
// =============================================================================

/// Encodes a [PdfImage] to a JSON-safe map, appending [img.bgra] (if
/// non-null) to [buffers] and referencing it via `bufIndex`.
Map<String, dynamic> encodeImage(PdfImage img, List<Uint8List> buffers) {
  int? bufIndex;
  if (img.bgra != null) {
    buffers.add(img.bgra!);
    bufIndex = buffers.length - 1;
  }
  return {
    'pageIndex': img.pageIndex,
    'objectIndex': img.objectIndex,
    'metadata': encodeImageMetadata(img.metadata),
    'bounds': encodeRect(img.bounds),
    'filters': img.filters,
    'bufIndex': bufIndex,
    'bitmapWidth': img.bitmapWidth,
    'bitmapHeight': img.bitmapHeight,
  };
}

/// Decodes a [PdfImage] from its wire map, resolving `bufIndex` against
/// [buffers] when present.
PdfImage decodeImage(Map<String, dynamic> j, List<Uint8List> buffers) {
  final bufIndex = j['bufIndex'] as int?;
  return PdfImage(
    pageIndex: j['pageIndex'] as int,
    objectIndex: j['objectIndex'] as int,
    metadata: decodeImageMetadata((j['metadata'] as Map).cast()),
    bounds: decodeRect((j['bounds'] as Map).cast()),
    filters: (j['filters'] as List).cast<String>(),
    bgra: bufIndex == null ? null : buffers[bufIndex],
    bitmapWidth: j['bitmapWidth'] as int?,
    bitmapHeight: j['bitmapHeight'] as int?,
  );
}

/// Encodes a [PdfPageImages] to a JSON-safe map, threading [buffers] through
/// each contained [PdfImage].
Map<String, dynamic> encodePageImages(
  PdfPageImages pi,
  List<Uint8List> buffers,
) => {
  'pageIndex': pi.pageIndex,
  'images': pi.images.map((i) => encodeImage(i, buffers)).toList(),
};

/// Decodes a [PdfPageImages] from its wire map.
PdfPageImages decodePageImages(
  Map<String, dynamic> j,
  List<Uint8List> buffers,
) => PdfPageImages(
  pageIndex: j['pageIndex'] as int,
  images: (j['images'] as List)
      .map((e) => decodeImage((e as Map).cast(), buffers))
      .toList(),
);

/// Encodes a [PdfThumbnail] to a JSON-safe map, appending [t.bgra] to
/// [buffers].
Map<String, dynamic> encodeThumbnail(PdfThumbnail t, List<Uint8List> buffers) {
  buffers.add(t.bgra);
  return {
    'bufIndex': buffers.length - 1,
    'width': t.width,
    'height': t.height,
    'source': t.source.name,
  };
}

/// Decodes a [PdfThumbnail] from its wire map.
PdfThumbnail decodeThumbnail(Map<String, dynamic> j, List<Uint8List> buffers) =>
    PdfThumbnail(
      bgra: buffers[j['bufIndex'] as int],
      width: j['width'] as int,
      height: j['height'] as int,
      source: PdfThumbnailSource.values.byName(j['source'] as String),
    );

/// Encodes a [PdfImageBitmap] to a JSON-safe map, appending [b.bgra] to
/// [buffers].
Map<String, dynamic> encodeImageBitmap(
  PdfImageBitmap b,
  List<Uint8List> buffers,
) {
  buffers.add(b.bgra);
  return {'bufIndex': buffers.length - 1, 'width': b.width, 'height': b.height};
}

/// Decodes a [PdfImageBitmap] from its wire map.
PdfImageBitmap decodeImageBitmap(
  Map<String, dynamic> j,
  List<Uint8List> buffers,
) => PdfImageBitmap(
  bgra: buffers[j['bufIndex'] as int],
  width: j['width'] as int,
  height: j['height'] as int,
);

/// Encodes a page-render result record to a JSON-safe map, appending
/// [pixels] to [buffers].
Map<String, dynamic> encodeRenderResult(
  ({Uint8List pixels, int pixelWidth, int pixelHeight}) r,
  List<Uint8List> buffers,
) {
  buffers.add(r.pixels);
  return {
    'bufIndex': buffers.length - 1,
    'pixelWidth': r.pixelWidth,
    'pixelHeight': r.pixelHeight,
  };
}

/// Decodes a page-render result record from its wire map.
({Uint8List pixels, int pixelWidth, int pixelHeight}) decodeRenderResult(
  Map<String, dynamic> j,
  List<Uint8List> buffers,
) => (
  pixels: buffers[j['bufIndex'] as int],
  pixelWidth: j['pixelWidth'] as int,
  pixelHeight: j['pixelHeight'] as int,
);
