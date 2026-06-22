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

/// The intrinsic size of a PDF page, measured in PDF user units (points).
///
/// One PDF user unit equals 1/72 inch. This is a storage-level measurement
/// independent of any rendering resolution. Use [sizeForDpi] to convert to
/// pixel dimensions at a target DPI for rendering.
///
/// ## Example
///
/// ```dart
/// final size = await doc.getPageSize(0);
/// // Convert to pixels at 150 DPI:
/// final pixelSize = size.sizeForDpi(150);
/// final image = await doc.renderPage(
///   0,
///   pixelSize.width.round(),
///   pixelSize.height.round(),
/// );
/// ```
class PdfPageSize {
  /// Creates a [PdfPageSize] with the given [widthPt] and [heightPt] in points.
  ///
  /// Both values must be positive. A value of zero or negative indicates a
  /// malformed page in the PDF; callers should guard against this before
  /// passing dimensions to [renderPage].
  const PdfPageSize({required this.widthPt, required this.heightPt});

  /// The page width in PDF user units (points, 1/72 inch).
  final double widthPt;

  /// The page height in PDF user units (points, 1/72 inch).
  final double heightPt;

  /// The aspect ratio of the page (width / height).
  ///
  /// Returns `1.0` when [heightPt] is zero to avoid division-by-zero on
  /// malformed pages. Callers should still guard against zero-sized pages
  /// before rendering.
  double get aspectRatio => heightPt > 0 ? widthPt / heightPt : 1.0;

  /// Returns the page size in pixels at the given [dpi] as a named record.
  ///
  /// Multiply [widthPt] and [heightPt] (both in points, 1/72 inch) by
  /// [dpi] / 72 to obtain pixel dimensions suitable for passing to
  /// [PdfDocument.renderPage].
  ///
  /// Example: an A4 page (595 × 842 pt) at 150 DPI yields
  /// approximately 1239 × 1754 pixels.
  ///
  /// [dpi] must be positive. Returns `(width: 0.0, height: 0.0)` when [dpi]
  /// is zero or negative.
  ({double width, double height}) sizeForDpi(double dpi) {
    if (dpi <= 0) return (width: 0.0, height: 0.0);
    final scale = dpi / 72.0;
    return (width: widthPt * scale, height: heightPt * scale);
  }

  @override
  String toString() => 'PdfPageSize(widthPt: $widthPt, heightPt: $heightPt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPageSize &&
          other.widthPt == widthPt &&
          other.heightPt == heightPt;

  @override
  int get hashCode => Object.hash(widthPt, heightPt);
}
