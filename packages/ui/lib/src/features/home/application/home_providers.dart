import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_data_source.dart';
import '../domain/home_summary.dart';

/// Application layer for `home`: exposes the use-case (`load a HomeSummary`)
/// to the Presentation layer via Riverpod, without the widget layer ever
/// touching a repository or the database directly.
final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) async {
  final progressRepository = ref.watch(progressRepositoryProvider);
  return HomeDataSource(progressRepository).load();
});
