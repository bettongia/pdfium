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

// PdfiumIsolate — process-wide singleton that owns the PDFium dynamic library
// and routes all PDFium FFI calls through a dedicated Dart Isolate.
//
// Design rationale:
//
//   PDFium is not thread-safe. FPDF_InitLibraryWithConfig() is a one-time
//   process-wide call; spawning a second isolate would call it again, which is
//   a correctness bug (double initialisation). All PDFium operations must
//   therefore happen on a single dedicated isolate — the "PDFium isolate".
//
//   PdfiumIsolate is the native-platform singleton that owns this isolate.
//   All PdfDocument instances share it. The isolate is lazily spawned on the
//   first PdfDocument.fromBytes() call and held for the lifetime of the process.
//   It is never torn down when documents are closed, because re-spawning for
//   each document would re-initialise PDFium unnecessarily.
//
//   All public PdfDocument methods are Future-returning; callers never interact
//   with the isolate directly.
//
// Isolate boundary note:
//
//   dart:ffi Pointer values cannot cross isolate boundaries (they are
//   platform-specific addresses). Document handles are therefore stored in a
//   registry inside the PDFium isolate and exposed to callers as opaque
//   integer tokens (the pointer address cast to int). The token is meaningless
//   outside the PDFium isolate.

import 'dart:ffi' as ffi;
import 'dart:io' show Directory, File, Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../generated/pdfium_bindings.dart';
import '../pdfium_version.dart';
import '../rendering/pdf_page_size.dart';
import 'isolate_messages.dart';
import 'pdf_date_parser.dart';
import 'pdf_types.dart';

// ---------------------------------------------------------------------------
// Isolate entry point (runs entirely inside the spawned isolate)
// ---------------------------------------------------------------------------

/// The entry point for the PDFium isolate.
///
/// This is a top-level function (required by [Isolate.spawn]). It runs
/// entirely within the spawned isolate and handles all PDFium FFI calls.
///
/// [bootstrapPort] is the [SendPort] on which the main isolate listens for
/// the [PdfiumInitCommand], which provides the dylib path and the reply port.
void pdfiumIsolateEntryPoint(SendPort bootstrapPort) {
  // Create the isolate's receive port for all commands after initialisation.
  final commandReceivePort = ReceivePort();

  // Registry: maps opaque int tokens to _DocumentEntry records.
  // Tokens are assigned as monotonically increasing integers.
  //
  // Each entry stores both the FPDF_DOCUMENT pointer address and the address
  // of the native Uint8 buffer that holds the raw PDF bytes. PDFium's
  // FPDF_LoadMemDocument64 does NOT copy the caller's buffer — the buffer
  // must remain allocated for the entire lifetime of the open document.
  // The buffer is freed in _handleCloseDocument alongside FPDF_CloseDocument.
  //
  // Addresses are stored as ints because dart:ffi Pointer values cannot be
  // stored in closures across message handling boundaries in a way the Dart VM
  // can safely GC. The int address is reconstructed into a Pointer inside the
  // isolate when needed.
  final Map<int, ({int docAddress, int bufferAddress})> openDocuments = {};
  var nextToken = 1;

  PdfiumBindings? bindings;

  // Listen for all incoming messages on the command port.
  commandReceivePort.listen((dynamic message) {
    if (message is PdfiumInitCommand) {
      // Initialise the library and send the command port back.
      try {
        final dylib = message.dylibPath != null
            ? ffi.DynamicLibrary.open(message.dylibPath!)
            : _openLibrary();
        bindings = PdfiumBindings(dylib);
        bindings!.FPDF_InitLibraryWithConfig(ffi.nullptr);
        message.replyPort.send(PdfiumInitResponse(commandReceivePort.sendPort));
      } catch (e) {
        // Signal failure by sending a null port — the main isolate will throw.
        message.replyPort.send(PdfiumInitFailedResponse('$e'));
      }
    } else if (bindings == null) {
      // Commands received before initialisation are ignored (should not happen
      // in normal use, since ensureInitialised() awaits PdfiumInitResponse).
    } else {
      // All non-init commands: dispatch with a top-level catch so that any
      // unhandled exception surfaces as an error response (instead of
      // silently killing the isolate and causing 30-second timeouts).
      try {
        if (message is PdfiumLoadDocumentCommand) {
          _handleLoadDocument(
            message,
            bindings!,
            openDocuments,
            nextToken,
            (t) => nextToken = t,
          );
        } else if (message is PdfiumGetMetadataCommand) {
          _handleGetMetadata(message, bindings!, openDocuments);
        } else if (message is PdfiumGetDocumentInfoCommand) {
          _handleGetDocumentInfo(message, bindings!, openDocuments);
        } else if (message is PdfiumCloseDocumentCommand) {
          _handleCloseDocument(message, bindings!, openDocuments);
        } else if (message is PdfiumGetPageCountCommand) {
          _handleGetPageCount(message, bindings!, openDocuments);
        } else if (message is PdfiumExtractPageTextCommand) {
          _handleExtractPageText(message, bindings!, openDocuments);
        } else if (message is PdfiumExtractPageAnnotationsCommand) {
          _handleExtractPageAnnotations(message, bindings!, openDocuments);
        } else if (message is PdfiumGetPageSizeCommand) {
          _handleGetPageSize(message, bindings!, openDocuments);
        } else if (message is PdfiumRenderPageCommand) {
          _handleRenderPage(message, bindings!, openDocuments);
        } else if (message is PdfiumGetTocCommand) {
          _handleGetToc(message, bindings!, openDocuments);
        } else if (message is PdfiumExtractPageImagesCommand) {
          _handleExtractPageImages(message, bindings!, openDocuments);
        } else if (message is PdfiumRenderImageCommand) {
          _handleRenderImage(message, bindings!, openDocuments);
        } else if (message is PdfiumSearchPageCommand) {
          _handleSearchPage(message, bindings!, openDocuments);
        } else if (message is PdfiumGetPageThumbnailCommand) {
          _handleGetPageThumbnail(message, bindings!, openDocuments);
        }
      } catch (e, stack) {
        // An unhandled exception in a command handler must never silently kill
        // the isolate — that produces 30-second timeouts with no diagnostics.
        // Send a PdfiumHandlerErrorResponse so the main isolate surfaces the
        // exception message in its StateError instead of just timing out.
        if (message is PdfiumCommand) {
          message.replyPort.send(PdfiumHandlerErrorResponse('$e', '$stack'));
        }
      }
    }
  });

  // Send the command port to the main isolate immediately. The main isolate
  // then sends PdfiumInitCommand on this port before any other commands.
  bootstrapPort.send(commandReceivePort.sendPort);
}

// ---------------------------------------------------------------------------
// Command handlers (run inside the spawned isolate)
// ---------------------------------------------------------------------------

/// Loads a PDF document from bytes and registers it in the open-documents map.
void _handleLoadDocument(
  PdfiumLoadDocumentCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
  int currentToken,
  void Function(int) updateToken,
) {
  final bytes = cmd.bytes;

  // Allocate a native buffer and copy the PDF bytes into it.
  //
  // IMPORTANT: FPDF_LoadMemDocument64 does NOT copy the caller's buffer — it
  // maps the provided memory for the lifetime of the open document. The buffer
  // must remain allocated until FPDF_CloseDocument is called. We store the
  // buffer address in the registry alongside the document pointer and free it
  // in _handleCloseDocument (or on load failure below).
  final nativePtr = calloc<ffi.Uint8>(bytes.length);
  final nativeList = nativePtr.asTypedList(bytes.length);
  nativeList.setAll(0, bytes);

  // FPDF_LoadMemDocument64 returns a null pointer on failure.
  // We pass ffi.nullptr for password — open (unencrypted) documents only.
  final docPtr = bindings.FPDF_LoadMemDocument64(
    nativePtr.cast<ffi.Void>(),
    bytes.length,
    ffi.nullptr, // no password
  );

  if (docPtr == ffi.nullptr) {
    // Load failed — free the buffer immediately since no document holds it.
    calloc.free(nativePtr);
    // FPDF_ERR_PASSWORD = 4 (defined in fpdfview.h)
    final errorCode = bindings.FPDF_GetLastError();
    final error = errorCode == 4
        ? PdfError.passwordRequired
        : PdfError.invalidDocument;
    cmd.replyPort.send(PdfiumLoadDocumentResponse.failure(error));
  } else {
    // Store both the document pointer address and the buffer address.
    // The buffer is freed when the document is closed via _handleCloseDocument.
    final token = currentToken;
    updateToken(currentToken + 1);
    openDocuments[token] = (
      docAddress: docPtr.address,
      bufferAddress: nativePtr.address,
    );
    cmd.replyPort.send(PdfiumLoadDocumentResponse.success(token));
  }
}

/// Reads all eight Info dictionary fields from an open document.
void _handleGetMetadata(
  PdfiumGetMetadataCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumGetMetadataResponse.failure(PdfError.invalidDocument),
    );
    return;
  }

  // Reconstruct the FPDF_DOCUMENT pointer from the stored address.
  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);

  // The eight standard PDF Info dictionary tags.
  const fieldNames = <String>[
    'Title',
    'Author',
    'Subject',
    'Keywords',
    'Creator',
    'Producer',
    'CreationDate',
    'ModDate',
  ];

  final values = <String, String?>{};
  for (final tag in fieldNames) {
    values[tag] = _readMetaText(bindings, docPtr, tag);
  }

  final metadata = PdfMetadata(
    title: values['Title'],
    author: values['Author'],
    subject: values['Subject'],
    keywords: values['Keywords'],
    creator: values['Creator'],
    producer: values['Producer'],
    creationDate: PdfDateParser.parse(values['CreationDate']),
    modDate: PdfDateParser.parse(values['ModDate']),
  );

  cmd.replyPort.send(PdfiumGetMetadataResponse.success(metadata));
}

/// Reads a single metadata field using the PDFium two-call buffer pattern.
///
/// Returns the field value, or `null` when the field is absent in the Info
/// dictionary. An absent field is indicated by a 2-byte result (a single
/// UTF-16LE null character — an empty string).
String? _readMetaText(
  PdfiumBindings bindings,
  ffi.Pointer<fpdf_document_t__> docPtr,
  String tag,
) {
  // Encode the tag as a null-terminated UTF-8 C string.
  // We use package:ffi's toNativeUtf8() for correctness (handles non-ASCII).
  final tagCStr = tag.toNativeUtf8(allocator: calloc);
  try {
    final tagPtr = tagCStr.cast<ffi.Char>();

    // First call: pass null buffer / zero length to get the required byte count.
    final requiredLen = bindings.FPDF_GetMetaText(
      docPtr,
      tagPtr,
      ffi.nullptr,
      0,
    );

    // A length of 0 or 2 means the field is absent. An empty UTF-16LE string
    // consists of a single null character = 2 bytes.
    if (requiredLen <= 2) return null;

    // Second call: allocate the buffer and fill it.
    final buffer = calloc<ffi.Uint8>(requiredLen);
    try {
      bindings.FPDF_GetMetaText(
        docPtr,
        tagPtr,
        buffer.cast<ffi.Void>(),
        requiredLen,
      );

      // Decode UTF-16LE. The buffer is (requiredLen) bytes; the last 2 are
      // the UTF-16LE null terminator — exclude them.
      final byteCount = requiredLen - 2;
      if (byteCount <= 0) return null;

      final codeUnits = <int>[];
      for (var i = 0; i < byteCount; i += 2) {
        // Little-endian: low byte at i, high byte at i+1.
        final codeUnit = buffer[i] | (buffer[i + 1] << 8);
        codeUnits.add(codeUnit);
      }

      final result = String.fromCharCodes(codeUnits);
      return result.isEmpty ? null : result;
    } finally {
      calloc.free(buffer);
    }
  } finally {
    calloc.free(tagCStr);
  }
}

/// Reads document-level properties (version and file identifiers).
void _handleGetDocumentInfo(
  PdfiumGetDocumentInfoCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumGetDocumentInfoResponse.failure(PdfError.invalidDocument),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);

  // Read the PDF file version (e.g. 17 for PDF 1.7).
  int? fileVersion;
  final versionPtr = calloc<ffi.Int>();
  try {
    final ok = bindings.FPDF_GetFileVersion(docPtr, versionPtr);
    if (ok != 0) {
      fileVersion = versionPtr.value;
    }
  } finally {
    calloc.free(versionPtr);
  }

  // Read both file identifiers (permanent and changing).
  final permanentId = _readFileIdentifier(
    bindings,
    docPtr,
    FPDF_FILEIDTYPE.FILEIDTYPE_PERMANENT,
  );
  final changingId = _readFileIdentifier(
    bindings,
    docPtr,
    FPDF_FILEIDTYPE.FILEIDTYPE_CHANGING,
  );

  cmd.replyPort.send(
    PdfiumGetDocumentInfoResponse.success(
      PdfDocumentInfo(
        fileVersion: fileVersion,
        permanentId: permanentId,
        changingId: changingId,
      ),
    ),
  );
}

