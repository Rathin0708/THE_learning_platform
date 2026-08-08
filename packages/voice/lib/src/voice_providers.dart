import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pronunciation_analyzer.dart';
import 'speech_to_text_service.dart';
import 'text_to_speech_service.dart';
import 'voice_service.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) => ref.watch(voiceServiceProvider).tts);

final speechToTextServiceProvider = Provider<SpeechToTextService>((ref) => ref.watch(voiceServiceProvider).asr);

final pronunciationAnalyzerProvider =
    Provider<PronunciationAnalyzer>((ref) => ref.watch(voiceServiceProvider).pronunciation);
