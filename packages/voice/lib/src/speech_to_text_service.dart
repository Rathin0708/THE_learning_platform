import 'dart:async';

import 'package:core/core.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Real, on-device-only speech recognition (THE-37/39/40), wrapping
/// `speech_to_text` (native OS ASR: Android SpeechRecognizer, iOS/macOS
/// Speech framework, Windows Speech Platform).
///
/// `onDevice: true` is always forced — per the package's own docs, this
/// makes the listen attempt fail outright rather than silently falling
/// back to a network-based recognizer, which matters because this app's
/// hard rule (spec 8.2) is that no core feature may depend on a network
/// call. A failed on-device attempt is surfaced as [AsrResult.unavailable]
/// so the UI can say so honestly, rather than the app silently phoning
/// home for something the user was told is offline.
///
/// Bundled Whisper.cpp as the universal fallback for devices/locales
/// without on-device OS recognition (spec 7.1's "bundled Whisper.cpp
/// engine as the universal fallback") is NOT implemented here — that is
/// a substantial native-binary-bundling project of its own (THE-37/38)
/// and is intentionally left as real remaining scope rather than faked.
class SpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
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