/// Reads a file identifier using the two-call buffer pattern.
///
/// Returns the raw identifier bytes, or `null` if not present.
Uint8List? _readFileIdentifier(
  PdfiumBindings bindings,
  ffi.Pointer<fpdf_document_t__> docPtr,
  FPDF_FILEIDTYPE idType,
) {
  // First call: determine required buffer size (in bytes).
  final requiredLen = bindings.FPDF_GetFileIdentifier(
    docPtr,
    idType,
    ffi.nullptr,
    0,
  );

  if (requiredLen == 0) return null;

  // Second call: fill the buffer.
  final buffer = calloc<ffi.Uint8>(requiredLen);
  try {
    final ok = bindings.FPDF_GetFileIdentifier(
      docPtr,
      idType,
      buffer.cast<ffi.Void>(),
      requiredLen,
    );

    if (ok == 0) return null;

    // Copy the raw bytes into a Dart Uint8List before freeing the native buffer.
    final result = Uint8List(requiredLen);
    final nativeView = buffer.asTypedList(requiredLen);
    result.setAll(0, nativeView);
    return result;
  } finally {
    calloc.free(buffer);
  }
}

/// Closes a document and removes it from the open-documents registry.
///
/// Both the PDFium document handle and the raw PDF byte buffer are released
/// here. The buffer was kept alive to satisfy FPDF_LoadMemDocument64's
/// requirement that the caller's memory remain valid for the document lifetime.
void _handleCloseDocument(
  PdfiumCloseDocumentCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments.remove(cmd.token);
  if (entry != null) {
    final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);
    bindings.FPDF_CloseDocument(docPtr);
    // Free the raw PDF byte buffer that was held alive for the document lifetime.
    calloc.free(ffi.Pointer<ffi.Uint8>.fromAddress(entry.bufferAddress));
  }
  // Always respond — close is idempotent (double-close is a no-op).
  cmd.replyPort.send(const PdfiumCloseDocumentResponse());
}

/// Returns the page count for an open document.
void _handleGetPageCount(
  PdfiumGetPageCountCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumGetPageCountResponse.failure(PdfError.invalidDocument),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);
  final count = bindings.FPDF_GetPageCount(docPtr);
  cmd.replyPort.send(PdfiumGetPageCountResponse.success(count));
}

/// Extracts plain text from a single page of an open document.
///
/// Handles the full RAII lifecycle within this function:
///   1. Load page handle via FPDF_LoadPage.
///   2. Load text page handle via FPDFText_LoadPage.
///   3. Extract text using the two-call buffer pattern.
///   4. Detect unicode errors and soft hyphens character-by-character.
///   5. Close text page then close page (reverse order of opening).
///
/// All resources are released in finally blocks so that even if an
/// exception occurs, handles are not leaked.
void _handleExtractPageText(
  PdfiumExtractPageTextCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumExtractPageTextResponse.failure(
        PdfError.invalidDocument,
        cmd.pageIndex,
      ),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);

  // Load the page handle. Returns null pointer on failure.
  final pagePtr = bindings.FPDF_LoadPage(docPtr, cmd.pageIndex);
  if (pagePtr == ffi.nullptr) {
    cmd.replyPort.send(
      PdfiumExtractPageTextResponse.failure(
        PdfError.invalidDocument,
        cmd.pageIndex,
      ),
    );
    return;
  }

  try {
    // Load the text page handle. Returns null pointer on failure.
    final textPagePtr = bindings.FPDFText_LoadPage(pagePtr);
    if (textPagePtr == ffi.nullptr) {
      // Treat a text-load failure as a page with no text layer rather than
      // an error — some PDF object types legitimately have no text stream.
      cmd.replyPort.send(
        PdfiumExtractPageTextResponse.success(
          pageIndex: cmd.pageIndex,
          text: '',
          hasUnicodeErrors: false,
          hasTextLayer: false,
        ),
      );
      return;
    }

    try {
      final charCount = bindings.FPDFText_CountChars(textPagePtr);

      // Detect unicode errors and soft hyphens in a single character pass.
      // This avoids serialising raw per-character data across the isolate
      // boundary — the work is done here, inside the isolate.
      var hasUnicodeErrors = false;
      // Track indices of soft-hyphen characters (U+00AD) so we can strip
      // them and join surrounding words after full text extraction.
      final softHyphenIndices = <int>{};

      for (var i = 0; i < charCount; i++) {
        // FPDFText_HasUnicodeMapError returns non-zero when the character
        // at index i has a broken Unicode mapping.
        if (bindings.FPDFText_HasUnicodeMapError(textPagePtr, i) != 0) {
          hasUnicodeErrors = true;
        }
        // FPDFText_IsHyphen returns non-zero for soft hyphen (U+00AD)
        // at a line-break position.
        if (bindings.FPDFText_IsHyphen(textPagePtr, i) != 0) {
          softHyphenIndices.add(i);
        }
      }

      // Extract the full text using the two-call buffer pattern.
      // FPDFText_GetText writes UTF-16LE into a Pointer<UnsignedShort>
      // (i.e. 2 bytes per code unit). We request all characters.
      final String extractedText;
      if (charCount <= 0) {
        extractedText = '';
      } else {
        // Buffer must be large enough for charCount UTF-16LE code units plus
        // one null terminator — FPDFText_GetText always null-terminates.
        final bufferCodeUnits = charCount + 1;
        final buffer = calloc<ffi.UnsignedShort>(bufferCodeUnits);
        try {
          final written = bindings.FPDFText_GetText(
            textPagePtr,
            0, // start_index
            charCount, // count
            buffer,
          );
          if (written <= 0) {
            extractedText = '';
          } else {
            // Decode UTF-16LE code units (excluding the null terminator).
            // written is the number of UTF-16LE code units written, including
            // the null terminator, so use (written - 1) characters.
            final codeUnits = <int>[];
            for (var i = 0; i < written - 1; i++) {
              codeUnits.add(buffer[i]);
            }
            extractedText = String.fromCharCodes(codeUnits);
          }
        } finally {
          calloc.free(buffer);
        }
      }

      // Post-process: strip soft hyphens at line-break positions.
      // A soft hyphen at a line break should be removed and the words joined.
      // Soft hyphens that are NOT at line breaks (i.e. not in
      // softHyphenIndices) are preserved as-is by PDFium; we only act on
      // the ones FPDFText_IsHyphen identified.
      //
      // Implementation: build a list of characters from the extracted string,
      // removing code points at indices that are soft hyphens. Then strip
      // any whitespace that was inserted purely to separate the now-joined
      // word fragments (i.e. newlines or spaces immediately adjacent to a
      // removed soft hyphen position).
      final processedText = softHyphenIndices.isEmpty
          ? extractedText
          : _stripSoftHyphens(extractedText, softHyphenIndices);

      // A page has a text layer if PDFium could extract at least one character.
      // Scanned/image-only pages yield charCount == 0.
      final hasTextLayer = charCount > 0;

      cmd.replyPort.send(
        PdfiumExtractPageTextResponse.success(
          pageIndex: cmd.pageIndex,
          text: processedText,
          hasUnicodeErrors: hasUnicodeErrors,
          hasTextLayer: hasTextLayer,
        ),
      );
    } finally {
      // Always close the text page handle, even if an exception was thrown.
      bindings.FPDFText_ClosePage(textPagePtr);
    }
  } finally {
    // Always close the page handle after the text page handle is closed.
    bindings.FPDF_ClosePage(pagePtr);
  }
}

/// Strips soft hyphens at line-break positions from extracted text and joins
/// the surrounding word fragments.
///
/// [text] is the raw extracted text. [softHyphenIndices] is the set of
/// character indices (in the PDFium character stream) where
/// `FPDFText_IsHyphen` returned non-zero.
///
/// The PDFium character stream and the extracted string have a 1:1 mapping
/// at the code-unit level (both are UTF-16LE). We exploit this to remove
/// the soft hyphens and any adjacent whitespace that was used to break the
/// word across lines.
String _stripSoftHyphens(String text, Set<int> softHyphenIndices) {
  // Convert to a list of runes for index-stable processing.
  // Note: PDFium uses UTF-16LE code units; String.fromCharCodes also builds
  // from UTF-16 code units. For BMP characters (the vast majority of PDF
  // text), rune index == code unit index. For surrogate pairs the indices
  // diverge, but FPDFText_IsHyphen only applies to U+00AD (BMP), so the
  // soft hyphen index in the code-unit stream directly corresponds to the
  // character's position in the decoded string.
  final buffer = StringBuffer();
  var skipNextWhitespace = false;

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];

    // If the previous character was a stripped soft hyphen, skip the
    // newline or space that was separating the two word fragments.
    if (skipNextWhitespace && (ch == '\n' || ch == '\r' || ch == ' ')) {
      skipNextWhitespace = false;
      continue;
    }
    skipNextWhitespace = false;

    if (softHyphenIndices.contains(i)) {
      // This is a soft hyphen at a line-break position — strip it.
      // Set the flag to also consume the following whitespace character.
      skipNextWhitespace = true;
      continue;
    }

    buffer.write(ch);
  }

  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Annotation extraction handler (runs inside the spawned isolate)
// ---------------------------------------------------------------------------

