import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_ai/src/local_ai_model_manager_io.dart';
import 'package:local_ai/src/model_downloader.dart';

/// Real end-to-end test (THE-61): a local HTTP server stands in for
/// HuggingFace (same approach as model_downloader_test.dart/
/// content_update_checker_test.dart), driving the exact
/// [LocalAiModelManagerIo] code the UI uses — download, select, delete —
/// against real files in a temp directory (via the `localAiDirOverride`
/// constructor param, since path_provider needs a platform channel that
/// plain `flutter test` doesn't register). What's NOT covered here is the
/// real HuggingFace URLs baked into the catalog — those are verified
/// manually (real download through the running app), since re-downloading
/// 500MB-1GB models on every test run isn't practical.
void main() {
  late HttpServer server;
  late String baseUrl;
  late Directory tempDir;
  final fakeModelBytes = List<int>.generate(50000, (i) => i % 256);
  final fakeModelChecksum = sha256.convert(fakeModelBytes).toString();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_ai_model_manager_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.address}:${server.port}';
    server.listen((request) async {
      request.response.add(fakeModelBytes);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  /// Downloads directly through [ModelDownloader] against the fake server
  /// into the exact path [LocalAiModelManagerIo] would use, bypassing the
  /// real-catalog URL — proves select()/delete()/isInstalled() work
  /// correctly on real files without needing HuggingFace reachable in CI.
  Future<LocalAiModelManagerIo> managerWithOneModelDownloaded(String modelId) async {
    final manager = LocalAiModelManagerIo(localAiDirOverride: () async => tempDir);
    final target = File('${tempDir.path}/models/$modelId.gguf');
    await ModelDownloader()
        .download(url: '$baseUrl/x', sha256Hex: fakeModelChecksum, expectedSizeBytes: fakeModelBytes.length, installPath: target.path)
        .toList();
    return manager;
  }

  test('catalog lists both known models with real sizes', () {
    final manager = LocalAiModelManagerIo(localAiDirOverride: () async => tempDir);
    expect(manager.catalog, hasLength(2));
    expect(manager.catalog.map((e) => e.id), containsAll(['qwen2.5-0.5b-instruct-q4_k_m', 'qwen2.5-1.5b-instruct-q4_k_m']));
  });

  test('isInstalled/selectedModelId are false/null before anything is downloaded', () async {
    final manager = LocalAiModelManagerIo(localAiDirOverride: () async => tempDir);
    expect(await manager.isInstalled('qwen2.5-0.5b-instruct-q4_k_m'), isFalse);
    expect(await manager.selectedModelId(), isNull);
  });

  test('select() copies the downloaded model to the canonical model.gguf path and records the id', () async {
    const modelId = 'qwen2.5-0.5b-instruct-q4_k_m';
    final manager = await managerWithOneModelDownloaded(modelId);

    expect(await manager.isInstalled(modelId), isTrue);
    await manager.select(modelId);

    expect(await manager.selectedModelId(), modelId);
    final canonicalPath = File('${tempDir.path}/model.gguf');
    expect(await canonicalPath.exists(), isTrue);
    expect(await canonicalPath.readAsBytes(), fakeModelBytes);
  });

  test('delete() removes the model and clears selection if it was selected', () async {
    const modelId = 'qwen2.5-0.5b-instruct-q4_k_m';
    final manager = await managerWithOneModelDownloaded(modelId);
    await manager.select(modelId);

    await manager.delete(modelId);

    expect(await manager.isInstalled(modelId), isFalse);
    expect(await manager.selectedModelId(), isNull);
    expect(await File('${tempDir.path}/model.gguf').exists(), isFalse);
  });

  test('deleting a non-selected model leaves the current selection untouched', () async {
    const selectedId = 'qwen2.5-0.5b-instruct-q4_k_m';
    const otherId = 'qwen2.5-1.5b-instruct-q4_k_m';
    final manager = await managerWithOneModelDownloaded(selectedId);
    await manager.select(selectedId);

    // Download the other model too, then delete it without selecting it.
    await ModelDownloader()
        .download(
          url: '$baseUrl/x',
          sha256Hex: fakeModelChecksum,
          expectedSizeBytes: fakeModelBytes.length,
          installPath: '${tempDir.path}/models/$otherId.gguf',
        )
        .toList();
    await manager.delete(otherId);

    expect(await manager.selectedModelId(), selectedId, reason: 'deleting an unselected model must not clear selection');
  });
}
