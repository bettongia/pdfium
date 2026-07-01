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

// Shared bitmap utility functions for the betto_pdfium native and web backends.
//
// This file is intentionally free of dart:ffi, dart:io, dart:isolate, and
// dart:js_interop imports so it can be imported by both _document_native.dart
// (via pdfium_isolate.dart) and _document_web.dart without triggering
// conditional-import conflicts.

import 'dart:typed_data';

/// Copies a PDFium bitmap buffer into a compact BGRA [Uint8List], stripping
/// any row-padding bytes that PDFium may have added for alignment.
///
/// PDFium allocates bitmap rows with alignment padding when `width * 4` is not
/// a multiple of its internal stride requirement. The [stride] parameter is the
/// actual byte width of each row in [src] (obtained via
/// `FPDFBitmap_GetStride`). When `stride == width * 4` there is no padding and
/// the buffer is copied directly. When `stride > width * 4` the slow path
/// copies each row individually to produce a compact output buffer.
///
/// This function is shared by both the native (FFI) and web (WASM) backends:
///
/// - **Native**: [src] comes from `FPDFBitmap_GetBuffer` via an FFI pointer
///   copy into a `Uint8List`.
/// - **Web**: [src] is a `Uint8List` sublist of `Module["HEAPU8"]` sliced at
///   `[bufferPtr, bufferPtr + stride * height)`.
///
/// Parameters:
///   [src]    — raw pixel buffer from `FPDFBitmap_GetBuffer`, length is
///              `stride * height`.
///   [width]  — pixel width of the bitmap.
///   [height] — pixel height of the bitmap.
///   [stride] — byte width of a single row (≥ `width * 4`).
///
/// Returns a [Uint8List] of exactly `width * height * 4` bytes in BGRA order.
///
/// Example:
/// ```dart
/// // After obtaining raw pixels from PDFium (native or WASM):
/// final compact = stripBitmapStride(rawPixels, 800, 600, 3200);
/// // compact.length == 800 * 600 * 4 == 1920000
/// ```
Uint8List stripBitmapStride(Uint8List src, int width, int height, int stride) {
  final expectedStride = width * 4;
  if (stride == expectedStride) {
    // Fast path: no padding — copy the contiguous buffer directly.
    return Uint8List.fromList(src);
  }
  // Slow path: strip row padding so the output is a compact BGRA buffer.
  final dst = Uint8List(width * height * 4);
  for (var row = 0; row < height; row++) {
    final srcOffset = row * stride;
    final dstOffset = row * expectedStride;
    dst.setRange(dstOffset, dstOffset + expectedStride, src, srcOffset);
  }
  return dst;
}

/// Converts a raw PDFium bitmap buffer (BGR, BGRx, or BGRA) into a compact
/// BGRA [Uint8List], expanding non-BGRA source formats and stripping row
/// padding in the same pass.
///
/// [format] is the raw `FPDFBitmap_*` format code: `2` (BGR, 3 bytes/px —
/// expanded to BGRA with alpha forced to `0xFF`), `3` (BGRx, 4 bytes/px whose
/// 4th byte is unused and is replaced with `0xFF`), or `4` (BGRA, 4 bytes/px,
/// copied directly). Returns `null` for any other (unsupported) format so
/// the caller can report or reject it.
///
/// [srcOffset] is the byte offset into [src] where the bitmap buffer begins.
/// Native callers typically pass a [Uint8List] already sized to exactly the
/// bitmap (`srcOffset: 0`, the default); the web backend indexes directly
/// into a shared WASM heap view, so it passes the bitmap's absolute heap
/// address as [srcOffset].
///
/// This function is shared by the native (FFI) and web (WASM) backends'
/// embedded-thumbnail handlers, which are the only call sites where the
/// source format genuinely varies. [stripBitmapStride] remains the right
/// choice for render/image call sites that always request BGRA output.
///
/// Example:
/// ```dart
/// // Embedded thumbnail bitmap reported as BGRx by PDFium:
/// final bgra = convertBitmapToCompactBgra(rawBuffer, 128, 96, 512, 3);
/// // bgra == null only if `format` is not 2, 3, or 4.
/// ```
Uint8List? convertBitmapToCompactBgra(
  Uint8List src,
  int width,
  int height,
  int stride,
  int format, {
  int srcOffset = 0,
}) {
  final int srcBytesPerPixel;
  switch (format) {
    case 4: // BGRA
      srcBytesPerPixel = 4;
      break;
    case 3: // BGRx — no alpha channel; replace with 0xFF.
      srcBytesPerPixel = 4;
      break;
    case 2: // BGR — expand to BGRA by appending 0xFF alpha.
      srcBytesPerPixel = 3;
      break;
    default:
      return null;
  }

  final bgra = Uint8List(width * height * 4);
  for (var row = 0; row < height; row++) {
    final srcRowBase = srcOffset + row * stride;
    final dstRowBase = row * width * 4;
    for (var col = 0; col < width; col++) {
      final srcOff = srcRowBase + col * srcBytesPerPixel;
      final dstOff = dstRowBase + col * 4;
      bgra[dstOff] = src[srcOff]; // B
      bgra[dstOff + 1] = src[srcOff + 1]; // G
      bgra[dstOff + 2] = src[srcOff + 2]; // R
      bgra[dstOff + 3] = (format == 4) ? src[srcOff + 3] : 0xFF; // A
    }
  }
  return bgra;
}
