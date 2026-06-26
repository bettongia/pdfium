/*
 * Copyright 2026 The Authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * pdfium_anchor.c — Dead-strip prevention anchor for the PDFium static
 * xcframework.
 *
 * PDFium is a C library statically linked into the iOS app via the
 * pdfium_binary SPM binaryTarget. Dart resolves all FPDF_* symbols at
 * runtime via DynamicLibrary.process(), so the linker has zero compile-time
 * references to any PDFium symbol and is free to dead-strip the entire
 * archive.
 *
 * This file provides a compile-time reference to FPDF_InitLibraryWithConfig
 * (the library's entry-point function). The __attribute__((used)) marker
 * prevents the compiler from optimising away the reference even though the
 * variable is never read. The linker then sees a reference to
 * FPDF_InitLibraryWithConfig, pulls that translation unit from the archive,
 * and the transitive closure of the PDFium library survives dead-stripping.
 *
 * After linking, all FPDF_* symbols are present in the process image and
 * DynamicLibrary.process() resolves them correctly at runtime.
 */

/* Forward-declare the entry point so we don't need to include fpdfview.h. */
extern void FPDF_InitLibraryWithConfig(const void* config);

/*
 * Anchor pointer — holds the address of FPDF_InitLibraryWithConfig.
 *
 * __attribute__((used)): instructs the compiler to retain this variable
 * even if it appears unused at the C level, preventing dead-code
 * elimination before the linker runs.
 *
 * static: limits linkage to this translation unit; the anchor itself
 * need not be visible to other compilation units.
 */
__attribute__((used)) static void* __pdfium_anchor =
    (void*)&FPDF_InitLibraryWithConfig;
