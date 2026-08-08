import 'package:core/core.dart';

import '../domain/home_summary.dart';

/// Data layer for `home`: assembles the domain-level [HomeSummary] purely
/// from packages/core repositories. Never touches sqflite/platform APIs
/// directly — that stays inside packages/core's own data layer.
class HomeDataSource {
  final ProgressRepository progressRepository;

  HomeDataSource(this.progressRepository);

  Future<HomeSummary> load() async {
    final settings = await progressRepository.getSettings();
    final due = await progressRepository.getDueContentIds();
    final stats = await progressRepository.getLearningStats();

    return HomeSummary(
      currentLevel: settings.currentLevel,
      reviewDueCount: due.length,
      wordsMastered: stats.wordsMastered,
      streakDays: stats.streakDays,
      dailyGoalMinutes: 15,
    );
  }
}
