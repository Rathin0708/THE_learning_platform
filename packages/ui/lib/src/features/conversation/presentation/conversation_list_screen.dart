import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';

/// Lists the structured Engine A scenarios (THE-28/THE-46/THE-47).
class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return AppScaffold(
      title: 'Conversation Practice',
      currentIndex: 0,
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load scenarios: $e')),
        data: (conversations) => ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final c = conversations[index];
            return ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(c.title),
              subtitle: Text(c.level),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/conversation/${c.id}'),
            );
          },
        ),
      ),
    );
  }
}
