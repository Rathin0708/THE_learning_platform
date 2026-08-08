import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../theme/app_theme.dart';

final _sentencesProvider = FutureProvider.autoDispose<List<SentenceEntity>>((ref) async {
  final level = ref.watch(currentLevelProvider);
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getSentencesByLevel(level);
});

class SentencesScreen extends ConsumerWidget {
  const SentencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentencesAsync = ref.watch(_sentencesProvider);

    return AppScaffold(
      title: 'Sentences',
      currentIndex: 0,
      body: sentencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load sentences: $e')),
        data: (sentences) => ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: sentences.length,
          itemBuilder: (context, index) => _SentenceCard(sentence: sentences[index]),
        ),
      ),
    );
  }
}

class _SentenceCard extends ConsumerWidget {
  final SentenceEntity sentence;
  const _SentenceCard({required this.sentence});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<Map<LanguageCode, String>>(
          future: ref.read(contentRepositoryProvider).getSentenceTranslations(sentence.id),
          builder: (context, snapshot) {
            final translations = snapshot.data ?? {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sentence.sourceText, style: Theme.of(context).textTheme.titleMedium),
                for (final entry in translations.entries.where((e) => e.key != LanguageCode.english))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(entry.value, style: Theme.of(context).textTheme.bodyMedium),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
