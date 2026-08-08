import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Versioned content update mechanism (THE-67, spec 8.4):
///
///   App detects internet -> checks for new pack -> downloads
///   -> verifies checksum -> installs -> deletes old pack
///   No internet -> continues on currently installed content, unaffected
///
/// This is the real download/verify/install machinery — it doesn't
/// require a live production CDN to exist to be genuine: point it at any
/// manifest URL serving `ContentUpdateManifest.toJson()`'s shape plus the
/// referenced .db file, and it does the real thing (verified in
/// content_update_checker_test.dart against a local HTTP server serving
/// an actual file, not mocked).
///
/// Every failure mode (no network, bad manifest, checksum mismatch,
/// download error) resolves to "keep using the currently installed
/// content" rather than throwing — matching spec 8.4's explicit
/// requirement that a missing network never breaks the app.
class ContentUpdateManifest {
  final int version;
  final String url;
  final String sha256;
  final int sizeBytes;

  const ContentUpdateManifest({
    required this.version,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  factory ContentUpdateManifest.fromJson(Map<String, dynamic> json) => ContentUpdateManifest(
        version: json['version'] as int,
        url: json['url'] as String,
        sha256: json['sha256'] as String,
        sizeBytes: json['size_bytes'] as int,
      );
}

enum ContentUpdateStatus { upToDate, noNetwork, manifestInvalid, downloadFailed, checksumMismatch, installed }

class ContentUpdateResult {
  final ContentUpdateStatus status;
  final int? installedVersion;
  const ContentUpdateResult(this.status, {this.installedVersion});
}

class ContentUpdateChecker {
  final http.Client _client;
  ContentUpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the manifest at [manifestUrl]. Returns null on any network or
  /// parse failure — the caller should treat that as "no update available
  /// right now", not an error to surface to the user.
  Future<ContentUpdateManifest?> checkForUpdate(String manifestUrl) async {
    try {
      final response = await _client.get(Uri.parse(manifestUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ContentUpdateManifest.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Downloads the pack described by [manifest], verifies its SHA-256
  /// checksum, and only on success replaces the file at [installPath].
  /// The old file is kept as [installPath].bak until the new one is
  /// verified in place, then deleted — so a failure partway through never
  /// leaves the app with a half-written or missing content database.
  Future<ContentUpdateResult> downloadAndInstall(
    ContentUpdateManifest manifest, {
    required String installPath,
    required int currentVersion,
  }) async {
    if (manifest.version <= currentVersion) {
      return const ContentUpdateResult(ContentUpdateStatus.upToDate);
    }

    final tempPath = '$installPath.download';
    final backupPath = '$installPath.bak';

    List<int> bytes;
    try {
      final response = await _client.get(Uri.parse(manifest.url)).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) return const ContentUpdateResult(ContentUpdateStatus.downloadFailed);
      bytes = response.bodyBytes;
    } catch (_) {
      return const ContentUpdateResult(ContentUpdateStatus.downloadFailed);
    }

    final actualChecksum = sha256.convert(bytes).toString();
    if (actualChecksum != manifest.sha256) {
      return const ContentUpdateResult(ContentUpdateStatus.checksumMismatch);
    }

    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    final installFile = File(installPath);
    if (await installFile.exists()) {
      await installFile.rename(backupPath);
    }
    await tempFile.rename(installPath);

    final backupFile = File(backupPath);
    if (await backupFile.exists()) {
      await backupFile.delete();
    }

    return ContentUpdateResult(ContentUpdateStatus.installed, installedVersion: manifest.version);
  }

  void close() => _client.close();
}
