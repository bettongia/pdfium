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

// pdfinfo — developer CLI tool for inspecting PDF metadata and extracted text.
//
// Usage:
//   dart run bin/pdfinfo.dart [--text] [--annot] [--toc] [--search <query>] [--json] <path-to-pdf>
//
// Flags:
//   --text           Also extract and print the plain text content of the PDF.
//                    Without this flag only metadata is displayed.
//   --annot          Also extract and print annotation data from every page.
//                    Without this flag annotations are not extracted.
//   --toc            Also extract and print the bookmark/outline tree (Table of Contents).
//                    Without this flag the TOC is not extracted.
//   --search <query> Search the document for the given query string and print
//                    all matching locations (page, character index, bounding rects).
//                    Without this flag no search is performed.
//   --json           Output everything as a single JSON object instead of the
//                    default human-readable key/value format.
//
// The --text, --annot, --toc, --search, and --json flags may be combined freely.
//
// Exit codes:
//   0  — success
//   1  — bad arguments, file not found, or unreadable
//   2  — PDF error (password required or invalid document)
//   3  — unexpected error

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:betto_pdfium/betto_pdfium.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'text',
      negatable: false,
      help: 'Extract and include plain text content.',
    )
    ..addFlag(
      'annot',
      negatable: false,
      help: 'Extract and include annotation data from every page.',
    )
    ..addFlag(
      'toc',
      negatable: false,
      help:
          'Extract and include the bookmark/outline tree (Table of Contents).',
    )
    ..addOption(
      'search',
      help:
          'Search the document for the given query string and print all '
          'matching locations (page, character index, bounding rects).',
      valueHelp: 'query',
    )
    ..addFlag(
      'json',
      negatable: false,
      help: 'Output results as JSON instead of plain text.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final ArgResults parsed;
  try {
    parsed = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    _printUsage(parser);
    exit(1);
  }

  if (parsed['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  if (parsed.rest.isEmpty || parsed.rest.length > 1) {
    stderr.writeln('Error: exactly one PDF path is required.');
    _printUsage(parser);
    exit(1);
  }

  final includeText = parsed['text'] as bool;
  final includeAnnot = parsed['annot'] as bool;
  final includeToc = parsed['toc'] as bool;
  final searchQuery = parsed['search'] as String?;
  final useJson = parsed['json'] as bool;

  final path = parsed.rest[0];
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('Error: file not found: $path');
    exit(1);
  }

  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (e) {
    stderr.writeln('Error: could not read file: $path');
    stderr.writeln('  $e');
    exit(1);
  }

  final doc = await _loadDocument(bytes);

  try {
    final info = await doc.getDocumentInfo();
    final meta = await doc.getMetadata();

    final List<PdfPageText> pages;
    if (includeText) {
      pages = await doc.extractPlainText().toList();
    } else {
      pages = const [];
    }

    final List<PdfPageAnnotations> annotPages;
    if (includeAnnot) {
      annotPages = await doc.extractAnnotations().toList();
    } else {
      annotPages = const [];
    }

    final List<PdfTocEntry> tocEntries;
    if (includeToc) {
      tocEntries = await doc.tableOfContents;
    } else {
      tocEntries = const [];
    }

    final List<PdfSearchMatch> searchMatches;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      searchMatches = await doc.search(searchQuery).toList();
    } else {
      searchMatches = const [];
    }

    if (useJson) {
      _printJson(
        info,
        meta,
        includeText ? pages : null,
        includeAnnot ? annotPages : null,
        includeToc ? tocEntries : null,
        searchQuery != null && searchQuery.isNotEmpty ? searchMatches : null,
      );
    } else {
      _printPlainDocumentInfo(info);
      _printPlainMetadata(meta);
      if (includeText) {
        _printPlainText(pages);
      }
      if (includeAnnot) {
        _printPlainAnnotations(annotPages);
      }
      if (includeToc) {
        _printPlainToc(tocEntries);
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        _printPlainSearch(searchQuery, searchMatches);
      }
    }
  } on PdfExtractionException catch (e) {
    stderr.writeln('Error reading PDF properties: ${e.error.name}');
    await doc.close();
    exit(2);
  } catch (e) {
    stderr.writeln('Error: unexpected error reading PDF: $e');
    await doc.close();
    exit(3);
  }
  await doc.close();
}

