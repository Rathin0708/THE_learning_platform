import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../content_update/content_update_checker.dart';
import 'schema.dart';
import 'web_content_seeder.dart';

/// Opens the two local databases described in spec section 4:
/// - Content DB: read-only, shipped as a bundled asset, copied to a writable
///   location on first run (sqflite cannot open directly from the asset
///   bundle) and never rewritten afterwards.
/// - User DB: read/write, created fresh on-device, holds all learning
///   progress and settings, never leaves the device.
///
/// Web (THE-58) is a genuinely different code path: there is no
/// filesystem to copy content.db into, and sqflite_common_ffi_web always
/// creates a database empty — WebContentSeeder populates it from a JSON
/// export instead. Desktop/mobile keep the original file-copy approach.
class AppDatabase {
  Database? _contentDb;
  Database? _userDb;
  String? _contentDbFilePath;

  static const String _contentDbAssetPath = 'assets/content/content.db';
  static const String _contentDbFileName = 'content.db';
  static const String _userDbFileName = 'user.db';

  /// The content database's real filesystem path — needed by
  /// ContentUpdateChecker (THE-67) to know what file to replace. Null on
  /// web, where there is no filesystem (content lives in IndexedDB
  /// instead; versioned file swaps don't apply there).
  String? get contentDbFilePath => _contentDbFilePath;

  Database get content {
    final db = _contentDb;
    if (db == null) {
      throw StateError('Content database not initialized. Call open() first.');
    }
    return db;
  }

  Database get user {
    final db = _userDb;
    if (db == null) {
      throw StateError('User database not initialized. Call open() first.');
    }
    return db;
  }

  Future<void> open() async {
    if (kIsWeb) {
      _contentDb = await _openContentDatabaseWeb();
      _userDb = await _openUserDatabaseWeb();
      return;
    }
    final supportDir = await getApplicationSupportDirectory();
    _contentDb = await _openContentDatabase(supportDir.path);
    _userDb = await _openUserDatabase(supportDir.path);
  }

  Future<Database> _openContentDatabase(String supportDirPath) async {
    final dbPath = p.join(supportDirPath, _contentDbFileName);
    _contentDbFilePath = dbPath;
    final file = File(dbPath);

    if (!await file.exists()) {
      try {
        final bytes = await rootBundle.load(_contentDbAssetPath);
        await file.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      } catch (_) {
        // No bundled content pack yet (first-run before `content_compiler`
        // has produced one) — fall back to an empty schema so the app still
        // boots; content-driven screens will simply show no results.
      }
    }

    final db = await openDatabase(dbPath, readOnly: false, version: 1);
    for (final statement in contentDatabaseDdl) {
      await db.execute(statement);
    }
    return db;
  }

  Future<Database> _openUserDatabase(String supportDirPath) async {
    final dbPath = p.join(supportDirPath, _userDbFileName);
    final db = await openDatabase(dbPath, version: 1);
    for (final statement in userDatabaseDdl) {
      await db.execute(statement);
    }
    return db;
  }

  Future<Database> _openContentDatabaseWeb() async {
    final db = await openDatabase(_contentDbFileName, version: 1);
    for (final statement in contentDatabaseDdl) {
      await db.execute(statement);
    }
    // Same graceful fallback as desktop/mobile if no export is bundled:
    // WebContentSeeder.seedIfEmpty() no-ops rather than throwing.
    await WebContentSeeder().seedIfEmpty(db);
    return db;
  }

  Future<Database> _openUserDatabaseWeb() async {
    final db = await openDatabase(_userDbFileName, version: 1);
    for (final statement in userDatabaseDdl) {
      await db.execute(statement);
    }
    return db;
  }

  Future<void> close() async {
    await _contentDb?.close();
    await _userDb?.close();
  }

  /// Applies a content update (THE-67) safely: the sqflite connection
  /// must be closed *before* the file is replaced — on Windows in
  /// particular, an open file handle blocks the rename ContentUpdateChecker
  /// does internally, so skipping this would make the update silently
  /// fail (or corrupt the file) rather than just not applying. Reopens
  /// the (possibly new) database afterward either way, so the app is
  /// never left without a usable content connection.
  Future<ContentUpdateResult> applyContentUpdate(
    ContentUpdateChecker checker,
    ContentUpdateManifest manifest,
    int currentVersion,
  ) async {
    final path = _contentDbFilePath;
    if (kIsWeb || path == null) {
      return const ContentUpdateResult(ContentUpdateStatus.downloadFailed);
    }

    await _contentDb?.close();
    final result = await checker.downloadAndInstall(manifest, installPath: path, currentVersion: currentVersion);

    final db = await openDatabase(path, readOnly: false, version: 1);
    for (final statement in contentDatabaseDdl) {
      await db.execute(statement);
    }
    _contentDb = db;

    return result;
  }
}
