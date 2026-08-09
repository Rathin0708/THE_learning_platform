import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'sherpa_tts_outcome.dart';
import 'sherpa_tts_shared_io.dart';

/// Real Piper TTS (THE-41) via `sherpa_onnx`'s VITS model family — Piper
/// voices are VITS models under the hood, and sherpa-onnx ships them
/// ready-to-use (no separate conversion step).
///
/// English-only: Piper publishes no Tamil/Hindi voices as of writing
/// (checked the full `rhasspy/piper-voices` language list). Tamil and
/// Hindi keep coming from [TextToSpeechService]'s OS-native voice via
/// `flutter_tts` regardless of whether this engine is installed.
///
/// Expects a pre-installed voice at `<app support dir>/tts/piper-en-us`
/// (a `.onnx` model, `tokens.txt`, and an `espeak-ng-data` directory — the
/// exact layout of sherpa-onnx's own published Piper voice bundles, e.g.
/// `vits-piper-en_US-lessac-medium.tar.bz2`). There is no download/install
/// flow here — that's THE-61 (model management UI) / THE-68 (install
/// packs); this class only needs the files to already be in place.
class PiperTtsService {
  sherpa.OfflineTts? _tts;
  bool? _ready;

  Future<String> _voiceDir() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/tts/piper-en-us';
  }

  File? _firstOnnxIn(Directory dir) {
    if (!dir.existsSync()) return null;
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.onnx')) return entity;
    }
    return null;
  }

  Future<bool> _ensureReady() async {
    if (_ready != null) return _ready!;
    try {
      final base = await _voiceDir();
      final modelFile = _firstOnnxIn(Directory(base));
      final tokensFile = File('$base/tokens.txt');
      final dataDir = Directory('$base/espeak-ng-data');
      if (modelFile == null || !tokensFile.existsSync() || !dataDir.existsSync()) {
        _ready = false;
        return false;
      }

      ensureSherpaBindingsInitialized();
      _tts = sherpa.OfflineTts(
        sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(model: modelFile.path, tokens: tokensFile.path, dataDir: dataDir.path),
            numThreads: 1,
            provider: 'cpu',
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    return _ready!;
  }

  Future<SherpaTtsOutcome> synthesize(String text) async {
    if (text.trim().isEmpty) return const SherpaTtsOutcome(SherpaTtsResult.error, null);
    final ready = await _ensureReady();
    if (!ready) return const SherpaTtsOutcome(SherpaTtsResult.modelNotInstalled, null);
    return synthesizeToTempWav(_tts!, text, 'piper');
  }

  void dispose() {
    _tts?.free();
    _tts = null;
    _ready = null;
  }
}
