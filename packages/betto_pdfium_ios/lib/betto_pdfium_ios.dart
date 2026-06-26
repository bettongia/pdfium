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

/// No-op Flutter iOS plugin that links the PDFium static xcframework.
///
/// This plugin's only purpose is to carry the SPM dependency on the PDFium
/// xcframework so that Xcode statically links it into the host app binary.
/// [DynamicLibrary.process()] in `betto_pdfium` can then resolve `FPDF_*`
/// symbols at runtime. There is no method channel, event channel, or
/// platform interaction.
library pdfium_ios;
