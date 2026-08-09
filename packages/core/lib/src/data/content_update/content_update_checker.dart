import 'dart:convert';

import 'package:http/http.dart' as http;

import '../install_pack/install_pack_installer.dart';

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
  ///
  /// Delegates the actual download/verify/swap to [InstallPackInstaller]
  /// (THE-68) as a single-file pack — the version-gate above is the only
  /// content-specific logic left here.
  Future<ContentUpdateResult> downloadAndInstall(
    ContentUpdateManifest manifest, {
    required String installPath,
    required int currentVersion,
  }) async {
    if (manifest.version <= currentVersion) {
      return const ContentUpdateResult(ContentUpdateStatus.upToDate);
    }

    final events = await InstallPackInstaller(client: _client).install([
      InstallPackFileSpec(url: manifest.url, sha256: manifest.sha256, sizeBytes: manifest.sizeBytes, installPath: installPath),
    ]).toList();

    return switch (events.last.status) {
      InstallPackStatus.complete => ContentUpdateResult(ContentUpdateStatus.installed, installedVersion: manifest.version),
      InstallPackStatus.checksumMismatch => const ContentUpdateResult(ContentUpdateStatus.checksumMismatch),
      InstallPackStatus.downloadFailed || InstallPackStatus.inProgress => const ContentUpdateResult(
          ContentUpdateStatus.downloadFailed,
        ),
    };
  }

  void close() => _client.close();
}
