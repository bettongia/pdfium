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

// Shared types for PDF document handling. These types have no platform
// dependencies and are used by both the native (dart:ffi) and web (WASM)
// backends. They represent the public API surface for metadata and error
// handling.

import 'dart:typed_data';

// Compares two lists for deep equality using element-wise [==].
//
// Dart's built-in List equality is reference equality, so callers that hold
// separate list instances with identical content would compare unequal without
// this helper. Used by annotation types that carry [List] fields.
bool _listEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Errors that can occur during PDF document operations.
enum PdfError {
  /// The document bytes are corrupt, not a valid PDF, or otherwise unloadable.
  invalidDocument,

  /// The document is password-protected. Passwords are not supported in v1;
  /// the caller should inform the user why the file could not be opened.
  passwordRequired,
}

/// Thrown when a PDF operation fails.
///
/// The [error] field provides the reason for the failure. Callers should
/// handle [PdfError.passwordRequired] and [PdfError.invalidDocument]
/// separately to give users actionable error messages.
///
/// Example:
/// ```dart
/// try {
///   final doc = await PdfDocument.fromBytes(bytes);
/// } on PdfExtractionException catch (e) {
///   if (e.error == PdfError.passwordRequired) {
///     // prompt user for a password
///   } else {
///     // report a corrupt or invalid file
///   }
/// }
/// ```
class PdfExtractionException implements Exception {
  /// Creates a [PdfExtractionException] with the given [error].
  const PdfExtractionException(this.error);

  /// The reason for the failure.
  final PdfError error;

  @override
  String toString() => 'PdfExtractionException(${error.name})';
}

/// A PDF date value, preserving both the raw string and the parsed [DateTime].
///
/// PDF dates use the format `D:YYYYMMDDHHmmSSOHH'mm'` (where O is +, -, or Z).
/// The `D:` prefix is optional in practice and the string may be truncated.
/// When parsing fails, [value] is `null` but [raw] is always preserved so
/// callers can inspect or log the original string.
class PdfDate {
  /// Creates a [PdfDate] with the given raw string and parsed [DateTime].
  const PdfDate({required this.raw, required this.value});

  /// The raw date string as stored in the PDF Info dictionary.
  ///
  /// This value is always non-empty when the field is present. It follows the
  /// PDF date format `D:YYYYMMDDHHmmSSOHH'mm'` but real-world PDFs may deviate.
  final String raw;

  /// The parsed [DateTime], or `null` if [raw] could not be parsed.
  ///
  /// The returned [DateTime] is always in UTC (offset is converted). When the
  /// raw string contains an invalid or partial date, this field is `null` and
  /// [raw] is preserved for debugging purposes.
  final DateTime? value;

  @override
  String toString() => 'PdfDate(raw: $raw, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfDate && raw == other.raw && value == other.value;

  @override
  int get hashCode => Object.hash(raw, value);
}

/// Metadata extracted from the PDF Info dictionary.
///
/// All fields are nullable; a `null` value means the field was not present in
/// the Info dictionary (as opposed to being present but empty). This mirrors
/// the PDF specification where field presence and field value are distinct states.
///
/// The eight standard Info dictionary fields are: [title], [author], [subject],
/// [keywords], [creator], [producer], [creationDate], and [modDate].
class PdfMetadata {
  /// Creates an immutable [PdfMetadata] value object.
  const PdfMetadata({
    this.title,
    this.author,
    this.subject,
    this.keywords,
    this.creator,
    this.producer,
    this.creationDate,
    this.modDate,
  });

  /// The document title, or `null` if not present.
  final String? title;

  /// The document author, or `null` if not present.
  final String? author;

  /// The document subject or description, or `null` if not present.
  final String? subject;

  /// Comma-separated keywords, or `null` if not present.
  final String? keywords;

  /// The application that created the original document, or `null` if not present.
  final String? creator;

  /// The application that converted the document to PDF, or `null` if not present.
  final String? producer;

  /// The date and time the document was created, or `null` if not present.
  final PdfDate? creationDate;

  /// The date and time the document was last modified, or `null` if not present.
  final PdfDate? modDate;

  @override
  String toString() =>
      'PdfMetadata('
      'title: $title, '
      'author: $author, '
      'subject: $subject, '
      'keywords: $keywords, '
      'creator: $creator, '
      'producer: $producer, '
      'creationDate: $creationDate, '
      'modDate: $modDate'
      ')';
}

// ---------------------------------------------------------------------------
// Text extraction types
// ---------------------------------------------------------------------------

/// The result of plain text extraction for a single PDF page.
///
/// Produced by [PdfDocument.extractPlainText]. Each item in the stream
/// corresponds to one page.
///
/// [hasTextLayer] is the primary signal for whether useful text was extracted.
/// Use [PdfDocument.isPlainTextExtractable] when you need a document-level
/// heuristic rather than per-page signals.
final class PdfPageText {
  /// Creates an immutable [PdfPageText] value.
  const PdfPageText({
    required this.pageIndex,
    required this.text,
    required this.hasUnicodeErrors,
    required this.hasTextLayer,
  });

  /// Zero-based index of the page this result corresponds to.
  final int pageIndex;

  /// The extracted Unicode text for this page.
  ///
  /// Soft hyphens (U+00AD) that appear at line-break positions are stripped
  /// and the surrounding words are joined. When [hasTextLayer] is false
  /// (scanned page), this is an empty string.
  final String text;

  /// True when at least one character on this page had a broken Unicode
  /// mapping (i.e. `FPDFText_HasUnicodeMapError` returned non-zero for it).
  ///
  /// Such characters are silently omitted from [text] by PDFium. This flag
  /// warns callers that the extracted text may be incomplete.
  final bool hasUnicodeErrors;

  /// True when PDFium extracted at least one character from this page.
  ///
  /// False indicates a scanned or image-only page with no text layer; [text]
  /// will be an empty string in that case.
  final bool hasTextLayer;

  @override
  String toString() =>
      'PdfPageText('
      'pageIndex: $pageIndex, '
      'hasTextLayer: $hasTextLayer, '
      'hasUnicodeErrors: $hasUnicodeErrors, '
      'text: ${text.length > 40 ? '${text.substring(0, 40)}…' : text}'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPageText &&
          pageIndex == other.pageIndex &&
          text == other.text &&
          hasUnicodeErrors == other.hasUnicodeErrors &&
          hasTextLayer == other.hasTextLayer;

