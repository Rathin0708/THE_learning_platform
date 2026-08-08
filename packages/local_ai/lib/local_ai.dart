/// [LlamaCppLocalLlmEngine] resolves to the real dart:ffi-backed
/// implementation on every platform that actually has dart:ffi (desktop,
/// mobile), and to a stub that reports itself unavailable on web — keeping
/// this package (and anything that depends on it) safe to compile for web,
/// even though Engine B is desktop-only and never actually constructs
/// this class there. See local_ai_platform_gate in core for the runtime
/// gate that keeps it off mobile too.
///
/// Deliberately conditioned on `dart.library.ffi`, not `dart.library.io`:
/// modern Dart ships a partial dart:io shim on web (Platform.isX etc., the
/// same one settings_screen.dart's `dart:io show Platform` relies on), so
/// `dart.library.io` is true on web too and would wrongly select the real
/// FFI implementation there, breaking `flutter build web` (confirmed by
/// actually running it — this isn't a hypothetical). dart:ffi itself has
/// no web shim at all, so this condition is web-safe.
library;

export 'src/local_llm_engine_stub.dart' if (dart.library.ffi) 'src/local_llm_engine_io.dart';
export 'src/engine_factory_stub.dart' if (dart.library.ffi) 'src/engine_factory_io.dart';
