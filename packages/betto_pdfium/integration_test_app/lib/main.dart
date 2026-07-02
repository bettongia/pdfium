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

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Flutter scaffold for the betto_pdfium integration test harness.
///
/// This app exists mainly to host the `flutter test integration_test/`
/// runner on iOS/Android — it has no user-facing functionality there. On
/// web, `flutter test -d chrome` cannot drive integration tests, so this
/// screen also doubles as a manual stress-test harness: it loads a large
/// real-world PDF and renders every page, giving a human something to
/// trigger while watching Chrome DevTools' Performance panel to confirm the
/// Web Worker offload keeps the main thread responsive (see the "Web Worker
/// offload" plan, Phase 9).
void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: _StressTestPage());
}

/// The PDF fixture rendered by the stress test — a real-world, multi-page
/// arXiv paper large enough (~6.6 MB) that a synchronous main-thread render
/// would previously cause a noticeable freeze.
const _stressTestAsset = 'assets/data/arxiv/2404.16130v2.pdf';

/// Render resolution for the stress test, in dots per inch.
const _renderDpi = 150.0;

class _StressTestPage extends StatefulWidget {
  const _StressTestPage();

  @override
  State<_StressTestPage> createState() => _StressTestPageState();
}

class _StressTestPageState extends State<_StressTestPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinner = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  bool _busy = false;
  String _status = 'Idle. Press the button to load and render a PDF.';

  @override
  void dispose() {
    _spinner.dispose();
    super.dispose();
  }

  Future<void> _runStressTest() async {
    setState(() {
      _busy = true;
      _status = 'Loading ${_stressTestAsset.split('/').last}…';
    });

    final stopwatch = Stopwatch()..start();
    PdfDocument? doc;
    try {
      final data = await rootBundle.load(_stressTestAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      doc = await PdfDocument.fromBytes(bytes);

      final pageCount = await doc.pageCount;
      setState(
        () => _status =
            'Loaded ($pageCount pages, '
            '${(bytes.length / 1e6).toStringAsFixed(1)} MB) — extracting text…',
      );

      var charCount = 0;
      await for (final page in doc.extractPlainText()) {
        charCount += page.text.length;
      }

      for (var i = 0; i < pageCount; i++) {
        setState(
          () => _status =
              'Rendering page ${i + 1} of $pageCount at '
              '$_renderDpi DPI…',
        );
        final size = await doc.getPageSize(i);
        final px = size.sizeForDpi(_renderDpi);
        await doc.renderPageToBytes(i, px.width.round(), px.height.round());
      }

      stopwatch.stop();
      setState(
        () => _status =
            'Done in ${stopwatch.elapsedMilliseconds} ms — '
            '$pageCount pages rendered at $_renderDpi DPI, '
            '$charCount characters extracted.\n\n'
            'While that ran, the spinner above should have kept turning '
            'smoothly — that (plus a DevTools Performance recording) is '
            'what confirms the main thread was never blocked.',
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      setState(
        () => _status =
            'FAILED after ${stopwatch.elapsedMilliseconds} ms:\n$error'
            '\n\n$stackTrace',
      );
    } finally {
      await doc?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('betto_pdfium — Worker offload test')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _spinner,
              child: const Icon(Icons.autorenew, size: 48),
            ),
            const SizedBox(height: 8),
            const Text(
              'This spinner is driven by the Flutter engine, not by the '
              'render call below — if it stutters or freezes while '
              'rendering, the main thread is blocked.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _runStressTest,
              child: Text(
                _busy
                    ? 'Running…'
                    : 'Load & render large PDF (${_stressTestAsset.split('/').last})',
              ),
            ),
            const SizedBox(height: 24),
            SelectableText(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