  @override
  int get hashCode =>
      Object.hash(pageIndex, text, hasUnicodeErrors, hasTextLayer);
}

/// Configuration for text extraction heuristics.
///
/// [scannedPageRatio] affects [PdfDocument.isPlainTextExtractable].
/// [PdfPageText.hasTextLayer] is always determined by whether PDFium can
/// extract any characters from the page — no configuration is needed.
final class PdfTextExtractorConfig {
  /// Creates a [PdfTextExtractorConfig].
  ///
  /// [scannedPageRatio] must be > 0 and ≤ 1.
  const PdfTextExtractorConfig({this.scannedPageRatio = 0.5})
    : assert(
        scannedPageRatio > 0 && scannedPageRatio <= 1,
        'scannedPageRatio must be > 0 and <= 1',
      );

  /// Fraction of pages that must have no text layer for
  /// [PdfDocument.isPlainTextExtractable] to return false. Default: 0.5.
  ///
  /// A value of 0.5 means a document is only considered predominantly scanned
  /// when more than half its pages yield no characters from PDFium. A single
  /// image or figure page in an otherwise text-based document will not trigger
  /// this flag.
  final double scannedPageRatio;

  @override
  String toString() =>
      'PdfTextExtractorConfig(scannedPageRatio: $scannedPageRatio)';
}

// ---------------------------------------------------------------------------
// Annotation types
// ---------------------------------------------------------------------------

/// The subtype of a PDF annotation, corresponding to the `fpdf_annot.h`
/// `FPDF_ANNOT_*` constants.
///
/// Only subtypes that are in scope for v0.02 are listed; form-field types
/// (`FPDF_ANNOT_WIDGET`, `FPDF_ANNOT_XFAWIDGET`) are out of scope and are
/// mapped to [unknown]. See `docs/spec/annotation_extraction.md` for details.
enum PdfAnnotationType {
  /// Sticky note annotation (`FPDF_ANNOT_TEXT = 1`).
  text,

  /// Hyperlink annotation (`FPDF_ANNOT_LINK = 2`).
  link,

  /// Free-text (typewriter) annotation (`FPDF_ANNOT_FREETEXT = 3`).
  freeText,

  /// Line annotation (`FPDF_ANNOT_LINE = 4`).
  line,

  /// Rectangle annotation (`FPDF_ANNOT_SQUARE = 5`).
  square,

  /// Ellipse annotation (`FPDF_ANNOT_CIRCLE = 6`).
  circle,

  /// Polygon annotation (`FPDF_ANNOT_POLYGON = 7`).
  polygon,

  /// Polyline annotation (`FPDF_ANNOT_POLYLINE = 8`).
  polyline,

  /// Highlight annotation (`FPDF_ANNOT_HIGHLIGHT = 9`).
  highlight,

  /// Underline annotation (`FPDF_ANNOT_UNDERLINE = 10`).
  underline,

  /// Squiggly underline annotation (`FPDF_ANNOT_SQUIGGLY = 11`).
  squiggly,

  /// Strikeout annotation (`FPDF_ANNOT_STRIKEOUT = 12`).
  strikeout,

  /// Rubber stamp annotation (`FPDF_ANNOT_STAMP = 13`).
  stamp,

  /// Free-draw ink annotation (`FPDF_ANNOT_INK = 15`).
  ink,

  /// Popup annotation (`FPDF_ANNOT_POPUP = 16`). Inlined on parent, not emitted
  /// as a top-level annotation.
  popup,

  /// Any annotation subtype not recognised by this library version.
  unknown,
}

/// An ARGB colour value as extracted from a PDF annotation.
///
/// Component values range from 0 to 255.
final class PdfColor {
  /// Creates a [PdfColor] from its RGBA components.
  const PdfColor({
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  });

  /// Red component, 0–255.
  final int r;

  /// Green component, 0–255.
  final int g;

  /// Blue component, 0–255.
  final int b;

  /// Alpha (opacity) component, 0–255 where 255 is fully opaque.
  final int a;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfColor &&
          r == other.r &&
          g == other.g &&
          b == other.b &&
          a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'PdfColor(r: $r, g: $g, b: $b, a: $a)';
}

/// A bounding rectangle in PDF page coordinates.
///
/// PDFium uses a bottom-left page origin, so [bottom] < [top] in typical
/// usage. Coordinates are in PDF user space units (points).
///
/// Callers that need screen coordinates must apply `FPDF_PageToDevice()` /
/// `FPDF_DeviceToPage()` themselves; this library exposes raw PDF coordinates.
final class PdfRect {
  /// Creates a [PdfRect] from PDF page coordinates.
  const PdfRect({
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
  });

  /// Left edge in PDF user space (lower x value).
  final double left;

  /// Bottom edge in PDF user space (lower y value for bottom-left origin).
  final double bottom;

  /// Right edge in PDF user space (higher x value).
  final double right;

  /// Top edge in PDF user space (higher y value for bottom-left origin).
  final double top;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfRect &&
          left == other.left &&
          bottom == other.bottom &&
          right == other.right &&
          top == other.top;

  @override
  int get hashCode => Object.hash(left, bottom, right, top);

  @override
  String toString() =>
      'PdfRect(left: $left, bottom: $bottom, right: $right, top: $top)';
}

/// A point in PDF page coordinates.
///
/// PDFium uses a bottom-left page origin. Coordinates are in PDF user space
/// units (points).
final class PdfPoint {
  /// Creates a [PdfPoint] at the given [x] and [y] coordinates.
  const PdfPoint({required this.x, required this.y});

  /// The x coordinate in PDF user space.
  final double x;

  /// The y coordinate in PDF user space.
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PdfPoint(x: $x, y: $y)';
}

/// A set of four corner points defining one quadrilateral region.
///
/// Used for text markup annotations (highlight, underline, squiggly,
/// strikeout) to describe the precise area of marked-up text, which may not
/// be axis-aligned. Points are ordered: top-left, top-right, bottom-left,
/// bottom-right (following the PDF specification quad-point ordering).
final class PdfQuadPoints {
  /// Creates a [PdfQuadPoints] from its four corner points.
  const PdfQuadPoints({
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
  });

  /// First point (top-left of the quadrilateral).
  final PdfPoint p1;

