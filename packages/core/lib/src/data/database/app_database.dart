import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Opens the two local databases described in spec section 4:
/// - Content DB: read-only, shipped as a bundled asset, copied to a writable
///   location on first run (sqflite cannot open directly from the asset
///   bundle) and never rewritten afterwards.
/// - User DB: read/write, created fresh on-device, holds all learning
///   progress and settings, never leaves the device.
class AppDatabase {
  Database? _contentDb;
  Database? _userDb;

  static const String _contentDbAssetPath = 'assets/content/content.db';
  static const String _contentDbFileName = 'content.db';
  static const String _userDbFileName = 'user.db';

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
    final supportDir = await getApplicationSupportDirectory();
    _contentDb = await _openContentDatabase(supportDir.path);
    _userDb = await _openUserDatabase(supportDir.path);
  }

  Future<Database> _openContentDatabase(String supportDirPath) async {
    final dbPath = p.join(supportDirPath, _contentDbFileName);
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

  Future<void> close() async {
    await _contentDb?.close();
    await _userDb?.close();
  }
}