/// Extracts all annotations from a single page, performing popup parent-linking.
///
/// Algorithm:
///   1. Open the page via [FPDF_LoadPage].
///   2. First pass: iterate every annotation. For each non-POPUP annotation,
///      extract all fields and add to [nonPopupAnnotations] keyed by index.
///      For each POPUP annotation, record the handle address and index for the
///      second pass.
///   3. Second pass: for each recorded POPUP, call
///      [FPDFAnnot_GetLinkedAnnot] with key `"IRT"` to find the parent
///      annotation, then inline the popup data onto the matching entry.
///   4. Close all handles and send the response.
///
/// The two-pass approach is required because a popup may appear at any index
/// relative to its parent in the annotation list.
void _handleExtractPageAnnotations(
  PdfiumExtractPageAnnotationsCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumExtractPageAnnotationsResponse.failure(
        PdfError.invalidDocument,
        cmd.pageIndex,
      ),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);
  final pagePtr = bindings.FPDF_LoadPage(docPtr, cmd.pageIndex);
  if (pagePtr == ffi.nullptr) {
    cmd.replyPort.send(
      PdfiumExtractPageAnnotationsResponse.failure(
        PdfError.invalidDocument,
        cmd.pageIndex,
      ),
    );
    return;
  }

  try {
    final annotCount = bindings.FPDFPage_GetAnnotCount(pagePtr);

    // --- First pass: extract non-POPUP annotations and record POPUP handles ---

    // Maps annotation index → extracted PdfAnnotation (mutable so we can set
    // the popup field in the second pass). We use a plain list here and replace
    // entries with popup-linked versions in the second pass.
    final List<PdfAnnotation?> extracted = List.filled(annotCount, null);

    // For each POPUP found in the first pass, record:
    //   (annotIndex, annotHandleAddress) so the second pass can reopen the
    //   handle and call FPDFAnnot_GetLinkedAnnot.
    final popupHandleAddresses = <int, int>{}; // annotIndex → handle address

    for (var i = 0; i < annotCount; i++) {
      final annotPtr = bindings.FPDFPage_GetAnnot(pagePtr, i);
      if (annotPtr == ffi.nullptr) continue;

      try {
        final subtypeInt = bindings.FPDFAnnot_GetSubtype(annotPtr);

        if (subtypeInt == 16) {
          // FPDF_ANNOT_POPUP = 16 — defer to second pass.
          // We cannot close the handle yet; we need to reopen it in pass 2.
          // Store the address so we can reconstruct it without re-opening.
          popupHandleAddresses[i] = annotPtr.address;
          // Do NOT close annotPtr here — we'll close it in the second pass.
          continue;
        }

        // Extract common fields shared by all annotation subtypes.
        final contents = _readAnnotStringValue(bindings, annotPtr, 'Contents');
        final author = _readAnnotStringValue(bindings, annotPtr, 'T');
        final modDateStr = _readAnnotStringValue(bindings, annotPtr, 'M');
        final modifiedDate = PdfDateParser.parse(modDateStr);
        final flags = bindings.FPDFAnnot_GetFlags(annotPtr);
        final rect = _readAnnotRect(bindings, annotPtr);
        final color = _readAnnotColor(
          bindings,
          annotPtr,
          FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
        );

        extracted[i] = _buildAnnotation(
          bindings: bindings,
          annotPtr: annotPtr,
          subtypeInt: subtypeInt,
          pageIndex: cmd.pageIndex,
          contents: contents,
          author: author,
          rect: rect,
          color: color,
          modifiedDate: modifiedDate,
          flags: flags,
          docPtr: docPtr,
          pagePtr: pagePtr,
        );
      } finally {
        // Skip closing popup handles here; they are closed in the second pass.
        if (!popupHandleAddresses.containsValue(annotPtr.address)) {
          bindings.FPDFPage_CloseAnnot(annotPtr);
        }
      }
    }

    // --- Second pass: match POPUP annotations to their parents ---
    for (final entry in popupHandleAddresses.entries) {
      final popupPtr = ffi.Pointer<fpdf_annotation_t__>.fromAddress(
        entry.value,
      );

      try {
        // FPDFAnnot_GetLinkedAnnot with key "IRT" (In-Reply-To) retrieves the
        // parent annotation that this popup belongs to.
        final irtKey = 'IRT'.toNativeUtf8(allocator: calloc);
        try {
          final parentPtr = bindings.FPDFAnnot_GetLinkedAnnot(
            popupPtr,
            irtKey.cast<ffi.Char>(),
          );

          if (parentPtr != ffi.nullptr) {
            try {
              // Identify the parent by its index in the page annotation list.
              final parentIndex = bindings.FPDFPage_GetAnnotIndex(
                pagePtr,
                parentPtr,
              );

              if (parentIndex >= 0 &&
                  parentIndex < annotCount &&
                  extracted[parentIndex] != null) {
                // Build the popup data and inline it on the parent.
                final popupRect = _readAnnotRect(bindings, popupPtr);
                final popupFlags = bindings.FPDFAnnot_GetFlags(popupPtr);
                final popupData = PdfPopupAnnotation(
                  rect: popupRect,
                  flags: popupFlags,
                );
                extracted[parentIndex] = _withPopup(
                  extracted[parentIndex]!,
                  popupData,
                );
              }
            } finally {
              bindings.FPDFPage_CloseAnnot(parentPtr);
            }
          }
        } finally {
          calloc.free(irtKey);
        }
      } finally {
        bindings.FPDFPage_CloseAnnot(popupPtr);
      }
    }

    // Collect non-null results in order, excluding nulls from skipped handles.
    final annotations = extracted
        .where((a) => a != null)
        .cast<PdfAnnotation>()
        .toList();

    cmd.replyPort.send(
      PdfiumExtractPageAnnotationsResponse.success(
        pageIndex: cmd.pageIndex,
        annotations: annotations,
      ),
    );
  } finally {
    bindings.FPDF_ClosePage(pagePtr);
  }
}

/// Reads a UTF-16LE string annotation dictionary value using the two-call
/// buffer pattern (same as [_readMetaText] but for annotation string keys).
///
/// Returns the string, or `null` if the key is absent (length <= 2 means
/// only the null terminator was returned), or `""` if the key exists but the
/// value is an empty string (length exactly 4: two null bytes for the UTF-16LE
/// empty string, plus the terminator pair... actually length == 2 is the
/// empty-string sentinel for absent, so absent and empty are both 2 bytes —
/// we return `null` for both as PDFium cannot distinguish them this way).
///
/// Note: `FPDFAnnot_GetStringValue` returns 2 when the key is absent OR when
/// the value is an empty string. We treat both as `null` (absent) here, which
/// is safe for `Contents` and `Author` fields where an empty string carries no
/// information.
String? _readAnnotStringValue(
  PdfiumBindings bindings,
  FPDF_ANNOTATION annotPtr,
  String key,
) {
  final keyCStr = key.toNativeUtf8(allocator: calloc);
  try {
    final keyPtr = keyCStr.cast<ffi.Char>();

    // First call: get required byte count.
    final requiredLen = bindings.FPDFAnnot_GetStringValue(
      annotPtr,
      keyPtr,
      ffi.nullptr,
      0,
    );

    // 0 = error; 2 = absent or empty string (UTF-16LE null terminator only).
    if (requiredLen <= 2) return null;

    // Second call: fill the buffer.
    // FPDFAnnot_GetStringValue writes UTF-16LE into a Pointer<UnsignedShort>.
    // requiredLen is in bytes; each UTF-16LE code unit is 2 bytes.
    final codeUnitCount = requiredLen ~/ 2;
    final buffer = calloc<ffi.UnsignedShort>(codeUnitCount);
    try {
      bindings.FPDFAnnot_GetStringValue(annotPtr, keyPtr, buffer, requiredLen);

      // Decode UTF-16LE code units, excluding the null terminator (last unit).
      final charCount = codeUnitCount - 1; // exclude null terminator
      if (charCount <= 0) return null;

      final codeUnits = <int>[];
      for (var i = 0; i < charCount; i++) {
        codeUnits.add(buffer[i]);
      }
      final result = String.fromCharCodes(codeUnits);
      // Per the plan edge-case decision: absent → null (handled by requiredLen
      // <= 2 above), empty string → null (no information content).
      return result.isEmpty ? null : result;
    } finally {
      calloc.free(buffer);
    }
  } finally {
    calloc.free(keyCStr);
  }
}

/// Reads the bounding rectangle of an annotation, or `null` on failure.
PdfRect? _readAnnotRect(PdfiumBindings bindings, FPDF_ANNOTATION annotPtr) {
  final rectPtr = calloc<FS_RECTF>();
  try {
    final ok = bindings.FPDFAnnot_GetRect(annotPtr, rectPtr);
    if (ok == 0) return null;
    // FS_RECTF fields: left, top, right, bottom.
    // Note: PDFium's FS_RECTF has top > bottom in PDF coordinate space
    // (bottom-left origin), so we preserve the raw values without swapping.
    return PdfRect(
      left: rectPtr.ref.left,
      bottom: rectPtr.ref.bottom,
      right: rectPtr.ref.right,
      top: rectPtr.ref.top,
    );
  } finally {
    calloc.free(rectPtr);
  }
}

/// Reads an annotation colour of the given [colorType], or `null` if the call
/// fails (e.g. the annotation has no colour or has an appearance stream).
PdfColor? _readAnnotColor(
  PdfiumBindings bindings,
  FPDF_ANNOTATION annotPtr,
  FPDFANNOT_COLORTYPE colorType,
) {
  final rPtr = calloc<ffi.UnsignedInt>();
  final gPtr = calloc<ffi.UnsignedInt>();
  final bPtr = calloc<ffi.UnsignedInt>();
  final aPtr = calloc<ffi.UnsignedInt>();
  try {
    final ok = bindings.FPDFAnnot_GetColor(
      annotPtr,
      colorType,
      rPtr,
      gPtr,
      bPtr,
      aPtr,
    );
    if (ok == 0) return null;
    return PdfColor(r: rPtr.value, g: gPtr.value, b: bPtr.value, a: aPtr.value);
  } finally {
    calloc.free(rPtr);
    calloc.free(gPtr);
    calloc.free(bPtr);
    calloc.free(aPtr);
  }
}

/// Reads all quad-point sets from a markup annotation.
///
/// Returns an empty list if the annotation has no attachment points or if
/// reading fails. Gracefully handles a count that does not match the actual
/// data by truncating.
List<PdfQuadPoints> _readAnnotQuadPoints(
  PdfiumBindings bindings,
  FPDF_ANNOTATION annotPtr,
) {
  final count = bindings.FPDFAnnot_CountAttachmentPoints(annotPtr);
  if (count == 0) return const [];

  final result = <PdfQuadPoints>[];
  final quadPtr = calloc<FS_QUADPOINTSF>();
  try {
    for (var i = 0; i < count; i++) {
      final ok = bindings.FPDFAnnot_GetAttachmentPoints(annotPtr, i, quadPtr);
      if (ok == 0) continue; // skip malformed quad

      result.add(
        PdfQuadPoints(
          p1: PdfPoint(x: quadPtr.ref.x1, y: quadPtr.ref.y1),
          p2: PdfPoint(x: quadPtr.ref.x2, y: quadPtr.ref.y2),
          p3: PdfPoint(x: quadPtr.ref.x3, y: quadPtr.ref.y3),
          p4: PdfPoint(x: quadPtr.ref.x4, y: quadPtr.ref.y4),
        ),
      );
    }
  } finally {
    calloc.free(quadPtr);
  }
  return result;
}

/// Extracts the text covered by a markup annotation's quad-point regions.
///
/// Uses [FPDFText_GetBoundedText] with the axis-aligned bounding box of each
/// quad. Returns null when the text page cannot be loaded (scanned/image-only
/// page), or a (possibly empty) string when the text layer exists.
String? _readMarkupMarkedText(
  PdfiumBindings bindings,
  FPDF_PAGE pagePtr,
  List<PdfQuadPoints> quadPoints,
) {
  if (quadPoints.isEmpty) return null;

  final textPagePtr = bindings.FPDFText_LoadPage(pagePtr);
  if (textPagePtr == ffi.nullptr) return null;

  try {
    final segments = <String>[];
    for (final quad in quadPoints) {
      // Compute the axis-aligned bounding box of the four quad corners.
      // PDF coordinate origin is bottom-left, so top = max(y) and bottom = min(y).
      var left = quad.p1.x;
      var right = quad.p1.x;
      var top = quad.p1.y;
      var bottom = quad.p1.y;
      for (final pt in [quad.p2, quad.p3, quad.p4]) {
        if (pt.x < left) left = pt.x;
        if (pt.x > right) right = pt.x;
        if (pt.y > top) top = pt.y;
        if (pt.y < bottom) bottom = pt.y;
      }

      // First call with null buffer to get character count in the region.
      final count = bindings.FPDFText_GetBoundedText(
        textPagePtr,
        left,
        top,
        right,
        bottom,
        ffi.nullptr,
        0,
      );
      if (count <= 0) continue;

      // Second call writes UTF-16LE code units (no null terminator).
      final buffer = calloc<ffi.UnsignedShort>(count);
      try {
        final written = bindings.FPDFText_GetBoundedText(
          textPagePtr,
          left,
          top,
          right,
          bottom,
          buffer,
          count,
        );
        if (written <= 0) continue;
        final codeUnits = <int>[];
        for (var i = 0; i < written; i++) {
          codeUnits.add(buffer[i]);
        }
        segments.add(String.fromCharCodes(codeUnits));
      } finally {
        calloc.free(buffer);
      }
    }
    return segments.join(' ');
  } finally {
    bindings.FPDFText_ClosePage(textPagePtr);
  }
}

/// Reads ink strokes from an `FPDF_ANNOT_INK` annotation.
///
/// Returns a list of strokes; each stroke is a list of [PdfPoint]s.
List<List<PdfPoint>> _readInkStrokes(
  PdfiumBindings bindings,
  FPDF_ANNOTATION annotPtr,
) {
  final strokeCount = bindings.FPDFAnnot_GetInkListCount(annotPtr);
  if (strokeCount == 0) return const [];

  final strokes = <List<PdfPoint>>[];
  for (var strokeIdx = 0; strokeIdx < strokeCount; strokeIdx++) {
    // First call: determine point count for this stroke.
    final pointCount = bindings.FPDFAnnot_GetInkListPath(
      annotPtr,
      strokeIdx,
      ffi.nullptr,
      0,
    );
    if (pointCount == 0) {
      strokes.add(const []);
      continue;
    }

    final buffer = calloc<FS_POINTF>(pointCount);
    try {
      final written = bindings.FPDFAnnot_GetInkListPath(
        annotPtr,
        strokeIdx,
        buffer,
        pointCount,
      );

      final points = <PdfPoint>[];
      for (var j = 0; j < written; j++) {
        points.add(PdfPoint(x: buffer[j].x, y: buffer[j].y));
      }
      strokes.add(points);
    } finally {
      calloc.free(buffer);
    }
  }
  return strokes;
}

