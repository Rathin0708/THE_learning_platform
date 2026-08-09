import 'package:core/core.dart';
import 'package:http/http.dart' as http;

/// Streaming download + SHA-256 verification + crash-safe atomic install
/// for a single large file (a GGUF model can be 500 MB-1 GB+, unlike
/// [ContentUpdateChecker]'s small content.db). Delegates to
/// [InstallPackInstaller] (THE-68) as a single-file pack — see that
/// class's doc comment for the actual download/verify/swap mechanics,
/// shared with [ContentUpdateChecker].
class ModelDownloader {
  final http.Client _client;
  ModelDownloader({http.Client? client}) : _client = client ?? http.Client();

  Stream<ModelDownloadEvent> download({
    required String url,
    required String sha256Hex,
    required int expectedSizeBytes,
    required String installPath,
  }) async* {
    final installer = InstallPackInstaller(client: _client);
    final files = [
      InstallPackFileSpec(url: url, sha256: sha256Hex, sizeBytes: expectedSizeBytes, installPath: installPath),
    ];
    await for (final event in installer.install(files)) {
      yield ModelDownloadEvent(_mapStatus(event.status), event.fraction);
    }
  }

  ModelDownloadStatus _mapStatus(InstallPackStatus status) => switch (status) {
        InstallPackStatus.inProgress => ModelDownloadStatus.inProgress,
        InstallPackStatus.complete => ModelDownloadStatus.complete,
        InstallPackStatus.downloadFailed => ModelDownloadStatus.downloadFailed,
        InstallPackStatus.checksumMismatch => ModelDownloadStatus.checksumMismatch,
      };

  void close() => _client.close();
}
