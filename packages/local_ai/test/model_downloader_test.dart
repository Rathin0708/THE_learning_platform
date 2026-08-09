import 'dart:io';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_ai/src/model_downloader.dart';
import 'package:path/path.dart' as p;

/// Real end-to-end test (THE-61): spins up an actual local HTTP server
/// serving a fake "model" file and drives [ModelDownloader] against it for
/// real — no mocked HTTP client — same approach as
/// packages/core/test/content_update_checker_test.dart.
void main() {
  late HttpServer server;
  late String baseUrl;
  late Directory tempDir;

  // Deliberately larger than one chunk so the streaming/progress path is
  // exercised, not just a single-shot download.
  final fakeModelBytes = List<int>.generate(200000, (i) => i % 256);
  final fakeModelChecksum = sha256.convert(fakeModelBytes).toString();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('model_downloader_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.address}:${server.port}';

    server.listen((request) async {
      if (request.uri.path == '/model.gguf') {
        request.response.add(fakeModelBytes);
      } else if (request.uri.path == '/missing') {
        request.response.statusCode = 404;
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  test('download() streams progress and installs a real file that matches the checksum', () async {
    final downloader = ModelDownloader();
    final installPath = p.join(tempDir.path, 'model.gguf');

    final events = await downloader
        .download(
          url: '$baseUrl/model.gguf',
          sha256Hex: fakeModelChecksum,
          expectedSizeBytes: fakeModelBytes.length,
          installPath: installPath,
        )
        .toList();

    expect(events.last.status, ModelDownloadStatus.complete);
    expect(events.any((e) => e.status == ModelDownloadStatus.inProgress), isTrue);
    expect(await File(installPath).readAsBytes(), fakeModelBytes);
    expect(await File('$installPath.bak').exists(), isFalse);
    expect(await File('$installPath.download').exists(), isFalse);
    downloader.close();
  });

  test('download() rejects a checksum mismatch and leaves no partial file behind', () async {
    final downloader = ModelDownloader();
    final installPath = p.join(tempDir.path, 'model.gguf');

    final events = await downloader
        .download(
          url: '$baseUrl/model.gguf',
          sha256Hex: 'deadbeef' * 8,
          expectedSizeBytes: fakeModelBytes.length,
          installPath: installPath,
        )
        .toList();

    expect(events.last.status, ModelDownloadStatus.checksumMismatch);
    expect(await File(installPath).exists(), isFalse);
    downloader.close();
  });

  test('download() reports downloadFailed for a 404 without throwing', () async {
    final downloader = ModelDownloader();
    final installPath = p.join(tempDir.path, 'model.gguf');

    final events = await downloader
        .download(url: '$baseUrl/missing', sha256Hex: fakeModelChecksum, expectedSizeBytes: 10, installPath: installPath)
        .toList();

    expect(events.last.status, ModelDownloadStatus.downloadFailed);
    downloader.close();
  });

  test('download() preserves the old file when a new download fails checksum verification', () async {
    final downloader = ModelDownloader();
    final installPath = p.join(tempDir.path, 'model.gguf');
    await File(installPath).writeAsBytes([9, 9, 9]);

    await downloader
        .download(
          url: '$baseUrl/model.gguf',
          sha256Hex: 'deadbeef' * 8,
          expectedSizeBytes: fakeModelBytes.length,
          installPath: installPath,
        )
        .toList();

    expect(await File(installPath).readAsBytes(), [9, 9, 9], reason: 'old file must be untouched on failure');
    downloader.close();
  });
}