/// Reads polygon or polyline vertices from an annotation.
List<PdfPoint> _readAnnotVertices(
  PdfiumBindings bindings,
  FPDF_ANNOTATION annotPtr,
) {
  // First call: get vertex count.
  final count = bindings.FPDFAnnot_GetVertices(annotPtr, ffi.nullptr, 0);
  if (count == 0) return const [];

  final buffer = calloc<FS_POINTF>(count);
  try {
    final written = bindings.FPDFAnnot_GetVertices(annotPtr, buffer, count);
    final vertices = <PdfPoint>[];
    for (var i = 0; i < written; i++) {
      vertices.add(PdfPoint(x: buffer[i].x, y: buffer[i].y));
    }
    return vertices;
  } finally {
    calloc.free(buffer);
  }
}

/// Reads the start and end points of a line annotation.
///
/// Returns a record of (start, end), or (null, null) on failure.
({PdfPoint? start, PdfPoint? end}) _readLineEndpoints(
  PdfiumBindings bindings,
  FPDF_ANNOTATION annotPtr,
) {
  final startPtr = calloc<FS_POINTF>();
  final endPtr = calloc<FS_POINTF>();
  try {
    final ok = bindings.FPDFAnnot_GetLine(annotPtr, startPtr, endPtr);
    if (ok == 0) return (start: null, end: null);
    return (
      start: PdfPoint(x: startPtr.ref.x, y: startPtr.ref.y),
      end: PdfPoint(x: endPtr.ref.x, y: endPtr.ref.y),
    );
  } finally {
    calloc.free(startPtr);
    calloc.free(endPtr);
  }
}

/// Reads the URI from a link annotation, or `null` if unavailable.
///
/// Uses [FPDFAnnot_GetLink] + [FPDFLink_GetAction] + [FPDFAction_GetType] +
/// [FPDFAction_GetURIPath] to extract the URI for `PDFACTION_URI` actions.
/// Non-URI actions (page destinations, launches, etc.) return `null`.
String? _readLinkUri(
  PdfiumBindings bindings,
  ffi.Pointer<fpdf_document_t__> docPtr,
  FPDF_ANNOTATION annotPtr,
) {
  final link = bindings.FPDFAnnot_GetLink(annotPtr);
  if (link == ffi.nullptr) return null;

  final action = bindings.FPDFLink_GetAction(link);
  if (action == ffi.nullptr) return null;

  // PDFACTION_URI = 3 (defined in fpdf_doc.h)
  final actionType = bindings.FPDFAction_GetType(action);
  if (actionType != 3) return null;

  // First call: determine the required buffer length (in bytes; ASCII string).
  final requiredLen = bindings.FPDFAction_GetURIPath(
    docPtr,
    action,
    ffi.nullptr,
    0,
  );
  if (requiredLen == 0) return null;

  // Second call: fill the buffer.
  final buffer = calloc<ffi.Uint8>(requiredLen);
  try {
    bindings.FPDFAction_GetURIPath(
      docPtr,
      action,
      buffer.cast<ffi.Void>(),
      requiredLen,
    );
    // The URI is a null-terminated ASCII/UTF-8 string.
    // requiredLen includes the null terminator.
    final uriBytes = buffer.asTypedList(requiredLen - 1);
    final uri = String.fromCharCodes(uriBytes);
    return uri.isEmpty ? null : uri;
  } finally {
    calloc.free(buffer);
  }
}

/// Maps a PDFium annotation subtype integer to the corresponding [PdfAnnotationType].
PdfAnnotationType _annotationTypeFromInt(int subtype) => switch (subtype) {
  1 => PdfAnnotationType.text,
  2 => PdfAnnotationType.link,
  3 => PdfAnnotationType.freeText,
  4 => PdfAnnotationType.line,
  5 => PdfAnnotationType.square,
  6 => PdfAnnotationType.circle,
  7 => PdfAnnotationType.polygon,
  8 => PdfAnnotationType.polyline,
  9 => PdfAnnotationType.highlight,
  10 => PdfAnnotationType.underline,
  11 => PdfAnnotationType.squiggly,
  12 => PdfAnnotationType.strikeout,
  13 => PdfAnnotationType.stamp,
  15 => PdfAnnotationType.ink,
  16 => PdfAnnotationType.popup,
  _ => PdfAnnotationType.unknown,
};

