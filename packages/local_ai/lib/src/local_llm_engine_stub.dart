import 'package:core/core.dart';

/// Web (and any platform without dart:io/dart:ffi) fallback. Engine B is
/// desktop-only per [LocalAiPlatformGate] (spec 7.3/12: never forced onto
/// mobile/web), so this only exists to keep the package importable —
/// and web builds compiling — from code that doesn't platform-branch
/// itself; it is never expected to actually be constructed on web.
class LlamaCppLocalLlmEngine implements LocalLlmEngine {
  LlamaCppLocalLlmEngine({required String libraryPath, required String modelPath, int maxTokens = 200});

  @override
  bool get isReady => false;

  @override
  Future<void> initialize() async {
    throw UnsupportedError('Local LLM (Engine B) is not available on this platform.');
  }

  @override
  Future<String> generate(String prompt) async {
    throw UnsupportedError('Local LLM (Engine B) is not available on this platform.');
  }

  @override
  Future<void> dispose() async {}
}
