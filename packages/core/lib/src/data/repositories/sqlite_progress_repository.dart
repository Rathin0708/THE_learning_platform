import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/user_entities.dart';
import '../../domain/repositories/progress_repository.dart';

class SqliteProgressRepository implements ProgressRepository {
  final Database db;

  /// Read-only handle to the Content DB, used only to resolve each
  /// reviewed content_id's language for per-language stats (THE-35).
  /// user.db and content.db remain separate connections/files (spec 4:
  /// "Two databases are kept logically separate") — this does a manual
  /// two-step join in Dart rather than ATTACHing one database to the
  /// other.
  final Database contentDb;

  SqliteProgressRepository(this.db, this.contentDb);

  UserProgressEntity _fromRow(Map<String, Object?> r) => UserProgressEntity(
        contentId: r['content_id'] as int,
        easeFactor: (r['ease_factor'] as num).toDouble(),
        interval: r['interval'] as int,
        repetitions: r['repetitions'] as int,
        lastReview: r['last_review'] != null ? DateTime.parse(r['last_review'] as String) : null,
        nextReview: r['next_review'] != null ? DateTime.parse(r['next_review'] as String) : null,
        mastery: (r['mastery'] as num).toDouble(),
      );

  @override
  Future<UserProgressEntity> getProgress(int contentId) async {
    final rows = await db.query('user_progress', where: 'content_id = ?', whereArgs: [contentId], limit: 1);
    if (rows.isEmpty) return UserProgressEntity.initial(contentId);
    return _fromRow(rows.first);
  }

