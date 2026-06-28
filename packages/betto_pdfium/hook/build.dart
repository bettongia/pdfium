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

/// Native-assets build hook for `betto_pdfium`.
///
/// Downloads the PDFium prebuilt binary for the target platform/arch from
/// [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
/// GitHub Releases, verifies the SHA-256 checksum of the `.tgz` tarball,
/// extracts the shared library, and emits it as a [CodeAsset] with
/// [DynamicLoadingBundled] link mode so the Dart/Flutter build system bundles
/// it alongside the executable.
///
/// ## Design
///
/// bblanchon/pdfium-binaries publishes per-platform `.tgz` tarballs. Each
/// tarball contains `lib/libpdfium.{dylib,so}` and `include/*.h` (public
/// headers). The hook:
///
/// 1. Downloads the `.tgz` to a `.part` temp file.
/// 2. Verifies SHA-256 of the `.tgz` against `version_pdfium.json` before
///    extracting — the SHA is over the tarball, not the library.
/// 3. Extracts `lib_path` from the tarball into the final location.
/// 4. Atomically renames the `.part` file on success.
/// 5. Writes a `.sha256` sidecar so subsequent builds skip the download.
///
/// Concurrent invocations use last-writer-wins on the atomic rename — both
/// writers produce byte-identical, checksum-verified output.
///
/// ## Platform manifest
///
/// All platform binary metadata (bblanchon build number, download URLs,
/// SHA-256 digests) is stored in `version_pdfium.json` at the package root.
/// The hook reads this file at build time via [_loadPlatformManifest].
/// The `BBLANCHON_BUILD` file is the canonical build number for developers.
///
/// ## Unsupported platforms
///
/// - **iOS**: the xcframework is a dynamic library embedded via SPM as a
///   `binaryTarget`. Flutter's iOS native-assets system is bypassed; SPM
///   downloads the xcframework directly during `flutter pub get`. No CodeAsset
///   is emitted; `_openLibrary()` in the runtime uses
///   `DynamicLibrary.process()` since the embedded dynamic framework's symbols
///   are in the process image.
///
/// - **Android**: the `.so` is placed in `jniLibs/` by
///   `fetch_mobile_binaries.sh` and loaded with
///   `DynamicLibrary.open('libpdfium.so')` at runtime. No CodeAsset is emitted.
///
/// - **Windows**: not yet supported.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

// ── Hook entry point ──────────────────────────────────────────────────────────

void main(List<String> args) async {
  await build(args, _buildHook);
}

Future<void> _buildHook(BuildInput input, BuildOutputBuilder output) async {
  if (!input.config.buildCodeAssets) return;

  final os = input.config.code.targetOS;
  final arch = input.config.code.targetArchitecture;
  final packageRoot = input.packageRoot;

  print('betto_pdfium hook: os=$os arch=$arch');

  if (os == OS.iOS) {
    // iOS uses an SPM binaryTarget (dynamic xcframework) downloaded during
    // `flutter pub get`. No CodeAsset is emitted here; the runtime opens the
    // library via DynamicLibrary.process() since the embedded framework's
    // symbols are in the process image.
    print(
      'betto_pdfium: iOS uses SPM binaryTarget (dynamic xcframework). '
      'No CodeAsset emitted from the native-assets hook.',
    );
    return;
  }

  if (os == OS.android) {
    // Android loads libpdfium.so from jniLibs/ via DynamicLibrary.open().
    // The .so is placed there by fetch_mobile_binaries.sh, not the hook.
    print(
      'betto_pdfium: Android loads libpdfium.so from jniLibs/. '
      'No CodeAsset emitted from the native-assets hook.',
    );
    return;
  }

  if (os == OS.windows) {
    print('betto_pdfium: Windows is not yet supported. No CodeAsset emitted.');
    return;
  }

  await _buildDesktop(input, output, os, arch, packageRoot);
}

// ── Desktop (macOS, Linux) ────────────────────────────────────────────────────

