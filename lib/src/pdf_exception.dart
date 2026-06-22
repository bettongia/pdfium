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

/// A general-purpose exception thrown when an unexpected PDFium native
/// failure occurs.
///
/// [PdfiumException] is thrown when a PDFium FFI call returns a failure that
/// cannot be attributed to a known, recoverable condition (such as an invalid
/// document or a missing password). For example, if [FPDFBitmap_Create]
/// returns `null` unexpectedly — indicating a native allocation failure — a
/// [PdfiumException] is thrown with a descriptive [message].
///
/// Known, recoverable conditions (password-required, corrupt document) use
/// [PdfError] and [PdfExtractionException] instead.
///
/// ## Example
///
/// ```dart
/// try {
///   final image = await doc.renderPage(0, 800, 600);
/// } on PdfiumException catch (e) {
///   print('PDFium native failure: ${e.message}');
/// }
/// ```
class PdfiumException implements Exception {
  /// Creates a [PdfiumException] with the given [message].
  const PdfiumException(this.message);

  /// A human-readable description of why the PDFium call failed.
  final String message;

  @override
  String toString() => 'PdfiumException: $message';
}
