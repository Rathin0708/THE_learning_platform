import '../entities/user_entities.dart';

abstract class ProgressRepository {
  Future<UserProgressEntity> getProgress(int contentId);

  Future<void> saveProgress(UserProgressEntity progress);

  /// All content_id values with next_review <= now (spec: Today's Review).
  Future<List<int>> getDueContentIds({DateTime? now});

  /// content_id values with repeated misses, for weak-word resurfacing (spec 6.4 / Phase 3).
  Future<List<int>> getWeakContentIds({int missThreshold = 2});

  Future<void> logReview(int contentId, int quality, DateTime reviewedAt);

  Future<LearningStats> getLearningStats();

  Future<UserSettingsEntity> getSettings();

  Future<void> saveSettings(UserSettingsEntity settings);

  /// Most-recent-first list of past search queries (spec 9.3 recent-search
  /// cache), capped at [limit].
  Future<List<String>> getRecentSearches({int limit = 10});

  Future<void> addRecentSearch(String query);
}
