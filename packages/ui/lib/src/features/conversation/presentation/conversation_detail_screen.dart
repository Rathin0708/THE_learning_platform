import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';

final _conversationLinesProvider =
    FutureProvider.autoDispose.family<List<ConversationLineEntity>, int>((ref, conversationId) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getConversationLines(conversationId);
});

/// Turn-taking role-play playback of a structured scenario (THE-49).
/// Wiring live speech capture into `expected_response` matching is THE-50
/// (Sprint 3), once ASR (THE-37/39/40) exists — this screen already models
/// the full conversation_lines flow the ASR hook will attach to.
class ConversationDetailScreen extends ConsumerStatefulWidget {
  final int conversationId;
  const ConversationDetailScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends ConsumerState<ConversationDetailScreen> {
  int _revealedCount = 1;

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
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => _LineBubble(line: visible[index]),
                ),
              ),
              if (hasMore)
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
