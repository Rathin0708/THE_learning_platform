import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice/voice.dart';

import '../../theme/app_theme.dart';

/// Real ASR-backed speaking practice (THE-44/45): record, transcribe
/// on-device, and score word-level pronunciation against the target word.
/// Shared between the Lessons Speak stage and the standalone Speaking
/// Practice / Study Session screens so both use one tested implementation.
class SpeakPracticeCard extends ConsumerStatefulWidget {
  final WordEntity word;
  const SpeakPracticeCard({super.key, required this.word});

  @override
  ConsumerState<SpeakPracticeCard> createState() => _SpeakPracticeCardState();
}

enum _RecordingState { idle, listening, done }

class _SpeakPracticeCardState extends ConsumerState<SpeakPracticeCard> {
  _RecordingState _state = _RecordingState.idle;
  AsrOutcome? _outcome;
  PronunciationScore? _score;

  Future<void> _record() async {
    setState(() {
      _state = _RecordingState.listening;
      _outcome = null;
      _score = null;
    });
    final outcome = await ref.read(speechToTextServiceProvider).listenOnce(widget.word.language);
    if (!mounted) return;
    final score = outcome.text != null
        ? ref.read(pronunciationAnalyzerProvider).score(widget.word.word, outcome.text!)
        : null;
    setState(() {
      _state = _RecordingState.done;
      _outcome = outcome;
      _score = score;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Say: "${widget.word.word}"', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('Hear it'),
            onPressed: () => ref.read(textToSpeechServiceProvider).speak(widget.word.word, widget.word.language),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            icon: Icon(_state == _RecordingState.listening ? Icons.mic : Icons.mic_none_outlined),
            label: Text(_state == _RecordingState.listening ? 'Listening…' : 'Record'),
            onPressed: _state == _RecordingState.listening ? null : _record,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildResult(),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final outcome = _outcome;
    if (_state != _RecordingState.done || outcome == null) return const SizedBox.shrink();

    switch (outcome.result) {
      case AsrResult.unavailable:
        return const Text('On-device speech recognition isn\'t available for this language on this device.');
      case AsrResult.permissionDenied:
        return const Text('Microphone permission is needed to practice speaking. Enable it in system settings.');
      case AsrResult.noSpeechDetected:
        return const Text('Didn\'t catch that — try again.');
      case AsrResult.error:
        return const Text('Could not start the microphone.');
      case AsrResult.recognized:
        final score = _score!;
        return Column(
          children: [
            Text('Heard: "${outcome.text}"'),
            const SizedBox(height: AppSpacing.sm),
            Text('${score.percent.round()}% word match', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final w in score.perWord)
                  Chip(
                    avatar: Icon(w.matched ? Icons.check_circle : Icons.cancel, size: 16),
                    label: Text(w.word),
                  ),
              ],
            ),
          ],
        );
    }
  }
}
