import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

class _FakeContentRepository implements ContentRepository {
  @override
  Future<List<SearchResult>> search(String query, {int limit = 20}) async => [];
  @override
  Future<WordDetail?> getWordDetail(int wordId) async => null;
  @override
  Future<List<WordEntity>> getWordsByLevel(String level, {int limit = 20, int offset = 0}) async => [];
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
  Future<int> getWordCount() async => 0;
}

class _FakeProgressRepository implements ProgressRepository {
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
}

void main() {
  testWidgets('Home screen renders the core action tiles', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(_FakeContentRepository()),
          progressRepositoryProvider.overrideWithValue(_FakeProgressRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue Learning'), findsOneWidget);
    expect(find.text("Today's Review"), findsOneWidget);
    expect(find.text('Speaking Practice'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
  });
}
