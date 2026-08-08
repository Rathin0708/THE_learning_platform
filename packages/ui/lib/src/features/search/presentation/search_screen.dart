import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../theme/app_theme.dart';

/// Multi-script search (THE-17, spec 9.3): typing a native-script term, a
/// transliterated term, or the English equivalent all resolve to the same
/// result cluster via the FTS5 index in packages/core.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return AppScaffold(
      title: 'Search',
      currentIndex: 1,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search words... (e.g. "sapidu", "eat", "சாப்பிடு")',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: resultsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Search failed: $e')),
                data: (results) {
                  if (_controller.text.trim().isEmpty) {
                    return const Center(child: Text('Start typing to search.'));
                  }
                  if (results.isEmpty) {
                    return const Center(child: Text('No matches found.'));
                  }
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) => _SearchResultTile(result: results[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final translationSummary = result.translations.entries.map((e) => e.value).join(' · ');
    return ListTile(
      title: Text(result.word.word),
      subtitle: Text(translationSummary),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/word/${result.word.id}'),
    );
  }
}