  @override
  Future<void> saveProgress(UserProgressEntity progress) async {
    await db.insert(
      'user_progress',
      {
        'content_id': progress.contentId,
        'ease_factor': progress.easeFactor,
        'interval': progress.interval,
        'repetitions': progress.repetitions,
        'last_review': progress.lastReview?.toIso8601String(),
        'next_review': progress.nextReview?.toIso8601String(),
        'mastery': progress.mastery,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<int>> getDueContentIds({DateTime? now}) async {
    final effectiveNow = (now ?? DateTime.now()).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT content_id FROM user_progress WHERE next_review IS NULL OR next_review <= ? ORDER BY next_review ASC',
      [effectiveNow],
    );
    return rows.map((r) => r['content_id'] as int).toList();
  }

  @override
  Future<List<int>> getWeakContentIds({int missThreshold = 2}) async {
    final rows = await db.rawQuery(
      '''
      SELECT content_id, COUNT(*) as misses FROM review_log
      WHERE quality < 3
      GROUP BY content_id
      HAVING misses >= ?
      ORDER BY misses DESC
      ''',
      [missThreshold],
    );
    return rows.map((r) => r['content_id'] as int).toList();
  }

  @override
  Future<void> logReview(int contentId, int quality, DateTime reviewedAt) async {
    await db.insert('review_log', {
      'content_id': contentId,
      'quality': quality,
      'reviewed_at': reviewedAt.toIso8601String(),
    });
  }

  @override
  Future<LearningStats> getLearningStats() async {
    final masteredWords = await db.rawQuery('SELECT COUNT(*) c FROM user_progress WHERE mastery >= 0.8');
    final streak = await _computeStreak();
    final wordsMastered = (masteredWords.first['c'] as int?) ?? 0;

    final masteryByLanguage = await _computeMasteryByLanguage();

    return LearningStats(
      masteryByLanguage: masteryByLanguage,
      wordsMastered: wordsMastered,
      // Neither sentence-level review, speaking (needs ASR, Phase 4), nor
      // grammar content/lessons exist yet — these stay honestly at 0
      // rather than showing a fabricated percentage with no data behind
      // it. Wire up when their respective review flows exist.
      sentencesMastered: 0,
      speakingPercent: 0,
      grammarPercent: 0,
      streakDays: streak,
    );
  }

  /// user_progress.content_id currently always refers to a word (the only
  /// reviewable content type so far). Resolves each id's language from
  /// content.db and averages mastery per language — a real per-language
  /// breakdown, not the same overall average repeated for every language.
  Future<Map<String, double>> _computeMasteryByLanguage() async {
    final progressRows = await db.query('user_progress', columns: ['content_id', 'mastery']);
    if (progressRows.isEmpty) return {};

    final masteryByContentId = {
      for (final r in progressRows) r['content_id'] as int: (r['mastery'] as num).toDouble(),
    };
    final ids = masteryByContentId.keys.toList();

    final placeholders = List.filled(ids.length, '?').join(',');
    final wordRows = await contentDb.rawQuery(
      '''
      SELECT w.id AS word_id, l.code AS lang_code
      FROM words w JOIN languages l ON l.id = w.language_id
      WHERE w.id IN ($placeholders)
      ''',
      ids,
    );

    final masteryByLanguage = <String, List<double>>{};
    for (final row in wordRows) {
      final wordId = row['word_id'] as int;
      final langCode = row['lang_code'] as String;
      final mastery = masteryByContentId[wordId];
      if (mastery == null) continue;
      masteryByLanguage.putIfAbsent(langCode, () => []).add(mastery);
    }

    return {
      for (final entry in masteryByLanguage.entries)
        entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
    };
  }

  Future<int> _computeStreak() async {
    final rows = await db.rawQuery(
      "SELECT DISTINCT date(reviewed_at) as d FROM review_log ORDER BY d DESC",
    );
    if (rows.isEmpty) return 0;
    var streak = 0;
    var cursor = DateTime.now();
    for (final row in rows) {
      final day = DateTime.parse(row['d'] as String);
      final diff = cursor.difference(DateTime(day.year, day.month, day.day)).inDays;
      if (diff <= 1) {
        streak++;
        cursor = DateTime(day.year, day.month, day.day);
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Future<UserSettingsEntity> getSettings() async {
    final rows = await db.query('user_settings');
    final map = {for (final r in rows) r['key'] as String: r['value'] as String};
    return UserSettingsEntity(
      activeLanguages: (map['active_languages'] ?? 'ta,en').split(','),
      installedPacks: (map['installed_packs'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
      audioEnabled: (map['audio_enabled'] ?? 'true') == 'true',
      currentLevel: map['current_level'] ?? 'level_1',
    );
  }

  @override
  Future<void> saveSettings(UserSettingsEntity settings) async {
    final entries = {
      'active_languages': settings.activeLanguages.join(','),
      'installed_packs': settings.installedPacks.join(','),
      'audio_enabled': settings.audioEnabled.toString(),
      'current_level': settings.currentLevel,
    };
    for (final entry in entries.entries) {
      await db.insert(
        'user_settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static const _recentSearchesKey = 'recent_searches';

  @override
  Future<List<String>> getRecentSearches({int limit = 10}) async {
    final rows = await db.query('user_settings', where: 'key = ?', whereArgs: [_recentSearchesKey], limit: 1);
    if (rows.isEmpty) return [];
    final decoded = jsonDecode(rows.first['value'] as String) as List<dynamic>;
    return decoded.cast<String>().take(limit).toList();
  }

  @override
  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final current = await getRecentSearches(limit: 50);
    final updated = [trimmed, ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase())].take(10).toList();
    await db.insert(
      'user_settings',
      {'key': _recentSearchesKey, 'value': jsonEncode(updated)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static const _contentVersionKey = 'content_version';

  @override
  Future<int> getContentVersion() async {
    final rows = await db.query('user_settings', where: 'key = ?', whereArgs: [_contentVersionKey], limit: 1);
    if (rows.isEmpty) return 1;
    return int.tryParse(rows.first['value'] as String) ?? 1;
  }

  @override
  Future<void> setContentVersion(int version) async {
    await db.insert(
      'user_settings',
      {'key': _contentVersionKey, 'value': version.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
