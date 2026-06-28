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

// Flutter iOS plugin package that embeds the PDFium dynamic xcframework.
//
// Design: two-target chain (no dead-strip workaround needed for dynamic libs).
//
// PDFium is now a dynamic framework (not a static archive). Xcode automatically
// embeds dynamic frameworks from a binaryTarget into the app bundle, and the
// linker links them normally — no PdfiumAnchor C anchor is required.
//
// The chain PdfiumIos → pdfium_binary ensures:
//  1. pdfium_binary (binaryTarget): SPM downloads the xcframework from the
//     bettongia/pdfium GitHub Release and Xcode embeds it in the app bundle.
//  2. PdfiumIos (Swift source target): the Flutter plugin class that Flutter's
//     generated plugin registrant imports. Its dependency on pdfium_binary
//     pulls the xcframework into the build graph.
//
// At runtime, DynamicLibrary.process() locates all PDFium symbols because
// the embedded dynamic framework's exports are present in the process image
// from the moment the app launches — no explicit dlopen path is needed.
//
// The binaryTarget uses a URL (not a local path) so that SPM downloads the
// xcframework directly from the bettongia/pdfium GitHub Release. A local path
// would break because Flutter copies this Package.swift into an ephemeral
// directory, making relative paths unresolvable.
//
// The URL and checksum are updated by `make update_pdfium_manifest` whenever
// the bblanchon build is bumped (after running `make repack_ios_xcframework`).

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
            dependencies: ["pdfium_binary"],
            path: "Sources/PdfiumIos"
        ),
        // Binary target: PDFium dynamic xcframework downloaded directly by SPM.
        // Repacked from bblanchon/pdfium-binaries iOS device + simulator
        // tarballs by `make repack_ios_xcframework`.
        // Updated by `make update_pdfium_manifest`.
        .binaryTarget(
            name: "pdfium_binary",
            url: "https://github.com/bettongia/pdfium/releases/download/bblanchon-chromium-7906/pdfium.xcframework.zip",
            checksum: "26595793be1323fcb887941b4111cde53050ce13284b0573058861ee298fddd9"
        ),
    ]
)
