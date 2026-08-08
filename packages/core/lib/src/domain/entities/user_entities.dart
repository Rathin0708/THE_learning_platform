/// Domain entities for the User database (local read/write, spec 4.2).
library;

class UserProgressEntity {
  final int contentId;
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime? lastReview;
  final DateTime? nextReview;
  final double mastery;

  const UserProgressEntity({
    required this.contentId,
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    this.lastReview,
    this.nextReview,
    required this.mastery,
  });

  UserProgressEntity copyWith({
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? lastReview,
    DateTime? nextReview,
    double? mastery,
  }) {
    return UserProgressEntity(
      contentId: contentId,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      lastReview: lastReview ?? this.lastReview,
      nextReview: nextReview ?? this.nextReview,
      mastery: mastery ?? this.mastery,
    );
  }

  static UserProgressEntity initial(int contentId) => UserProgressEntity(
        contentId: contentId,
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        mastery: 0.0,
      );
}

class UserSettingsEntity {
  final List<String> activeLanguages;
  final List<String> installedPacks;
  final bool audioEnabled;
  final String currentLevel;

  const UserSettingsEntity({
    this.activeLanguages = const ['ta', 'en'],
    this.installedPacks = const [],
    this.audioEnabled = true,
    this.currentLevel = 'level_1',
  });
}

class LearningStats {
  final Map<String, double> masteryByLanguage;
  final int wordsMastered;
  final int sentencesMastered;
  final double speakingPercent;
  final double grammarPercent;
  final int streakDays;

  const LearningStats({
    required this.masteryByLanguage,
    required this.wordsMastered,
    required this.sentencesMastered,
    required this.speakingPercent,
    required this.grammarPercent,
    required this.streakDays,
  });

  static const empty = LearningStats(
    masteryByLanguage: {},
    wordsMastered: 0,
    sentencesMastered: 0,
    speakingPercent: 0,
    grammarPercent: 0,
    streakDays: 0,
  );
}
