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
