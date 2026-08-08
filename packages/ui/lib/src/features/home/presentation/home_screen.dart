import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../theme/app_theme.dart';
import '../application/home_providers.dart';
import '../domain/home_summary.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider);

    return AppScaffold(
      title: 'Language Learning OS',
      currentIndex: 0,
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load your progress: $e')),
        data: (summary) => _HomeContent(summary: summary),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final HomeSummary summary;
  const _HomeContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingForNow();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Today's goal: ${summary.dailyGoalMinutes} min streak",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ActionTile(
          icon: Icons.menu_book_outlined,
          title: 'Continue Learning',
          subtitle: _levelLabel(summary.currentLevel),
          onTap: () => context.go(AppRoutes.lessons),
        ),
        _ActionTile(
          icon: Icons.refresh_outlined,
          title: "Today's Review",
          subtitle: '${summary.reviewDueCount} words due',
          highlight: summary.reviewDueCount > 0,
          onTap: () => context.go(AppRoutes.revision),
        ),
        _ActionTile(
          icon: Icons.mic_outlined,
          title: 'Speaking Practice',
          subtitle: 'Start',
          onTap: () => context.go(AppRoutes.speaking),
        ),
        _ActionTile(
          icon: Icons.forum_outlined,
          title: 'Conversation',
          subtitle: 'Practice',
          onTap: () => context.go(AppRoutes.conversation),
        ),
        _ActionTile(
          icon: Icons.search_outlined,
          title: 'Quick Search',
          subtitle: 'Search words...',
          onTap: () => context.go(AppRoutes.search),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatChip(label: 'Words mastered', value: '${summary.wordsMastered}'),
                _StatChip(label: 'Streak', value: '${summary.streakDays}d'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String _levelLabel(String level) => switch (level) {
        'level_1' => 'English Level 1',
        'level_2' => 'English Level 2',
        'level_3' => 'English Level 3',
        _ => level,
      };
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: highlight ? scheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
