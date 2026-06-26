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

import 'package:flutter/material.dart';

/// Minimal Flutter scaffold for the betto_pdfium integration test harness.
///
/// This app exists solely to host the Flutter integration tests — it has no
/// user-facing functionality. The integration test runner replaces the normal
/// app lifecycle; this scaffold is only visible briefly during test startup.
void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('betto_pdfium integration test harness')),
    ),
  );
}