Future<void> _buildDesktop(
  BuildInput input,
  BuildOutputBuilder output,
  OS os,
  Architecture arch,
  Uri packageRoot,
) async {
  final platformEntry = _loadPlatformManifest(os, arch, packageRoot);
  final build = _readBblanchonBuild(packageRoot);
  final url = platformEntry['url'] as String;
  final expectedSha = platformEntry['sha256'] as String;
  final libPath = platformEntry['lib_path'] as String;

  final libFileName = os == OS.macOS ? 'libpdfium.dylib' : 'libpdfium.so';
  final cacheDir = _cacheDirectory(packageRoot, build);
  final libFile = File('${cacheDir.path}/$libFileName');

  await _ensureTgzExtracted(
    dest: libFile,
    libPathInTgz: libPath,
    expectedSha256: expectedSha,
    downloadUrl: url,
  );

  output.assets.code.add(
    CodeAsset(
      package: 'betto_pdfium',
      name: 'src/pdfium_library.dart',
      linkMode: DynamicLoadingBundled(),
      file: libFile.uri,
    ),
  );

  print('betto_pdfium: emitted CodeAsset ${libFile.path}');
}

// ── Platform manifest ─────────────────────────────────────────────────────────

/// Reads the `bblanchon_build` field from `version_pdfium.json`.
///
/// This slash-free build number (e.g. `'7906'`) is used as the cache
/// directory key so that a build-number bump causes a fresh download.
String _readBblanchonBuild(Uri packageRoot) {
  final f = File.fromUri(packageRoot.resolve('version_pdfium.json'));
  final decoded = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return decoded['bblanchon_build'] as String;
}

/// Loads and returns the platform entry from `version_pdfium.json`.
///
/// Each entry has the following fields:
/// - `url`:      full download URL for the bblanchon `.tgz` tarball
/// - `lib_path`: path within the tarball to the shared library
/// - `sha256`:   expected SHA-256 of the `.tgz` file (not the extracted lib)
///
/// Platform key mapping:
///   - macOS arm64   → `"macos-arm64"`
///   - Linux arm64   → `"linux-arm64"`
///   - Linux x64     → `"linux-x64"`
Map<String, dynamic> _loadPlatformManifest(
  OS os,
  Architecture arch,
  Uri packageRoot,
) {
  final manifestFile = File.fromUri(packageRoot.resolve('version_pdfium.json'));
  if (!manifestFile.existsSync()) {
    throw StateError(
      'version_pdfium.json not found at ${manifestFile.path}. '
      'This file must exist in the betto_pdfium package root.',
    );
  }

  final decoded =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final platforms = decoded['platforms'] as Map<String, dynamic>;

  final key = _platformKey(os, arch);
  final entry = platforms[key] as Map<String, dynamic>?;
  if (entry == null) {
    throw StateError(
      'No entry for platform key "$key" in version_pdfium.json. '
      'Supported keys: ${platforms.keys.join(', ')}',
    );
  }
  return entry;
}

String _platformKey(OS os, Architecture arch) {
  if (os == OS.macOS) {
    if (arch != Architecture.arm64) {
      throw UnsupportedError(
        'betto_pdfium: macOS x86_64 (Intel) is not supported.',
      );
    }
    return 'macos-arm64';
  }
  if (os == OS.linux) {
    return arch == Architecture.arm64 ? 'linux-arm64' : 'linux-x64';
  }
  throw UnsupportedError('betto_pdfium: unsupported OS for hook: $os');
}

// ── Cache directory ───────────────────────────────────────────────────────────

/// Returns `.dart_tool/betto_pdfium/{build}/` inside the package root.
///
/// Using `.dart_tool/` ensures the cache is gitignored. The build number
/// scopes the cache so a bblanchon version bump causes a fresh download.
Directory _cacheDirectory(Uri packageRoot, String build) {
  return Directory.fromUri(
    packageRoot.resolve('.dart_tool/betto_pdfium/$build/'),
  );
}

// ── File acquisition (tgz) ───────────────────────────────────────────────────

