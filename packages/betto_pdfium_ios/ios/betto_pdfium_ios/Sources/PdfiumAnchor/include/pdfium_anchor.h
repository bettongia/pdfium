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
 * pdfium_anchor.h — Public header for the PdfiumAnchor SPM target.
 *
 * This header exists solely to satisfy SPM's requirement that a C target
 * depended on by a Swift target must have a public headers directory.
 * The PdfiumIos Swift target depends on PdfiumAnchor for link-order reasons
 * only (to pull the PDFium xcframework into the final binary); it does not
 * call or import any symbol defined here.
 *
 * The anchor variable itself is declared in pdfium_anchor.c and is
 * intentionally not exported — its only job is to create a compile-time
 * reference to FPDF_InitLibraryWithConfig that prevents the linker from
 * dead-stripping the PDFium archive.
 */

#ifndef PDFIUM_ANCHOR_H
#define PDFIUM_ANCHOR_H

/* Nothing to export. */

#endif /* PDFIUM_ANCHOR_H */
