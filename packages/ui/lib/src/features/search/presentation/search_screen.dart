import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../theme/app_theme.dart';

/// Multi-script search (THE-17, spec 9.3): typing a native-script term, a
/// transliterated term, or the English equivalent all resolve to the same
/// result cluster via the FTS5 index in packages/core. Recent searches are
/// cached and surfaced when the search box is empty.
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

  void _runSearch(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
    if (value.trim().isNotEmpty) {
      ref.read(recordSearchProvider)(value);
    }
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
              // Live filtering as the user types...
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
              // ...but only a completed search (submit) is recorded into
              // recent searches, so "s", "sa", "sap" don't all get cached.
              onSubmitted: _runSearch,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: resultsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Search failed: $e')),
                data: (results) {
                  if (_controller.text.trim().isEmpty) {
                    return _RecentSearches(
                      onTap: (query) {
                        _controller.text = query;
                        _runSearch(query);
                      },
                    );
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

class _RecentSearches extends ConsumerWidget {
  final void Function(String query) onTap;
  const _RecentSearches({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentSearchesProvider);
    return recentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (recent) {
        if (recent.isEmpty) {
          return const Center(child: Text('Start typing to search.'));
        }
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Recent searches', style: Theme.of(context).textTheme.labelLarge),
            ),
            for (final query in recent)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                onTap: () => onTap(query),
              ),
          ],
        );
      },
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