/// Ensures [dest] exists and is the extracted shared library from a bblanchon
/// `.tgz` tarball.
///
/// ## Crash-safe write discipline
///
/// 1. Check fast path: if [dest] and its sidecar `.sha256` already exist and
///    the sidecar content matches [expectedSha256], trust the cached file.
/// 2. Download the `.tgz` to a `.tgz.part` temp file.
/// 3. Verify SHA-256 of the `.tgz` **before extraction** — the checksum is
///    over the whole tarball, not the extracted library.
/// 4. Atomically rename `.tgz.part` → `.tgz` on success.
/// 5. Extract [libPathInTgz] from the `.tgz` to a `.part` temp file.
/// 6. Rename the extracted `.part` → final [dest].
/// 7. Write a `.sha256` sidecar (of the `.tgz`, not the library) for the
///    fast-path check on subsequent invocations.
///
/// Concurrent invocations use last-writer-wins on the atomic rename — both
/// writers produce byte-identical, checksum-verified output.
///
/// ## macOS xattr
///
/// Downloaded files on macOS receive `com.apple.quarantine` and
/// `com.apple.provenance` extended attributes that block `install_name_tool`
/// (run by Flutter's bundler) and may interfere with `dlopen`. They are
/// stripped after every write via `xattr -c`.
Future<void> _ensureTgzExtracted({
  required File dest,
  required String libPathInTgz,
  required String expectedSha256,
  required String downloadUrl,
}) async {
  final sidecar = File('${dest.path}.sha256');

  // Fast path: extracted library present and tgz sidecar matches.
  if (dest.existsSync() && sidecar.existsSync()) {
    final stored = sidecar.readAsStringSync().trim();
    if (stored == expectedSha256) {
      print('  cached: ${dest.path}');
      if (Platform.isMacOS) await _stripXattrs(dest);
      return;
    }
  }

  await dest.parent.create(recursive: true);

  // Download the tarball to a .part file for crash safety.
  final tgzPath = '${dest.parent.path}/${_tgzName(downloadUrl)}';
  final tgzPart = File('$tgzPath.part');
  final tgzFile = File(tgzPath);

  print('  downloading ${Uri.parse(downloadUrl).pathSegments.last} ...');
  final bytes = await _download(downloadUrl);

  // Verify SHA-256 of the tarball BEFORE extraction.
  final actual = _sha256PureDart(Uint8List.fromList(bytes));
  if (actual != expectedSha256) {
    throw StateError(
      'SHA-256 mismatch for ${Uri.parse(downloadUrl).pathSegments.last}.\n'
      '  Expected : $expectedSha256\n'
      '  Got      : $actual\n'
      'The download may be corrupt or tampered. Delete '
      '${dest.parent.path} and retry, or update version_pdfium.json.',
    );
  }

  // Write and atomically rename the tarball.
  await tgzPart.writeAsBytes(bytes, flush: true);
  await tgzPart.rename(tgzFile.path);

  // Extract the shared library from the verified tarball.
  await _extractFromTgz(tgzFile, libPathInTgz, dest);
  if (Platform.isMacOS) await _stripXattrs(dest);

  // Write the sidecar (SHA-256 of the tgz) for future fast-path checks.
  await sidecar.writeAsString(expectedSha256, flush: true);
  print('  staged: ${dest.path}');
}

/// Returns the tarball filename from the download URL (last path segment).
String _tgzName(String url) => Uri.parse(url).pathSegments.last;

