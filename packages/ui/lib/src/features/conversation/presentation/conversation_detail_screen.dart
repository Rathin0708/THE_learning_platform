import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice/voice.dart';

import '../../../theme/app_theme.dart';

final _conversationLinesProvider =
    FutureProvider.autoDispose.family<List<ConversationLineEntity>, int>((ref, conversationId) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getConversationLines(conversationId);
});

/// Turn-taking role-play playback of a structured scenario (THE-49), with
/// real ASR-backed response matching (THE-50): when a line has an
/// expected_response, the learner records their reply, it's transcribed
/// on-device and matched against the expected phrase (THE-47's tolerant
/// matcher, which handles free-form templates like "My name is ...").
/// Feedback is shown either way and the scripted conversation continues —
/// practice, not a hard gate.
class ConversationDetailScreen extends ConsumerStatefulWidget {
  final int conversationId;
  const ConversationDetailScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends ConsumerState<ConversationDetailScreen> {
  int _revealedCount = 1;
  // index -> whether the learner has attempted/skipped that line's response prompt.
  final Set<int> _respondedTo = {};

  @override
  Widget build(BuildContext context) {
    final linesAsync = ref.watch(_conversationLinesProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: linesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load scenario: $e')),
        data: (lines) {
          final visible = lines.take(_revealedCount).toList();
          final hasMore = _revealedCount < lines.length;
          final lastIndex = visible.length - 1;
          final lastLine = visible.isEmpty ? null : visible[lastIndex];
          final needsResponse = lastLine?.expectedResponse != null && !_respondedTo.contains(lastIndex);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => _LineBubble(line: visible[index]),
                ),
              ),
              if (needsResponse)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _YourTurnPrompt(
                    expectedResponse: lastLine!.expectedResponse!,
                    onDone: () => setState(() => _respondedTo.add(lastIndex)),
                  ),
                )
              else if (hasMore)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton(
                    onPressed: () => setState(() => _revealedCount++),
                    child: const Text('Next line'),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('Scenario complete.'),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _PromptState { idle, listening, done }

class _YourTurnPrompt extends ConsumerStatefulWidget {
  final String expectedResponse;
  final VoidCallback onDone;
  const _YourTurnPrompt({required this.expectedResponse, required this.onDone});

  @override
  ConsumerState<_YourTurnPrompt> createState() => _YourTurnPromptState();
}

class _YourTurnPromptState extends ConsumerState<_YourTurnPrompt> {
  _PromptState _state = _PromptState.idle;
  AsrOutcome? _outcome;
  ConversationMatchResult? _match;

  Future<void> _record() async {
    setState(() => _state = _PromptState.listening);
    final outcome = await ref.read(speechToTextServiceProvider).listenOnce(LanguageCode.english);
    if (!mounted) return;
    final match = outcome.text != null
        ? ref.read(conversationResponseMatcherProvider).match(widget.expectedResponse, outcome.text!)
        : null;
    setState(() {
      _state = _PromptState.done;
      _outcome = outcome;
      _match = match;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your turn', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            if (_state != _PromptState.done) ...[
              FilledButton.icon(
                icon: Icon(_state == _PromptState.listening ? Icons.mic : Icons.mic_none_outlined),
                label: Text(_state == _PromptState.listening ? 'Listening…' : 'Record your reply'),
                onPressed: _state == _PromptState.listening ? null : _record,
              ),
              TextButton(onPressed: widget.onDone, child: const Text('Skip')),
            ] else
              _buildFeedback(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final outcome = _outcome!;
    String message;
    if (outcome.result == AsrResult.unavailable) {
      message = 'On-device speech recognition isn\'t available on this device.';
    } else if (outcome.result == AsrResult.noSpeechDetected) {
      message = 'Didn\'t catch that.';
    } else if (outcome.result == AsrResult.error) {
      message = 'Could not start the microphone.';
    } else {
      final match = _match!;
      message = match.matched ? 'Nice — that matches!' : 'Heard: "${outcome.text}" — not quite, but let\'s continue.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(onPressed: widget.onDone, child: const Text('Continue')),
      ],
    );
  }
}

class _LineBubble extends StatelessWidget {
  final ConversationLineEntity line;
  const _LineBubble({required this.line});

  @override
  Widget build(BuildContext context) {
    final isA = line.speaker == 'A';
    return Align(
      alignment: isA ? Alignment.centerLeft : Alignment.centerRight,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.speaker, style: Theme.of(context).textTheme.labelSmall),
              Text(line.text, style: Theme.of(context).textTheme.bodyLarge),
              Text(line.translation, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
