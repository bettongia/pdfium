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
  final bytes = await File('test/data/arxiv/2312.17524v1.pdf').readAsBytes();

  final doc = await PdfDocument.fromBytes(bytes);
  try {
    // Check whether the document has a usable text layer before extracting.
    final extractable = await doc.isPlainTextExtractable();
    if (!extractable) {
      print('Document appears to be scanned — no text layer.');
      return;
    }

    // Stream pages one at a time. Cancel the subscription at any point to stop.
    await for (final page in doc.extractPlainText()) {
      if (page.hasTextLayer) {
        print('--- Page ${page.pageIndex} ---');
        print(page.text);
      } else {
        print('Page ${page.pageIndex}: no text layer (image/scanned)');
      }
      if (page.hasUnicodeErrors) {
        print('  (warning: some characters had no Unicode mapping)');
      }
    }

    // Extract a single page by index:
    final firstPage = await doc.extractPlainText(pageIndex: 0).first;
    print('Page 0 has ${firstPage.text.length} characters.');
  } finally {
    await doc.close();
  }
}