/// Extracts [libPathInTgz] from [tgz] into [dest].
///
/// Uses the system `tar` command with `--strip-components=<depth>` so only
/// the final filename lands in the destination parent directory. The library
/// is extracted to a `.part` file alongside [dest], then atomically renamed.
///
/// Throws [StateError] if `tar` exits non-zero or the extracted file is
/// missing.
Future<void> _extractFromTgz(File tgz, String libPathInTgz, File dest) async {
  // Calculate --strip-components depth from the path within the tarball.
  // e.g. "lib/libpdfium.dylib" → depth 1 (strip the "lib/" prefix).
  final components = libPathInTgz.split('/').length - 1;

  final destPart = File('${dest.path}.part');
  await dest.parent.create(recursive: true);

  // tar extracts to a directory; we use the parent of dest for that.
  // The entry path is used to select only the desired file.
  final result = await Process.run('tar', [
    '-xzf',
    tgz.path,
    '-C',
    dest.parent.path,
    '--strip-components=$components',
    libPathInTgz,
  ]);

  if (result.exitCode != 0) {
    throw StateError(
      'tar extraction failed (exit ${result.exitCode}) for '
      '${tgz.path}:\n${result.stderr}',
    );
  }

  // `tar` extracts to dest.parent/<filename>; rename to finalise.
  final extracted = File('${dest.parent.path}/${libPathInTgz.split('/').last}');
  if (!extracted.existsSync()) {
    throw StateError(
      'tar reported success but extracted file not found: ${extracted.path}\n'
      'Expected to find $libPathInTgz extracted from ${tgz.path}.',
    );
  }

  // Atomic rename: extracted → destPart → dest.
  await extracted.rename(destPart.path);
  await destPart.rename(dest.path);
}

Future<void> _stripXattrs(File file) async {
  final result = await Process.run('xattr', ['-c', file.path]);
  if (result.exitCode != 0) {
    print('  warning: xattr -c failed for ${file.path}: ${result.stderr}');
  }
}

Future<List<int>> _download(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to download PDFium binary (HTTP ${response.statusCode}): $url',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.toBytes();
  } finally {
    client.close();
  }
}

// ── Pure-Dart SHA-256 ─────────────────────────────────────────────────────────

/// Computes the lowercase hex SHA-256 digest of [message].
///
/// Pure-Dart (FIPS 180-4) to avoid adding `package:crypto` as a dependency
/// of `betto_pdfium`. Identical implementation to `betto_onnxrt`'s hook.
String _sha256PureDart(Uint8List message) {
  final h = Uint32List.fromList([
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ]);

  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  final msgLen = message.length;
  final bitLen = msgLen * 8;
  final paddedLen = ((msgLen + 1 + 8 + 63) ~/ 64) * 64;
  final padded = Uint8List(paddedLen);
  padded.setRange(0, msgLen, message);
  padded[msgLen] = 0x80;
  for (var i = 0; i < 8; i++) {
    padded[paddedLen - 8 + i] = (bitLen >> (56 - i * 8)) & 0xff;
  }

  final w = Uint32List(64);
  for (var chunk = 0; chunk < paddedLen; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] =
          (padded[chunk + i * 4] << 24) |
          (padded[chunk + i * 4 + 1] << 16) |
          (padded[chunk + i * 4 + 2] << 8) |
          padded[chunk + i * 4 + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 =
          _rotr32(w[i - 15], 7) ^ _rotr32(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 =
          _rotr32(w[i - 2], 17) ^ _rotr32(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = _u32(w[i - 16] + s0 + w[i - 7] + s1);
    }

    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];

    for (var i = 0; i < 64; i++) {
      final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
      final ch = (e & f) ^ (~e & g);
      final temp1 = _u32(hh + s1 + ch + k[i] + w[i]);
      final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = _u32(s0 + maj);
      hh = g;
      g = f;
      f = e;
      e = _u32(d + temp1);
      d = c;
      c = b;
      b = a;
      a = _u32(temp1 + temp2);
    }

    h[0] = _u32(h[0] + a);
    h[1] = _u32(h[1] + b);
    h[2] = _u32(h[2] + c);
    h[3] = _u32(h[3] + d);
    h[4] = _u32(h[4] + e);
    h[5] = _u32(h[5] + f);
    h[6] = _u32(h[6] + g);
    h[7] = _u32(h[7] + hh);
  }

  final sb = StringBuffer();
  for (final word in h) {
    sb.write(word.toRadixString(16).padLeft(8, '0'));
  }
  return sb.toString();
}

int _rotr32(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xffffffff;
int _u32(int x) => x & 0xffffffff;