/// Constructs a [PdfAnnotation] subclass from the extracted fields.
PdfAnnotation _buildAnnotation({
  required PdfiumBindings bindings,
  required FPDF_ANNOTATION annotPtr,
  required int subtypeInt,
  required int pageIndex,
  required String? contents,
  required String? author,
  required PdfRect? rect,
  required PdfColor? color,
  required PdfDate? modifiedDate,
  required int flags,
  required ffi.Pointer<fpdf_document_t__> docPtr,
  required FPDF_PAGE pagePtr,
}) {
  // Markup subtypes: highlight, underline, squiggly, strikeout.
  if (subtypeInt == 9 ||
      subtypeInt == 10 ||
      subtypeInt == 11 ||
      subtypeInt == 12) {
    final subtype = _annotationTypeFromInt(subtypeInt);
    final quadPoints = _readAnnotQuadPoints(bindings, annotPtr);
    final markedText = _readMarkupMarkedText(bindings, pagePtr, quadPoints);
    return PdfMarkupAnnotation(
      pageIndex: pageIndex,
      subtype: subtype,
      quadPoints: quadPoints,
      markedText: markedText,
      contents: contents,
      author: author,
      rect: rect,
      color: color,
      modifiedDate: modifiedDate,
      flags: flags,
    );
  }

  // Shape subtypes: square (rectangle) and circle (ellipse).
  if (subtypeInt == 5 || subtypeInt == 6) {
    final subtype = _annotationTypeFromInt(subtypeInt);
    final interiorColor = _readAnnotColor(
      bindings,
      annotPtr,
      FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_InteriorColor,
    );
    return PdfShapeAnnotation(
      pageIndex: pageIndex,
      subtype: subtype,
      interiorColor: interiorColor,
      contents: contents,
      author: author,
      rect: rect,
      color: color,
      modifiedDate: modifiedDate,
      flags: flags,
    );
  }

  switch (subtypeInt) {
    case 1: // FPDF_ANNOT_TEXT — sticky note
      return PdfTextAnnotation(
        pageIndex: pageIndex,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 2: // FPDF_ANNOT_LINK
      final uri = _readLinkUri(bindings, docPtr, annotPtr);
      return PdfLinkAnnotation(
        pageIndex: pageIndex,
        uri: uri,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 3: // FPDF_ANNOT_FREETEXT
      return PdfFreeTextAnnotation(
        pageIndex: pageIndex,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 4: // FPDF_ANNOT_LINE
      final (:start, :end) = _readLineEndpoints(bindings, annotPtr);
      // If endpoints couldn't be read, fall back to rect corners or defaults.
      final lineStart =
          start ?? PdfPoint(x: rect?.left ?? 0, y: rect?.bottom ?? 0);
      final lineEnd = end ?? PdfPoint(x: rect?.right ?? 0, y: rect?.top ?? 0);
      return PdfLineAnnotation(
        pageIndex: pageIndex,
        lineStart: lineStart,
        lineEnd: lineEnd,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 7: // FPDF_ANNOT_POLYGON
    case 8: // FPDF_ANNOT_POLYLINE
      final subtype = _annotationTypeFromInt(subtypeInt);
      final vertices = _readAnnotVertices(bindings, annotPtr);
      return PdfPolygonAnnotation(
        pageIndex: pageIndex,
        subtype: subtype,
        vertices: vertices,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 13: // FPDF_ANNOT_STAMP
      return PdfStampAnnotation(
        pageIndex: pageIndex,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    case 15: // FPDF_ANNOT_INK
      final strokes = _readInkStrokes(bindings, annotPtr);
      return PdfInkAnnotation(
        pageIndex: pageIndex,
        strokes: strokes,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );

    default:
      // Unknown or out-of-scope subtype (widget, form, multimedia, etc.).
      return PdfUnknownAnnotation(
        pageIndex: pageIndex,
        rawSubtype: subtypeInt,
        contents: contents,
        author: author,
        rect: rect,
        color: color,
        modifiedDate: modifiedDate,
        flags: flags,
      );
  }
}

/// Returns a copy of [annotation] with [popup] set.
///
/// Each concrete subtype is handled explicitly because [PdfAnnotation] is
/// a sealed class — we cannot mutate instances, and Dart does not provide
/// a generic `copyWith` mechanism on sealed hierarchies.
PdfAnnotation _withPopup(PdfAnnotation annotation, PdfPopupAnnotation popup) {
  return switch (annotation) {
    PdfTextAnnotation a => PdfTextAnnotation(
      pageIndex: a.pageIndex,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfFreeTextAnnotation a => PdfFreeTextAnnotation(
      pageIndex: a.pageIndex,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfMarkupAnnotation a => PdfMarkupAnnotation(
      pageIndex: a.pageIndex,
      subtype: a.subtype,
      quadPoints: a.quadPoints,
      markedText: a.markedText,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfShapeAnnotation a => PdfShapeAnnotation(
      pageIndex: a.pageIndex,
      subtype: a.subtype,
      interiorColor: a.interiorColor,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfLineAnnotation a => PdfLineAnnotation(
      pageIndex: a.pageIndex,
      lineStart: a.lineStart,
      lineEnd: a.lineEnd,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfInkAnnotation a => PdfInkAnnotation(
      pageIndex: a.pageIndex,
      strokes: a.strokes,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfPolygonAnnotation a => PdfPolygonAnnotation(
      pageIndex: a.pageIndex,
      subtype: a.subtype,
      vertices: a.vertices,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfLinkAnnotation a => PdfLinkAnnotation(
      pageIndex: a.pageIndex,
      uri: a.uri,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfStampAnnotation a => PdfStampAnnotation(
      pageIndex: a.pageIndex,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
    PdfUnknownAnnotation a => PdfUnknownAnnotation(
      pageIndex: a.pageIndex,
      rawSubtype: a.rawSubtype,
      contents: a.contents,
      author: a.author,
      rect: a.rect,
      color: a.color,
      modifiedDate: a.modifiedDate,
      flags: a.flags,
      popup: popup,
    ),
  };
}

// ---------------------------------------------------------------------------
// Page size and rendering handlers (run inside the spawned isolate)
// ---------------------------------------------------------------------------

/// Returns the intrinsic size of a single page in PDF user units (points).
///
/// Calls `FPDF_LoadPage` then `FPDF_GetPageWidthF` / `FPDF_GetPageHeightF`,
/// then closes the page handle. The width and height are in PDF user units
/// (1 point = 1/72 inch), which is the coordinate system stored in the PDF.
void _handleGetPageSize(
  PdfiumGetPageSizeCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumGetPageSizeResponse.failure(PdfError.invalidDocument),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);
  final pagePtr = bindings.FPDF_LoadPage(docPtr, cmd.pageIndex);
  if (pagePtr == ffi.nullptr) {
    cmd.replyPort.send(
      PdfiumGetPageSizeResponse.failure(PdfError.invalidDocument),
    );
    return;
  }

  try {
    final widthPt = bindings.FPDF_GetPageWidthF(pagePtr);
    final heightPt = bindings.FPDF_GetPageHeightF(pagePtr);
    cmd.replyPort.send(
      PdfiumGetPageSizeResponse.success(
        PdfPageSize(widthPt: widthPt, heightPt: heightPt),
      ),
    );
  } finally {
    bindings.FPDF_ClosePage(pagePtr);
  }
}

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
/// Parameters:
///   [src]    — raw pixel buffer from `FPDFBitmap_GetBuffer`, length is
///              `stride * height`.
///   [width]  — pixel width of the bitmap.
///   [height] — pixel height of the bitmap.
///   [stride] — byte width of a single row (≥ `width * 4`).
///
/// Returns a [Uint8List] of exactly `width * height * 4` bytes in BGRA order.
@visibleForTesting
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

/// Renders a single PDF page to a BGRA pixel buffer.
///
/// Algorithm (all steps run inside the isolate):
///   1. Validate the document token.
///   2. Load the page via `FPDF_LoadPage`.
///   3. Allocate a bitmap via `FPDFBitmap_Create` (format BGRA = 1 with alpha).
///   4. Fill the bitmap with the requested background colour via
///      `FPDFBitmap_FillRect`. The colour is already in `0xAARRGGBB` format.
///   5. Render the page into the bitmap via `FPDF_RenderPageBitmap` with the
///      caller-supplied flags (e.g. `FPDF_ANNOT`, `FPDF_LCD_TEXT`).
///   6. Obtain the raw pixel buffer pointer via `FPDFBitmap_GetBuffer`.
///   7. **Copy** the pixel bytes into a Dart `Uint8List` before destroying the
///      bitmap. The copy is essential: `FPDFBitmap_GetBuffer` returns a raw
///      pointer into bitmap-owned memory; once `FPDFBitmap_Destroy` is called
///      that memory is freed. The `Uint8List` is the only data that crosses
///      the isolate boundary.
///   8. Destroy the bitmap handle and close the page handle.
void _handleRenderPage(
  PdfiumRenderPageCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumRenderPageResponse.failure(
        'Document token ${cmd.token} is not open (document may have been closed).',
      ),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);

  // Load the page — returns null on failure.
  final pagePtr = bindings.FPDF_LoadPage(docPtr, cmd.pageIndex);
  if (pagePtr == ffi.nullptr) {
    cmd.replyPort.send(
      PdfiumRenderPageResponse.failure(
        'FPDF_LoadPage returned null for page ${cmd.pageIndex}.',
      ),
    );
    return;
  }

  try {
    // Allocate a BGRA bitmap (alpha = 1 → FPDFBitmap_BGRA format).
    // FPDFBitmap_Create returns null when allocation fails (e.g. OOM).
    final bitmap = bindings.FPDFBitmap_Create(
      cmd.pixelWidth,
      cmd.pixelHeight,
      1, // hasAlpha = 1 → BGRA format
    );
    if (bitmap == ffi.nullptr) {
      cmd.replyPort.send(
        PdfiumRenderPageResponse.failure(
          'FPDFBitmap_Create returned null for '
          '${cmd.pixelWidth}x${cmd.pixelHeight} bitmap '
          '(possible out-of-memory condition).',
        ),
      );
      return;
    }

    try {
      // Fill the entire bitmap with the background colour.
      // backgroundColor is already in 0xAARRGGBB format as expected by PDFium.
      bindings.FPDFBitmap_FillRect(
        bitmap,
        0,
        0,
        cmd.pixelWidth,
        cmd.pixelHeight,
        cmd.backgroundColor,
      );

      // Render the page into the bitmap at the full bitmap size.
      // start_x=0, start_y=0, size_x=width, size_y=height, rotate=0.
      bindings.FPDF_RenderPageBitmap(
        bitmap,
        pagePtr,
        0, // start_x
        0, // start_y
        cmd.pixelWidth, // size_x
        cmd.pixelHeight, // size_y
        0, // rotate (0 = no rotation)
        cmd.renderFlags,
      );

      // Obtain the raw buffer pointer and copy bytes into a Dart Uint8List.
      // This copy MUST happen before FPDFBitmap_Destroy, which frees the
      // underlying native memory. The stride may be larger than pixelWidth*4
      // on some platforms; use FPDFBitmap_GetStride to handle padding correctly.
      final bufferPtr = bindings.FPDFBitmap_GetBuffer(bitmap);
      final stride = bindings.FPDFBitmap_GetStride(bitmap);
      final byteCount = stride * cmd.pixelHeight;
      final rawBytes = bufferPtr.cast<ffi.Uint8>().asTypedList(byteCount);

      // If stride == pixelWidth * 4 (no row padding), we can copy the whole
      // buffer directly. Otherwise we copy row-by-row to strip padding bytes.
      final pixels = stripBitmapStride(
        rawBytes,
        cmd.pixelWidth,
        cmd.pixelHeight,
        stride,
      );

      cmd.replyPort.send(
        PdfiumRenderPageResponse.success(
          pixels: pixels,
          pixelWidth: cmd.pixelWidth,
          pixelHeight: cmd.pixelHeight,
        ),
      );
    } finally {
      // Always destroy the bitmap handle to free the native pixel buffer.
      bindings.FPDFBitmap_Destroy(bitmap);
    }
  } finally {
    // Always close the page handle after the bitmap is destroyed.
    bindings.FPDF_ClosePage(pagePtr);
  }
}

// ---------------------------------------------------------------------------
// TOC (bookmark/outline) extraction handler (runs inside the spawned isolate)
// ---------------------------------------------------------------------------

/// Retrieves the complete bookmark/outline tree for an open document.
///
/// Algorithm:
///   1. Look up the document token in [openDocuments].
///   2. Call [_walkBookmarkTree] with `nullptr` to retrieve the root-level
///      entries.
///   3. Recurse into children via [FPDFBookmark_GetFirstChild] and siblings
///      via [FPDFBookmark_GetNextSibling].
///   4. For each entry resolve the destination (action → dest → page index /
///      URI, or direct dest → page index).
///   5. Optionally extract an XYZ scroll position via
///      [FPDFDest_GetLocationInPage].
///   6. Send a [PdfiumGetTocResponse] with the resulting tree.
///
/// Documents without any bookmarks return an empty list — not an error.
///
/// Note: the recursive [PdfTocEntry] tree is deep-copied across the isolate
/// boundary by Dart's built-in message-passing serialisation. This is
/// acceptable for the bounded sizes of typical PDF bookmark trees.
void _handleGetToc(
  PdfiumGetTocCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(PdfiumGetTocResponse.failure(PdfError.invalidDocument));
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);

  // Walk the tree starting from the document root (nullptr bookmark).
  final visited = <int>{};
  final rootEntries = _walkBookmarkTree(bindings, docPtr, ffi.nullptr, visited);

  cmd.replyPort.send(PdfiumGetTocResponse.success(rootEntries));
}

/// Recursively walks the bookmark tree from [parentBookmark].
///
/// Pass `ffi.nullptr` as [parentBookmark] to retrieve the root-level entries.
/// [visited] is a [Set] of raw bookmark pointer addresses used for cycle
/// detection. If a handle address has been seen before, recursion stops
/// without processing that node.
///
/// Returns the list of [PdfTocEntry] objects at this level of the tree.
/// Children of each entry are built by a recursive call.
List<PdfTocEntry> _walkBookmarkTree(
  PdfiumBindings bindings,
  ffi.Pointer<fpdf_document_t__> docPtr,
  FPDF_BOOKMARK parentBookmark,
  Set<int> visited,
) {
  final entries = <PdfTocEntry>[];

  // FPDFBookmark_GetFirstChild returns nullptr when there are no children.
  var bookmark = bindings.FPDFBookmark_GetFirstChild(docPtr, parentBookmark);

  while (bookmark != ffi.nullptr) {
    // Cycle detection: use the raw pointer address as the identity key.
    final handleAddress = bookmark.address;
    if (visited.contains(handleAddress)) {
      // Malformed PDF with a bookmark cycle — stop here to prevent an
      // infinite loop.
      break;
    }
    visited.add(handleAddress);

    // Decode the title using the two-call buffer pattern.
    final title = _readBookmarkTitle(bindings, bookmark);

    // Resolve the destination (page index / URI / null).
    final (:pageIndex, :uri, :scrollPosition) = _resolveBookmarkDestination(
      bindings,
      docPtr,
      bookmark,
    );

    // Recursively collect children of this bookmark.
    final children = _walkBookmarkTree(bindings, docPtr, bookmark, visited);

    entries.add(
      PdfTocEntry(
        title: title,
        pageIndex: pageIndex,
        uri: uri,
        scrollPosition: scrollPosition,
        children: children,
      ),
    );

    // Advance to the next sibling.
    bookmark = bindings.FPDFBookmark_GetNextSibling(docPtr, bookmark);
  }

  return entries;
}

/// Decodes the title of a bookmark using the PDFium two-call buffer pattern.
///
/// Returns an empty string if the title buffer is absent or empty. UTF-16LE
/// decoding mirrors the approach used by [_readMetaText].
String _readBookmarkTitle(PdfiumBindings bindings, FPDF_BOOKMARK bookmark) {
  // First call: pass null buffer / zero length to get the required byte count.
  final requiredLen = bindings.FPDFBookmark_GetTitle(bookmark, ffi.nullptr, 0);

  // 0 or 2 bytes means absent / empty (UTF-16LE null terminator only).
  if (requiredLen <= 2) return '';

  final buffer = calloc<ffi.Uint8>(requiredLen);
  try {
    bindings.FPDFBookmark_GetTitle(
      bookmark,
      buffer.cast<ffi.Void>(),
      requiredLen,
    );

    // Decode UTF-16LE, excluding the 2-byte null terminator.
    final byteCount = requiredLen - 2;
    if (byteCount <= 0) return '';

    final codeUnits = <int>[];
    for (var i = 0; i < byteCount; i += 2) {
      // Little-endian: low byte at i, high byte at i+1.
      final codeUnit = buffer[i] | (buffer[i + 1] << 8);
      codeUnits.add(codeUnit);
    }
    return String.fromCharCodes(codeUnits);
  } finally {
    calloc.free(buffer);
  }
}

/// Resolves a bookmark's destination to a page index, URI, or null.
///
/// Resolution order per the plan's specification:
///   1. Try `FPDFBookmark_GetAction`. If non-null, inspect the action type:
///      - `PDFACTION_GOTO` (1): resolve dest from action → page index.
///      - `PDFACTION_URI` (3): extract the URI string.
///      - Anything else: both null.
///   2. If no action (or action handle is null), try `FPDFBookmark_GetDest`
///      directly → page index.
///   3. If both null → section label with no target.
///
/// Also attempts to extract the XYZ scroll position from a dest when the
/// destination's view mode is `PDFDEST_VIEW_XYZ` (= 1).
({int? pageIndex, String? uri, PdfPoint? scrollPosition})
_resolveBookmarkDestination(
  PdfiumBindings bindings,
  ffi.Pointer<fpdf_document_t__> docPtr,
  FPDF_BOOKMARK bookmark,
) {
  // --- Step 1: Try the action path ---
  final action = bindings.FPDFBookmark_GetAction(bookmark);
  if (action != ffi.nullptr) {
    final actionType = bindings.FPDFAction_GetType(action);

    if (actionType == 1) {
      // PDFACTION_GOTO: resolve the internal-page destination.
      final dest = bindings.FPDFAction_GetDest(docPtr, action);
      if (dest != ffi.nullptr) {
        final pageIndex = _resolveDestPageIndex(bindings, docPtr, dest);
        final scrollPosition = _resolveXyzScrollPosition(bindings, dest);
        return (
          pageIndex: pageIndex,
          uri: null,
          scrollPosition: scrollPosition,
        );
      }
      // Action was GOTO but dest is null — treat as no target.
      return (pageIndex: null, uri: null, scrollPosition: null);
    }

    if (actionType == 3) {
      // PDFACTION_URI: extract the URI string.
      final uri = _readActionUri(bindings, docPtr, action);
      return (pageIndex: null, uri: uri, scrollPosition: null);
    }

    // PDFACTION_REMOTEGOTO (2), PDFACTION_LAUNCH (4), PDFACTION_EMBEDDEDGOTO (5),
    // or PDFACTION_UNSUPPORTED (0): no page index, no URI.
    return (pageIndex: null, uri: null, scrollPosition: null);
  }

  // --- Step 2: Try the direct destination path ---
  final dest = bindings.FPDFBookmark_GetDest(docPtr, bookmark);
  if (dest != ffi.nullptr) {
    final pageIndex = _resolveDestPageIndex(bindings, docPtr, dest);
    final scrollPosition = _resolveXyzScrollPosition(bindings, dest);
    return (pageIndex: pageIndex, uri: null, scrollPosition: scrollPosition);
  }

  // --- Step 3: Section label with no target ---
  return (pageIndex: null, uri: null, scrollPosition: null);
}

/// Extracts the zero-based page index from a dest handle.
///
/// Returns `null` when `FPDFDest_GetDestPageIndex` returns -1 (invalid).
int? _resolveDestPageIndex(
  PdfiumBindings bindings,
  ffi.Pointer<fpdf_document_t__> docPtr,
  FPDF_DEST dest,
) {
  final pageIndex = bindings.FPDFDest_GetDestPageIndex(docPtr, dest);
  return pageIndex < 0 ? null : pageIndex;
}

/// Extracts the XYZ scroll position from a dest handle.
///
/// Returns a [PdfPoint] when the dest's view mode is `PDFDEST_VIEW_XYZ`
/// (= 1) and at least one of hasX or hasY is set. Returns `null` when:
///   - `FPDFDest_GetLocationInPage` returns FALSE, or
///   - The view mode is not XYZ.
///
/// Zoom is intentionally not surfaced; see [PdfTocEntry]'s class-level doc
/// comment for the rationale.
PdfPoint? _resolveXyzScrollPosition(PdfiumBindings bindings, FPDF_DEST dest) {
  final hasXPtr = calloc<ffi.Int>();
  final hasYPtr = calloc<ffi.Int>();
  final hasZoomPtr = calloc<ffi.Int>();
  final xPtr = calloc<ffi.Float>();
  final yPtr = calloc<ffi.Float>();
  final zoomPtr = calloc<ffi.Float>();

  try {
    final ok = bindings.FPDFDest_GetLocationInPage(
      dest,
      hasXPtr,
      hasYPtr,
      hasZoomPtr,
      xPtr,
      yPtr,
      zoomPtr,
    );

    // ok == 0 means the call failed (dest has no XYZ location info).
    if (ok == 0) return null;

    // Only surface x/y when the view mode is XYZ (= 1). For other view modes
    // (FIT, FITH, etc.) there are no explicit x/y coordinates.
    final hasX = hasXPtr.value != 0;
    final hasY = hasYPtr.value != 0;

    if (!hasX && !hasY) return null;

    // Use 0.0 for a missing axis coordinate (PDF spec allows partial XYZ).
    return PdfPoint(x: hasX ? xPtr.value : 0.0, y: hasY ? yPtr.value : 0.0);
  } finally {
    calloc.free(hasXPtr);
    calloc.free(hasYPtr);
    calloc.free(hasZoomPtr);
    calloc.free(xPtr);
    calloc.free(yPtr);
    calloc.free(zoomPtr);
  }
}

/// Reads the URI string from a `PDFACTION_URI` action.
///
/// Returns the URI, or `null` if the buffer is empty. The URI is a
/// null-terminated ASCII/UTF-8 string (not UTF-16LE).
String? _readActionUri(
  PdfiumBindings bindings,
  ffi.Pointer<fpdf_document_t__> docPtr,
  FPDF_ACTION action,
) {
  // First call: determine required buffer length (in bytes; ASCII string).
  final requiredLen = bindings.FPDFAction_GetURIPath(
    docPtr,
    action,
    ffi.nullptr,
    0,
  );
  if (requiredLen == 0) return null;

  final buffer = calloc<ffi.Uint8>(requiredLen);
  try {
    bindings.FPDFAction_GetURIPath(
      docPtr,
      action,
      buffer.cast<ffi.Void>(),
      requiredLen,
    );
    // The URI is null-terminated; requiredLen includes the null terminator.
    final uriBytes = buffer.asTypedList(requiredLen - 1);
    final uri = String.fromCharCodes(uriBytes);
    return uri.isEmpty ? null : uri;
  } finally {
    calloc.free(buffer);
  }
}

// ---------------------------------------------------------------------------
// Image extraction handlers (run inside the spawned isolate)
// ---------------------------------------------------------------------------

/// Extracts all image objects from a single page.
///
/// Algorithm:
///   1. Look up the document token. Send failure if not found.
///   2. Load the page via [FPDF_LoadPage]. Send failure if null.
///   3. Iterate all page objects via [FPDFPage_CountObjects] /
///      [FPDFPage_GetObject]. For each object whose type is
///      [FPDF_PAGEOBJ_IMAGE]:
///      a. Call [FPDFImageObj_GetImageMetadata] to fill metadata. If it
///         fails, skip the object (warn is not available in isolate; we
///         simply omit the image).
///      b. Call [FPDFPageObj_GetBounds] for the axis-aligned bounding box;
///         fall back to a zero [PdfRect] if it returns false.
///      c. Read filter names via [FPDFImageObj_GetImageFilterCount] /
///         [FPDFImageObj_GetImageFilter].
///      d. If [cmd.includeBitmap] is true, call
///         [FPDFImageObj_GetRenderedBitmap] and copy the BGRA bytes; destroy
///         the bitmap handle immediately. Leave bitmap fields null if the
///         call returns null.
///   4. Close the page handle.
///   5. Send [PdfiumExtractPageImagesResponse.success].
void _handleExtractPageImages(
  PdfiumExtractPageImagesCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumExtractPageImagesResponse.failure(
        PdfError.invalidDocument,
        cmd.pageIndex,
      ),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);
  final pagePtr = bindings.FPDF_LoadPage(docPtr, cmd.pageIndex);
  if (pagePtr == ffi.nullptr) {
    cmd.replyPort.send(
      PdfiumExtractPageImagesResponse.failure(
        PdfError.invalidDocument,
        cmd.pageIndex,
      ),
    );
    return;
  }

  try {
    final objectCount = bindings.FPDFPage_CountObjects(pagePtr);
    final images = <PdfImage>[];

    for (var i = 0; i < objectCount; i++) {
      final objPtr = bindings.FPDFPage_GetObject(pagePtr, i);
      if (objPtr == ffi.nullptr) continue;

      // FPDF_PAGEOBJ_IMAGE = 3 — skip all non-image objects.
      final objType = bindings.FPDFPageObj_GetType(objPtr);
      if (objType != 3) continue;

      // Extract metadata using the FPDF_IMAGEOBJ_METADATA struct.
      final metaPtr = calloc<FPDF_IMAGEOBJ_METADATA>();
      bool metaOk;
      try {
        metaOk =
            bindings.FPDFImageObj_GetImageMetadata(objPtr, pagePtr, metaPtr) !=
            0;
      } finally {
        // Do not free yet; we read fields below before freeing.
        // (actually we free in the outer try block)
      }

      if (!metaOk) {
        calloc.free(metaPtr);
        continue; // Skip images whose metadata cannot be read.
      }

      final meta = metaPtr.ref;
      final metadata = PdfImageMetadata(
        width: meta.width,
        height: meta.height,
        horizontalDpi: meta.horizontal_dpi,
        verticalDpi: meta.vertical_dpi,
        bitsPerPixel: meta.bits_per_pixel,
        colorspace: _colorspaceFromInt(meta.colorspace),
        markedContentId: meta.marked_content_id,
      );
      calloc.free(metaPtr);

      // Read the axis-aligned bounding box. Fall back to zero rect on failure.
      final bounds = _readPageObjBounds(bindings, objPtr);

      // Read compression filter names.
      final filters = _readImageFilters(bindings, objPtr);

      // Optionally render the composited BGRA bitmap.
      Uint8List? bgra;
      int? bitmapWidth;
      int? bitmapHeight;

      if (cmd.includeBitmap) {
        final bitmapResult = _renderImageBitmap(
          bindings,
          docPtr,
          pagePtr,
          objPtr,
        );
        bgra = bitmapResult?.bgra;
        bitmapWidth = bitmapResult?.width;
        bitmapHeight = bitmapResult?.height;
      }

      images.add(
        PdfImage(
          pageIndex: cmd.pageIndex,
          objectIndex: i,
          metadata: metadata,
          bounds: bounds,
          filters: filters,
          bgra: bgra,
          bitmapWidth: bitmapWidth,
          bitmapHeight: bitmapHeight,
        ),
      );
    }

    cmd.replyPort.send(
      PdfiumExtractPageImagesResponse.success(
        pageIndex: cmd.pageIndex,
        images: images,
      ),
    );
  } finally {
    bindings.FPDF_ClosePage(pagePtr);
  }
}

/// Fetches the rendered BGRA bitmap for a single image object by index.
///
/// Algorithm:
///   1. Look up the document token. Send failure if not found.
///   2. Load the page via [FPDF_LoadPage]. Send failure if null.
///   3. Call [FPDFPage_GetObject] at [cmd.objectIndex].
///   4. If the object is null or not of type [FPDF_PAGEOBJ_IMAGE], send a
///      successful response with `bitmap: null`.
///   5. Call [FPDFImageObj_GetRenderedBitmap] → copy bytes → destroy handle.
///   6. Close the page handle.
///   7. Send [PdfiumRenderImageResponse.success] (bitmap may be null if
///      [FPDFImageObj_GetRenderedBitmap] returned null).
void _handleRenderImage(
  PdfiumRenderImageCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumRenderImageResponse.failure(PdfError.invalidDocument),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);
  final pagePtr = bindings.FPDF_LoadPage(docPtr, cmd.pageIndex);
  if (pagePtr == ffi.nullptr) {
    cmd.replyPort.send(
      PdfiumRenderImageResponse.failure(PdfError.invalidDocument),
    );
    return;
  }

  try {
    // O(1) index access — returns null pointer for out-of-range indices.
    final objPtr = bindings.FPDFPage_GetObject(pagePtr, cmd.objectIndex);

    if (objPtr == ffi.nullptr) {
      // Object index is out of range for this page.
      cmd.replyPort.send(const PdfiumRenderImageResponse.success(null));
      return;
    }

    // Verify the object is an image (FPDF_PAGEOBJ_IMAGE = 3).
    final objType = bindings.FPDFPageObj_GetType(objPtr);
    if (objType != 3) {
      // Object exists but is not an image type.
      cmd.replyPort.send(const PdfiumRenderImageResponse.success(null));
      return;
    }

    // Render the composited BGRA bitmap. Returns null for mask-only objects.
    final bitmapResult = _renderImageBitmap(bindings, docPtr, pagePtr, objPtr);
    cmd.replyPort.send(PdfiumRenderImageResponse.success(bitmapResult));
  } finally {
    bindings.FPDF_ClosePage(pagePtr);
  }
}

/// Renders an image object to a [PdfImageBitmap] using
/// [FPDFImageObj_GetRenderedBitmap].
///
/// Returns `null` when [FPDFImageObj_GetRenderedBitmap] returns a null handle
/// (e.g. mask-only objects that have no renderable bitmap).
///
/// The bitmap handle is always destroyed before this function returns, so the
/// caller receives a Dart-owned [Uint8List] and does not need to manage the
/// native bitmap lifecycle.
PdfImageBitmap? _renderImageBitmap(
  PdfiumBindings bindings,
  ffi.Pointer<fpdf_document_t__> docPtr,
  FPDF_PAGE pagePtr,
  FPDF_PAGEOBJECT objPtr,
) {
  final bitmap = bindings.FPDFImageObj_GetRenderedBitmap(
    docPtr,
    pagePtr,
    objPtr,
  );
  if (bitmap == ffi.nullptr) return null;

  try {
    final width = bindings.FPDFBitmap_GetWidth(bitmap);
    final height = bindings.FPDFBitmap_GetHeight(bitmap);
    final stride = bindings.FPDFBitmap_GetStride(bitmap);

    if (width <= 0 || height <= 0) return null;

    final bufferPtr = bindings.FPDFBitmap_GetBuffer(bitmap);
    final byteCount = stride * height;
    final rawBytes = bufferPtr.cast<ffi.Uint8>().asTypedList(byteCount);

    // Copy into a Dart-owned Uint8List (stride-stripping if needed).
    // The copy MUST happen before FPDFBitmap_Destroy frees the native buffer.
    final expectedStride = width * 4;
    final Uint8List bgra;
    if (stride == expectedStride) {
      // Fast path: no row padding — copy the contiguous buffer.
      bgra = Uint8List.fromList(rawBytes);
    } else {
      // Slow path: strip row padding so the output is a compact BGRA buffer.
      bgra = Uint8List(width * height * 4);
      for (var row = 0; row < height; row++) {
        final srcOffset = row * stride;
        final dstOffset = row * expectedStride;
        bgra.setRange(
          dstOffset,
          dstOffset + expectedStride,
          rawBytes,
          srcOffset,
        );
      }
    }

    return PdfImageBitmap(bgra: bgra, width: width, height: height);
  } finally {
    // Always destroy the native bitmap handle to free the pixel buffer.
    bindings.FPDFBitmap_Destroy(bitmap);
  }
}

/// Reads the axis-aligned bounding box of a page object.
///
/// Returns a zero [PdfRect] when [FPDFPageObj_GetBounds] fails (returns 0).
PdfRect _readPageObjBounds(PdfiumBindings bindings, FPDF_PAGEOBJECT objPtr) {
  final leftPtr = calloc<ffi.Float>();
  final bottomPtr = calloc<ffi.Float>();
  final rightPtr = calloc<ffi.Float>();
  final topPtr = calloc<ffi.Float>();
  try {
    final ok = bindings.FPDFPageObj_GetBounds(
      objPtr,
      leftPtr,
      bottomPtr,
      rightPtr,
      topPtr,
    );
    if (ok == 0) {
      return const PdfRect(left: 0, bottom: 0, right: 0, top: 0);
    }
    return PdfRect(
      left: leftPtr.value,
      bottom: bottomPtr.value,
      right: rightPtr.value,
      top: topPtr.value,
    );
  } finally {
    calloc.free(leftPtr);
    calloc.free(bottomPtr);
    calloc.free(rightPtr);
    calloc.free(topPtr);
  }
}

/// Reads the list of compression filter names applied to an image object.
///
/// Uses the two-call buffer pattern for each filter name. Returns an empty
/// list when there are no filters or the call fails.
///
/// Filter names are null-terminated ASCII strings (e.g. `"DCTDecode"`,
/// `"FlateDecode"`).
List<String> _readImageFilters(
  PdfiumBindings bindings,
  FPDF_PAGEOBJECT objPtr,
) {
  final count = bindings.FPDFImageObj_GetImageFilterCount(objPtr);
  if (count <= 0) return const [];

  final filters = <String>[];
  for (var i = 0; i < count; i++) {
    // First call: determine required buffer length (in bytes).
    final requiredLen = bindings.FPDFImageObj_GetImageFilter(
      objPtr,
      i,
      ffi.nullptr,
      0,
    );

    if (requiredLen <= 0) continue;

    final buffer = calloc<ffi.Uint8>(requiredLen);
    try {
      bindings.FPDFImageObj_GetImageFilter(
        objPtr,
        i,
        buffer.cast<ffi.Void>(),
        requiredLen,
      );
      // Filter names are null-terminated ASCII strings.
      // requiredLen includes the null terminator.
      final bytes = buffer.asTypedList(requiredLen - 1);
      final name = String.fromCharCodes(bytes);
      if (name.isNotEmpty) filters.add(name);
    } finally {
      calloc.free(buffer);
    }
  }
  return filters;
}

/// Maps a PDFium `FPDF_COLORSPACE_*` integer to the corresponding
/// [PdfColorspace] enum value.
///
/// Returns [PdfColorspace.unknown] for any value not recognised by this
/// version of the library.
PdfColorspace _colorspaceFromInt(int value) => switch (value) {
  0 => PdfColorspace.unknown,
  1 => PdfColorspace.deviceGray,
  2 => PdfColorspace.deviceRgb,
  3 => PdfColorspace.deviceCmyk,
  4 => PdfColorspace.calGray,
  5 => PdfColorspace.calRgb,
  6 => PdfColorspace.lab,
  7 => PdfColorspace.iccBased,
  8 => PdfColorspace.separation,
  9 => PdfColorspace.deviceN,
  10 => PdfColorspace.indexed,
  11 => PdfColorspace.pattern,
  _ => PdfColorspace.unknown,
};

/// Searches for text on a single page of an open document.
///
/// The full lifecycle is contained within this function:
///   1. Validate the document token.
///   2. Load the page via `FPDF_LoadPage`.
///   3. Load the text page via `FPDFText_LoadPage`.
///   4. Encode [PdfiumSearchPageCommand.query] as a null-terminated UTF-16LE
///      buffer (`FPDF_WIDESTRING`).
///   5. Start the search via `FPDFText_FindStart`.
///   6. Iterate `FPDFText_FindNext`, collecting the char index, char count,
///      and bounding rects for each match.
///   7. Close the search handle and text-page handle (in `try/finally` blocks
///      so handles are never leaked even on exception).
///   8. Close the page handle.
///   9. Send a [PdfiumSearchPageResponse].
///
/// Pages with no text layer (`FPDFText_LoadPage` returns null) produce a
/// success response with an empty matches list — not an error.
void _handleSearchPage(
  PdfiumSearchPageCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumSearchPageResponse.failure(PdfError.invalidDocument, cmd.pageIndex),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);

  // Load the page handle. Returns null pointer on failure (e.g. bad page index).
  final pagePtr = bindings.FPDF_LoadPage(docPtr, cmd.pageIndex);
  if (pagePtr == ffi.nullptr) {
    cmd.replyPort.send(
      PdfiumSearchPageResponse.failure(PdfError.invalidDocument, cmd.pageIndex),
    );
    return;
  }

  try {
    // Load the text page. Null return means no text layer — treat as empty.
    final textPagePtr = bindings.FPDFText_LoadPage(pagePtr);
    if (textPagePtr == ffi.nullptr) {
      cmd.replyPort.send(
        PdfiumSearchPageResponse.success(
          pageIndex: cmd.pageIndex,
          matches: const [],
        ),
      );
      return;
    }

    try {
      // Encode the query string as a null-terminated UTF-16LE buffer.
      // FPDF_WIDESTRING = Pointer<FPDF_WCHAR> = Pointer<UnsignedShort>.
      // Allocate (charCount + 1) UnsignedShort slots: one per code unit
      // plus one for the null terminator.
      final query = cmd.query;
      final codeUnits = query.codeUnits; // Dart String is UTF-16.
      final wideBuffer = calloc<ffi.UnsignedShort>(codeUnits.length + 1);
      try {
        // Write the query code units as little-endian 16-bit values.
        for (var i = 0; i < codeUnits.length; i++) {
          wideBuffer[i] = codeUnits[i];
        }
        // Null-terminate.
        wideBuffer[codeUnits.length] = 0;

        final findHandle = bindings.FPDFText_FindStart(
          textPagePtr,
          wideBuffer.cast<FPDF_WCHAR>(),
          cmd.flags,
          0, // start_index: start from the beginning of the page
        );

        if (findHandle == ffi.nullptr) {
          // FindStart returned null — emit empty matches.
          cmd.replyPort.send(
            PdfiumSearchPageResponse.success(
              pageIndex: cmd.pageIndex,
              matches: const [],
            ),
          );
          return;
        }

        final matches = <PdfSearchMatch>[];

        try {
          // Iterate all matches on this page.
          while (bindings.FPDFText_FindNext(findHandle) != 0) {
            final charIndex = bindings.FPDFText_GetSchResultIndex(findHandle);
            final charCount = bindings.FPDFText_GetSchCount(findHandle);

            // Collect bounding rectangles for this match.
            // A multi-line match produces one rect per visual line fragment.
            final rectCount = bindings.FPDFText_CountRects(
              textPagePtr,
              charIndex,
              charCount,
            );

            final rects = <PdfRect>[];
            // Output pointers for FPDFText_GetRect; PDFium writes y-axis as
            // top-then-bottom (PDF user space: top > bottom).
            final leftPtr = calloc<ffi.Double>();
            final topPtr = calloc<ffi.Double>();
            final rightPtr = calloc<ffi.Double>();
            final bottomPtr = calloc<ffi.Double>();
            try {
              for (var r = 0; r < rectCount; r++) {
                bindings.FPDFText_GetRect(
                  textPagePtr,
                  r,
                  leftPtr,
                  topPtr,
                  rightPtr,
                  bottomPtr,
                );
                rects.add(
                  PdfRect(
                    left: leftPtr.value,
                    bottom: bottomPtr.value,
                    right: rightPtr.value,
                    top: topPtr.value,
                  ),
                );
              }
            } finally {
              calloc.free(leftPtr);
              calloc.free(topPtr);
              calloc.free(rightPtr);
              calloc.free(bottomPtr);
            }

            matches.add(
              PdfSearchMatch(
                pageIndex: cmd.pageIndex,
                charIndex: charIndex,
                charCount: charCount,
                rects: rects,
              ),
            );
          }
        } finally {
          // Always close the search handle — required to prevent resource leaks.
          bindings.FPDFText_FindClose(findHandle);
        }

        cmd.replyPort.send(
          PdfiumSearchPageResponse.success(
            pageIndex: cmd.pageIndex,
            matches: matches,
          ),
        );
      } finally {
        calloc.free(wideBuffer);
      }
    } finally {
      // Always close the text page handle.
      bindings.FPDFText_ClosePage(textPagePtr);
    }
  } finally {
    // Always close the page handle.
    bindings.FPDF_ClosePage(pagePtr);
  }
}

// ---------------------------------------------------------------------------
// Thumbnail extraction handler (runs inside the spawned isolate)
// ---------------------------------------------------------------------------

/// Retrieves the embedded thumbnail bitmap for a single PDF page.
///
/// Algorithm (all steps run inside the isolate):
///   1. Validate the document token.
///   2. Load the page via `FPDF_LoadPage`.
///   3. Call `FPDFPage_GetThumbnailAsBitmap(page)`.
///   4. If the result is `nullptr`, send a success response with `bgra: null`
///      (no embedded thumbnail present — not an error).
///   5. Call `FPDFBitmap_GetFormat` and handle format variants:
///      - `FPDFBitmap_BGRA` (4): already BGRA, copy directly with optional
///        row-padding strip.
///      - `FPDFBitmap_BGRx` (3): no alpha channel; expand each 4-byte pixel
///        to BGRA by setting the A byte to 0xFF (fully opaque).
///      - `FPDFBitmap_BGR` (2): 3 bytes per pixel; expand to BGRA similarly.
///      - Any other format: send a failure response with a descriptive message.
///   6. Obtain the raw buffer pointer via `FPDFBitmap_GetBuffer`, stride via
///      `FPDFBitmap_GetStride`, and dimensions via `FPDFBitmap_GetWidth` /
///      `FPDFBitmap_GetHeight`.
///   7. Copy into a compact `Uint8List` in BGRA layout, stripping row padding.
///   8. Destroy the bitmap handle (in a `finally` block) and close the page.
///
/// The page and bitmap handles are always released, even if an error occurs —
/// mirrors the pattern used in [_handleRenderPage].
void _handleGetPageThumbnail(
  PdfiumGetPageThumbnailCommand cmd,
  PdfiumBindings bindings,
  Map<int, ({int docAddress, int bufferAddress})> openDocuments,
) {
  final entry = openDocuments[cmd.token];
  if (entry == null) {
    cmd.replyPort.send(
      PdfiumGetPageThumbnailResponse.failure(
        'Document token ${cmd.token} is not open (document may have been closed).',
      ),
    );
    return;
  }

  final docPtr = ffi.Pointer<fpdf_document_t__>.fromAddress(entry.docAddress);

  // Load the page — returns null on failure.
  final pagePtr = bindings.FPDF_LoadPage(docPtr, cmd.pageIndex);
  if (pagePtr == ffi.nullptr) {
    cmd.replyPort.send(
      PdfiumGetPageThumbnailResponse.failure(
        'FPDF_LoadPage returned null for page ${cmd.pageIndex}.',
      ),
    );
    return;
  }

  try {
    // Call FPDFPage_GetThumbnailAsBitmap. This is marked Experimental API.
    // Returns nullptr when the page has no embedded /Thumb stream — that is a
    // normal result (not an error), so we send success with bgra: null.
    final bitmap = bindings.FPDFPage_GetThumbnailAsBitmap(pagePtr);
    if (bitmap == ffi.nullptr) {
      // No embedded thumbnail on this page — signal "absent" with null bgra.
      cmd.replyPort.send(
        const PdfiumGetPageThumbnailResponse.success(
          bgra: null,
          width: 0,
          height: 0,
        ),
      );
      return;
    }

    try {
      final width = bindings.FPDFBitmap_GetWidth(bitmap);
      final height = bindings.FPDFBitmap_GetHeight(bitmap);
      final stride = bindings.FPDFBitmap_GetStride(bitmap);
      final format = bindings.FPDFBitmap_GetFormat(bitmap);
      final bufferPtr = bindings.FPDFBitmap_GetBuffer(bitmap);

      // Determine how many source bytes per pixel based on the bitmap format.
      // We always output 4 bytes per pixel (BGRA).
      //
      // FPDFBitmap_BGRA = 4: 4 bytes/px (B, G, R, A) — copy directly.
      // FPDFBitmap_BGRx = 3: 4 bytes/px (B, G, R, x) — replace x with 0xFF.
      // FPDFBitmap_BGR  = 2: 3 bytes/px (B, G, R)    — append 0xFF for A.
      // Other formats are unsupported — the embedded thumbnail has an unusual
      // colour representation; reject it with a descriptive message so the
      // caller can fall back to rendering.
      final int srcBytesPerPixel;
      switch (format) {
        case FPDFBitmap_BGRA:
          srcBytesPerPixel = 4;
          break;
        case FPDFBitmap_BGRx:
          // 4 bytes per pixel but the 4th byte is reserved (not alpha).
          // PDFium fills the x byte with 0 — we overwrite it with 0xFF.
          srcBytesPerPixel = 4;
          break;
        case FPDFBitmap_BGR:
          srcBytesPerPixel = 3;
          break;
        default:
          cmd.replyPort.send(
            PdfiumGetPageThumbnailResponse.failure(
              'FPDFPage_GetThumbnailAsBitmap returned a bitmap in unsupported '
              'format $format for page ${cmd.pageIndex}. '
              'Only BGRA, BGRx, and BGR formats are supported.',
            ),
          );
          return;
      }

      // Allocate the compact BGRA output buffer.
      final bgra = Uint8List(width * height * 4);

      // The native buffer contains [height] rows, each [stride] bytes.
      // [stride] may be > [srcBytesPerPixel * width] due to row padding.
      // We strip padding by copying only the pixel data bytes per row.
      final nativeView = bufferPtr.cast<ffi.Uint8>().asTypedList(
        stride * height,
      );

      for (var row = 0; row < height; row++) {
        final srcRowBase = row * stride;
        final dstRowBase = row * width * 4;

        for (var col = 0; col < width; col++) {
          final srcOff = srcRowBase + col * srcBytesPerPixel;
          final dstOff = dstRowBase + col * 4;

          // Copy B, G, R bytes directly.
          bgra[dstOff] = nativeView[srcOff]; // B
          bgra[dstOff + 1] = nativeView[srcOff + 1]; // G
          bgra[dstOff + 2] = nativeView[srcOff + 2]; // R

          if (format == FPDFBitmap_BGRA) {
            // BGRA: 4th source byte is the real alpha.
            bgra[dstOff + 3] = nativeView[srcOff + 3]; // A
          } else {
            // BGRx or BGR: no alpha channel — set fully opaque.
            bgra[dstOff + 3] = 0xFF; // A = opaque
          }
        }
      }

      cmd.replyPort.send(
        PdfiumGetPageThumbnailResponse.success(
          bgra: bgra,
          width: width,
          height: height,
        ),
      );
    } finally {
      // Always destroy the bitmap handle to free the native pixel buffer.
      // This mirrors the pattern in _handleRenderPage.
      bindings.FPDFBitmap_Destroy(bitmap);
    }
  } finally {
    // Always close the page handle after the bitmap work is complete.
    bindings.FPDF_ClosePage(pagePtr);
  }
}

// ---------------------------------------------------------------------------
// PdfiumIsolate — the process-wide singleton used by PdfDocumentNative
// ---------------------------------------------------------------------------

/// Process-wide singleton that owns the PDFium isolate.
///
/// All [PdfDocument] instances share a single [PdfiumIsolate]. This mirrors
/// the PDFium model where [FPDF_InitLibraryWithConfig] is a one-time
/// process-wide call; spawning a second isolate would double-initialise the
/// library, which is a correctness bug.
///
/// The isolate is lazily spawned on the first call to [ensureInitialised].
/// It is held for the lifetime of the process — never torn down when
/// individual documents are closed.
///
/// Callers do not interact with this class directly; it is an internal
/// implementation detail of the native backend.
class PdfiumIsolate {
  PdfiumIsolate._();

  static PdfiumIsolate? _instance;

  // Guard future: ensures concurrent calls to ensureInitialised() all await
  // the same spawn operation rather than spawning multiple isolates.
  static Future<PdfiumIsolate>? _initFuture;

  /// The [SendPort] for sending commands to the PDFium isolate.
  late final SendPort _commandPort;

  /// Returns the singleton [PdfiumIsolate], spawning it if necessary.
  ///
  /// Safe to call concurrently — multiple callers racing on first use all
  /// await the same [Future] and receive the same instance.
  static Future<PdfiumIsolate> ensureInitialised({String? dylibPath}) {
    // Fast path: already initialised.
    if (_instance != null) return Future.value(_instance);

    // Slow path: spawn once. The guard future prevents duplicate spawns from
    // concurrent callers.
    _initFuture ??= _spawn(dylibPath: dylibPath);
    return _initFuture!;
  }

  /// Resets the singleton state so a new isolate can be spawned.
  ///
  /// **For testing only.** Calling this in production code will cause the
  /// next [ensureInitialised] call to spawn a new isolate and call
  /// [FPDF_InitLibraryWithConfig] again, which is a correctness bug if the
  /// previous isolate is still running.
  ///
  /// Use this in test [tearDown] / [tearDownAll] blocks when the test suite
  /// needs a fresh PDFium isolate (e.g. after the dylib has been unloaded by
  /// a smoke test's [FPDF_DestroyLibrary] call).
  // ignore: invalid_use_of_visible_for_testing_member
  static void resetForTesting() {
    _instance = null;
    _initFuture = null;
  }

  /// Spawns the PDFium isolate and sends it the initialisation command.
  static Future<PdfiumIsolate> _spawn({String? dylibPath}) async {
    final instance = PdfiumIsolate._();

    // The bootstrap receive port receives the command SendPort from the isolate
    // (sent unconditionally at startup, before the init command).
    final bootstrapReceivePort = ReceivePort();

    await Isolate.spawn(
      pdfiumIsolateEntryPoint,
      bootstrapReceivePort.sendPort,
      debugName: 'PdfiumIsolate',
    );

    // Receive the isolate's command SendPort.
    final commandPort = await bootstrapReceivePort.first as SendPort;
    bootstrapReceivePort.close();

    // Send the init command with the dylib path (null = auto-detect).
    final initReceivePort = ReceivePort();
    final resolvedPath = dylibPath ?? _defaultDylibPathOrNull();
    commandPort.send(PdfiumInitCommand(initReceivePort.sendPort, resolvedPath));

    // Wait for the init response.
    final dynamic initResponse = await initReceivePort.first;
    initReceivePort.close();

    // The isolate sends PdfiumInitResponse on success or
    // PdfiumInitFailedResponse if the dylib could not be loaded.
    if (initResponse is! PdfiumInitResponse) {
      _initFuture = null; // Allow a future retry with a corrected path.
      final detail = initResponse is PdfiumInitFailedResponse
          ? initResponse.message
          : '$initResponse';
      throw StateError(
        'PdfiumIsolate: failed to initialise PDFium library: $detail',
      );
    }

    // initResponse is PdfiumInitResponse — PDFium initialised successfully.
    // We already hold commandPort; the response merely confirms success.
    instance._commandPort = commandPort;
    _instance = instance;
    return instance;
  }

  /// Sends a [command] to the PDFium isolate and awaits the [PdfiumResponse].
  ///
  /// Each command includes its own reply [SendPort] (created here) so that
  /// concurrent commands from different callers are matched independently
  /// without a shared queue.
  Future<T> send<T extends PdfiumResponse>(
    PdfiumCommand Function(SendPort) commandFactory,
  ) async {
    final replyPort = ReceivePort();
    final command = commandFactory(replyPort.sendPort);
    _commandPort.send(command);
    final response = await replyPort.first;
    replyPort.close();
    if (response is PdfiumHandlerErrorResponse) {
      throw StateError(
        'PdfiumIsolate: handler threw ${response.error}\n${response.stack}',
      );
    }
    if (response is! T) {
      throw StateError(
        'PdfiumIsolate: unexpected response type '
        '${response.runtimeType}, expected $T',
      );
    }
    return response;
  }
}

/// Returns an explicit dylib path when the legacy `third_party/pdfium_bin/`
/// layout (populated by `make fetch_pdfium`) is present, otherwise `null`.
///
/// A `null` return causes the spawned isolate to call [_openLibrary], which
/// uses platform-appropriate auto-detection for the native-assets hook case.
///
/// iOS and Android always return `null`: iOS loads from the process image
/// (static xcframework linked at build time) and Android loads by bare name
/// from the APK `jni/{abi}/` directory.
String? _defaultDylibPathOrNull() {
  // coverage:ignore-next-line
  // iOS and Android always return null here; they are platform-gated and
  // cannot be reached on the macOS/Linux test host.
  if (Platform.isIOS || Platform.isAndroid) return null;
  if (Platform.isLinux) {
    final arch = ffi.Abi.current() == ffi.Abi.linuxArm64
        ? 'linux_arm64'
        : 'linux_x64';
    final legacy = 'third_party/pdfium_bin/$arch/libpdfium.so';
    if (File(legacy).existsSync()) return legacy;
    return null;
  }
  if (Platform.isMacOS) {
    const legacy = 'third_party/pdfium_bin/macos_arm64/libpdfium.dylib';
    if (File(legacy).existsSync()) return legacy;
    return null;
  }
  return null;
}

/// Opens the PDFium [ffi.DynamicLibrary] for the current platform using
/// native-assets auto-detection.
///
/// Called by the spawned isolate when [PdfiumInitCommand.dylibPath] is `null`
/// (i.e. the native-assets hook staged the binary rather than `make
/// fetch_pdfium`).
///
/// Platform strategy:
///   - **iOS**: PDFium is statically linked by the SPM plugin shim →
///     [ffi.DynamicLibrary.process].
///   - **Android**: the `.so` is bundled in the APK `jni/{abi}/` directory by
///     the Flutter build → [ffi.DynamicLibrary.open] by bare name.
///   - **Linux**: probes absolute candidate paths (dart build output, dart test
///     staged location, hook cache) then falls back to bare name if none exist.
///     The bare-name fallback only works when `LD_LIBRARY_PATH` is set (e.g.
///     inside the `dart test` process itself), not in subprocesses spawned by
///     tests — so absolute paths must be tried first.
///   - **macOS**: tries the Flutter framework bundle path first, then probes
///     several absolute candidate paths (dart build output, dart test staged
///     location, hook cache).
ffi.DynamicLibrary _openLibrary() {
  // coverage:ignore-start
  // iOS and Android branches are only reachable on physical/emulated devices;
  // the macOS/Linux test host cannot exercise them. They are excluded from
  // coverage so the 90% gate is not penalised for platform-gated code.
  if (Platform.isIOS) {
    return ffi.DynamicLibrary.process();
  }
  if (Platform.isAndroid) {
    return ffi.DynamicLibrary.open('libpdfium.so');
  }
  // coverage:ignore-end
  if (Platform.isLinux) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;
    const libName = 'libpdfium.so';
    final candidates = <String>[
      // dart build cli: bundle/bin/<exe> → bundle/lib/<libName>.
      '$exeDir/../lib/$libName',
      // dart test / dart run (JIT): build system stages to .dart_tool/lib/.
      '$cwd/.dart_tool/lib/$libName',
      // Hook cache direct path (fallback if staging hasn't copied the file).
      '$cwd/.dart_tool/betto_pdfium/$pdfiumSha/$libName',
    ];
    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) {
        try {
          return ffi.DynamicLibrary.open(f.absolute.path);
        } catch (_) {
          // Try next candidate.
        }
      }
    }
    // Last resort: bare name works when LD_LIBRARY_PATH is set by the dart
    // test runner, but not in subprocesses spawned by tests.
    return ffi.DynamicLibrary.open(libName);
  }
  if (Platform.isMacOS) {
    // Strategy 1: Flutter app bundle — the build system wraps
    // DynamicLoadingBundled dylibs in versioned .framework bundles.
    // For libpdfium.dylib the framework name is 'pdfium'.
    try {
      return ffi.DynamicLibrary.open('pdfium.framework/pdfium');
    } catch (_) {
      // Fall through to strategy 2.
    }

    // Strategy 2: probe absolute candidate paths.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;
    const dylib = 'libpdfium.dylib';
    final candidates = <String>[
      // dart build cli: bundle/bin/<exe> → bundle/lib/<dylib>.
      '$exeDir/../lib/$dylib',
      // dart test / dart run (JIT): build system stages to .dart_tool/lib/.
      '$cwd/.dart_tool/lib/$dylib',
      // Hook cache direct path (fallback if staging hasn't copied the file).
      '$cwd/.dart_tool/betto_pdfium/$pdfiumSha/$dylib',
    ];

    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) {
        try {
          return ffi.DynamicLibrary.open(f.absolute.path);
        } catch (_) {
          // Try next candidate.
        }
      }
    }

    // All strategies failed — surface the diagnostic error from the framework
    // path attempt so the message mentions the expected bundle layout.
    return ffi.DynamicLibrary.open('pdfium.framework/pdfium');
  }
  throw UnsupportedError(
    'betto_pdfium: unsupported platform ${Platform.operatingSystem}. '
    'Supported: macOS arm64, Linux x64/arm64, Android, iOS.',
  );
}
