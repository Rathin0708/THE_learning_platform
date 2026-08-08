import '../entities/content_entities.dart';

abstract class ContentRepository {
  /// Multi-script search: resolves native script, Tamil-approximate
  /// pronunciation, and transliterated input to the same result set
  /// (spec 4.3 / 9.3), returning a small indexed page — never a full scan.
  Future<List<SearchResult>> search(String query, {int limit = 20});

  Future<WordDetail?> getWordDetail(int wordId);

  Future<List<WordEntity>> getWordsByLevel(String level, {int limit = 20, int offset = 0});

  Future<List<SentenceEntity>> getSentencesByLevel(String level, {int limit = 20, int offset = 0});

  Future<Map<LanguageCode, String>> getSentenceTranslations(int sentenceId);

  Future<List<QuizQuestionEntity>> getQuizQuestions(String level, {int limit = 10});

  Future<List<ConversationEntity>> getConversations({String? level});

  Future<List<ConversationLineEntity>> getConversationLines(int conversationId);

  Future<int> getWordCount();
}
