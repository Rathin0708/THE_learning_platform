import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../theme/app_theme.dart';
import 'package:core/core.dart';

/// Progress dashboard (THE-25, spec 9.4).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(learningStatsProvider);

    return AppScaffold(
      title: 'Your Progress',
      currentIndex: 2,
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load progress: $e')),
        data: (stats) => _ProgressBody(stats: stats),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  final LearningStats stats;
  const _ProgressBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final english = ((stats.masteryByLanguage['en'] ?? 0) * 100).round();
    final hindi = ((stats.masteryByLanguage['hi'] ?? 0) * 100).round();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _StatRow(label: 'English', valueLabel: '$english%', progress: english / 100),
        _StatRow(label: 'Hindi', valueLabel: '$hindi%', progress: hindi / 100),
        const SizedBox(height: AppSpacing.md),
        _MetricGrid(stats: stats),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double progress;
  const _StatRow({required this.label, required this.valueLabel, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(valueLabel)],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 8),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final LearningStats stats;
  const _MetricGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Words mastered', '${stats.wordsMastered}'),
      ('Sentences', '${stats.sentencesMastered}'),
      ('Speaking', '${stats.speakingPercent.round()}%'),
      ('Grammar', '${stats.grammarPercent.round()}%'),
      ('Streak', '${stats.streakDays} days'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.2,
      children: [
        for (final m in metrics)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(m.$2, style: Theme.of(context).textTheme.titleLarge),
                  Text(m.$1, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
