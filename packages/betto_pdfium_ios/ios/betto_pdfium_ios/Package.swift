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
// The binaryTarget uses a URL (not a local path) so that SPM downloads the
// xcframework directly from the GitHub Release. A local path would break
// because Flutter copies this Package.swift into an ephemeral directory,
// making relative paths unresolvable.
//
// The URL and checksum are updated by `make update_pdfium_manifest` whenever
// the PDFium SHA is bumped.

import PackageDescription

let package = Package(
    name: "betto_pdfium_ios",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "betto-pdfium-ios", targets: ["betto_pdfium_ios"]),
    ],
    targets: [
        // Swift plugin registration target. Flutter's generated ObjC
        // registrant calls `@import betto_pdfium_ios;` so the target name
        // must match the plugin name exactly.
        .target(
            name: "betto_pdfium_ios",
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
        // Binary target: PDFium xcframework downloaded directly by SPM.
        // Updated by `make update_pdfium_manifest`.
        .binaryTarget(
            name: "pdfium_binary",
            url: "https://github.com/bettongia/pdfium/releases/download/pdfium-75ea0a73e1cb08beabb2800b0ba3f5c931d2cdef/libpdfium-ios-arm64.xcframework.zip",
            checksum: "660ab74f31a80b69097e53676425ac083ce86391255c6b20e28d2da8005aabd4"
        ),
    ]
)
