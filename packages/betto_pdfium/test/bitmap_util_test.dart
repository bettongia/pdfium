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

// Unit tests for the stripBitmapStride helper in _bitmap_utils.dart.
//
// stripBitmapStride is a shared utility used by both the native (FFI) and web
// (WASM) backends to strip PDFium bitmap row-padding before returning the
// pixel buffer to the caller. The tests exercise:
//   - Fast path: stride == width * 4 (no padding, direct copy).
//   - Slow path: stride > width * 4 (padding present, row-by-row copy).
//   - Output length is always exactly width * height * 4.
//   - Non-zero padding bytes are NOT copied into the output.
//   - Row order is preserved.
//   - Single-row and single-pixel edge cases.

import 'dart:typed_data';

import 'package:betto_pdfium/src/document/_bitmap_utils.dart'
    show convertBitmapToCompactBgra, stripBitmapStride;
import 'package:test/test.dart';

void main() {
  group('stripBitmapStride', () {
    // -------------------------------------------------------------------------
    // Fast path (stride == width * 4)
    // -------------------------------------------------------------------------

    test(
      'fast path: stride == width * 4 returns a copy of the full buffer',
      () {
        // 2×2 BGRA image, no padding: stride = 2 * 4 = 8.
        final src = Uint8List.fromList([
          // row 0
          1, 2, 3, 4, 5, 6, 7, 8,
          // row 1
          9, 10, 11, 12, 13, 14, 15, 16,
        ]);
        final result = stripBitmapStride(src, 2, 2, 8);
        expect(result.length, equals(2 * 2 * 4));
        expect(result, equals(src));
      },
    );

    test('fast path: result is a copy, not the same instance', () {
      final src = Uint8List.fromList(List.generate(16, (i) => i));
      final result = stripBitmapStride(src, 2, 2, 8);
      expect(identical(result, src), isFalse);
    });

    // -------------------------------------------------------------------------
    // Slow path (stride > width * 4)
    // -------------------------------------------------------------------------

    test('slow path: output length is width * height * 4', () {
      // 3 pixels wide, 2 rows, stride = 16 (3*4=12 pixel bytes + 4 pad bytes).
      const width = 3;
      const height = 2;
      const stride = 16;
      final src = Uint8List(stride * height); // all zeros
      final result = stripBitmapStride(src, width, height, stride);
      expect(result.length, equals(width * height * 4));
    });

    test('slow path: padding bytes are not copied into output', () {
      // 1 pixel wide, 2 rows, stride = 8 (1*4=4 pixel bytes + 4 pad bytes).
      // Padding bytes are set to 0xFF to prove they are NOT copied.
      const width = 1;
      const height = 2;
      const stride = 8;
      const pixelBytes = width * 4;
      final src = Uint8List(stride * height);
      // Row 0 pixel: B=10, G=20, R=30, A=40
      src[0] = 10;
      src[1] = 20;
      src[2] = 30;
      src[3] = 40;
      // Row 0 padding: 0xFF (sentinel to verify not copied).
      src[4] = 0xFF;
      src[5] = 0xFF;
      src[6] = 0xFF;
      src[7] = 0xFF;
      // Row 1 pixel: B=50, G=60, R=70, A=80
      src[8] = 50;
      src[9] = 60;
      src[10] = 70;
      src[11] = 80;
      // Row 1 padding: 0xFF
      src[12] = 0xFF;
      src[13] = 0xFF;
      src[14] = 0xFF;
      src[15] = 0xFF;

      final result = stripBitmapStride(src, width, height, stride);

      expect(result.length, equals(width * height * 4));
      // Row 0 pixels preserved.
      expect(result.sublist(0, pixelBytes), equals([10, 20, 30, 40]));
      // Row 1 pixels preserved.
      expect(
        result.sublist(pixelBytes, pixelBytes * 2),
        equals([50, 60, 70, 80]),
      );
      // No 0xFF sentinel values in the output.
      expect(result.contains(0xFF), isFalse);
    });

    test('slow path: row order is preserved', () {
      // 2 pixels wide, 3 rows, stride = 12 (2*4=8 pixel bytes + 4 pad bytes).
      const width = 2;
      const height = 3;
      const stride = 12;
      final src = Uint8List(stride * height);

      // Fill each row's pixel area with a distinct byte value: row 0 = 0x11,
      // row 1 = 0x22, row 2 = 0x33. Padding bytes = 0xFF.
      for (var row = 0; row < height; row++) {
        final base = row * stride;
        final marker = (row + 1) * 0x11;
        for (var col = 0; col < width * 4; col++) {
          src[base + col] = marker;
        }
        // Padding bytes.
        src[base + width * 4] = 0xFF;
        src[base + width * 4 + 1] = 0xFF;
        src[base + width * 4 + 2] = 0xFF;
        src[base + width * 4 + 3] = 0xFF;
      }

      final result = stripBitmapStride(src, width, height, stride);
      const rowBytes = width * 4;

      for (var row = 0; row < height; row++) {
        final expected = (row + 1) * 0x11;
        for (var b = 0; b < rowBytes; b++) {
          expect(
            result[row * rowBytes + b],
            equals(expected),
            reason:
                'row $row byte $b should be 0x${expected.toRadixString(16)}',
          );
        }
      }
    });

    // -------------------------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------------------------

    test('single pixel, no padding', () {
      final src = Uint8List.fromList([10, 20, 30, 40]);
      final result = stripBitmapStride(src, 1, 1, 4);
      expect(result, equals([10, 20, 30, 40]));
    });

    test('single pixel with padding', () {
      // stride = 8, pixel width = 1 → 4 pixel bytes + 4 pad bytes.
      final src = Uint8List.fromList([10, 20, 30, 40, 0xFF, 0xFF, 0xFF, 0xFF]);
      final result = stripBitmapStride(src, 1, 1, 8);
      expect(result.length, equals(4));
      expect(result, equals([10, 20, 30, 40]));
    });

    test(
      'off-by-one: non-zero padding byte at first padding position is dropped',
      () {
        // 1 pixel wide, 1 row, stride = 5 (4 pixel + 1 pad byte).
        // Verifies the row slice uses exactly `width * 4` bytes, not `stride`.
        final src = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD, 0xEE]);
        final result = stripBitmapStride(src, 1, 1, 5);
        expect(result.length, equals(4));
        expect(result, equals([0xAA, 0xBB, 0xCC, 0xDD]));
        expect(result.contains(0xEE), isFalse);
      },
    );
  });

  group('convertBitmapToCompactBgra', () {
    // -------------------------------------------------------------------------
    // BGRA (format 4)
    // -------------------------------------------------------------------------

    test('BGRA: copies alpha directly and strips padding', () {
      // 1 pixel wide, 2 rows, stride = 8 (4 pixel bytes + 4 pad bytes).
      final src = Uint8List.fromList([
        10, 20, 30, 40, 0xFF, 0xFF, 0xFF, 0xFF, // row 0 + padding
        50, 60, 70, 80, 0xFF, 0xFF, 0xFF, 0xFF, // row 1 + padding
      ]);
      final result = convertBitmapToCompactBgra(src, 1, 2, 8, 4);
      expect(result, isNotNull);
      expect(result!.length, equals(1 * 2 * 4));
      expect(result, equals([10, 20, 30, 40, 50, 60, 70, 80]));
    });

    // -------------------------------------------------------------------------
    // BGRx (format 3) — 4 bytes/px, 4th byte replaced with 0xFF
    // -------------------------------------------------------------------------

    test('BGRx: 4th source byte is replaced with 0xFF alpha', () {
      // 1 pixel wide, 1 row: B=10, G=20, R=30, x=0x00 (should become 0xFF).
      final src = Uint8List.fromList([10, 20, 30, 0]);
      final result = convertBitmapToCompactBgra(src, 1, 1, 4, 3);
      expect(result, equals([10, 20, 30, 0xFF]));
    });

    // -------------------------------------------------------------------------
    // BGR (format 2) — 3 bytes/px, expanded to BGRA with 0xFF alpha
    // -------------------------------------------------------------------------

    test('BGR: expands 3 bytes/px to 4 bytes/px with 0xFF alpha', () {
      // 2 pixels wide, 1 row, stride = 6 (2 * 3 bytes/px, no padding).
      final src = Uint8List.fromList([10, 20, 30, 40, 50, 60]);
      final result = convertBitmapToCompactBgra(src, 2, 1, 6, 2);
      expect(result, equals([10, 20, 30, 0xFF, 40, 50, 60, 0xFF]));
    });

    // -------------------------------------------------------------------------
    // srcOffset — web backend reads from an absolute WASM heap address
    // -------------------------------------------------------------------------

    test('srcOffset: reads the bitmap starting at a non-zero offset', () {
      // Simulates a WASM heap where the bitmap buffer starts at byte 100.
      // 1 pixel wide, stride = 8 (4 pixel bytes + 4 padding bytes per row).
      final heap = Uint8List(116);
      heap.setRange(100, 116, [
        10, 20, 30, 40, 0xFF, 0xFF, 0xFF, 0xFF, // row 0 + padding
        50, 60, 70, 80, 0xFF, 0xFF, 0xFF, 0xFF, // row 1 + padding
      ]);
      final result = convertBitmapToCompactBgra(
        heap,
        1,
        2,
        8,
        4,
        srcOffset: 100,
      );
      expect(result, equals([10, 20, 30, 40, 50, 60, 70, 80]));
    });

    // -------------------------------------------------------------------------
    // Unsupported format
    // -------------------------------------------------------------------------

    test('unsupported format returns null', () {
      final src = Uint8List(16);
      expect(convertBitmapToCompactBgra(src, 2, 2, 8, 1), isNull);
      expect(convertBitmapToCompactBgra(src, 2, 2, 8, 0), isNull);
    });
  });
}
