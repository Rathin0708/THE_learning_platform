import 'dart:io' show Platform;

import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';

final _settingsProvider = FutureProvider.autoDispose<UserSettingsEntity>((ref) async {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.getSettings();
});

/// Resolves the real running platform into core's platform-agnostic
/// [DevicePlatform] (core deliberately has no dart:io/kIsWeb dependency —
/// see LocalAiPlatformGate's doc comment).
DevicePlatform _currentDevicePlatform() {
  if (kIsWeb) return DevicePlatform.web;
  if (Platform.isAndroid) return DevicePlatform.android;
  if (Platform.isIOS) return DevicePlatform.ios;
  if (Platform.isMacOS) return DevicePlatform.macos;
  if (Platform.isLinux) return DevicePlatform.linux;
  return DevicePlatform.windows;
}

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
            Builder(builder: (context) {
              final available = ref.read(localAiPlatformGateProvider).isLocalAiAvailable(_currentDevicePlatform());
              return ListTile(
                title: const Text('Local AI tutor'),
                subtitle: Text(
                  available
                      ? 'Available on this device (desktop). Not yet built — see THE-51..54.'
                      : 'Not offered on this device — kept desktop-only so it\'s never forced onto mobile hardware.',
                ),
                trailing: Icon(available ? Icons.check_circle_outline : Icons.block_outlined),
              );
            }),
          ],
        ),
      ),
    );
  }
}
