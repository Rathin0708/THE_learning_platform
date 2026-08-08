/// The narrow contract Engine B (spec 7.3) needs from a local LLM: raw
/// text in, raw text out. Kept intentionally minimal and free of any
/// FFI/native dependency so it can live in the pure-Dart domain layer and
/// be faked in tests — the concrete llama.cpp-backed implementation lives
/// in packages/local_ai (kept out of packages/core so core's dependency
/// graph, which apps/web also pulls in, never has to compile dart:ffi).
abstract class LocalLlmEngine {
  /// Whether a model is currently loaded and ready to generate.
  bool get isReady;

  /// Loads/initializes the model. Implementations should be safe to call
  /// once at app startup (desktop only, gated by [LocalAiPlatformGate]).
  Future<void> initialize();

  /// Runs one completion for [prompt]. Throws if [isReady] is false.
  Future<String> generate(String prompt);

  Future<void> dispose();
}
