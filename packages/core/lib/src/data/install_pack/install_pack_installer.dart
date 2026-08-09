import 'dart:io';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// One file within an install pack: its source, expected checksum/size,
/// and where it lands on disk.
class InstallPackFileSpec {
  final String url;
  final String sha256;
  final int sizeBytes;
  final String installPath;

  const InstallPackFileSpec({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.installPath,
  });
}

enum InstallPackStatus { inProgress, complete, downloadFailed, checksumMismatch }

class InstallPackEvent {
  final InstallPackStatus status;

  /// Fraction of total bytes (across every file in the pack) transferred
  /// so far, in [0.0, 1.0].
  final double fraction;

  const InstallPackEvent(this.status, this.fraction);
}

/// Generalizes [ContentUpdateChecker] and `ModelDownloader`'s download ->
/// verify -> atomic install -> cleanup pattern (THE-68) to N files
/// installed as one unit — e.g. a Piper voice (model + tokens + an
/// espeak-ng-data directory of many files), not just a single content.db
/// or GGUF file.
///
/// Each file streams to disk with incremental SHA-256 verification (no
/// whole-response buffering — the same reason [ModelDownloader] needed
/// this over [ContentUpdateChecker]'s original in-memory approach, now
/// the shared behavior for both). Every file in the pack must download
/// and verify successfully before *any* of them are swapped into place —
/// a pack is never left half-installed. The swap itself keeps each old
/// file as `<path>.bak` until its replacement is confirmed in place, the
/// same crash-safe rename dance the two single-file mechanisms already
/// used individually.
class InstallPackInstaller {
  final http.Client _client;
  InstallPackInstaller({http.Client? client}) : _client = client ?? http.Client();

  Stream<InstallPackEvent> install(List<InstallPackFileSpec> files) async* {
    final tempPaths = [for (final f in files) '${f.installPath}.download'];
    final backupPaths = [for (final f in files) '${f.installPath}.bak'];
    final totalBytes = files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    var bytesSoFar = 0;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final tempFile = File(tempPaths[i]);
      await tempFile.parent.create(recursive: true);

      final sink = tempFile.openWrite();
      final hashOutput = AccumulatorSink<Digest>();
      final hashInput = sha256.startChunkedConversion(hashOutput);

      try {
        final response = await _client.send(http.Request('GET', Uri.parse(file.url))).timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          await sink.close();
          await _cleanup(tempPaths);
          yield InstallPackEvent(InstallPackStatus.downloadFailed, _fraction(bytesSoFar, totalBytes));
          return;
        }
        await for (final chunk in response.stream) {
          sink.add(chunk);
          hashInput.add(chunk);
          bytesSoFar += chunk.length;
          yield InstallPackEvent(InstallPackStatus.inProgress, _fraction(bytesSoFar, totalBytes));
        }
        hashInput.close();
        await sink.close();
      } catch (_) {
        await sink.close();
        await _cleanup(tempPaths);
        yield InstallPackEvent(InstallPackStatus.downloadFailed, _fraction(bytesSoFar, totalBytes));
        return;
      }

      final actualHash = hashOutput.events.single.toString();
      if (actualHash != file.sha256) {
        await _cleanup(tempPaths);
        yield InstallPackEvent(InstallPackStatus.checksumMismatch, _fraction(bytesSoFar, totalBytes));
        return;
      }
    }

    // Every file verified — now swap them all in.
    for (var i = 0; i < files.length; i++) {
      final installFile = File(files[i].installPath);
      if (await installFile.exists()) await installFile.rename(backupPaths[i]);
      await File(tempPaths[i]).rename(files[i].installPath);
    }
    await _cleanup(backupPaths);

    yield const InstallPackEvent(InstallPackStatus.complete, 1.0);
  }

  double _fraction(int bytesSoFar, int totalBytes) => totalBytes == 0 ? 0 : (bytesSoFar / totalBytes).clamp(0.0, 1.0);

  Future<void> _cleanup(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort — a leftover .download/.bak file next to a
        // successfully-verified install is harmless.
      }
    }
  }

  void close() => _client.close();
}
