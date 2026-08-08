import 'package:core/core.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Real, offline text-to-speech, wrapping each platform's native OS TTS
/// engine (Windows SAPI/OneCore, Android TextToSpeech, iOS AVSpeechSynthesizer)
/// via `flutter_tts`. No network call is made — speech is synthesized
/// entirely on-device, satisfying spec 8.2's "100% offline" hard rule.
///
/// This is a deliberate substitution for the spec's named Piper/Kokoro
/// engines (spec 7.2): the available Flutter Piper plugins are immature
/// (unversioned/early-stage, undocumented Hindi/Tamil model support), so
/// this ships real, working, offline audio today. Benchmarking Piper vs.
/// Kokoro and swapping in a dedicated neural voice remains separate future
/// work (THE-41/THE-42) if a specific voice engine is required.
///
/// Only TextToSpeech is implemented here. SpeechToText (ASR) and
/// PronunciationAnalyzer from the spec 2.5 VoiceService diagram are
/// Phase 4 tickets (THE-37/39/40, THE-44) and are intentionally not
/// stubbed out with fake behavior.
class TextToSpeechService {
  final FlutterTts _tts = FlutterTts();
  Set<String>? _availableLanguageCodesCache;

  static const Map<LanguageCode, String> _bcp47 = {
    LanguageCode.english: 'en-US',
    LanguageCode.tamil: 'ta-IN',
    LanguageCode.hindi: 'hi-IN',
  };

  Future<void> _ensureLanguagesLoaded() async {
    if (_availableLanguageCodesCache != null) return;
    try {
      final languages = await _tts.getLanguages;
      _availableLanguageCodesCache = (languages as List).map((e) => e.toString()).toSet();
    } catch (_) {
      _availableLanguageCodesCache = {};
    }
  }

  /// Whether the current device/OS has a voice installed for [language].
  /// Hindi and Tamil system voices are not guaranteed to be present on
  /// every device — this lets the UI show an honest "voice unavailable"
  /// state instead of failing silently.
  Future<bool> isLanguageAvailable(LanguageCode language) async {
    await _ensureLanguagesLoaded();
    final code = _bcp47[language]!;
    return _availableLanguageCodesCache!.any((l) => l.toLowerCase() == code.toLowerCase());
  }

  Future<TtsResult> speak(String text, LanguageCode language) async {
    if (text.trim().isEmpty) return TtsResult.skipped;
    final available = await isLanguageAvailable(language);
    if (!available) return TtsResult.languageUnavailable;

    try {
      await _tts.setLanguage(_bcp47[language]!);
      await _tts.setSpeechRate(0.45); // slower default — this is a learner tool, not a screen reader
      await _tts.speak(text);
      return TtsResult.spoken;
    } catch (_) {
      return TtsResult.error;
    }
  }

  Future<void> stop() => _tts.stop();
}

enum TtsResult { spoken, languageUnavailable, error, skipped }
