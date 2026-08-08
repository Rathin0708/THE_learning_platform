/// Voice layer for the Language Learning OS (spec 2.5 VoiceService):
/// TextToSpeech (flutter_tts, OS-native), SpeechToText (speech_to_text
/// OS-native on-device recognizer first, WhisperFallbackService/whisper_ggml
/// bundled fallback second — spec 7.1's exact architecture), and
/// word-level pronunciation scoring.
library;

export 'src/text_to_speech_service.dart';
export 'src/speech_to_text_service.dart';
export 'src/whisper_fallback_service.dart';
export 'src/pronunciation_analyzer.dart';
export 'src/voice_service.dart';
export 'src/voice_providers.dart';