void _printUsage(ArgParser parser) {
  stderr.writeln(
    'Usage: dart run bin/pdfinfo.dart [--text] [--annot] [--toc] '
    '[--search <query>] [--json] <path-to-pdf>',
  );
  stderr.writeln(parser.usage);
}

/// Loads the PDF document from [bytes], exiting with an appropriate error
/// message and code if the document cannot be opened.
Future<PdfDocument> _loadDocument(Uint8List bytes) async {
  try {
    return await PdfDocument.fromBytes(bytes);
  } on PdfExtractionException catch (e) {
    switch (e.error) {
      case PdfError.passwordRequired:
        stderr.writeln('Error: the PDF is password-protected.');
        stderr.writeln(
          '  Password-protected documents are not supported in v1.',
        );
        exit(2);
      case PdfError.invalidDocument:
        stderr.writeln(
          'Error: the file is not a valid PDF or the document is corrupt.',
        );
        exit(2);
    }
  } catch (e) {
    stderr.writeln('Error: unexpected error loading PDF: $e');
    exit(3);
  }
}

// ---------------------------------------------------------------------------
// Plain text output
// ---------------------------------------------------------------------------

/// Prints document-level properties (version and file identifiers).
void _printPlainDocumentInfo(PdfDocumentInfo info) {
  _printSection('Document Properties');

  if (info.fileVersion != null) {
    final major = info.fileVersion! ~/ 10;
    final minor = info.fileVersion! % 10;
    _printField('PDF Version', '$major.$minor (raw: ${info.fileVersion})');
  } else {
    _printField('PDF Version', '(not available)');
  }

  _printField('Permanent ID', _formatId(info.permanentId));
  _printField('Changing ID', _formatId(info.changingId));
}

/// Prints all eight Info dictionary metadata fields.
void _printPlainMetadata(PdfMetadata meta) {
  _printSection('Info Dictionary Metadata');

  _printField('Title', meta.title);
  _printField('Author', meta.author);
  _printField('Subject', meta.subject);
  _printField('Keywords', meta.keywords);
  _printField('Creator', meta.creator);
  _printField('Producer', meta.producer);
  _printDateField('Creation Date', meta.creationDate);
  _printDateField('Modification Date', meta.modDate);
}

/// Prints extracted text page by page.
void _printPlainText(List<PdfPageText> pages) {
  _printSection('Extracted Text');

  if (pages.isEmpty) {
    stdout.writeln('  (no pages)');
    return;
  }

  for (final page in pages) {
    stdout.writeln('');
    stdout.writeln('  --- Page ${page.pageIndex + 1} ---');
    if (page.text.isEmpty) {
      stdout.writeln(
        page.hasTextLayer ? '  (empty)' : '  (no text layer — scanned page)',
      );
    } else {
      if (!page.hasTextLayer) {
        stdout.writeln(
          '  [note: below density threshold — may be sparse page]',
        );
      }
      // Indent each line of the extracted text for readability.
      for (final line in page.text.split('\n')) {
        stdout.writeln('  $line');
      }
    }
    if (page.hasUnicodeErrors) {
      stdout.writeln('  [warning: page has unicode mapping errors]');
    }
  }
}

/// Prints a section header.
void _printSection(String title) {
  stdout.writeln('');
  stdout.writeln('--- $title ---');
}

/// Prints a key/value pair, substituting a placeholder for null values.
void _printField(String key, String? value) {
  final display = value ?? '(not present)';
  stdout.writeln('  ${key.padRight(20)} $display');
}

