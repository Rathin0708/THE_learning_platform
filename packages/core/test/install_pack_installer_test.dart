import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:core/core.dart';

/// Real end-to-end test (THE-68): a local HTTP server serves several
/// files, and [InstallPackInstaller] downloads/verifies/installs them as
/// one pack — same real-HTTP-server approach as
/// content_update_checker_test.dart. The behavior this adds beyond the
/// single-file mechanisms it replaces internally (see
/// content_update_checker_test.dart / model_downloader_test.dart, both
/// still passing unchanged) is proven here: a pack installs atomically —
/// if any one file fails, *none* of them land.
void main() {
  late HttpServer server;
  late String baseUrl;
  late Directory tempDir;

  final fileA = List<int>.generate(30000, (i) => i % 256);
  final fileB = List<int>.generate(50000, (i) => (i * 3) % 256);
  final fileAHash = sha256.convert(fileA).toString();
  final fileBHash = sha256.convert(fileB).toString();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('install_pack_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.address}:${server.port}';
    server.listen((request) async {
      switch (request.uri.path) {
        case '/a.bin':
          request.response.add(fileA);
        case '/b.bin':
          request.response.add(fileB);
        default:
          request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  test('install() downloads and installs every file in a multi-file pack', () async {
    final installer = InstallPackInstaller();
    final files = [
      InstallPackFileSpec(url: '$baseUrl/a.bin', sha256: fileAHash, sizeBytes: fileA.length, installPath: p.join(tempDir.path, 'a.bin')),
      InstallPackFileSpec(url: '$baseUrl/b.bin', sha256: fileBHash, sizeBytes: fileB.length, installPath: p.join(tempDir.path, 'sub', 'b.bin')),
    ];

    final events = await installer.install(files).toList();

    expect(events.last.status, InstallPackStatus.complete);
    expect(await File(p.join(tempDir.path, 'a.bin')).readAsBytes(), fileA);
    expect(await File(p.join(tempDir.path, 'sub', 'b.bin')).readAsBytes(), fileB);
    installer.close();
  });

  test('install() is all-or-nothing: one bad checksum leaves every file in the pack uninstalled', () async {
    final installer = InstallPackInstaller();
    final aPath = p.join(tempDir.path, 'a.bin');
    final bPath = p.join(tempDir.path, 'b.bin');
    final files = [
      InstallPackFileSpec(url: '$baseUrl/a.bin', sha256: fileAHash, sizeBytes: fileA.length, installPath: aPath),
      // Wrong checksum for b — the whole pack must fail, including the
      // already-downloaded-and-verified a.bin.
      InstallPackFileSpec(url: '$baseUrl/b.bin', sha256: 'deadbeef' * 8, sizeBytes: fileB.length, installPath: bPath),
    ];

    final events = await installer.install(files).toList();

    expect(events.last.status, InstallPackStatus.checksumMismatch);
    expect(await File(aPath).exists(), isFalse, reason: 'a.bin verified fine but must not be installed since b.bin failed');
    expect(await File(bPath).exists(), isFalse);
    installer.close();
  });

  test('install() preserves existing files when a pack update fails', () async {
    final installer = InstallPackInstaller();
    final aPath = p.join(tempDir.path, 'a.bin');
    await Directory(tempDir.path).create(recursive: true);
    await File(aPath).writeAsBytes([9, 9, 9]);

    final files = [
      InstallPackFileSpec(url: '$baseUrl/missing', sha256: fileAHash, sizeBytes: 10, installPath: aPath),
    ];
    final events = await installer.install(files).toList();

    expect(events.last.status, InstallPackStatus.downloadFailed);
    expect(await File(aPath).readAsBytes(), [9, 9, 9], reason: 'old file must survive a failed pack update');
    installer.close();
  });
}
