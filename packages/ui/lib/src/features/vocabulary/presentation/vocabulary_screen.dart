import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voice/voice.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../theme/app_theme.dart';

/// Vocabulary browser, filterable by the 3-level curriculum (THE-22).
/// When [listeningMode] is true this doubles as the /listening route,
/// playing each word aloud via on-device TTS (THE-21).
class VocabularyScreen extends ConsumerWidget {
  final bool listeningMode;
  const VocabularyScreen({super.key, this.listeningMode = false});

  static const _levels = ['level_1', 'level_2', 'level_3'];
  static const _levelLabels = {'level_1': 'Level 1 · Survival', 'level_2': 'Level 2 · Everyday', 'level_3': 'Level 3 · Natural'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.watch(currentLevelProvider);
    final wordsAsync = ref.watch(wordsForLevelProvider);

    return AppScaffold(
      title: listeningMode ? 'Listening Practice' : 'Vocabulary',
      currentIndex: 0,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SegmentedButton<String>(
              segments: [
                for (final level in _levels) ButtonSegment(value: level, label: Text(_levelLabels[level]!)),
              ],
              selected: {currentLevel},
              onSelectionChanged: (selection) => ref.read(currentLevelProvider.notifier).state = selection.first,
            ),
          ),
          Expanded(
            child: wordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Could not load vocabulary: $e')),
              data: (words) {
                if (words.isEmpty) {
                  return const Center(child: Text('No words at this level yet.'));
                }
                return ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final word = words[index];
                    return ListTile(
                      title: Text(word.word),
                      subtitle: Text(word.category),
                      trailing: listeningMode
                          ? const Icon(Icons.volume_up_outlined)
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (!listeningMode) {
                          context.push('/word/${word.id}');
                          return;
                        }
                        final tts = ref.read(textToSpeechServiceProvider);
                        final result = await tts.speak(word.word, word.language);
                        if (!context.mounted || result != TtsResult.languageUnavailable) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No voice installed for this language on this device.')),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
