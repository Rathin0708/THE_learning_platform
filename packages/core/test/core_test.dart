import 'package:flutter_test/flutter_test.dart';

import 'package:core/core.dart';

void main() {
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
