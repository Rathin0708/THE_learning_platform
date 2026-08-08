import 'package:sqflite/sqflite.dart';

import '../../domain/entities/content_entities.dart';
import '../../domain/repositories/content_repository.dart';

class SqliteContentRepository implements ContentRepository {
  final Database db;

  SqliteContentRepository(this.db);

  WordEntity _wordFromRow(Map<String, Object?> row) => WordEntity(
        id: row['id'] as int,
        language: LanguageCodeX.fromCode(row['lang_code'] as String? ?? 'en'),
        word: row['word'] as String,
        normalizedWord: row['normalized_word'] as String,
        partOfSpeech: (row['type'] as String?) ?? '',
        level: row['level'] as String,
        category: row['category'] as String,
        frequency: (row['frequency'] as num?)?.toDouble() ?? 0,
        difficulty: (row['difficulty'] as int?) ?? 1,
      );

  static const _wordSelect = '''
    SELECT w.*, l.code AS lang_code FROM words w
    JOIN languages l ON l.id = w.language_id
  ''';

  @override
  Future<List<SearchResult>> search(String query, {int limit = 20}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    // FTS5 match across word / normalized_word / romanized columns resolves
    // native script, transliteration, and Tamil-approximate input to the
    // same result set (spec 4.3 / 9.3).
    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(
        '''
        $_wordSelect
        WHERE w.id IN (
          SELECT rowid FROM words_fts WHERE words_fts MATCH ?
        )
        ORDER BY w.frequency DESC
        LIMIT ?
        ''',
        ['$normalized*', limit],
      );
    } catch (_) {
      // FTS5 query syntax error (e.g. punctuation) — fall back to LIKE.
      rows = [];
    }

    if (rows.isEmpty) {
      rows = await db.rawQuery(
        '''
        $_wordSelect
        WHERE w.normalized_word LIKE ? OR w.word LIKE ?
        ORDER BY w.frequency DESC
        LIMIT ?
        ''',
        ['%$normalized%', '%$normalized%', limit],
      );
    }

    final results = <SearchResult>[];
    for (final row in rows) {
      final word = _wordFromRow(row);
      final translations = await _translationsFor(word.id);
      results.add(SearchResult(word: word, translations: translations));
    }
    return results;
  }

  Future<Map<LanguageCode, String>> _translationsFor(int wordId) async {
    final rows = await db.rawQuery(
      '''
      SELECT tw.word AS target_word, l.code AS lang_code
      FROM translations t
      JOIN words tw ON tw.id = t.target_word_id
      JOIN languages l ON l.id = tw.language_id
      WHERE t.source_word_id = ?
      ''',
      [wordId],
    );
    final map = <LanguageCode, String>{};
    for (final row in rows) {
      map[LanguageCodeX.fromCode(row['lang_code'] as String)] = row['target_word'] as String;
    }
    return map;
  }

  @override
  Future<WordDetail?> getWordDetail(int wordId) async {
    final rows = await db.rawQuery('$_wordSelect WHERE w.id = ?', [wordId]);
    if (rows.isEmpty) return null;
    final word = _wordFromRow(rows.first);
    final translations = await _translationsFor(wordId);

    final pronRows = await db.query('pronunciations', where: 'content_id = ?', whereArgs: [wordId], limit: 1);
    PronunciationEntity? pronunciation;
    if (pronRows.isNotEmpty) {
      final r = pronRows.first;
      pronunciation = PronunciationEntity(
        id: r['id'] as int,
        contentId: r['content_id'] as int,
        language: LanguageCodeX.fromCode(r['language'] as String),
        ipa: r['ipa'] as String?,
        tamilPronunciation: r['tamil_pronunciation'] as String?,
        englishPronunciation: r['english_pronunciation'] as String?,
        audioAsset: r['audio_asset'] as String?,
      );
    }

    final exampleRows = await db.query('examples', where: 'word_id = ?', whereArgs: [wordId]);
    final examples = exampleRows
        .map((r) => ExampleEntity(
              id: r['id'] as int,
              wordId: r['word_id'] as int?,
              sentenceId: r['sentence_id'] as int?,
              context: (r['context'] as String?) ?? '',
              meaning: (r['meaning'] as String?) ?? '',
            ))
        .toList();

    return WordDetail(word: word, translations: translations, pronunciation: pronunciation, examples: examples);
  }

  @override
  Future<List<WordEntity>> getWordsByLevel(String level, {int limit = 20, int offset = 0}) async {
    final rows = await db.rawQuery(
      '$_wordSelect WHERE w.level = ? ORDER BY w.frequency DESC LIMIT ? OFFSET ?',
      [level, limit, offset],
    );
    return rows.map(_wordFromRow).toList();
  }

  @override
  Future<List<SentenceEntity>> getSentencesByLevel(String level, {int limit = 20, int offset = 0}) async {
    final rows = await db.query('sentences', where: 'level = ?', whereArgs: [level], limit: limit, offset: offset);
    return rows
        .map((r) => SentenceEntity(
              id: r['id'] as int,
              level: r['level'] as String,
              category: r['category'] as String,
              sourceLanguage: LanguageCodeX.fromCode(r['source_language'] as String),
              sourceText: r['source_text'] as String,
            ))
        .toList();
  }

  @override
  Future<Map<LanguageCode, String>> getSentenceTranslations(int sentenceId) async {
    final rows = await db.query('sentence_translations', where: 'sentence_id = ?', whereArgs: [sentenceId]);
    final map = <LanguageCode, String>{};
    for (final r in rows) {
      map[LanguageCodeX.fromCode(r['language'] as String)] = r['translated_text'] as String;
    }
    return map;
  }

  @override
  Future<List<QuizQuestionEntity>> getQuizQuestions(String level, {int limit = 10}) async {
    final rows = await db.query('quiz_questions', where: 'level = ?', whereArgs: [level], limit: limit);
    return rows
        .map((r) => QuizQuestionEntity(
              id: r['id'] as int,
              level: r['level'] as String,
              type: r['type'] as String,
              question: r['question'] as String,
              answer: r['answer'] as String,
              options: ((r['options'] as String?) ?? '').split('|').where((s) => s.isNotEmpty).toList(),
              contentId: r['content_id'] as int?,
            ))
        .toList();
  }

  @override
  Future<List<ConversationEntity>> getConversations({String? level}) async {
    final rows = level == null
        ? await db.query('conversations')
        : await db.query('conversations', where: 'level = ?', whereArgs: [level]);
    return rows
        .map((r) => ConversationEntity(
              id: r['id'] as int,
              level: r['level'] as String,
              scenario: r['scenario'] as String,
              title: r['title'] as String,
            ))
        .toList();
  }

  @override
  Future<List<ConversationLineEntity>> getConversationLines(int conversationId) async {
    final rows = await db.query('conversation_lines', where: 'conversation_id = ?', whereArgs: [conversationId]);
    return rows
        .map((r) => ConversationLineEntity(
              id: r['id'] as int,
              conversationId: r['conversation_id'] as int,
              speaker: r['speaker'] as String,
              text: r['text'] as String,
              translation: r['translation'] as String,
              expectedResponse: r['expected_response'] as String?,
            ))
        .toList();
  }

  @override
  Future<int> getWordCount() async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM words');
    return (rows.first['c'] as int?) ?? 0;
  }
}
