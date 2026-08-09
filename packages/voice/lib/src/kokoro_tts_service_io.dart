import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'sherpa_tts_outcome.dart';
import 'sherpa_tts_shared_io.dart';

/// Real Kokoro TTS (THE-42) via `sherpa_onnx`'s Kokoro model family.
///
/// English-only: Kokoro-82M's model card lists only `en` as a supported
/// language. Tamil and Hindi keep coming from [TextToSpeechService]'s
/// OS-native voice via `flutter_tts` regardless of whether this engine is
/// installed. See [PiperTtsService] for the other half of THE-41/THE-42's
/// "benchmark Piper vs. Kokoro" comparison — both engines share the same
/// shape (install a voice locally, synthesize, hand the WAV to
/// [AudioPlayerService]) via [synthesizeToTempWav].
///
/// Expects a pre-installed voice at `<app support dir>/tts/kokoro-en`
/// (`model.onnx`, `voices.bin`, `tokens.txt`, `espeak-ng-data/` — the exact
/// layout of sherpa-onnx's own published `kokoro-en-v0_19.tar.bz2`). No
/// download/install flow here — that's THE-61/THE-68.
class KokoroTtsService {
  sherpa.OfflineTts? _tts;
  bool? _ready;

  Future<String> _voiceDir() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/tts/kokoro-en';
  }

  Future<bool> _ensureReady() async {
    if (_ready != null) return _ready!;
    try {
      final base = await _voiceDir();
      final modelFile = File('$base/model.onnx');
      final voicesFile = File('$base/voices.bin');
      final tokensFile = File('$base/tokens.txt');
      final dataDir = Directory('$base/espeak-ng-data');
      if (!modelFile.existsSync() || !voicesFile.existsSync() || !tokensFile.existsSync() || !dataDir.existsSync()) {
        _ready = false;
        return false;
      }

      ensureSherpaBindingsInitialized();
      _tts = sherpa.OfflineTts(
        sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            kokoro: sherpa.OfflineTtsKokoroModelConfig(
              model: modelFile.path,
              voices: voicesFile.path,
              tokens: tokensFile.path,
              dataDir: dataDir.path,
              lang: 'en-us',
            ),
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
    return synthesizeToTempWav(_tts!, text, 'kokoro');
  }

  void dispose() {
    _tts?.free();
    _tts = null;
    _ready = null;
  }
}
