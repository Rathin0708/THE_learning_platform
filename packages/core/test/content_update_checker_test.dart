import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:core/core.dart';

/// Real end-to-end test (THE-67, spec 8.4): spins up an actual local HTTP
/// server serving a manifest + content file, and drives
/// ContentUpdateChecker against it for real — no mocked HTTP client, no
/// pretend network. This is exactly the mechanism a real content CDN
/// would be hit through.
void main() {
  late HttpServer server;
  late String baseUrl;
  late Directory tempDir;
  const fakeContentBytes = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  final fakeContentChecksum = sha256.convert(fakeContentBytes).toString();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('content_update_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.address}:${server.port}';

    server.listen((request) async {
      if (request.uri.path == '/manifest.json') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'version': 2,
          'url': '$baseUrl/content-v2.db',
          'sha256': fakeContentChecksum,
          'size_bytes': fakeContentBytes.length,
        }));
      } else if (request.uri.path == '/content-v2.db') {
        request.response.add(fakeContentBytes);
      } else if (request.uri.path == '/manifest_bad_checksum.json') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'version': 2,
          'url': '$baseUrl/content-v2.db',
          'sha256': 'deadbeef' * 8, // deliberately wrong
          'size_bytes': fakeContentBytes.length,
        }));
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

  test('checkForUpdate fetches and parses a real manifest over HTTP', () async {
    final checker = ContentUpdateChecker();
    final manifest = await checker.checkForUpdate('$baseUrl/manifest.json');

    expect(manifest, isNotNull);
    expect(manifest!.version, 2);
    expect(manifest.sha256, fakeContentChecksum);
    checker.close();
  });

  test('checkForUpdate returns null for an unreachable server (no network -> keep current content)', () async {
    final checker = ContentUpdateChecker();
    final manifest = await checker.checkForUpdate('http://127.0.0.1:1/manifest.json');
    expect(manifest, isNull);
    checker.close();
  });

  test('downloadAndInstall actually downloads, verifies checksum, and installs the file', () async {
    final checker = ContentUpdateChecker();
    final installPath = p.join(tempDir.path, 'content.db');
    await File(installPath).writeAsBytes([0, 0, 0]); // old content

    final manifest = await checker.checkForUpdate('$baseUrl/manifest.json');
    final result = await checker.downloadAndInstall(manifest!, installPath: installPath, currentVersion: 1);

    expect(result.status, ContentUpdateStatus.installed);
    expect(result.installedVersion, 2);
    expect(await File(installPath).readAsBytes(), fakeContentBytes);
    expect(await File('$installPath.bak').exists(), isFalse, reason: 'backup should be cleaned up after success');
    checker.close();
  });

  test('downloadAndInstall rejects a manifest with a checksum that doesn\'t match the downloaded bytes', () async {
    final checker = ContentUpdateChecker();
    final installPath = p.join(tempDir.path, 'content.db');
    await File(installPath).writeAsBytes([9, 9, 9]);

    final manifest = await checker.checkForUpdate('$baseUrl/manifest_bad_checksum.json');
    final result = await checker.downloadAndInstall(manifest!, installPath: installPath, currentVersion: 1);

    expect(result.status, ContentUpdateStatus.checksumMismatch);
    expect(await File(installPath).readAsBytes(), [9, 9, 9], reason: 'old content must be untouched on failure');
    checker.close();
  });

  test('downloadAndInstall is a no-op when already up to date', () async {
    final checker = ContentUpdateChecker();
    final installPath = p.join(tempDir.path, 'content.db');
    await File(installPath).writeAsBytes([9, 9, 9]);

    final manifest = await checker.checkForUpdate('$baseUrl/manifest.json'); // version 2
    final result = await checker.downloadAndInstall(manifest!, installPath: installPath, currentVersion: 2);

    expect(result.status, ContentUpdateStatus.upToDate);
    expect(await File(installPath).readAsBytes(), [9, 9, 9]);
    checker.close();
  });
}
