import 'pronunciation_analyzer.dart';
import 'speech_to_text_service.dart';
import 'text_to_speech_service.dart';

/// Single service-layer entry point bundling TextToSpeech, SpeechToText,
/// and PronunciationAnalyzer (spec 2.5's VoiceService diagram), so voice
/// capabilities have one discoverable surface even though each concern is
/// still its own focused class underneath (and each is also independently
/// injectable via its own Riverpod provider for call sites that only need
/// one — a standard Riverpod pattern, not a layering violation: nothing
/// outside packages/voice talks to flutter_tts/speech_to_text directly).
///
/// AudioPlayer (the fourth box in spec 2.5) is not a separate class here:
/// there are no bundled/pre-generated audio files to play (THE-21's
/// disclosed deviation — on-device TTS synthesis is the actual playback
/// path), so a dedicated player with nothing routed through it would be
/// dead code.
class VoiceService {
  final TextToSpeechService tts;
  final SpeechToTextService asr;
  final PronunciationAnalyzer pronunciation;

  VoiceService({TextToSpeechService? tts, SpeechToTextService? asr, PronunciationAnalyzer? pronunciation})
      : tts = tts ?? TextToSpeechService(),
        asr = asr ?? SpeechToTextService(),
        pronunciation = pronunciation ?? PronunciationAnalyzer();
}
