// swift-tools-version: 5.9
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

// Local SPM package that vends the PDFium static xcframework for iOS.
//
// Design: two-target structure to prevent linker dead-stripping.
//
// The PDFium xcframework is statically linked. Because Dart resolves all
// FPDF_* symbols at runtime via DynamicLibrary.process(), the linker sees
// zero compile-time references to any PDFium symbol and is free to
// dead-strip the entire archive. A bare binaryTarget is not sufficient to
// prevent this.
//
// The `pdfium` source target depends on `pdfium_binary` and contains a thin
// C file (Sources/PdfiumAnchor/pdfium_anchor.c) that holds an
// __attribute__((used)) pointer to FPDF_InitLibraryWithConfig. This gives
// the linker a compile-time reference, which pulls the translation unit from
// the archive. The transitive closure of the library then survives
// dead-stripping, and DynamicLibrary.process() can resolve all FPDF_* symbols
// at runtime.
//
// The `../../Frameworks/pdfium.xcframework` path is relative to this
// Package.swift and resolves to ios/Frameworks/pdfium.xcframework — the
// gitignored location populated by scripts/fetch_mobile_binaries.sh.

import PackageDescription

let package = Package(
    name: "pdfium",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "pdfium", targets: ["pdfium"]),
    ],
    targets: [
        // Source target: provides the dead-strip anchor reference.
        // Depends on the binary target so the xcframework is linked.
        .target(
            name: "pdfium",
            dependencies: ["pdfium_binary"],
            path: "Sources/PdfiumAnchor"
        ),
        // Binary target: the PDFium static xcframework.
        // Path is relative to this Package.swift file.
        .binaryTarget(
            name: "pdfium_binary",
            path: "../../Frameworks/pdfium.xcframework"
        ),
    ]
)
