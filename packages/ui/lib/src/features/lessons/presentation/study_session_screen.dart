import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice/voice.dart';

import '../../../theme/app_theme.dart';

final _dueWordsProvider = FutureProvider.autoDispose<List<WordEntity>>((ref) async {
  final ids = await ref.watch(dueReviewIdsProvider.future);
  final repo = ref.watch(contentRepositoryProvider);
  final words = <WordEntity>[];
  for (final id in ids) {
    final detail = await repo.getWordDetail(id);
    if (detail != null) words.add(detail.word);
  }
  // Nothing reviewed yet: fall back to today's level so Today's Review is
  // never an empty dead-end on day one.
  if (words.isEmpty) {
    return repo.getWordsByLevel(ref.read(currentLevelProvider), limit: 10);
  }
  return words;
});

final _singleWordProvider = FutureProvider.autoDispose.family<List<WordEntity>, int>((ref, wordId) async {
  final repo = ref.watch(contentRepositoryProvider);
  final detail = await repo.getWordDetail(wordId);
  return detail == null ? [] : [detail.word];
});

/// Backs /practice, /revision, /speaking (due-review queue), and — when
/// [singleWordId] is set — the per-word practice flow launched from the
/// Word Detail screen's Practice button (THE-27).
class StudySessionScreen extends ConsumerStatefulWidget {
  final bool speakingMode;
  final int? singleWordId;
  const StudySessionScreen({super.key, this.speakingMode = false, this.singleWordId});

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  int _index = 0;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final wordsAsync = widget.singleWordId != null
        ? ref.watch(_singleWordProvider(widget.singleWordId!))
        : ref.watch(_dueWordsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.speakingMode ? 'Speaking Practice' : 'Review')),
      body: wordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load review queue: $e')),
        data: (words) {
          if (words.isEmpty) {
            return const Center(child: Text('Nothing due for review right now. 🎉'));
          }
          if (_index >= words.length) {
            return const Center(child: Text('Session complete!'));
          }
          return _buildCard(words[_index]);
        },
      ),
    );
  }

  Widget _buildCard(WordEntity word) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _revealed = !_revealed),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(word.word, style: Theme.of(context).textTheme.headlineMedium),
                        if (widget.speakingMode) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const Text('Say this word aloud, then tap to reveal.'),
                          const SizedBox(height: AppSpacing.sm),
                          IconButton(
                            icon: const Icon(Icons.volume_up_outlined),
                            tooltip: 'Hear it',
                            onPressed: () => ref.read(textToSpeechServiceProvider).speak(word.word, word.language),
                          ),
                        ],
                        if (!_revealed) ...[
                          const SizedBox(height: AppSpacing.md),
                          const Text('Tap to reveal'),
                        ] else ...[
                          const SizedBox(height: AppSpacing.md),
                          FutureBuilder<WordDetail?>(
                            future: ref.read(contentRepositoryProvider).getWordDetail(word.id),
                            builder: (context, snapshot) {
                              final translations = snapshot.data?.translations ?? {};
                              return Column(
                                children: [
                                  for (final e in translations.entries) Text(e.value),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_revealed) _qualityButtons(word),
        ],
      ),
    );
  }

  Widget _qualityButtons(WordEntity word) {
    final review = ref.read(reviewContentProvider);
    void answer(int quality) {
      review(word.id, quality);
      setState(() {
        _index++;
        _revealed = false;
      });
    }

    return Row(
      children: [
        Expanded(child: OutlinedButton(onPressed: () => answer(1), child: const Text('Again'))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: OutlinedButton(onPressed: () => answer(3), child: const Text('Hard'))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: FilledButton(onPressed: () => answer(4), child: const Text('Good'))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: FilledButton(onPressed: () => answer(5), child: const Text('Easy'))),
      ],
    );
  }
}