/// Prints a [PdfDate] field showing both the parsed value and the raw string.
///
/// This dual display is intentional: real-world PDFs often have malformed
/// dates, and showing both forms makes it easy to debug parsing issues.
void _printDateField(String key, PdfDate? date) {
  if (date == null) {
    _printField(key, null);
    return;
  }
  final parsed = date.value != null
      ? date.value!.toIso8601String()
      : '(could not parse)';
  // Display the parsed ISO 8601 string and the original raw string on one line.
  stdout.writeln('  ${key.padRight(20)} $parsed');
  stdout.writeln('  ${''.padRight(20)} raw: ${date.raw}');
}

/// Formats a file identifier byte array as a hex string, or a placeholder.
String _formatId(Uint8List? bytes) {
  if (bytes == null) return '(not present)';
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

// ---------------------------------------------------------------------------
// JSON output
// ---------------------------------------------------------------------------

/// Outputs all collected data as a single JSON object.
///
/// When [pages] is null the `text` key is omitted entirely (--text not passed).
/// When [annotPages] is null the `annotations` key is omitted (--annot not passed).
/// When [tocEntries] is null the `toc` key is omitted (--toc not passed).
/// When [searchMatches] is null the `search` key is omitted (--search not passed).
void _printJson(
  PdfDocumentInfo info,
  PdfMetadata meta,
  List<PdfPageText>? pages,
  List<PdfPageAnnotations>? annotPages,
  List<PdfTocEntry>? tocEntries,
  List<PdfSearchMatch>? searchMatches,
) {
  final Map<String, dynamic> root = {
    'documentProperties': _documentInfoToJson(info),
    'metadata': _metadataToJson(meta),
  };

  if (pages != null) {
    root['text'] = pages.map(_pageTextToJson).toList();
  }

  if (annotPages != null) {
    root['annotations'] = annotPages.map(_pageAnnotationsToJson).toList();
  }

  if (tocEntries != null) {
    root['toc'] = tocEntries.map(_tocEntryToJson).toList();
  }

  if (searchMatches != null) {
    root['search'] = searchMatches.map(_searchMatchToJson).toList();
  }

  final encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert(root));
}

Map<String, dynamic> _documentInfoToJson(PdfDocumentInfo info) {
  String? pdfVersion;
  if (info.fileVersion != null) {
    final major = info.fileVersion! ~/ 10;
    final minor = info.fileVersion! % 10;
    pdfVersion = '$major.$minor';
  }

  return {
    'pdfVersion': pdfVersion,
    'permanentId': _formatId(info.permanentId) == '(not present)'
        ? null
        : _formatId(info.permanentId),
    'changingId': _formatId(info.changingId) == '(not present)'
        ? null
        : _formatId(info.changingId),
  };
}

Map<String, dynamic> _metadataToJson(PdfMetadata meta) => {
  'title': meta.title,
  'author': meta.author,
  'subject': meta.subject,
  'keywords': meta.keywords,
  'creator': meta.creator,
  'producer': meta.producer,
  'creationDate': _dateToJson(meta.creationDate),
  'modificationDate': _dateToJson(meta.modDate),
};

Map<String, dynamic>? _dateToJson(PdfDate? date) {
  if (date == null) return null;
  return {'raw': date.raw, 'parsed': date.value?.toIso8601String()};
}

Map<String, dynamic> _pageTextToJson(PdfPageText page) => {
  'pageIndex': page.pageIndex,
  'hasTextLayer': page.hasTextLayer,
  'hasUnicodeErrors': page.hasUnicodeErrors,
  'text': page.text,
};

// ---------------------------------------------------------------------------
// Plain text annotation output
// ---------------------------------------------------------------------------

