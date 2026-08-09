import 'sherpa_tts_outcome.dart';

/// Web stub for [PiperTtsService] — see piper_tts_service.dart's
/// conditional export. `sherpa_onnx`'s native FFI bindings have no web
/// implementation path wired up here (out of scope for THE-41; web TTS
/// stays on `flutter_tts` via [TextToSpeechService]), so this platform
/// always reports itself not installed rather than attempting a native
/// call.
class PiperTtsService {
  Future<SherpaTtsOutcome> synthesize(String text) async {
    return const SherpaTtsOutcome(SherpaTtsResult.modelNotInstalled, null);
  }

  void dispose() {}
}
