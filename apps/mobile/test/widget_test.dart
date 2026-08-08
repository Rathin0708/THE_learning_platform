import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('Home screen renders the core action tiles', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
          progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
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