/// Prints all annotations page by page in a human-readable format.
void _printPlainAnnotations(List<PdfPageAnnotations> pages) {
  _printSection('Annotations');

  if (pages.isEmpty) {
    stdout.writeln('  (no pages)');
    return;
  }

  var totalAnnotations = 0;
  for (final page in pages) {
    totalAnnotations += page.annotations.length;
  }

  if (totalAnnotations == 0) {
    stdout.writeln('  (no annotations found)');
    return;
  }

  for (final page in pages) {
    if (page.annotations.isEmpty) continue;

    stdout.writeln('');
    stdout.writeln('  --- Page ${page.pageIndex + 1} ---');

    for (var i = 0; i < page.annotations.length; i++) {
      final annot = page.annotations[i];
      stdout.writeln('');
      stdout.writeln('  Annotation ${i + 1}: ${_annotTypeName(annot)}');

      if (annot.contents != null) {
        stdout.writeln('    Contents:  ${annot.contents}');
      }
      if (annot.author != null) {
        stdout.writeln('    Author:    ${annot.author}');
      }
      if (annot.rect != null) {
        final r = annot.rect!;
        stdout.writeln(
          '    Rect:      [${r.left.toStringAsFixed(2)}, '
          '${r.bottom.toStringAsFixed(2)}, '
          '${r.right.toStringAsFixed(2)}, '
          '${r.top.toStringAsFixed(2)}]',
        );
      }
      if (annot.color != null) {
        final c = annot.color!;
        stdout.writeln(
          '    Color:     rgba(${c.r.toStringAsFixed(3)}, '
          '${c.g.toStringAsFixed(3)}, ${c.b.toStringAsFixed(3)}, '
          '${c.a.toStringAsFixed(3)})',
        );
      }
      if (annot.modifiedDate != null) {
        final d = annot.modifiedDate!;
        final parsed = d.value?.toIso8601String() ?? d.raw;
        stdout.writeln('    Modified:  $parsed');
      }
      if (annot.popup != null) {
        stdout.writeln('    Has popup: yes');
      }

      // Subtype-specific fields.
      switch (annot) {
        case PdfMarkupAnnotation(:final quadPoints, :final markedText):
          stdout.writeln('    Quad sets: ${quadPoints.length}');
          if (markedText != null && markedText.isNotEmpty) {
            stdout.writeln('    Marked:    $markedText');
          }
        case PdfInkAnnotation(:final strokes):
          stdout.writeln('    Strokes:   ${strokes.length}');
          for (var s = 0; s < strokes.length; s++) {
            stdout.writeln(
              '      Stroke ${s + 1}: ${strokes[s].length} points',
            );
          }
        case PdfLineAnnotation(:final lineStart, :final lineEnd):
          stdout.writeln(
            '    Line:      (${lineStart.x.toStringAsFixed(2)}, '
            '${lineStart.y.toStringAsFixed(2)}) → '
            '(${lineEnd.x.toStringAsFixed(2)}, '
            '${lineEnd.y.toStringAsFixed(2)})',
          );
        case PdfShapeAnnotation(:final interiorColor):
          if (interiorColor != null) {
            stdout.writeln(
              '    Fill:      rgba(${interiorColor.r.toStringAsFixed(3)}, '
              '${interiorColor.g.toStringAsFixed(3)}, '
              '${interiorColor.b.toStringAsFixed(3)}, '
              '${interiorColor.a.toStringAsFixed(3)})',
            );
          }
        case PdfPolygonAnnotation(:final vertices):
          stdout.writeln('    Vertices:  ${vertices.length}');
        case PdfLinkAnnotation(:final uri):
          if (uri != null) {
            stdout.writeln('    URI:       $uri');
          }
        case PdfUnknownAnnotation(:final rawSubtype):
          stdout.writeln('    Raw type:  $rawSubtype');
        case PdfTextAnnotation():
        case PdfFreeTextAnnotation():
        case PdfStampAnnotation():
          break;
      }
    }
  }
}

/// Returns a display name for the annotation type.
String _annotTypeName(PdfAnnotation annot) => switch (annot) {
  PdfTextAnnotation() => 'Text (sticky note)',
  PdfFreeTextAnnotation() => 'Free Text',
  PdfMarkupAnnotation(:final subtype) => switch (subtype) {
    PdfAnnotationType.highlight => 'Highlight',
    PdfAnnotationType.underline => 'Underline',
    PdfAnnotationType.squiggly => 'Squiggly underline',
    PdfAnnotationType.strikeout => 'Strikethrough',
    _ => 'Markup (${subtype.name})',
  },
  PdfShapeAnnotation(:final subtype) => switch (subtype) {
    PdfAnnotationType.square => 'Rectangle',
    PdfAnnotationType.circle => 'Ellipse',
    _ => 'Shape (${subtype.name})',
  },
  PdfLineAnnotation() => 'Line',
  PdfInkAnnotation() => 'Ink',
  PdfPolygonAnnotation(:final subtype) => switch (subtype) {
    PdfAnnotationType.polygon => 'Polygon',
    PdfAnnotationType.polyline => 'Polyline',
    _ => 'Polygon (${subtype.name})',
  },
  PdfLinkAnnotation() => 'Link',
  PdfStampAnnotation() => 'Stamp',
  PdfUnknownAnnotation() => 'Unknown',
};

