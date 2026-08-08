import 'dart:io';

import 'package:core/core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_llm_engine_io.dart';

String get _libraryFileName {
  if (Platform.isWindows) return 'llama.dll';
  if (Platform.isMacOS) return 'libllama.dylib';
  return 'libllama.so'; // Linux
}

/// Looks for a model installed at
/// `<app support dir>/local_ai/{llama.dll|libllama.dylib|libllama.so}` and
/// `<app support dir>/local_ai/model.gguf`, and if both are present,
/// constructs and initializes a real [LlamaCppLocalLlmEngine].
///
/// There is no bundling/download flow yet (THE-61, still open) — this is
/// intentionally just a fixed, documented install location (see
/// docs/local_ai_setup.md) rather than a fake "always available" claim.
/// Only the Windows path has actually been verified end-to-end (THE-51);
/// macOS/Linux use the same logic but are unverified — see
/// [LocalAiPlatformGate]'s doc comment.
Future<LocalLlmEngine?> tryLoadDesktopLocalLlmEngine() async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return null;

  final supportDir = await getApplicationSupportDirectory();
  final localAiDir = p.join(supportDir.path, 'local_ai');
  final libraryPath = p.join(localAiDir, _libraryFileName);
  final modelPath = p.join(localAiDir, 'model.gguf');

  if (!File(libraryPath).existsSync() || !File(modelPath).existsSync()) {
    return null;
  }

  final engine = LlamaCppLocalLlmEngine(libraryPath: libraryPath, modelPath: modelPath);
  await engine.initialize();
  return engine;
}
