import 'sherpa_tts_outcome.dart';

/// Web stub for [KokoroTtsService] — see kokoro_tts_service.dart's
/// conditional export. Same rationale as [PiperTtsService]'s stub: web
/// TTS stays on `flutter_tts` via [TextToSpeechService] (out of scope for
/// THE-42), so this platform always reports itself not installed.
class KokoroTtsService {
  Future<SherpaTtsOutcome> synthesize(String text) async {
    return const SherpaTtsOutcome(SherpaTtsResult.modelNotInstalled, null);
  }

  void dispose() {}
}
