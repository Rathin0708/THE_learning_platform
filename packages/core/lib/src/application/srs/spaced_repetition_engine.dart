import '../../domain/entities/user_entities.dart';

/// Implements the spaced-repetition schedule from spec section 6.3:
/// Day 1 -> 2 -> 4 -> 7 -> 14 -> 30 -> 60. A correct answer lengthens the
/// interval; a miss resets/shortens it.
///
/// Ease-factor adjustment follows the SM-2 family of algorithms so review
/// difficulty (not just correct/incorrect) affects future spacing.
class SpacedRepetitionEngine {
  static const List<int> _scheduleDays = [1, 2, 4, 7, 14, 30, 60];
  static const double _minEaseFactor = 1.3;

  /// [quality] is 0-5 (0 = total blackout, 5 = perfect recall), matching the
  /// SM-2 convention. Anything below 3 counts as a miss.
  UserProgressEntity review(UserProgressEntity progress, int quality, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final isCorrect = quality >= 3;

    if (!isCorrect) {
      // Miss: reset repetitions and drop back to the start of the schedule.
      final newEase = (progress.easeFactor - 0.2).clamp(_minEaseFactor, 2.5 + 0.5);
      return progress.copyWith(
        repetitions: 0,
        interval: _scheduleDays.first,
        easeFactor: newEase,
        lastReview: effectiveNow,
        nextReview: effectiveNow.add(Duration(days: _scheduleDays.first)),
      );
    }

    final newRepetitions = progress.repetitions + 1;
    final newEase = _adjustEaseFactor(progress.easeFactor, quality);
    final newInterval = _nextInterval(progress.interval, newRepetitions, newEase);
    final newMastery = _updateMastery(progress.mastery, newRepetitions);

    return progress.copyWith(
      repetitions: newRepetitions,
      easeFactor: newEase,
      interval: newInterval,
      mastery: newMastery,
      lastReview: effectiveNow,
      nextReview: effectiveNow.add(Duration(days: newInterval)),
    );
  }

  int _nextInterval(int previousInterval, int repetitions, double easeFactor) {
    if (repetitions - 1 < _scheduleDays.length) {
      // Still walking the fixed early schedule: 1 -> 2 -> 4 -> 7 -> 14 -> 30 -> 60.
      return _scheduleDays[repetitions - 1];
    }
    // Beyond the fixed schedule, grow by the ease factor (standard SM-2 behavior).
    return (previousInterval * easeFactor).round();
  }

  double _adjustEaseFactor(double easeFactor, int quality) {
    final delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
    return (easeFactor + delta).clamp(_minEaseFactor, 3.0);
  }

  double _updateMastery(double previousMastery, int repetitions) {
    // Mastery approaches 1.0 asymptotically as repetitions accumulate.
    final target = 1.0 - (1.0 / (repetitions + 1));
    return (previousMastery + (target - previousMastery) * 0.6).clamp(0.0, 1.0);
  }

  bool isDue(UserProgressEntity progress, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final next = progress.nextReview;
    if (next == null) return true;
    return !next.isAfter(effectiveNow);
  }
}
