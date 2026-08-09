import 'dart:io';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Streaming download + SHA-256 verification + crash-safe atomic install
/// for a single large file (a GGUF model can be 500 MB-1 GB+, unlike
/// [ContentUpdateChecker]'s small content.db, so this streams to disk and
/// hashes incrementally rather than buffering the whole response in
/// memory). Same "old file kept as `.bak` until the new one verifies"
/// swap [ContentUpdateChecker] uses, and the same "never throws, resolves
/// to a terminal failure status instead" contract.
///
/// THE-68 (modular install packs) is expected to generalize this and
/// [ContentUpdateChecker] into one shared mechanism; kept separate for now
/// since unifying a single-file GGUF download with a single-file content-DB
/// download isn't worth forcing together before THE-68 actually needs to
/// handle multi-file packs too.
class ModelDownloader {
  final http.Client _client;
  ModelDownloader({http.Client? client}) : _client = client ?? http.Client();

  Stream<ModelDownloadEvent> download({
    required String url,
    required String sha256Hex,
    required int expectedSizeBytes,
    required String installPath,
  }) async* {
    final tempFile = File('$installPath.download');
    final backupFile = File('$installPath.bak');
    await tempFile.parent.create(recursive: true);

    final sink = tempFile.openWrite();
    final hashOutput = AccumulatorSink<Digest>();
    final hashInput = sha256.startChunkedConversion(hashOutput);

    try {
      final response = await _client.send(http.Request('GET', Uri.parse(url))).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await sink.close();
        await _deleteIfExists(tempFile);
        yield const ModelDownloadEvent(ModelDownloadStatus.downloadFailed, 0);
        return;
      }

      var received = 0;
      final total = response.contentLength ?? expectedSizeBytes;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        hashInput.add(chunk);
        received += chunk.length;
        yield ModelDownloadEvent(ModelDownloadStatus.inProgress, total == 0 ? 0 : (received / total).clamp(0.0, 1.0));
      }
      hashInput.close();
      await sink.close();
    } catch (_) {
      await sink.close();
      await _deleteIfExists(tempFile);
      yield const ModelDownloadEvent(ModelDownloadStatus.downloadFailed, 0);
      return;
    }

    final actualHash = hashOutput.events.single.toString();
    if (actualHash != sha256Hex) {
      await _deleteIfExists(tempFile);
      yield const ModelDownloadEvent(ModelDownloadStatus.checksumMismatch, 0);
      return;
    }

    final installFile = File(installPath);
    if (await installFile.exists()) await installFile.rename(backupFile.path);
    await tempFile.rename(installPath);
    await _deleteIfExists(backupFile);

    yield const ModelDownloadEvent(ModelDownloadStatus.complete, 1.0);
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup — a leftover .download/.bak file next to a
      // successfully-verified install is harmless, so don't fail the
      // whole operation over it.
    }
  }

  void close() => _client.close();
}
