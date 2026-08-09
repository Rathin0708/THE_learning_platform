import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:record/record.dart';
import 'package:universal_io/io.dart' show File;
import 'package:whisper_ggml/whisper_ggml.dart';

import 'speech_to_text_service.dart' show AsrOutcome, AsrResult;

/// Bundled Whisper.cpp ASR (THE-37) — the "universal fallback" half of
/// spec 7.1's voice architecture: "native on-device recognizer first,
/// capability-detected; bundled Whisper.cpp engine as the universal
/// fallback." [SpeechToTextService] (OS-native, on-device only) is tried
/// first; this class is what it falls back to when that isn't available.
///
/// Uses `whisper_ggml` (precompiled whisper.cpp binaries — no native
/// compilation required, unlike llama_cpp_dart for the local-LLM case)
/// and the bundled `ggml-tiny.bin` multilingual model (~75MB, matches
/// spec 8.3's own ASR model size estimate) for fully offline, on-device
/// transcription — no network call, ever: the bundled asset is written
/// to the exact path `downloadModel` would fetch it to, so it always
/// finds the file already present and never opens an HTTP request.
class WhisperFallbackService {
  static const _modelAssetPath = 'assets/models/ggml-tiny.bin';
  static const _model = WhisperModel.tiny;

  final _controller = WhisperController();
  final _recorder = AudioRecorder();
  bool? _modelReady;

  Future<bool> _ensureModelReady() async {
    if (_modelReady != null) return _modelReady!;
    try {
      final modelPath = await _controller.getPath(_model);
      final file = File(modelPath);
      if (!file.existsSync()) {
        final ByteData assetBytes = await rootBundle.load(_modelAssetPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          assetBytes.buffer.asUint8List(assetBytes.offsetInBytes, assetBytes.lengthInBytes),
          flush: true,
        );
      }
      _modelReady = true;
    } catch (_) {
      // No bundled model asset (e.g. not downloaded per docs/setup.md),
      // or this platform has no native whisper implementation (web) —
      // fall back to unavailable rather than crash.
      _modelReady = false;
    }
    return _modelReady!;
  }

  static String _localeIdFor(LanguageCode language) => switch (language) {
        LanguageCode.english => 'en',
        LanguageCode.tamil => 'ta',
        LanguageCode.hindi => 'hi',
      };

  Future<AsrOutcome> listenOnce(LanguageCode language, {Duration timeout = const Duration(seconds: 8)}) async {
    final ready = await _ensureModelReady();
    if (!ready) return const AsrOutcome(AsrResult.unavailable, null);

    if (!await _recorder.hasPermission()) {
      return const AsrOutcome(AsrResult.permissionDenied, null);
    }

    Stream<Uint8List> pcmStream;
    try {
      pcmStream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
      );
    } catch (_) {
      return const AsrOutcome(AsrResult.error, null);
    }

    try {
      final session = await _controller.transcribeLive(
        model: _model,
        pcm16Stream: pcmStream,
        lang: _localeIdFor(language),
      );
      await Future<void>.delayed(timeout);
      await _recorder.stop();
      final text = (await session.stop()).trim();

      if (text.isEmpty) return const AsrOutcome(AsrResult.noSpeechDetected, null);
      return AsrOutcome(AsrResult.recognized, text);
    } catch (_) {
      await _recorder.stop();
      return const AsrOutcome(AsrResult.error, null);
    }
  }
}
