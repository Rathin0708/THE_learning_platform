import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../theme/app_theme.dart';

/// Standalone Quiz screen (THE-24) — same quiz_questions data source used
/// inside the lesson loop (THE-23), but accessible directly and reused for
/// spot-checking a level offline.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _index = 0;
  int _correct = 0;
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(currentLevelProvider);
    final questionsAsync = ref.watch(quizQuestionsProvider(level));

    return AppScaffold(
      title: 'Quiz',
      currentIndex: 0,
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load quiz: $e')),
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(child: Text('No quiz questions available for this level yet.'));
          }
          if (_index >= questions.length) {
            return Center(child: Text('Score: $_correct / ${questions.length}'));
          }
          final q = questions[_index];
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${_index + 1} / ${questions.length}', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.md),
                Text(q.question, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                for (final option in q.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: FilledButton.tonal(
                      onPressed: _selected == null
                          ? () async {
                              final correct = option == q.answer;
                              setState(() {
                                _selected = option;
                                if (correct) _correct++;
                              });
                              await Future<void>.delayed(const Duration(milliseconds: 500));
                              if (!mounted) return;
                              setState(() {
                                _selected = null;
                                _index++;
                              });
                            }
                          : null,
                      child: Text(option),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
