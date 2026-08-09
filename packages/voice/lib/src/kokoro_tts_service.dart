/// [KokoroTtsService] resolves to the real `sherpa_onnx`-backed
/// implementation everywhere dart:ffi actually exists (desktop, mobile),
/// and to a stub that always reports itself not installed on web — same
/// conditional-export pattern as [PiperTtsService].
library;

export 'kokoro_tts_service_stub.dart' if (dart.library.ffi) 'kokoro_tts_service_io.dart';