  /// Second point (top-right of the quadrilateral).
  final PdfPoint p2;

  /// Third point (bottom-left of the quadrilateral).
  final PdfPoint p3;

  /// Fourth point (bottom-right of the quadrilateral).
  final PdfPoint p4;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfQuadPoints &&
          p1 == other.p1 &&
          p2 == other.p2 &&
          p3 == other.p3 &&
          p4 == other.p4;

  @override
  int get hashCode => Object.hash(p1, p2, p3, p4);

  @override
  String toString() => 'PdfQuadPoints(p1: $p1, p2: $p2, p3: $p3, p4: $p4)';
}

/// Popup annotation data inlined onto a parent annotation.
///
/// `FPDF_ANNOT_POPUP` annotations are child annotations of sticky-note and
/// free-text annotations. Rather than exposing them as top-level entries (which
/// would confuse callers), the library inlines their data on the parent
/// annotation as an optional [PdfPopupAnnotation] field.
final class PdfPopupAnnotation {
  /// Creates a [PdfPopupAnnotation].
  const PdfPopupAnnotation({this.rect, required this.flags});

  /// The bounding rectangle of the popup window, or `null` if not available.
  final PdfRect? rect;

  /// Raw `FPDF_ANNOT_FLAG_*` bitmask for the popup annotation.
  final int flags;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPopupAnnotation && rect == other.rect && flags == other.flags;

  @override
  int get hashCode => Object.hash(rect, flags);

  @override
  String toString() => 'PdfPopupAnnotation(rect: $rect, flags: $flags)';
}

/// Base class for all PDF annotation types.
///
/// Use a `switch` expression on the concrete subtype to access type-specific
/// fields:
///
/// ```dart
/// switch (annotation) {
///   PdfMarkupAnnotation(:final quadPoints, :final color) => ...,
///   PdfLinkAnnotation(:final uri) => ...,
///   _ => ...,
/// }
/// ```
///
/// ## Common fields
///
/// Every annotation carries [pageIndex], [flags], and optionally [rect],
/// [color], [contents], [author], and [modifiedDate]. Type-specific fields
/// live only on the appropriate subclass.
///
/// ## Coordinate system
///
/// [rect] is in raw PDF page coordinates (bottom-left origin). Callers that
/// need screen coordinates must apply `FPDF_PageToDevice()` themselves.
sealed class PdfAnnotation {
  /// Creates a [PdfAnnotation] with common fields.
  const PdfAnnotation({
    required this.pageIndex,
    this.contents,
    this.author,
    this.rect,
    this.color,
    this.modifiedDate,
    required this.flags,
    this.popup,
  });

  /// Zero-based index of the page this annotation belongs to.
  final int pageIndex;

  /// The annotation's `Contents` string, or `null` if absent.
  ///
  /// An empty string means the field is present but empty; `null` means the
  /// field is absent. These cases are intentionally distinguishable.
  final String? contents;

  /// The annotation author (`/T` dictionary entry), or `null` if absent.
  final String? author;

  /// The bounding rectangle in PDF page coordinates, or `null` if unavailable.
  final PdfRect? rect;

  /// The annotation colour, or `null` if no colour entry is present.
  final PdfColor? color;

  /// The last-modified date (`/M` dictionary entry), or `null` if absent.
  ///
  /// Parsed via `pdf_date_parser.dart`, consistent with [PdfMetadata.modDate].
  final PdfDate? modifiedDate;

  /// Raw `FPDF_ANNOT_FLAG_*` bitmask.
  ///
  /// See `FPDF_ANNOT_FLAG_HIDDEN`, `FPDF_ANNOT_FLAG_PRINT`, etc.
  final int flags;

  /// Inlined popup annotation data, or `null` if this annotation has no popup.
  ///
  /// Popup annotations (`FPDF_ANNOT_POPUP`) are child annotations of sticky
  /// notes and free-text annotations. They are not emitted as top-level
  /// entries; their data is inlined here instead.
  final PdfPopupAnnotation? popup;
}

