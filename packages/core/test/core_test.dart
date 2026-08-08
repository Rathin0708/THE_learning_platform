import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:core/core.dart';

Future<Database> _openInMemory(List<String> ddl) async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  for (final statement in ddl) {
    await db.execute(statement);
  }
  return db;
}

void main() {
  sqfliteFfiInit();

  group('SqliteContentRepository.getSentencesContainingWord (THE-34, spec 6.4)', () {
    late Database contentDb;
    late SqliteContentRepository repo;

    setUp(() async {
      contentDb = await _openInMemory(contentDatabaseDdl);
      repo = SqliteContentRepository(contentDb);

      var id = 1;
      Future<void> insertSentence(String text) async {
        await contentDb.insert('sentences', {
          'id': id, 'level': 'level_1', 'category': 'basic_verbs',
          'source_language': 'en', 'source_text': text,
        });
        id++;
      }

      // The exact spec 6.4 worked example: missing "want"/"need" should
      // resurface those words plus every sentence using them.
      await insertSentence('I want water.');
      await insertSentence('I need help.');
      await insertSentence('I want to go.');
      await insertSentence('I need to work.');
      await insertSentence('This is unwanted.'); // must NOT match "want" (word-boundary check)
      await insertSentence('The weather is good.'); // unrelated, must not match
    });

    tearDown(() async => contentDb.close());

    test('resurfaces every sentence using the missed word "want"', () async {
      final sentences = await repo.getSentencesContainingWord('want');
      final texts = sentences.map((s) => s.sourceText).toSet();

      expect(texts, containsAll(['I want water.', 'I want to go.']));
      expect(texts, isNot(contains('This is unwanted.')), reason: 'must respect word boundaries, not substring-match');
      expect(texts, isNot(contains('I need help.')));
    });

    test('resurfaces every sentence using the missed word "need"', () async {
      final sentences = await repo.getSentencesContainingWord('need');
      final texts = sentences.map((s) => s.sourceText).toSet();

      expect(texts, containsAll(['I need help.', 'I need to work.']));
      expect(texts, isNot(contains('I want water.')));
    });
  });

  group('SqliteProgressRepository.getLearningStats', () {
    late Database contentDb;
    late Database userDb;
    late SqliteProgressRepository repo;

    setUp(() async {
      contentDb = await _openInMemory(contentDatabaseDdl);
      userDb = await _openInMemory(userDatabaseDdl);
      repo = SqliteProgressRepository(userDb, contentDb);

      // Seed one English word and one Tamil word in content.db.
      await contentDb.insert('languages', {'id': 1, 'code': 'en', 'name': 'English', 'native_name': 'English'});
      await contentDb.insert('languages', {'id': 2, 'code': 'ta', 'name': 'Tamil', 'native_name': 'தமிழ்'});
      await contentDb.insert('words', {
        'id': 101, 'language_id': 1, 'word': 'hello', 'normalized_word': 'hello',
        'level': 'level_1', 'category': 'greetings', 'frequency': 0.9, 'difficulty': 1,
      });
      await contentDb.insert('words', {
        'id': 201, 'language_id': 2, 'word': 'வணக்கம்', 'normalized_word': 'vanakkam',
        'level': 'level_1', 'category': 'greetings', 'frequency': 0.9, 'difficulty': 1,
      });
    });

    tearDown(() async {
      await contentDb.close();
      await userDb.close();
    });

    test('computes real per-language mastery, not the same value repeated for every language', () async {
      await repo.saveProgress(UserProgressEntity.initial(101).copyWith(mastery: 0.9)); // english word
      await repo.saveProgress(UserProgressEntity.initial(201).copyWith(mastery: 0.3)); // tamil word

      final stats = await repo.getLearningStats();

      expect(stats.masteryByLanguage['en'], 0.9);
      expect(stats.masteryByLanguage['ta'], 0.3);
      expect(stats.masteryByLanguage['en'], isNot(equals(stats.masteryByLanguage['ta'])));
    });

    test('averages mastery across multiple words in the same language', () async {
      await contentDb.insert('words', {
        'id': 102, 'language_id': 1, 'word': 'goodbye', 'normalized_word': 'goodbye',
        'level': 'level_1', 'category': 'greetings', 'frequency': 0.8, 'difficulty': 1,
      });
      await repo.saveProgress(UserProgressEntity.initial(101).copyWith(mastery: 1.0));
      await repo.saveProgress(UserProgressEntity.initial(102).copyWith(mastery: 0.5));

      final stats = await repo.getLearningStats();

      expect(stats.masteryByLanguage['en'], closeTo(0.75, 0.0001));
    });

    test('returns an empty map when nothing has been reviewed yet', () async {
      final stats = await repo.getLearningStats();
      expect(stats.masteryByLanguage, isEmpty);
      expect(stats.wordsMastered, 0);
    });
  });

  group('SpacedRepetitionEngine', () {
    final engine = SpacedRepetitionEngine();
    final now = DateTime(2026, 1, 1);

    test('first correct review schedules a 1-day interval', () {
      final progress = UserProgressEntity.initial(1);
      final updated = engine.review(progress, 4, now: now);
      expect(updated.interval, 1);
      expect(updated.repetitions, 1);
      expect(updated.nextReview, now.add(const Duration(days: 1)));
    });

    test('schedule walks 1 -> 2 -> 4 -> 7 -> 14 -> 30 -> 60 on repeated correct answers', () {
      var progress = UserProgressEntity.initial(1);
      const expectedIntervals = [1, 2, 4, 7, 14, 30, 60];
      for (final expected in expectedIntervals) {
        progress = engine.review(progress, 4, now: now);
        expect(progress.interval, expected);
      }
    });

    test('a miss resets repetitions and shortens the interval back to day 1', () {
      var progress = UserProgressEntity.initial(1);
      progress = engine.review(progress, 4, now: now); // interval 1
      progress = engine.review(progress, 5, now: now); // interval 2
      progress = engine.review(progress, 2, now: now); // miss

      expect(progress.repetitions, 0);
      expect(progress.interval, 1);
    });

    test('mastery increases toward 1.0 with repeated correct reviews', () {
      var progress = UserProgressEntity.initial(1);
      for (var i = 0; i < 5; i++) {
        progress = engine.review(progress, 5, now: now);
      }
      expect(progress.mastery, greaterThan(0.5));
    });

    test('isDue is true when nextReview is null or in the past', () {
      final neverReviewed = UserProgressEntity.initial(1);
      expect(engine.isDue(neverReviewed, now: now), isTrue);

      final dueToday = neverReviewed.copyWith(nextReview: now.subtract(const Duration(days: 1)));
      expect(engine.isDue(dueToday, now: now), isTrue);

      final dueLater = neverReviewed.copyWith(nextReview: now.add(const Duration(days: 5)));
      expect(engine.isDue(dueLater, now: now), isFalse);
    });
  });
}
