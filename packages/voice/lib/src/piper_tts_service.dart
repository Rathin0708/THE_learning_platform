/// [PiperTtsService] resolves to the real `sherpa_onnx`-backed
/// implementation everywhere dart:ffi actually exists (desktop, mobile),
/// and to a stub that always reports itself not installed on web — same
/// conditional-export pattern as [WhisperFallbackService], for the same
/// reason (sherpa_onnx's native bindings use dart:ffi, which has no web
/// implementation wired up here).
library;

export 'piper_tts_service_stub.dart' if (dart.library.ffi) 'piper_tts_service_io.dart';
