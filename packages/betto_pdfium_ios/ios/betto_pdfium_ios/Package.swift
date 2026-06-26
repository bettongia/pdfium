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

// Flutter iOS plugin package that links the PDFium static xcframework.
//
// Design: three-target chain to prevent linker dead-stripping.
//
// PDFium is a C library statically linked into the iOS app. Because Dart
// resolves all FPDF_* symbols at runtime via DynamicLibrary.process(), the
// linker has zero compile-time references to any PDFium symbol and is free
// to dead-strip the entire archive. A bare binaryTarget is not sufficient.
//
// The chain PdfiumIos → PdfiumAnchor → pdfium_binary ensures:
//  1. pdfium_binary (binaryTarget): the xcframework is linked.
//  2. PdfiumAnchor (C source target): holds __attribute__((used)) pointer to
//     FPDF_InitLibraryWithConfig, giving the linker a compile-time reference
//     that prevents dead-stripping of the archive.
//  3. PdfiumIos (Swift source target): the Flutter plugin class that Flutter's
//     generated plugin registrant imports. Its dependency on PdfiumAnchor
//     pulls the anchor (and transitively the xcframework) into the build.
//
// The binaryTarget path ../Frameworks/pdfium.xcframework is relative to this
// Package.swift and resolves to ios/Frameworks/pdfium.xcframework inside the
// pdfium_ios plugin directory — the gitignored location populated by
// integration_test_app/scripts/fetch_mobile_binaries.sh.

import PackageDescription

let package = Package(
    name: "betto_pdfium_ios",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "betto-pdfium-ios", targets: ["PdfiumIos"]),
    ],
    targets: [
        // Swift plugin registration target. Flutter's generated plugin
        // registrant imports this product, pulling PdfiumAnchor and the
        // xcframework into the link.
        .target(
            name: "PdfiumIos",
            dependencies: ["PdfiumAnchor"],
            path: "Sources/PdfiumIos"
        ),
        // C anchor target: provides the compile-time FPDF_* reference that
        // prevents the linker from dead-stripping the PDFium archive.
        .target(
            name: "PdfiumAnchor",
            dependencies: ["pdfium_binary"],
            path: "Sources/PdfiumAnchor"
        ),
        // Binary target: the PDFium static xcframework.
        .binaryTarget(
            name: "pdfium_binary",
            path: "../Frameworks/pdfium.xcframework"
        ),
    ]
)
