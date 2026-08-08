/// Voice layer for the Language Learning OS. Currently implements real,
/// offline TextToSpeech (see text_to_speech_service.dart for why this uses
/// flutter_tts instead of the spec's named Piper/Kokoro engines). ASR and
/// pronunciation scoring are Phase 4 tickets, not implemented here.
library;

export 'src/text_to_speech_service.dart';
export 'src/voice_providers.dart';
