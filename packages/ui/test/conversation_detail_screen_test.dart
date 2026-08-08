import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ui/ui.dart';
import 'package:ui/src/features/conversation/presentation/conversation_detail_screen.dart';

class _FakeContentRepository implements ContentRepository {
  final List<ConversationLineEntity> lines;
  _FakeContentRepository(this.lines);

  @override
  Future<List<SearchResult>> search(String query, {int limit = 20}) async => [];
  @override
  Future<WordDetail?> getWordDetail(int wordId) async => null;
  @override
  Future<List<WordEntity>> getWordsByLevel(String level, {int limit = 20, int offset = 0}) async => [];
  @override
  Future<List<SentenceEntity>> getSentencesByLevel(String level, {int limit = 20, int offset = 0}) async => [];
  @override
  Future<List<SentenceEntity>> getSentencesContainingWord(String word, {int limit = 10}) async => [];
  @override
  Future<Map<LanguageCode, String>> getSentenceTranslations(int sentenceId) async => {};
  @override
  Future<List<QuizQuestionEntity>> getQuizQuestions(String level, {int limit = 10}) async => [];
  @override
  Future<List<ConversationEntity>> getConversations({String? level}) async => [];
  @override
  Future<List<ConversationLineEntity>> getConversationLines(int conversationId) async => lines;
  @override
  Future<int> getWordCount() async => 0;
}

void main() {
  testWidgets('a line with expected_response shows a Your Turn prompt, blocking "Next line" until skipped/answered',
      (WidgetTester tester) async {
    final lines = [
      const ConversationLineEntity(
        id: 1, conversationId: 1, speaker: 'A', text: 'Hello!', translation: 'வணக்கம்!',
        expectedResponse: 'Hello!',
      ),
      const ConversationLineEntity(
        id: 2, conversationId: 1, speaker: 'B', text: 'How are you?', translation: 'எப்படி இருக்கிறீர்கள்?',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(_FakeContentRepository(lines)),
        ],
        child: const MaterialApp(home: ConversationDetailScreen(conversationId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    // First line has expected_response -> Your Turn prompt shown, not "Next line".
    expect(find.text('Your turn'), findsOneWidget);
    expect(find.text('Next line'), findsNothing);

    // Skipping the prompt should reveal the "Next line" control instead.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Next line'), findsOneWidget);
    expect(find.text('Your turn'), findsNothing);

    // Advancing reveals the second line, which has no expected_response,
    // so the scenario should now show "Scenario complete." directly.
    await tester.tap(find.text('Next line'));
    await tester.pumpAndSettle();

    expect(find.text('Scenario complete.'), findsOneWidget);
    expect(find.text('How are you?'), findsOneWidget);
  });
}
