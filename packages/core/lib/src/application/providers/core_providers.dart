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
  return SqliteProgressRepository(db.user, db.content);
});

final srsEngineProvider = Provider<SpacedRepetitionEngine>((ref) => SpacedRepetitionEngine());

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.watch(contentRepositoryProvider);
  return repo.search(query);
});

/// Recent-search cache (spec 9.3), most-recent-first.
final recentSearchesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.getRecentSearches();
});

/// Records a completed search (on submit, not on every keystroke) and
/// refreshes the recent-search cache.
final recordSearchProvider = Provider<Future<void> Function(String query)>((ref) {
  return (String query) async {
    final repo = ref.read(progressRepositoryProvider);
    await repo.addRecentSearch(query);
    ref.invalidate(recentSearchesProvider);
  };
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

/// Weak-word list (THE-33): content_id values with >= [missThreshold]
/// missed reviews, most-missed first. Queryable independently (e.g. for a
/// dedicated view) and also consumed by [wordsForLessonProvider] /
/// [prioritizedDueWordsProvider] to give weak words review priority.
final weakContentIdsProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.getWeakContentIds();
});

/// Due-review words with weak words (repeated misses) surfaced first,
/// ahead of words that are merely due on schedule (THE-33).
final prioritizedDueWordsProvider = FutureProvider.autoDispose<List<WordEntity>>((ref) async {
  final dueIds = await ref.watch(dueReviewIdsProvider.future);
  final weakIds = await ref.watch(weakContentIdsProvider.future);
  final repo = ref.watch(contentRepositoryProvider);

  final weakSet = weakIds.toSet();
  final orderedIds = [
    ...weakIds.where(dueIds.contains),
    ...dueIds.where((id) => !weakSet.contains(id)),
  ];

  final words = <WordEntity>[];
  for (final id in orderedIds) {
    final detail = await repo.getWordDetail(id);
    if (detail != null) words.add(detail.word);
  }
  if (words.isEmpty) {
    return repo.getWordsByLevel(ref.read(currentLevelProvider), limit: 10);
  }
  return words;
});

/// A lesson's word set for a level, with any weak words for that level
/// pulled to the front so a lesson session reinforces trouble spots first
/// (THE-33's "higher priority in ... lesson sequencing" requirement).
final wordsForLessonProvider = FutureProvider.autoDispose<List<WordEntity>>((ref) async {
  final level = ref.watch(currentLevelProvider);
  final repo = ref.watch(contentRepositoryProvider);
  final weakIds = (await ref.watch(weakContentIdsProvider.future)).toSet();

  final levelWords = await repo.getWordsByLevel(level, limit: 20);
  final weak = levelWords.where((w) => weakIds.contains(w.id));
  final rest = levelWords.where((w) => !weakIds.contains(w.id));
  return [...weak, ...rest].take(5).toList();
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