// ---------------------------------------------------------------------------
// JSON annotation output
// ---------------------------------------------------------------------------

/// Serialises a page's annotations to a JSON-compatible map.
Map<String, dynamic> _pageAnnotationsToJson(PdfPageAnnotations page) => {
  'pageIndex': page.pageIndex,
  'annotations': page.annotations.map(_annotationToJson).toList(),
};

/// Serialises a single [PdfAnnotation] to a JSON-compatible map.
///
/// Fields that are not applicable to a given subtype are omitted from the
/// output rather than included as null, to keep the JSON concise.
Map<String, dynamic> _annotationToJson(PdfAnnotation annot) {
  final Map<String, dynamic> map = {
    'type': _annotTypeName(annot),
    'flags': annot.flags,
  };

  if (annot.contents != null) map['contents'] = annot.contents;
  if (annot.author != null) map['author'] = annot.author;
  if (annot.rect != null) {
    final r = annot.rect!;
    map['rect'] = {
      'left': r.left,
      'bottom': r.bottom,
      'right': r.right,
      'top': r.top,
    };
  }
  if (annot.color != null) {
    map['color'] = _colorToJson(annot.color!);
  }
  if (annot.modifiedDate != null) {
    map['modifiedDate'] = _dateToJson(annot.modifiedDate!);
  }
  if (annot.popup != null) {
    map['popup'] = {
      'flags': annot.popup!.flags,
      if (annot.popup!.rect != null)
        'rect': {
          'left': annot.popup!.rect!.left,
          'bottom': annot.popup!.rect!.bottom,
          'right': annot.popup!.rect!.right,
          'top': annot.popup!.rect!.top,
        },
    };
  }

  // Subtype-specific fields.
  switch (annot) {
    case PdfMarkupAnnotation(
      :final subtype,
      :final quadPoints,
      :final markedText,
    ):
      map['subtype'] = subtype.name;
      if (markedText != null) map['markedText'] = markedText;
      map['quadPoints'] = quadPoints
          .map(
            (q) => [
              {'x': q.p1.x, 'y': q.p1.y},
              {'x': q.p2.x, 'y': q.p2.y},
              {'x': q.p3.x, 'y': q.p3.y},
              {'x': q.p4.x, 'y': q.p4.y},
            ],
          )
          .toList();
    case PdfShapeAnnotation(:final subtype, :final interiorColor):
      map['subtype'] = subtype.name;
      if (interiorColor != null) {
        map['interiorColor'] = _colorToJson(interiorColor);
      }
    case PdfLineAnnotation(:final lineStart, :final lineEnd):
      map['lineStart'] = {'x': lineStart.x, 'y': lineStart.y};
      map['lineEnd'] = {'x': lineEnd.x, 'y': lineEnd.y};
    case PdfInkAnnotation(:final strokes):
      map['strokes'] = strokes
          .map((s) => s.map((p) => {'x': p.x, 'y': p.y}).toList())
          .toList();
    case PdfPolygonAnnotation(:final subtype, :final vertices):
      map['subtype'] = subtype.name;
      map['vertices'] = vertices.map((p) => {'x': p.x, 'y': p.y}).toList();
    case PdfLinkAnnotation(:final uri):
      if (uri != null) map['uri'] = uri;
    case PdfUnknownAnnotation(:final rawSubtype):
      map['rawSubtype'] = rawSubtype;
    case PdfTextAnnotation():
    case PdfFreeTextAnnotation():
    case PdfStampAnnotation():
      break;
  }

  return map;
}

