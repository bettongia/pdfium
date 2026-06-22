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

/// Pure-Dart entry point for betto_pdf.
///
/// Exports document loading, metadata extraction, text extraction, annotation
/// extraction, and page-size queries. Has no dependency on `dart:ui` or
/// Flutter, so it can be used in CLI tools and pure-Dart programs:
///
/// ```dart
/// import 'package:betto_pdf/pdfart_core.dart';
/// ```
///
/// Flutter applications that also need page rendering and the [PdfPageView]
/// widget should import `package:betto_pdf/pdfart.dart` instead, which
/// re-exports everything here plus the Flutter layer.
library;

export 'src/document/pdf_document.dart';
export 'src/pdf_exception.dart';
