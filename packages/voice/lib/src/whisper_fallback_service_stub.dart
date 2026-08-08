import 'package:core/core.dart';

import 'speech_to_text_service.dart' show AsrOutcome, AsrResult;

/// Web fallback for [WhisperFallbackService] — see whisper_fallback_service.dart's
/// conditional export. `whisper_ggml` uses dart:ffi (real native whisper.cpp
/// bindings), which has no web implementation, so this platform always
/// reports itself unavailable rather than attempting a native call. Web's
/// own ASR fallback story is THE-38 (Whisper WASM), tracked separately.
class WhisperFallbackService {
  Future<AsrOutcome> listenOnce(LanguageCode language, {Duration timeout = const Duration(seconds: 8)}) async {
    return const AsrOutcome(AsrResult.unavailable, null);
  }
}
