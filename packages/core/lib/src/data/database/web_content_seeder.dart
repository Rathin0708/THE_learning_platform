import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

/// Populates an empty web (IndexedDB-backed) content database from the
/// JSON export produced by tools/content_compiler/compile.py (THE-58).
///
/// sqflite_common_ffi_web has no API to import an existing SQLite file
/// into its IndexedDB storage — openDatabase() on web always creates an
/// empty database. On desktop/mobile, AppDatabase instead copies the
/// compiled content.db file bytes directly and opens that (see
/// app_database.dart) — this seeder exists only because web can't do
/// that and needs a second, INSERT-based path to reach the same state.
class WebContentSeeder {
  static const String _assetPath = 'assets/content/content.json';

  /// Order matters: tables with foreign keys must be seeded after the
  /// tables they reference.
  static const List<String> _tableOrder = [
    'languages',
    'levels',
    'categories',
    'words',
    'translations',
    'sentences',
    'sentence_translations',
    'pronunciations',
    'examples',
    'grammar',
    'conversations',
    'conversation_lines',
    'quiz_questions',
  ];

  Future<void> seedIfEmpty(Database db) async {
    final existing = await db.rawQuery('SELECT COUNT(*) AS c FROM words');
    final wordCount = (existing.first['c'] as int?) ?? 0;
    if (wordCount > 0) return; // already seeded (e.g. hot-reload keeping IndexedDB)

    String jsonString;
    try {
      jsonString = await rootBundle.loadString(_assetPath);
    } catch (_) {
      // No web content export bundled (e.g. compiler hasn't been run with
      // --json-out yet) — same graceful empty-schema fallback as the
      // desktop/mobile path in app_database.dart.
      return;
    }

    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    await db.transaction((txn) async {
      for (final table in _tableOrder) {
        final rows = (data[table] as List<dynamic>?) ?? const [];
        if (rows.isEmpty) continue;
        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(table, Map<String, Object?>.from(row as Map));
        }
        await batch.commit(noResult: true);
      }
    });
  }
}