/// A sticky note annotation (`FPDF_ANNOT_TEXT`).
///
/// Sticky notes carry [contents], [author], [color], and optionally a [popup].
final class PdfTextAnnotation extends PdfAnnotation {
  /// Creates a [PdfTextAnnotation].
  const PdfTextAnnotation({
    required super.pageIndex,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfTextAnnotation &&
          pageIndex == other.pageIndex &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfTextAnnotation(pageIndex: $pageIndex, contents: $contents, '
      'author: $author, rect: $rect, color: $color, '
      'modifiedDate: $modifiedDate, flags: $flags, popup: $popup)';
}

/// A free-text (typewriter) annotation (`FPDF_ANNOT_FREETEXT`).
final class PdfFreeTextAnnotation extends PdfAnnotation {
  /// Creates a [PdfFreeTextAnnotation].
  const PdfFreeTextAnnotation({
    required super.pageIndex,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfFreeTextAnnotation &&
          pageIndex == other.pageIndex &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfFreeTextAnnotation(pageIndex: $pageIndex, contents: $contents, '
      'author: $author, rect: $rect, color: $color, '
      'modifiedDate: $modifiedDate, flags: $flags, popup: $popup)';
}

/// A text markup annotation: highlight, underline, squiggly, or strikeout.
///
/// The [subtype] field distinguishes the four variants. [quadPoints] describes
/// the exact region(s) of marked-up text; each element corresponds to one
/// quadrilateral covering a line of text.
final class PdfMarkupAnnotation extends PdfAnnotation {
  /// Creates a [PdfMarkupAnnotation].
  const PdfMarkupAnnotation({
    required super.pageIndex,
    required this.subtype,
    required this.quadPoints,
    this.markedText,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  /// The markup subtype: [PdfAnnotationType.highlight], [PdfAnnotationType.underline],
  /// [PdfAnnotationType.squiggly], or [PdfAnnotationType.strikeout].
  final PdfAnnotationType subtype;

  /// Quad-point sets describing the marked-up text regions.
  ///
  /// Each element covers one line of text. An empty list means no quad-points
  /// were found (the bounding [rect] can still be used as a fallback).
  final List<PdfQuadPoints> quadPoints;

  /// The text covered by this markup annotation, extracted from the page's text layer.
  ///
  /// Null when the text page could not be loaded (e.g. the page has no text
  /// layer, as with scanned documents). An empty string means the text layer
  /// exists but no characters fall within the annotated region.
  final String? markedText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfMarkupAnnotation &&
          pageIndex == other.pageIndex &&
          subtype == other.subtype &&
          _listEqual(quadPoints, other.quadPoints) &&
          markedText == other.markedText &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    subtype,
    Object.hashAll(quadPoints),
    markedText,
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfMarkupAnnotation(pageIndex: $pageIndex, subtype: $subtype, '
      'quadPoints: ${quadPoints.length} quads, markedText: $markedText, '
      'contents: $contents, author: $author, color: $color, flags: $flags)';
}

/// A shape annotation: rectangle or ellipse.
///
/// [subtype] is either [PdfAnnotationType.square] (rectangle) or
/// [PdfAnnotationType.circle] (ellipse). [interiorColor] is the fill colour
/// of the shape, distinct from the border [color].
final class PdfShapeAnnotation extends PdfAnnotation {
  /// Creates a [PdfShapeAnnotation].
  const PdfShapeAnnotation({
    required super.pageIndex,
    required this.subtype,
    this.interiorColor,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  /// The shape subtype: [PdfAnnotationType.square] or [PdfAnnotationType.circle].
  final PdfAnnotationType subtype;

  /// The fill (interior) colour, or `null` if not set.
  final PdfColor? interiorColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfShapeAnnotation &&
          pageIndex == other.pageIndex &&
          subtype == other.subtype &&
          interiorColor == other.interiorColor &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    subtype,
    interiorColor,
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfShapeAnnotation(pageIndex: $pageIndex, subtype: $subtype, '
      'interiorColor: $interiorColor, rect: $rect, color: $color, flags: $flags)';
}

/// A line annotation (`FPDF_ANNOT_LINE`).
///
/// The line runs from [lineStart] to [lineEnd] in PDF page coordinates.
final class PdfLineAnnotation extends PdfAnnotation {
  /// Creates a [PdfLineAnnotation].
  const PdfLineAnnotation({
    required super.pageIndex,
    required this.lineStart,
    required this.lineEnd,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  /// The starting point of the line in PDF page coordinates.
  final PdfPoint lineStart;

  /// The ending point of the line in PDF page coordinates.
  final PdfPoint lineEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfLineAnnotation &&
          pageIndex == other.pageIndex &&
          lineStart == other.lineStart &&
          lineEnd == other.lineEnd &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    lineStart,
    lineEnd,
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfLineAnnotation(pageIndex: $pageIndex, lineStart: $lineStart, '
      'lineEnd: $lineEnd, color: $color, flags: $flags)';
}

/// A free-draw ink annotation (`FPDF_ANNOT_INK`).
///
/// [strokes] is a list of strokes; each stroke is a list of [PdfPoint]s
/// forming a continuous path. Multiple strokes represent separate pen-down
/// gestures.
final class PdfInkAnnotation extends PdfAnnotation {
  /// Creates a [PdfInkAnnotation].
  const PdfInkAnnotation({
    required super.pageIndex,
    required this.strokes,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  /// The list of ink strokes. Each inner list is one pen-down gesture.
  ///
  /// An empty outer list means no ink paths could be read (e.g. the annotation
  /// is present but contains no ink data). An inner list may be empty if a
  /// stroke has zero points.
  final List<List<PdfPoint>> strokes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfInkAnnotation &&
          pageIndex == other.pageIndex &&
          _strokesEqual(strokes, other.strokes) &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  /// Deep-equality helper for the nested strokes list.
  static bool _strokesEqual(List<List<PdfPoint>> a, List<List<PdfPoint>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (var j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    pageIndex,
    Object.hashAll(strokes.map(Object.hashAll)),
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfInkAnnotation(pageIndex: $pageIndex, strokes: ${strokes.length}, '
      'color: $color, flags: $flags)';
}

/// A polygon or polyline annotation.
///
/// [subtype] is either [PdfAnnotationType.polygon] or
/// [PdfAnnotationType.polyline]. [vertices] are the corner points.
final class PdfPolygonAnnotation extends PdfAnnotation {
  /// Creates a [PdfPolygonAnnotation].
  const PdfPolygonAnnotation({
    required super.pageIndex,
    required this.subtype,
    required this.vertices,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  /// The polygon/polyline subtype.
  final PdfAnnotationType subtype;

  /// The vertex points of the polygon or polyline, in order.
  final List<PdfPoint> vertices;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPolygonAnnotation &&
          pageIndex == other.pageIndex &&
          subtype == other.subtype &&
          _listEqual(vertices, other.vertices) &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    subtype,
    Object.hashAll(vertices),
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfPolygonAnnotation(pageIndex: $pageIndex, subtype: $subtype, '
      'vertices: ${vertices.length}, color: $color, flags: $flags)';
}

/// A link annotation (`FPDF_ANNOT_LINK`).
///
/// Links carry either a [uri] (for URI actions) or a page destination (not
/// yet exposed — [uri] is `null` for non-URI actions). Callers should check
/// [uri] and filter appropriately; not all links have URI actions.
final class PdfLinkAnnotation extends PdfAnnotation {
  /// Creates a [PdfLinkAnnotation].
  const PdfLinkAnnotation({
    required super.pageIndex,
    this.uri,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  /// The URI target of this link, or `null` if the link does not have a URI
  /// action (e.g. it is a page-destination link or an unsupported action type).
  final String? uri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfLinkAnnotation &&
          pageIndex == other.pageIndex &&
          uri == other.uri &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    uri,
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfLinkAnnotation(pageIndex: $pageIndex, uri: $uri, '
      'rect: $rect, flags: $flags)';
}

/// A rubber stamp annotation (`FPDF_ANNOT_STAMP`).
final class PdfStampAnnotation extends PdfAnnotation {
  /// Creates a [PdfStampAnnotation].
  const PdfStampAnnotation({
    required super.pageIndex,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfStampAnnotation &&
          pageIndex == other.pageIndex &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfStampAnnotation(pageIndex: $pageIndex, contents: $contents, '
      'rect: $rect, flags: $flags)';
}

/// An annotation whose subtype is not recognised by this library version.
///
/// The [rawSubtype] field carries the original `FPDF_ANNOT_*` integer so
/// callers can inspect it for debugging or future-proofing purposes.
final class PdfUnknownAnnotation extends PdfAnnotation {
  /// Creates a [PdfUnknownAnnotation].
  const PdfUnknownAnnotation({
    required super.pageIndex,
    required this.rawSubtype,
    super.contents,
    super.author,
    super.rect,
    super.color,
    super.modifiedDate,
    required super.flags,
    super.popup,
  });

  /// The raw `FPDF_ANNOT_*` integer value that was not recognised.
  final int rawSubtype;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfUnknownAnnotation &&
          pageIndex == other.pageIndex &&
          rawSubtype == other.rawSubtype &&
          contents == other.contents &&
          author == other.author &&
          rect == other.rect &&
          color == other.color &&
          modifiedDate == other.modifiedDate &&
          flags == other.flags &&
          popup == other.popup;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    rawSubtype,
    contents,
    author,
    rect,
    color,
    modifiedDate,
    flags,
    popup,
  );

  @override
  String toString() =>
      'PdfUnknownAnnotation(pageIndex: $pageIndex, rawSubtype: $rawSubtype, '
      'flags: $flags)';
}

/// The annotations extracted from a single PDF page.
///
/// Produced by [PdfDocument.extractAnnotations]. Each item in the stream
/// corresponds to one page. Pages with no annotations emit an entry with an
/// empty [annotations] list, so callers can track page coverage without gaps.
final class PdfPageAnnotations {
  /// Creates an immutable [PdfPageAnnotations] value.
  const PdfPageAnnotations({
    required this.pageIndex,
    required this.annotations,
  });

  /// Zero-based index of the page this result corresponds to.
  final int pageIndex;

  /// The annotations found on this page, in the order returned by PDFium.
  ///
  /// Popup annotations are inlined as [PdfAnnotation.popup] on their parent
  /// and are not present as top-level entries in this list.
  final List<PdfAnnotation> annotations;

  @override
  String toString() =>
      'PdfPageAnnotations(pageIndex: $pageIndex, '
      'annotations: ${annotations.length})';
}

// ---------------------------------------------------------------------------
// Table of contents types
// ---------------------------------------------------------------------------

/// A single entry in the PDF bookmark/outline tree (Table of Contents).
///
/// A PDF's "Outline" dictionary is its native Table of Contents structure.
/// Each entry has a [title], an optional destination ([pageIndex] and
/// [scrollPosition]), and an optional [uri] for URI-action entries.
/// [children] holds any nested sub-entries in the same tree shape.
///
/// ## Destination resolution
///
/// Bookmark destinations are resolved as follows:
/// - If the bookmark has a `PDFACTION_GOTO` action, [pageIndex] is the
///   zero-based page index and [scrollPosition] is the XYZ anchor (if any).
/// - If the bookmark has a `PDFACTION_URI` action, [uri] is the URI string and
///   [pageIndex] is `null`.
/// - If neither a matching action nor a direct destination is found, both
///   [pageIndex] and [uri] are `null` (section-label entry with no target).
///
/// ## Zoom omission
///
/// `FPDFDest_GetLocationInPage` returns an (x, y, zoom) triple for
/// `PDFDEST_VIEW_XYZ` destinations. The zoom value is intentionally **not**
/// surfaced here. Exposing zoom risks overriding the user's OS accessibility
/// zoom settings or Flutter's `textScaleFactor`, which would create a hostile
/// experience for users who rely on display magnification. Callers that need
/// precise magnification control should manage zoom independently of the
/// bookmark destination. Only the (x, y) scroll anchor is captured via
/// [scrollPosition].
final class PdfTocEntry {
  /// Creates an immutable [PdfTocEntry].
  const PdfTocEntry({
    required this.title,
    this.pageIndex,
    this.uri,
    this.scrollPosition,
    this.children = const [],
  });

  /// The display title of this bookmark entry.
  ///
  /// An empty string is valid — PDFium found a bookmark with no title text.
  final String title;

  /// The zero-based page index this entry navigates to, or `null` if the
  /// entry has no internal-page destination (e.g. it is a URI action or a
  /// section label with no target).
  ///
  /// A value of `null` does not indicate an error; it indicates that this
  /// entry either has a [uri] target or is a pure structural label.
  final int? pageIndex;

  /// The URI this entry navigates to, or `null` if the entry is not a URI
  /// action.
  ///
  /// Non-null only for bookmarks with a `PDFACTION_URI` action.
  /// [pageIndex] is always `null` when [uri] is non-null.
  final String? uri;

  /// The XYZ scroll anchor within the destination page, or `null` if either
  /// the entry has no page destination or the destination does not carry
  /// explicit position coordinates.
  ///
  /// Coordinates are in PDF user space (points, bottom-left origin), matching
  /// the coordinate system used by [PdfRect] and [PdfPoint] throughout this
  /// library. Callers that need screen-space coordinates must apply
  /// `FPDF_PageToDevice()` themselves.
  ///
  /// See the class-level doc comment for why the zoom component of XYZ
  /// destinations is not surfaced here.
  final PdfPoint? scrollPosition;

  /// The child entries nested under this entry, in document order.
  ///
  /// An empty list means this is a leaf entry with no sub-items.
  final List<PdfTocEntry> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfTocEntry &&
          title == other.title &&
          pageIndex == other.pageIndex &&
          uri == other.uri &&
          scrollPosition == other.scrollPosition &&
          _listEqual(children, other.children);

  @override
  int get hashCode => Object.hash(
    title,
    pageIndex,
    uri,
    scrollPosition,
    Object.hashAll(children),
  );

  @override
  String toString() =>
      'PdfTocEntry(title: $title, pageIndex: $pageIndex, uri: $uri, '
      'scrollPosition: $scrollPosition, children: ${children.length})';
}

// ---------------------------------------------------------------------------
// Image extraction types
// ---------------------------------------------------------------------------

/// The colorspace of a PDF image object, corresponding to the
/// `FPDF_COLORSPACE_*` constants in `fpdf_edit.h`.
///
/// Raw PDFium integer constants are not exposed in the public API; all
/// colorspaces are mapped to this enum. Use [unknown] as the fallback for
/// any value not recognised by this version of the library.
enum PdfColorspace {
  /// `FPDF_COLORSPACE_UNKNOWN = 0` — colorspace not identified.
  unknown,

  /// `FPDF_COLORSPACE_DEVICEGRAY = 1` — single-channel grey.
  deviceGray,

  /// `FPDF_COLORSPACE_DEVICERGB = 2` — additive RGB.
  deviceRgb,

  /// `FPDF_COLORSPACE_DEVICECMYK = 3` — subtractive CMYK.
  deviceCmyk,

  /// `FPDF_COLORSPACE_CALGRAY = 4` — calibrated greyscale.
  calGray,

  /// `FPDF_COLORSPACE_CALRGB = 5` — calibrated RGB.
  calRgb,

  /// `FPDF_COLORSPACE_LAB = 6` — CIE L*a*b*.
  lab,

  /// `FPDF_COLORSPACE_ICCBASED = 7` — ICC profile-based colorspace.
  iccBased,

  /// `FPDF_COLORSPACE_SEPARATION = 8` — separation (spot colour).
  separation,

  /// `FPDF_COLORSPACE_DEVICEN = 9` — DeviceN (multi-ink).
  deviceN,

  /// `FPDF_COLORSPACE_INDEXED = 10` — indexed / palette.
  indexed,

  /// `FPDF_COLORSPACE_PATTERN = 11` — pattern colorspace.
  pattern,
}

/// Source-level metadata for a single image object in a PDF page.
///
/// These values come directly from the `FPDF_IMAGEOBJ_METADATA` struct and
/// describe the image as stored in the PDF (before any transforms are applied).
/// The rendered output may differ in dimensions — see [PdfImage.bitmapWidth]
/// and [PdfImage.bitmapHeight].
///
/// [markedContentId] links the image to the document's structure tree for
/// alt-text lookup via `fpdf_structtree.h`. A value of `-1` means no
/// marked-content identifier is present.
final class PdfImageMetadata {
  /// Creates an immutable [PdfImageMetadata].
  const PdfImageMetadata({
    required this.width,
    required this.height,
    required this.horizontalDpi,
    required this.verticalDpi,
    required this.bitsPerPixel,
    required this.colorspace,
    required this.markedContentId,
  });

  /// Source pixel width of the image as stored in the PDF.
  final int width;

  /// Source pixel height of the image as stored in the PDF.
  final int height;

  /// Horizontal resolution in dots per inch.
  final double horizontalDpi;

  /// Vertical resolution in dots per inch.
  final double verticalDpi;

  /// Bits per pixel of the source image data (e.g. 1, 8, 24).
  ///
  /// A value of 1 typically indicates an image mask (stencil). Image mask
  /// objects appear in the [PdfPageImages.images] list and are not suppressed
  /// automatically — callers can identify them via this field.
  final int bitsPerPixel;

  /// The colorspace of the source image data.
  final PdfColorspace colorspace;

  /// The marked-content identifier linking this image to the structure tree,
  /// or `-1` if the image has no marked-content entry.
  ///
  /// Callers that need the associated alt-text must look up this identifier
  /// in the document structure tree via `fpdf_structtree.h` independently.
  final int markedContentId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfImageMetadata &&
          width == other.width &&
          height == other.height &&
          horizontalDpi == other.horizontalDpi &&
          verticalDpi == other.verticalDpi &&
          bitsPerPixel == other.bitsPerPixel &&
          colorspace == other.colorspace &&
          markedContentId == other.markedContentId;

  @override
  int get hashCode => Object.hash(
    width,
    height,
    horizontalDpi,
    verticalDpi,
    bitsPerPixel,
    colorspace,
    markedContentId,
  );

  @override
  String toString() =>
      'PdfImageMetadata('
      'width: $width, height: $height, '
      'horizontalDpi: $horizontalDpi, verticalDpi: $verticalDpi, '
      'bitsPerPixel: $bitsPerPixel, colorspace: $colorspace, '
      'markedContentId: $markedContentId)';
}

/// A single image object on a PDF page.
///
/// Produced by [PdfDocument.extractImages]. [objectIndex] is the stable
/// per-page integer position of this object in the page's object list; pass it
/// to [PdfDocument.renderImage] to fetch the bitmap on demand.
///
/// ## Bitmap fields
///
/// [bgra], [bitmapWidth], and [bitmapHeight] are `null` when
/// [PdfDocument.extractImages] was called with `includeBitmap: false` (the
/// default, metadata-only mode). Use [PdfDocument.renderImage] to retrieve the
/// composited BGRA bitmap for a specific image without re-enumerating the page.
///
/// When `includeBitmap: true` is passed, all three fields are populated for
/// every image that has a renderable bitmap; they remain `null` for mask-only
/// or otherwise unrenderable objects (when `FPDFImageObj_GetRenderedBitmap`
/// returns null).
///
/// ## Image masks
///
/// Image mask objects (`bits_per_pixel == 1`) are included in the output and
/// are not suppressed automatically. Callers can identify them via
/// `metadata.bitsPerPixel == 1`.
final class PdfImage {
  /// Creates an immutable [PdfImage].
  const PdfImage({
    required this.pageIndex,
    required this.objectIndex,
    required this.metadata,
    required this.bounds,
    required this.filters,
    this.bgra,
    this.bitmapWidth,
    this.bitmapHeight,
  });

  /// Zero-based index of the page this image belongs to.
  final int pageIndex;

  /// Position of this object in the page's object list (zero-based).
  ///
  /// This index is stable for the lifetime of the open document and can be
  /// passed directly to [PdfDocument.renderImage] to fetch the BGRA bitmap
  /// on demand.
  final int objectIndex;

  /// Source-level metadata for this image (dimensions, DPI, colorspace).
  final PdfImageMetadata metadata;

  /// Axis-aligned bounding box of the image in PDF user-space coordinates.
  ///
  /// Coordinates use the PDF bottom-left origin. The box reflects the image's
  /// position and scaling on the page after all transforms are applied.
  final PdfRect bounds;

  /// The compression filter names applied to the image data, in order.
  ///
  /// For example, `['DCTDecode']` indicates JPEG encoding, and
  /// `['FlateDecode']` indicates zlib/deflate. An empty list means no filters
  /// were found (or the image uses an inline/uncompressed format).
  final List<String> filters;

  /// The rendered BGRA pixel bytes, or `null` if the bitmap was not requested.
  ///
  /// Non-null only when [PdfDocument.extractImages] was called with
  /// `includeBitmap: true` and `FPDFImageObj_GetRenderedBitmap` succeeded.
  /// The byte length equals [bitmapWidth]! * [bitmapHeight]! * 4.
  final Uint8List? bgra;

  /// The rendered pixel width, or `null` if the bitmap was not requested.
  ///
  /// May differ from [PdfImageMetadata.width] after transforms are applied.
  final int? bitmapWidth;

  /// The rendered pixel height, or `null` if the bitmap was not requested.
  ///
  /// May differ from [PdfImageMetadata.height] after transforms are applied.
  final int? bitmapHeight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfImage &&
          pageIndex == other.pageIndex &&
          objectIndex == other.objectIndex &&
          metadata == other.metadata &&
          bounds == other.bounds &&
          _listEqual(filters, other.filters) &&
          bitmapWidth == other.bitmapWidth &&
          bitmapHeight == other.bitmapHeight;
  // bgra is intentionally excluded from equality to avoid comparing large
  // byte buffers by value; callers that need bitmap equality should compare
  // the bgra lists directly.

  @override
  int get hashCode => Object.hash(
    pageIndex,
    objectIndex,
    metadata,
    bounds,
    Object.hashAll(filters),
    bitmapWidth,
    bitmapHeight,
  );

  @override
  String toString() =>
      'PdfImage('
      'pageIndex: $pageIndex, objectIndex: $objectIndex, '
      'metadata: $metadata, bounds: $bounds, '
      'filters: $filters, '
      'bitmapWidth: $bitmapWidth, bitmapHeight: $bitmapHeight, '
      'bgra: ${bgra != null ? '${bgra!.length} bytes' : 'null'})';
}

/// A rendered bitmap returned by [PdfDocument.renderImage].
///
/// [bgra] is the composited BGRA pixel buffer produced by
/// `FPDFImageObj_GetRenderedBitmap`. The rendering includes mask composition
/// and transform application, so the output dimensions ([width] × [height])
/// may differ from the source image dimensions in [PdfImageMetadata].
final class PdfImageBitmap {
  /// Creates an immutable [PdfImageBitmap].
  const PdfImageBitmap({
    required this.bgra,
    required this.width,
    required this.height,
  });

  /// Rendered BGRA pixel bytes. Length equals [width] * [height] * 4.
  final Uint8List bgra;

  /// Rendered pixel width.
  final int width;

  /// Rendered pixel height.
  final int height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfImageBitmap && width == other.width && height == other.height;
  // bgra is intentionally excluded from equality; compare lists directly if
  // pixel-exact equality is required.

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() =>
      'PdfImageBitmap(width: $width, height: $height, '
      'bgra: ${bgra.length} bytes)';
}

/// The image objects extracted from a single PDF page.
///
/// Produced by [PdfDocument.extractImages]. Each item in the stream
/// corresponds to one page. Pages with no image objects emit an entry with an
/// empty [images] list, so callers can track page coverage without gaps.
final class PdfPageImages {
  /// Creates an immutable [PdfPageImages] value.
  const PdfPageImages({required this.pageIndex, required this.images});

  /// Zero-based index of the page this result corresponds to.
  final int pageIndex;

  /// The image objects found on this page, in object-list order.
  ///
  /// Includes image mask objects (`metadata.bitsPerPixel == 1`); these are
  /// not suppressed automatically. An empty list means the page has no image
  /// objects.
  final List<PdfImage> images;

  @override
  String toString() =>
      'PdfPageImages(pageIndex: $pageIndex, images: ${images.length})';
}

// ---------------------------------------------------------------------------
// Search types
// ---------------------------------------------------------------------------

/// Flags that control the text-search behaviour of [PdfDocument.search].
///
/// Combine flags using a [Set]:
///
/// ```dart
/// final matches = doc.search('example',
///   flags: {PdfSearchFlag.matchCase, PdfSearchFlag.matchWholeWord});
/// ```
///
/// Flag values correspond to the PDFium `FPDF_MATCHCASE`,
/// `FPDF_MATCHWHOLEWORD`, and `FPDF_CONSECUTIVE` constants defined in
/// `fpdf_text.h`.
enum PdfSearchFlag {
  /// Case-sensitive matching (`FPDF_MATCHCASE = 0x00000001`).
  ///
  /// When set, "Apple" does not match "apple". When absent the search is
  /// case-insensitive.
  matchCase,

  /// Whole-word matching (`FPDF_MATCHWHOLEWORD = 0x00000002`).
  ///
  /// When set, "art" does not match the substring "art" inside "artist".
  matchWholeWord,

  /// Allow overlapping / consecutive matches (`FPDF_CONSECUTIVE = 0x00000004`).
  ///
  /// When set, searching for "aa" in "aaa" produces two overlapping matches
  /// (at index 0 and index 1). When absent each match starts immediately after
  /// the previous match ends.
  consecutive,
}

/// A single text-search match returned by [PdfDocument.search].
///
/// Each instance describes one occurrence of the search query on a specific
/// page. Multi-line matches (where the matching text wraps across visual rows)
/// produce a single [PdfSearchMatch] with multiple entries in [rects] — one
/// per visual line fragment.
///
/// ## Coordinate system
///
/// All coordinates in [rects] are in **PDF user space** (origin bottom-left,
/// units in points), consistent with [PdfRect] and page-size coordinates used
/// throughout this library. Callers that need screen-space coordinates must
/// apply `FPDF_PageToDevice()` / `FPDF_DeviceToPage()` themselves.
final class PdfSearchMatch {
  /// Creates an immutable [PdfSearchMatch].
  const PdfSearchMatch({
    required this.pageIndex,
    required this.charIndex,
    required this.charCount,
    required this.rects,
  });

  /// Zero-based index of the page on which this match was found.
  final int pageIndex;

  /// Zero-based character index of the first matched character on this page.
  ///
  /// This index is relative to the page's text layer, consistent with the
  /// character indices used by `FPDFText_GetText` and `FPDFText_GetCharBox`.
  final int charIndex;

  /// Number of matched characters.
  ///
  /// The matched text spans characters `[charIndex, charIndex + charCount)`.
  final int charCount;

  /// Bounding rectangles of this match in PDF user-space (origin bottom-left,
  /// units in points).
  ///
  /// A match that spans a single visual line produces one rect. A match that
  /// wraps across multiple visual rows produces one rect per row fragment.
  /// Callers should treat all rects as fragments that together cover the full
  /// extent of this match.
  ///
  /// Uses [PdfRect] — the same coordinate space as page sizes and annotation
  /// bounding boxes throughout this library.
  final List<PdfRect> rects;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfSearchMatch &&
          pageIndex == other.pageIndex &&
          charIndex == other.charIndex &&
          charCount == other.charCount &&
          _listEqual(rects, other.rects);

  @override
  int get hashCode =>
      Object.hash(pageIndex, charIndex, charCount, Object.hashAll(rects));

  @override
  String toString() =>
      'PdfSearchMatch('
      'pageIndex: $pageIndex, '
      'charIndex: $charIndex, '
      'charCount: $charCount, '
      'rects: ${rects.length})';
}

// ---------------------------------------------------------------------------
// Thumbnail types
// ---------------------------------------------------------------------------

/// Whether a [PdfThumbnail] came from an embedded stream or was rendered.
///
/// Embedded thumbnails are smaller than rendered ones (typically 64–256 px)
/// and are returned at their native size. Rendered thumbnails are produced on
/// demand by the rendering engine at the caller-controlled `maxDimension`.
enum PdfThumbnailSource {
  /// Decoded from an embedded `/Thumb` stream in the PDF page dictionary.
  ///
  /// Not all PDFs contain embedded thumbnails. Modern tools like `pdflatex`
  /// and many web-based PDF creators do not produce `/Thumb` streams. When a
  /// thumbnail is embedded, [PdfDocument.getThumbnail] returns it at its
  /// native dimensions without any scaling.
  embedded,

  /// Rendered from the page content at [PdfDocument.getThumbnail]'s
  /// `maxDimension` because no embedded thumbnail was present.
  ///
  /// The rendered thumbnail is produced by the same rendering engine as
  /// [PdfDocument.renderPageToBytes]. On high-DPI displays, multiply
  /// `maxDimension` by the device pixel ratio before calling to obtain a
  /// retina-sharp result.
  rendered,
}

/// A thumbnail image for a PDF page.
///
/// Obtain via [PdfDocument.getThumbnail]. Pixel data is in BGRA format
/// (4 bytes per pixel, blue first). The [source] field indicates whether
/// the thumbnail was decoded from an embedded stream or synthesised by
/// rendering the page.
///
/// ## Pixel format
///
/// [bgra] is always a compact BGRA buffer: `length == width * height * 4`.
/// The bytes are ordered B, G, R, A per pixel, row-major. Row padding from
/// the underlying PDFium bitmap is stripped before delivery.
///
/// ## Embedded vs rendered thumbnails
///
/// Embedded thumbnails ([PdfThumbnailSource.embedded]) are stored directly in
/// the PDF and returned at whatever dimensions the authoring tool chose.
/// Rendered thumbnails ([PdfThumbnailSource.rendered]) respect `maxDimension`.
///
/// Example — converting a [PdfThumbnail] to a Flutter `dart:ui Image`:
///
/// ```dart
/// final thumb = await doc.getThumbnail(0);
/// if (thumb != null) {
///   final codec = await ui.instantiateImageCodec(
///     thumb.bgra,
///     targetWidth: thumb.width,
///     targetHeight: thumb.height,
///   );
///   final frame = await codec.getNextFrame();
///   final image = frame.image;
/// }
/// ```
final class PdfThumbnail {
  /// Creates an immutable [PdfThumbnail].
  const PdfThumbnail({
    required this.bgra,
    required this.width,
    required this.height,
    required this.source,
  });

  /// BGRA pixel bytes. Length is always [width] * [height] * 4.
  ///
  /// Bytes are ordered B, G, R, A per pixel, row-major. Row padding from the
  /// underlying PDFium bitmap has been stripped; the buffer is compact.
  final Uint8List bgra;

  /// Width of the thumbnail in pixels.
  final int width;

  /// Height of the thumbnail in pixels.
  final int height;

  /// Whether this thumbnail was decoded from an embedded stream or rendered.
  final PdfThumbnailSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfThumbnail &&
          width == other.width &&
          height == other.height &&
          source == other.source;
  // bgra is intentionally excluded from equality to avoid comparing large
  // byte buffers by value. Callers that need pixel-exact equality should
  // compare the bgra lists directly.

  @override
  int get hashCode => Object.hash(width, height, source);

  @override
  String toString() =>
      'PdfThumbnail(width: $width, height: $height, source: $source, '
      'bgra: ${bgra.length} bytes)';
}

// ---------------------------------------------------------------------------
// Document info types
// ---------------------------------------------------------------------------

/// Document-level properties that are distinct from content metadata.
///
/// These are low-level PDF document properties: the PDF file version and the
/// two file identifier entries (permanent and changing). They are returned as
/// a single batched call to avoid multiple isolate round-trips.
///
/// File identifiers are typically 16-byte MD5 hashes. They are returned as
/// [Uint8List] (raw bytes) so callers can choose their own encoding (e.g.
/// hex string via `hex.encode()`).
class PdfDocumentInfo {
  /// Creates an immutable [PdfDocumentInfo] value object.
  const PdfDocumentInfo({this.fileVersion, this.permanentId, this.changingId});

  /// The PDF file version as an integer (e.g. 17 for PDF 1.7), or `null` if
  /// the version could not be read.
  final int? fileVersion;

  /// The permanent file identifier (typically a 16-byte MD5 hash), or `null`
  /// if the document has no file identifier array.
  ///
  /// The permanent ID is set when the document is first created and does not
  /// change across save operations. Callers that need a hex string can use
  /// `permanentId?.map((b) => b.toRadixString(16).padLeft(2, '0')).join()`.
  final Uint8List? permanentId;

  /// The changing file identifier (typically a 16-byte MD5 hash), or `null`
  /// if the document has no file identifier array.
  ///
  /// The changing ID is updated on each save. Together with [permanentId] it
  /// can be used to detect whether a file is a revision of a known document.
  final Uint8List? changingId;

  @override
  String toString() {
    String? hexEncode(Uint8List? bytes) =>
        bytes?.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'PdfDocumentInfo('
        'fileVersion: $fileVersion, '
        'permanentId: ${hexEncode(permanentId)}, '
        'changingId: ${hexEncode(changingId)}'
        ')';
  }
}