Map<String, dynamic> _colorToJson(PdfColor c) => {
  'r': c.r,
  'g': c.g,
  'b': c.b,
  'a': c.a,
};

// ---------------------------------------------------------------------------
// Plain text TOC output
// ---------------------------------------------------------------------------

/// Prints the bookmark/outline tree in an indented human-readable format.
///
/// Each entry is printed as `<indent><title> → page <n>` (1-based), or
/// `<indent><title> → <uri>` for URI entries, or `<indent><title>` for
/// section-label entries with no target. Two spaces of indentation are added
/// per nesting level.
///
/// When [entries] is empty, a "(no bookmarks)" message is printed.
void _printPlainToc(List<PdfTocEntry> entries) {
  _printSection('Table of Contents');

  if (entries.isEmpty) {
    stdout.writeln('  (no bookmarks)');
    return;
  }

  void printEntries(List<PdfTocEntry> items, int depth) {
    final indent = '  ' * (depth + 1);
    for (final entry in items) {
      final String target;
      if (entry.pageIndex != null) {
        target = ' → page ${entry.pageIndex! + 1}';
      } else if (entry.uri != null) {
        target = ' → ${entry.uri}';
      } else {
        target = '';
      }
      stdout.writeln('$indent${entry.title}$target');
      if (entry.children.isNotEmpty) {
        printEntries(entry.children, depth + 1);
      }
    }
  }

  printEntries(entries, 0);
}

// ---------------------------------------------------------------------------
// JSON TOC output
// ---------------------------------------------------------------------------

/// Serialises a [PdfTocEntry] to a JSON-compatible map, recursively including
/// children.
Map<String, dynamic> _tocEntryToJson(PdfTocEntry entry) {
  final map = <String, dynamic>{'title': entry.title};
  if (entry.pageIndex != null) map['pageIndex'] = entry.pageIndex;
  if (entry.uri != null) map['uri'] = entry.uri;
  if (entry.scrollPosition != null) {
    map['scrollPosition'] = {
      'x': entry.scrollPosition!.x,
      'y': entry.scrollPosition!.y,
    };
  }
  if (entry.children.isNotEmpty) {
    map['children'] = entry.children.map(_tocEntryToJson).toList();
  }
  return map;
}

// ---------------------------------------------------------------------------
// Plain text search output
// ---------------------------------------------------------------------------

/// Prints search results in a human-readable format.
///
/// Each match is printed with its one-based page number, character index,
/// character count, and bounding rectangles. Coordinates are in PDF user space
/// (origin bottom-left, units in points).
void _printPlainSearch(String query, List<PdfSearchMatch> matches) {
  _printSection('Search Results for "$query"');

  if (matches.isEmpty) {
    stdout.writeln('  (no matches found)');
    return;
  }

  stdout.writeln('  Total matches: ${matches.length}');

  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    stdout.writeln('');
    stdout.writeln(
      '  Match ${i + 1}: page ${m.pageIndex + 1}, '
      'char ${m.charIndex} (${m.charCount} chars)',
    );
    for (var r = 0; r < m.rects.length; r++) {
      final rect = m.rects[r];
      stdout.writeln(
        '    Rect ${r + 1}: [${rect.left.toStringAsFixed(2)}, '
        '${rect.bottom.toStringAsFixed(2)}, '
        '${rect.right.toStringAsFixed(2)}, '
        '${rect.top.toStringAsFixed(2)}]',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// JSON search output
// ---------------------------------------------------------------------------

/// Serialises a [PdfSearchMatch] to a JSON-compatible map.
Map<String, dynamic> _searchMatchToJson(PdfSearchMatch match) => {
  'pageIndex': match.pageIndex,
  'charIndex': match.charIndex,
  'charCount': match.charCount,
  'rects': match.rects
      .map(
        (r) => {
          'left': r.left,
          'bottom': r.bottom,
          'right': r.right,
          'top': r.top,
        },
      )
      .toList(),
};
