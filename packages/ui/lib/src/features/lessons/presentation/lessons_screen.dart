import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice/voice.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../theme/app_theme.dart';

enum _Stage { learn, practice, speak, quiz, mistakeReview, mastery }

/// Full lesson loop (THE-23, spec 6.2):
/// Learn -> Practice -> Speak -> Quiz -> Mistake -> Review -> Mastery.
class LessonsScreen extends ConsumerStatefulWidget {
  const LessonsScreen({super.key});

  @override
  ConsumerState<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends ConsumerState<LessonsScreen> {
  List<WordEntity>? _sessionWords;
  _Stage _stage = _Stage.learn;
  int _wordIndex = 0;
  final Set<int> _missedWordIds = {};

  Future<void> _startLesson() async {
    final level = ref.read(currentLevelProvider);
    final repo = ref.read(contentRepositoryProvider);
    final words = await repo.getWordsByLevel(level, limit: 5);
    setState(() {
      _sessionWords = words;
      _stage = _Stage.learn;
      _wordIndex = 0;
      _missedWordIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Lessons',
      currentIndex: 0,
      body: _sessionWords == null ? _buildIntro() : _buildSession(),
    );
  }

  Widget _buildIntro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ready for today\'s lesson?'),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: _startLesson, child: const Text('Start Lesson')),
          ],
        ),
      ),
    );
  }

  Widget _buildSession() {
    final words = _sessionWords!;
    if (words.isEmpty) {
      return const Center(child: Text('No vocabulary available for this level yet.'));
    }

    switch (_stage) {
      case _Stage.learn:
        return _learnStage(words[_wordIndex]);
      case _Stage.practice:
        return _practiceStage(words[_wordIndex]);
      case _Stage.speak:
        return _speakStage(words[_wordIndex]);
      case _Stage.quiz:
        return _quizStage();
      case _Stage.mistakeReview:
        return _mistakeReviewStage(words);
      case _Stage.mastery:
        return _masteryStage(words);
    }
  }

  Widget _stageScaffold({required String label, required Widget child, VoidCallback? onNext, String nextLabel = 'Next'}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: child),
          if (onNext != null) FilledButton(onPressed: onNext, child: Text(nextLabel)),
        ],
      ),
    );
  }

  Widget _learnStage(WordEntity word) {
    return _stageScaffold(
      label: 'Learn',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(word.word, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(word.category),
          ],
        ),
      ),
      onNext: () => setState(() => _stage = _Stage.practice),
    );
  }

  Widget _practiceStage(WordEntity word) {
    return _stageScaffold(
      label: 'Practice — recall the meaning',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(word.word, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            const Text('(Silently recall the translation, then continue.)'),
          ],
        ),
      ),
      onNext: () => setState(() => _stage = _Stage.speak),
    );
  }

  Widget _speakStage(WordEntity word) {
    // TTS playback is real (THE-21). Scoring the learner's own attempt
    // needs ASR, which is a separate Phase 4 ticket (THE-37/39/40/44) —
    // that gap is called out honestly rather than faked.
    return _stageScaffold(
      label: 'Speak',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Say: "${word.word}"', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Hear it'),
              onPressed: () => ref.read(textToSpeechServiceProvider).speak(word.word, word.language),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Pronunciation scoring arrives with ASR (Phase 4).'),
          ],
        ),
      ),
      onNext: () {
        final isLastWord = _wordIndex >= _sessionWords!.length - 1;
        if (isLastWord) {
          setState(() => _stage = _Stage.quiz);
        } else {
          setState(() {
            _wordIndex++;
            _stage = _Stage.learn;
          });
        }
      },
    );
  }

  Widget _quizStage() {
    final level = ref.read(currentLevelProvider);
    return FutureBuilder<List<QuizQuestionEntity>>(
      future: ref.read(contentRepositoryProvider).getQuizQuestions(level, limit: _sessionWords!.length),
      builder: (context, snapshot) {
        final questions = snapshot.data;
        if (questions == null) return const Center(child: CircularProgressIndicator());
        if (questions.isEmpty) {
          return _stageScaffold(
            label: 'Quiz',
            child: const Center(child: Text('No quiz questions available for this level yet.')),
            onNext: () => setState(() => _stage = _mistakeOrMasteryStage()),
          );
        }
        return _QuizQuestionList(
          questions: questions,
          onFinished: (missedQuestionIds) {
            _missedWordIds.addAll(missedQuestionIds);
            setState(() => _stage = _mistakeOrMasteryStage());
          },
        );
      },
    );
  }

  _Stage _mistakeOrMasteryStage() => _missedWordIds.isEmpty ? _Stage.mastery : _Stage.mistakeReview;

  Widget _mistakeReviewStage(List<WordEntity> words) {
    return _stageScaffold(
      label: 'Mistake Review',
      child: Center(
        child: Text('You missed ${_missedWordIds.length} question(s). Review them before mastery.'),
      ),
      onNext: () => setState(() => _stage = _Stage.mastery),
      nextLabel: 'Continue to Mastery',
    );
  }

  Widget _masteryStage(List<WordEntity> words) {
    final reviewFn = ref.read(reviewContentProvider);
    for (final word in words) {
      final missed = _missedWordIds.contains(word.id);
      // quality: 4 (correct) or 2 (missed) on the SM-2 0-5 scale.
      reviewFn(word.id, missed ? 2 : 4);
    }
    return _stageScaffold(
      label: 'Mastery',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text('Lesson complete! ${words.length - _missedWordIds.length}/${words.length} correct.'),
          ],
        ),
      ),
      onNext: () => setState(() {
        _sessionWords = null;
      }),
      nextLabel: 'Done',
    );
  }
}

class _QuizQuestionList extends StatefulWidget {
  final List<QuizQuestionEntity> questions;
  final void Function(List<int> missedQuestionIds) onFinished;
  const _QuizQuestionList({required this.questions, required this.onFinished});

  @override
  State<_QuizQuestionList> createState() => _QuizQuestionListState();
}

class _QuizQuestionListState extends State<_QuizQuestionList> {
  int _index = 0;
  final List<int> _missed = [];

  void _answer(String selected) {
    final q = widget.questions[_index];
    if (selected != q.answer) _missed.add(q.id);
    if (_index == widget.questions.length - 1) {
      widget.onFinished(_missed);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('QUIZ ${_index + 1}/${widget.questions.length}', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.md),
          Text(q.question, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          for (final option in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OutlinedButton(onPressed: () => _answer(option), child: Text(option)),
            ),
        ],
      ),
    );
  }
}
