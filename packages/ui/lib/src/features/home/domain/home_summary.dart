/// Domain layer for the `home` feature module — the reference
/// implementation of the Presentation/Application/Domain/Data/Infrastructure
/// layering required by THE-10. Every other feature module in packages/ui
/// should copy this shape.
class HomeSummary {
  final String currentLevel;
  final int reviewDueCount;
  final int wordsMastered;
  final int streakDays;
  final int dailyGoalMinutes;

  const HomeSummary({
    required this.currentLevel,
    required this.reviewDueCount,
    required this.wordsMastered,
    required this.streakDays,
    required this.dailyGoalMinutes,
  });

  static const empty = HomeSummary(
    currentLevel: 'level_1',
    reviewDueCount: 0,
    wordsMastered: 0,
    streakDays: 0,
    dailyGoalMinutes: 15,
  );
}
