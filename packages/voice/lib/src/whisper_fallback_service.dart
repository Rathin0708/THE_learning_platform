/// [WhisperFallbackService] resolves to the real `whisper_ggml`
/// (dart:ffi-backed) implementation everywhere dart:ffi actually exists
/// (desktop, mobile), and to a stub that always reports itself
/// unavailable on web.
///
/// This was a real, previously-undiscovered bug found while validating
/// THE-51/53's web-safety: `whisper_ggml` imports `package:ffi` directly
/// (external FFI declarations), which fails to compile for web
/// (`Error: Only JS interop members may be 'external'`) — confirmed by
/// actually running `flutter build web`, which had apparently never been
/// run against apps/mobile since THE-37 (bundled Whisper) was added, only
/// `flutter analyze`/`flutter test`, neither of which catches this class
/// of dart2js-specific restriction. Conditioned on `dart.library.ffi`,
/// not `dart.library.io`: modern Dart ships a partial dart:io shim on
/// web (Platform.isX etc.), so `dart.library.io` alone is true on web too
/// and would wrongly select the real FFI implementation there.
library;

export 'whisper_fallback_service_stub.dart' if (dart.library.ffi) 'whisper_fallback_service_io.dart';
