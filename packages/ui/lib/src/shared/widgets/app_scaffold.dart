import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_router.dart';

/// Shared scaffold with a persistent bottom nav (Home / Search / Progress /
/// Settings) so every top-level destination is always one tap away,
/// regardless of how deep the user has navigated (THE-16).
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final int currentIndex;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentIndex,
    this.actions,
    this.floatingActionButton,
  });

  static const _destinations = [
    (AppRoutes.home, Icons.home_outlined, 'Home'),
    (AppRoutes.search, Icons.search_outlined, 'Search'),
    (AppRoutes.progress, Icons.bar_chart_outlined, 'Progress'),
    (AppRoutes.settings, Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index == currentIndex) return;
          context.go(_destinations[index].$1);
        },
        destinations: [
          for (final d in _destinations) NavigationDestination(icon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
