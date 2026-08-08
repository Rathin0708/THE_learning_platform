import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'test_fakes.dart';

/// Verifies THE-16's back-stack acceptance criterion: pushing a route and
/// then going back returns to the previous screen with its state intact,
/// exercised through go_router's real Navigator integration (not assumed).
void main() {
  // Note: bottom-nav destinations (Home/Search/Progress/Settings) use
  // context.go(), which *replaces* the current route rather than pushing —
  // correct UX for top-level tabs, and correctly has no back button. The
  // real back-stack case is push-based navigation, e.g. into Word Detail.
  testWidgets('word detail is reachable and pop returns to vocabulary list', (WidgetTester tester) async {
    final router = buildAppRouter(onboardingComplete: true);
    final words = [
      const WordEntity(
        id: 1,
        language: LanguageCode.english,
        word: 'hello',
        normalizedWord: 'hello',
        partOfSpeech: 'interjection',
        level: 'level_1',
        category: 'greetings',
        frequency: 0.98,
        difficulty: 1,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository(words: words)),
          progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/vocabulary');
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();
    expect(find.text('HELLO'), findsOneWidget, reason: 'should now be on Word Detail');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget, reason: 'back should return to the vocabulary list');
  });
}
