import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';

final _settingsProvider = FutureProvider.autoDispose<UserSettingsEntity>((ref) async {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.getSettings();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(_settingsProvider);

    return AppScaffold(
      title: 'Settings',
      currentIndex: 3,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load settings: $e')),
        data: (settings) => ListView(
          children: [
            SwitchListTile(
              title: const Text('Audio enabled'),
              subtitle: const Text('On-device text-to-speech for Listen buttons across the app'),
              value: settings.audioEnabled,
              onChanged: (value) async {
                final repo = ref.read(progressRepositoryProvider);
                await repo.saveSettings(UserSettingsEntity(
                  activeLanguages: settings.activeLanguages,
                  installedPacks: settings.installedPacks,
                  audioEnabled: value,
                  currentLevel: settings.currentLevel,
                ));
                ref.invalidate(_settingsProvider);
              },
            ),
            ListTile(
              title: const Text('Active languages'),
              subtitle: Text(settings.activeLanguages.join(', ')),
            ),
            ListTile(
              title: const Text('Current level'),
              subtitle: Text(settings.currentLevel),
            ),
            const ListTile(
              title: Text('Network'),
              subtitle: Text('Optional, not required — all core features work fully offline.'),
            ),
          ],
        ),
      ),
    );
  }
}
