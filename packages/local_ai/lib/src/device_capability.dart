import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';

/// Coarse device-RAM probe (THE-62's "platform-tiered model strategy").
///
/// [LocalAiPlatformGate] already answers "is local AI allowed on this OS
/// at all" (desktop-only). This answers the next question — "which model
/// size is this desktop actually comfortable running" — by querying total
/// physical RAM with a plain OS command per platform (no extra native
/// dependency; matches this project's existing preference for a small,
/// inspectable dart:io Process call over pulling in a package for a
/// one-line native query, e.g. docs/local_ai_setup.md's own DLL-search
/// workarounds).
///
/// Thresholds: below 6 GB, only [ModelTier.small] (the ~469 MB
/// Qwen2.5-0.5B already validated in THE-52) is recommended; at or above
/// that, [ModelTier.standard] (the larger Qwen2.5-1.5B) is offered as the
/// default pick, though the model management UI still lets the user
/// choose either regardless of this recommendation.
Future<ModelTier?> detectDeviceRamTier() async {
  final bytes = await _totalPhysicalMemoryBytes();
  if (bytes == null) return null;
  const sixGb = 6 * 1024 * 1024 * 1024;
  return bytes >= sixGb ? ModelTier.standard : ModelTier.small;
}

Future<int?> _totalPhysicalMemoryBytes() async {
  try {
    if (Platform.isWindows) return _windowsTotalMemory();
    if (Platform.isMacOS) return _macosTotalMemory();
    if (Platform.isLinux) return _linuxTotalMemory();
  } catch (_) {
    // Fall through to null — an unknown tier is a safe default; the UI
    // treats it as "let the user choose", never as "unsupported".
  }
  return null;
}

Future<int?> _windowsTotalMemory() async {
  final result = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
  ]);
  if (result.exitCode != 0) return null;
  return int.tryParse((result.stdout as String).trim());
}

Future<int?> _macosTotalMemory() async {
  final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
  if (result.exitCode != 0) return null;
  return int.tryParse((result.stdout as String).trim());
}

Future<int?> _linuxTotalMemory() async {
  final meminfo = File('/proc/meminfo');
  if (!meminfo.existsSync()) return null;
  for (final line in const LineSplitter().convert(await meminfo.readAsString())) {
    if (!line.startsWith('MemTotal:')) continue;
    final kb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
    return kb == null ? null : kb * 1024;
  }
  return null;
}
