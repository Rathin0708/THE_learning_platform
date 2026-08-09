import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'sherpa_tts_outcome.dart';

bool _sherpaBindingsInitialized = false;

/// Initializes the shared sherpa-onnx native bindings exactly once.
///
/// Required before creating any sherpa-onnx object. The package's own docs
/// note each Dart isolate needs its own call — this app only does TTS work
/// on the main isolate, so a single module-level guard is sufficient here.
void ensureSherpaBindingsInitialized() {
  if (_sherpaBindingsInitialized) return;
  sherpa.initBindings();
  _sherpaBindingsInitialized = true;
}

/// Generates audio with [tts] and saves it to a fresh temp WAV file.
/// Shared by [PiperTtsService] and [KokoroTtsService] since generation and
/// file output are identical once each has its own configured [OfflineTts]
/// — only model setup differs between the two engines.
Future<SherpaTtsOutcome> synthesizeToTempWav(sherpa.OfflineTts tts, String text, String enginePrefix) async {
  try {
    final audio = tts.generate(text: text);
    if (audio.samples.isEmpty) return const SherpaTtsOutcome(SherpaTtsResult.error, null);

    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/${enginePrefix}_${DateTime.now().microsecondsSinceEpoch}.wav';
    final saved = sherpa.writeWave(filename: outPath, samples: audio.samples, sampleRate: audio.sampleRate);
    if (!saved) return const SherpaTtsOutcome(SherpaTtsResult.error, null);

    return SherpaTtsOutcome(SherpaTtsResult.synthesized, outPath);
  } catch (_) {
    return const SherpaTtsOutcome(SherpaTtsResult.error, null);
  }
}
