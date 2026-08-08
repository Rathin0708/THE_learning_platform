import 'dart:io' show Platform;

import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/app_router.dart';
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
            Consumer(builder: (context, ref, _) {
              final platformOk = ref.read(localAiPlatformGateProvider).isLocalAiAvailable(_currentDevicePlatform());
              final service = ref.watch(grammarCorrectionServiceProvider);
              final ready = platformOk && service != null;
              return ListTile(
                title: const Text('Local AI tutor'),
                subtitle: Text(
                  ready
                      ? 'Ready — grammar correction and open-ended tutoring, fully offline.'
                      : platformOk
                          ? 'No local model installed. See docs/local_ai_setup.md.'
                          : 'Not offered on this device — kept desktop-only so it\'s never forced onto mobile hardware.',
                ),
                trailing: Icon(ready ? Icons.check_circle_outline : Icons.block_outlined),
                onTap: ready ? () => context.push(AppRoutes.localTutor) : null,
              );
            }),
            if (!kIsWeb) const _ContentUpdateSection(),
          ],
        ),
      ),
    );
  }
}

/// Content update UI (THE-67). No production manifest server exists for
/// this project — that's a hosting decision outside this app's code, not
/// something to fabricate — so this honestly reports "not configured"
/// rather than pretending to reach a real CDN. The download/verify/
/// install machinery itself (ContentUpdateChecker) is real and tested
/// against an actual local HTTP server (see content_update_checker_test.dart).
class _ContentUpdateSection extends ConsumerStatefulWidget {
  const _ContentUpdateSection();

  @override
  ConsumerState<_ContentUpdateSection> createState() => _ContentUpdateSectionState();
}

class _ContentUpdateSectionState extends ConsumerState<_ContentUpdateSection> {
  bool _checking = false;
  String? _lastResultMessage;

  static const _manifestUrl = ''; // no production content CDN configured

  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _lastResultMessage = null;
    });
    final outcome = await ref.read(checkForContentUpdateProvider)(_manifestUrl);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _lastResultMessage = switch (outcome) {
        ContentUpdateCheckOutcome.noUpdateConfigured => 'No content update server is configured yet.',
        ContentUpdateCheckOutcome.upToDate => 'Content is already up to date.',
        ContentUpdateCheckOutcome.noNetwork => 'Could not reach the update server — using current content.',
        ContentUpdateCheckOutcome.applied => 'Content updated successfully.',
        ContentUpdateCheckOutcome.failed => 'Update check failed — using current content.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionAsync = ref.watch(contentVersionProvider);
    return ListTile(
      title: const Text('Content pack version'),
      subtitle: Text(
        versionAsync.when(
          data: (v) => _lastResultMessage ?? 'v$v (bundled)',
          loading: () => 'Loading…',
          error: (e, st) => 'Unknown',
        ),
      ),
      trailing: _checking
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(onPressed: _checkNow, child: const Text('Check')),
    );
  }
}
