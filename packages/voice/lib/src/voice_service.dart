import 'audio_player_service.dart';
import 'pronunciation_analyzer.dart';
import 'speech_to_text_service.dart';
import 'text_to_speech_service.dart';

/// Single service-layer entry point bundling TextToSpeech, SpeechToText,
/// PronunciationAnalyzer, and AudioPlayer (spec 2.5's VoiceService diagram),
/// so voice capabilities have one discoverable surface even though each
/// concern is still its own focused class underneath (and each is also
/// independently injectable via its own Riverpod provider for call sites
/// that only need one — a standard Riverpod pattern, not a layering
/// violation: nothing outside packages/voice talks to
/// flutter_tts/speech_to_text/just_audio directly).
///
/// [player] (THE-43) sits idle for OS-native TTS (which speaks directly,
/// no intermediate file) and is exercised once a synthesis backend that
/// produces a standalone audio file — Piper/Kokoro via `sherpa_onnx`,
/// THE-41/THE-42 — is wired in.
class VoiceService {
  final TextToSpeechService tts;
  final SpeechToTextService asr;
  final PronunciationAnalyzer pronunciation;
  final AudioPlayerService player;

  VoiceService({
    TextToSpeechService? tts,
    SpeechToTextService? asr,
    PronunciationAnalyzer? pronunciation,
    AudioPlayerService? player,
  })  : tts = tts ?? TextToSpeechService(),
        asr = asr ?? SpeechToTextService(),
        pronunciation = pronunciation ?? PronunciationAnalyzer(),
        player = player ?? AudioPlayerService();
}
