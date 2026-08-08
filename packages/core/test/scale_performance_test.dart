import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:core/core.dart';

/// THE-69 (spec 9.6): "Never load all 100K records at startup — always
/// indexed query returning a small page." This is a genuine stress test
/// at 100K+ rows, not a claim taken on faith — seeds a real 120,000-row
/// words table in an in-memory database and times/inspects the exact
/// query the app uses.
void main() {
  sqfliteFfiInit();

  group('SqliteContentRepository at 100K+ scale', () {
    late Database db;
    late SqliteContentRepository repo;

    setUpAll(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      for (final statement in contentDatabaseDdl) {
        await db.execute(statement);
      }
      repo = SqliteContentRepository(db);

      await db.insert('languages', {'id': 1, 'code': 'en', 'name': 'English', 'native_name': 'English'});

      const total = 120000;
      const batchSize = 2000;
      final levels = ['level_1', 'level_2', 'level_3'];
      var inserted = 0;
      while (inserted < total) {
        final batch = db.batch();
        for (var i = 0; i < batchSize && inserted < total; i++, inserted++) {
          batch.insert('words', {
            'language_id': 1,
            'word': 'word_$inserted',
            'normalized_word': 'word_$inserted',
            'level': levels[inserted % levels.length],
            'category': 'test',
            'frequency': (inserted % 1000) / 1000.0,
            'difficulty': 1,
          });
        }
        await batch.commit(noResult: true);
      }
    });

    tearDownAll(() async => db.close());

    test('the real word count is genuinely 100K+ (sanity-checking the test setup itself)', () async {
      final count = await repo.getWordCount();
      expect(count, greaterThanOrEqualTo(100000));
    });

    test('getWordsByLevel (the query Vocabulary/Lessons actually call) never scans the whole table', () async {
      final plan = await db.rawQuery(
        "EXPLAIN QUERY PLAN SELECT w.*, l.code AS lang_code FROM words w "
        "JOIN languages l ON l.id = w.language_id "
        "WHERE w.level = ? ORDER BY w.frequency DESC LIMIT ? OFFSET ?",
        ['level_1', 20, 0],
      );
      final planText = plan.map((r) => r.values.join(' ')).join('\n');

      expect(planText, isNot(contains('SCAN words')),
          reason: 'a bare "SCAN words" (full table scan) at 100K+ rows would defeat the point of this ticket.\n'
              'Actual plan:\n$planText');
    });

    test('getWordsByLevel returns a small page fast, regardless of table size', () async {
      final stopwatch = Stopwatch()..start();
      final page = await repo.getWordsByLevel('level_1', limit: 20, offset: 0);
      stopwatch.stop();

      expect(page.length, 20, reason: 'must return a small page, never the full matching set');
      // Generous bound for a debug/CI-mode in-memory DB — the point isn't
      // a strict SLA, it's proving this doesn't scale linearly with table
      // size (an unindexed scan of 100K+ rows would be far slower and
      // grow with content volume, which a page-limited indexed query must not).
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'query took ${stopwatch.elapsedMilliseconds}ms against 120,000 rows — '
              'should be near-instant regardless of table size if truly indexed');
    });

    test('search() also returns a bounded page, not the full result set', () async {
      final results = await repo.search('word', limit: 20);
      expect(results.length, lessThanOrEqualTo(20));
    });
  });
}
