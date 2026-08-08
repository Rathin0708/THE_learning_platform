import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice/voice.dart';

import '../../../theme/app_theme.dart';

final _wordDetailProvider = FutureProvider.autoDispose.family<WordDetail?, int>((ref, wordId) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getWordDetail(wordId);
});

/// Word Detail screen (THE-27, spec 9.2): word, translations, pronunciation
/// (native + Tamil-approx), IPA, example sentence, Listen/Practice actions.
class WordDetailScreen extends ConsumerWidget {
  final int wordId;
  const WordDetailScreen({super.key, required this.wordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_wordDetailProvider(wordId));

    return Scaffold(
      appBar: AppBar(title: const Text('Word')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load word: $e')),
        data: (detail) {
          if (detail == null) return const Center(child: Text('Word not found.'));
          return _WordDetailBody(detail: detail);
        },
      ),
    );
  }
}

class _WordDetailBody extends ConsumerWidget {
  final WordDetail detail;
  const _WordDetailBody({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final word = detail.word;
    final pron = detail.pronunciation;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(word.word.toUpperCase(), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            Chip(label: Text(word.category)),
            Chip(label: Text(word.level)),
            if (word.partOfSpeech.isNotEmpty) Chip(label: Text(word.partOfSpeech)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final entry in detail.translations.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${_langLabel(entry.key)}: ${entry.value}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (pron != null) ...[
          const SizedBox(height: AppSpacing.md),
          if (pron.ipa != null) Text('IPA: ${pron.ipa}', style: Theme.of(context).textTheme.bodyMedium),
          if (pron.tamilPronunciation != null)
            Text('Pronunciation (romanized): ${pron.tamilPronunciation}',
                style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (detail.examples.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Example', style: Theme.of(context).textTheme.titleSmall),
          for (final ex in detail.examples)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('${ex.context} — ${ex.meaning}'),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Listen'),
                onPressed: () async {
                  final tts = ref.read(textToSpeechServiceProvider);
                  final result = await tts.speak(word.word, word.language);
                  if (!context.mounted) return;
                  final message = switch (result) {
                    TtsResult.spoken => null,
                    TtsResult.languageUnavailable =>
                      'No ${_langLabel(word.language)} voice installed on this device.',
                    TtsResult.error => 'Could not play audio.',
                    TtsResult.skipped => null,
                  };
                  if (message != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.school_outlined),
                label: const Text('Practice'),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added "${word.word}" to your practice queue.')),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _langLabel(LanguageCode code) => switch (code) {
        LanguageCode.english => 'English',
        LanguageCode.tamil => 'Tamil',
        LanguageCode.hindi => 'Hindi',
      };
}
