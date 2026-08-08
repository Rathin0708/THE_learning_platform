import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/sqlite_content_repository.dart';
import '../../data/repositories/sqlite_progress_repository.dart';
import '../../domain/entities/content_entities.dart';
import '../../domain/entities/user_entities.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../srs/spaced_repetition_engine.dart';

/// Must be overridden in main() once AppDatabase.open() has completed —
/// see packages/ui App bootstrap. Keeping DB init out of provider creation
/// means the splash screen controls exactly when heavy I/O happens
/// (spec 9.6: splash -> tiny metadata only -> home -> lazy-load DB modules).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden after AppDatabase.open()');
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteContentRepository(db.content);
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteProgressRepository(db.user);
});

final srsEngineProvider = Provider<SpacedRepetitionEngine>((ref) => SpacedRepetitionEngine());

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.watch(contentRepositoryProvider);
  return repo.search(query);
});

final currentLevelProvider = StateProvider<String>((ref) => 'level_1');

final wordsForLevelProvider = FutureProvider.autoDispose<List<WordEntity>>((ref) async {
  final level = ref.watch(currentLevelProvider);
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getWordsByLevel(level);
});

final dueReviewIdsProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.getDueContentIds();
});

final learningStatsProvider = FutureProvider.autoDispose<LearningStats>((ref) async {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.getLearningStats();
});

final conversationsProvider = FutureProvider.autoDispose<List<ConversationEntity>>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getConversations();
});

final quizQuestionsProvider = FutureProvider.autoDispose.family<List<QuizQuestionEntity>, String>((ref, level) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getQuizQuestions(level);
});

/// Reviews a piece of content and persists both the updated SRS state and
/// the review-log entry (used for weak-word detection and stats).
final reviewContentProvider = Provider<Future<void> Function(int contentId, int quality)>((ref) {
  return (int contentId, int quality) async {
    final progressRepo = ref.read(progressRepositoryProvider);
    final srs = ref.read(srsEngineProvider);
    final current = await progressRepo.getProgress(contentId);
    final updated = srs.review(current, quality);
    await progressRepo.saveProgress(updated);
    await progressRepo.logReview(contentId, quality, DateTime.now());
    ref.invalidate(dueReviewIdsProvider);
    ref.invalidate(learningStatsProvider);
  };
});
