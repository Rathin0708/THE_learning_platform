/// Voice layer for the Language Learning OS (spec 2.5 VoiceService):
/// TextToSpeech (flutter_tts, OS-native), SpeechToText (speech_to_text,
/// on-device-only via onDevice: true), and word-level pronunciation
/// scoring. Bundled Whisper.cpp as a universal offline-ASR fallback for
/// devices without OS-level on-device recognition is not implemented —
/// see speech_to_text_service.dart for why, and what that would take.
library;

export 'src/text_to_speech_service.dart';
export 'src/speech_to_text_service.dart';
export 'src/pronunciation_analyzer.dart';
export 'src/voice_service.dart';
export 'src/voice_providers.dart';
