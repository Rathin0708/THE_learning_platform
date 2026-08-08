import 'dart:async';

import 'package:core/core.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'whisper_fallback_service.dart';

/// Real, on-device speech recognition matching spec 7.1's exact
/// architecture: "native on-device recognizer first, capability-detected;
/// bundled Whisper.cpp engine as the universal fallback."
///
/// Tries `speech_to_text` (native OS ASR: Android SpeechRecognizer,
/// iOS/macOS Speech framework, Windows Speech Platform) with
/// `onDevice: true` forced first — per the package's own docs, this makes
/// the attempt fail outright rather than silently use a network-based
/// recognizer, which matters because this app's hard rule (spec 8.2) is
/// that no core feature may depend on a network call. When that's
/// unavailable for the requested language/device, falls back to
/// [WhisperFallbackService] (bundled whisper.cpp, THE-37) — also fully
/// offline. Only if both fail does this surface [AsrResult.unavailable].
class SpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final WhisperFallbackService _whisperFallback = WhisperFallbackService();
  bool? _available;

  Future<bool> _ensureInitialized() async {
    if (_available != null) return _available!;
    try {
      _available = await _speech.initialize();
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// Listens once and resolves with the final recognized text (or a
  /// reason it didn't work). [timeout] bounds how long listening runs if
  /// the user never stops speaking.
  Future<AsrOutcome> listenOnce(LanguageCode language, {Duration timeout = const Duration(seconds: 8)}) async {
    final onDeviceResult = await _listenOnceOnDevice(language, timeout: timeout);
    if (onDeviceResult.result != AsrResult.unavailable) return onDeviceResult;

    // OS on-device recognizer isn't available for this language/device —
    // fall back to the bundled Whisper model rather than give up.
    return _whisperFallback.listenOnce(language, timeout: timeout);
  }

  Future<AsrOutcome> _listenOnceOnDevice(LanguageCode language, {required Duration timeout}) async {
    final initialized = await _ensureInitialized();
    if (!initialized) return const AsrOutcome(AsrResult.unavailable, null);

    final localeId = _localeIdFor(language);
    final hasOnDeviceLocale = await _supportsOnDevice(localeId);
    if (!hasOnDeviceLocale) return const AsrOutcome(AsrResult.unavailable, null);

    final completer = _ListenCompleter();
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.finalResult) completer.complete(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          onDevice: true,
          partialResults: false,
          listenMode: stt.ListenMode.confirmation,
          localeId: localeId,
          listenFor: timeout,
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      return const AsrOutcome(AsrResult.error, null);
    }

    final text = await completer.future.timeout(timeout + const Duration(seconds: 2), onTimeout: () => null);
    await _speech.stop();

    if (text == null) return const AsrOutcome(AsrResult.noSpeechDetected, null);
    return AsrOutcome(AsrResult.recognized, text);
  }

  Future<bool> _supportsOnDevice(String localeId) async {
    try {
      final locales = await _speech.locales();
      return locales.any((l) => l.localeId == localeId);
    } catch (_) {
      return false;
    }
  }

  static String _localeIdFor(LanguageCode language) => switch (language) {
        LanguageCode.english => 'en_US',
        LanguageCode.tamil => 'ta_IN',
        LanguageCode.hindi => 'hi_IN',
      };

  Future<void> stop() => _speech.stop();
}

enum AsrResult { recognized, unavailable, noSpeechDetected, error }

class AsrOutcome {
  final AsrResult result;
  final String? text;
  const AsrOutcome(this.result, this.text);
}

class _ListenCompleter {
  final _completer = Completer<String?>();
  Future<String?> get future => _completer.future;
  void complete(String value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }
}
