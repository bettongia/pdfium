// Copyright 2026 The Authors. See the AUTHORS file for details.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';
import 'package:betto_pdfium/betto_pdfium.dart';

void main() async {
  final bytes = await File('test/fixtures/full_metadata.pdf').readAsBytes();

  try {
    final doc = await PdfDocument.fromBytes(bytes);
    try {
      final meta = await doc.getMetadata();
      print('Title: ${meta.title}');
      print('Author: ${meta.author}');
      print('Created: ${meta.creationDate?.value?.toIso8601String()}');

      final info = await doc.getDocumentInfo();
      print('PDF version: ${info.fileVersion}');
    } finally {
      await doc.close();
    }
  } on PdfExtractionException catch (e) {
    if (e.error == PdfError.passwordRequired) {
      print('This PDF is password-protected.');
    } else {
      print('Could not open PDF: ${e.error}');
    }
  }
}
