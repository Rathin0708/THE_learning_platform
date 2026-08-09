import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_player_service.dart';
import 'kokoro_tts_service.dart';
import 'piper_tts_service.dart';
import 'pronunciation_analyzer.dart';
import 'speech_to_text_service.dart';
import 'text_to_speech_service.dart';
import 'voice_service.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) => ref.watch(voiceServiceProvider).tts);

final speechToTextServiceProvider = Provider<SpeechToTextService>((ref) => ref.watch(voiceServiceProvider).asr);

final pronunciationAnalyzerProvider =
    Provider<PronunciationAnalyzer>((ref) => ref.watch(voiceServiceProvider).pronunciation);

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) => ref.watch(voiceServiceProvider).player);

/// English-only alternate TTS engines (THE-41/THE-42), independent of
/// [voiceServiceProvider]'s [TextToSpeechService] (which remains the
/// default/fallback OS-native voice for all three languages). Not
/// installed by default — see [PiperTtsService]/[KokoroTtsService] for the
/// expected on-disk voice layout.
final piperTtsServiceProvider = Provider<PiperTtsService>((ref) => PiperTtsService());

final kokoroTtsServiceProvider = Provider<KokoroTtsService>((ref) => KokoroTtsService());
