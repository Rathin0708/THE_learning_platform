import 'package:core/core.dart';

class FakeContentRepository implements ContentRepository {
  final List<WordEntity> words;
  FakeContentRepository({this.words = const []});

  @override
  Future<List<SearchResult>> search(String query, {int limit = 20}) async => [];
  @override
  Future<WordDetail?> getWordDetail(int wordId) async {
    for (final w in words) {
      if (w.id == wordId) return WordDetail(word: w, translations: const {});
    }
    return null;
  }

  @override
  Future<List<WordEntity>> getWordsByLevel(String level, {int limit = 20, int offset = 0}) async => words;
  @override
  Future<List<SentenceEntity>> getSentencesByLevel(String level, {int limit = 20, int offset = 0}) async => [];
  @override
  Future<Map<LanguageCode, String>> getSentenceTranslations(int sentenceId) async => {};
  @override
  Future<List<QuizQuestionEntity>> getQuizQuestions(String level, {int limit = 10}) async => [];
  @override
  Future<List<ConversationEntity>> getConversations({String? level}) async => [];
  @override
  Future<List<ConversationLineEntity>> getConversationLines(int conversationId) async => [];
  @override
  Future<int> getWordCount() async => words.length;
  @override
  Future<List<SentenceEntity>> getSentencesContainingWord(String word, {int limit = 10}) async => [];
}

class FakeProgressRepository implements ProgressRepository {
  @override
  Future<UserProgressEntity> getProgress(int contentId) async => UserProgressEntity.initial(contentId);
  @override
  Future<void> saveProgress(UserProgressEntity progress) async {}
  @override
  Future<List<int>> getDueContentIds({DateTime? now}) async => [];
  @override
  Future<List<int>> getWeakContentIds({int missThreshold = 2}) async => [];
  @override
  Future<void> logReview(int contentId, int quality, DateTime reviewedAt) async {}
  @override
  Future<LearningStats> getLearningStats() async => LearningStats.empty;
  @override
  Future<UserSettingsEntity> getSettings() async => const UserSettingsEntity();
  @override
  Future<void> saveSettings(UserSettingsEntity settings) async {}
  @override
  Future<List<String>> getRecentSearches({int limit = 10}) async => [];
  @override
  Future<void> addRecentSearch(String query) async {}
}
