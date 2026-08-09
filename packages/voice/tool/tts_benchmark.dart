// ignore_for_file: avoid_print — this is a CLI tool; printing is the point.
//
// Benchmarks Piper vs. Kokoro synthesis speed (THE-42's "benchmark vs
// Piper" requirement) on real, locally-installed voices. Not run by
// `flutter test` — it needs multi-hundred-MB model files that aren't
// bundled in the repo (same "dev-machine validation, manually installed"
// precedent as docs/local_ai_setup.md's Qwen model).
//
// Usage:
//   dart run tool/tts_benchmark.dart \
//     --dylib-dir <dir containing the built sherpa-onnx-c-api native lib> \
//     --piper-dir <dir with a Piper voice: *.onnx, tokens.txt, espeak-ng-data/> \
//     --kokoro-dir <dir with a Kokoro voice: model.onnx, voices.bin, tokens.txt, espeak-ng-data/> \
//     [--output docs/tts_benchmark.md]
import 'dart:io';

import 'package:args/args.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

const _sentences = [
  'Hello, how are you today?',
  'I would like to order a coffee, please.',
  'Where is the nearest train station?',
  'This is a test of the speech synthesis pipeline.',
  'Practice makes perfect when learning a new language.',
];

class _EngineResult {
  final String name;
  final List<double> synthesisSeconds;
  final List<double> audioSeconds;
  _EngineResult(this.name, this.synthesisSeconds, this.audioSeconds);

  double get totalSynthesisSeconds => synthesisSeconds.fold(0.0, (a, b) => a + b);
  double get totalAudioSeconds => audioSeconds.fold(0.0, (a, b) => a + b);
  double get realTimeFactor => totalAudioSeconds == 0 ? 0 : totalSynthesisSeconds / totalAudioSeconds;
}

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('dylib-dir', help: 'Directory containing the built sherpa-onnx native library')
    ..addOption('piper-dir', help: 'Directory with a Piper voice (*.onnx, tokens.txt, espeak-ng-data/)')
    ..addOption('kokoro-dir', help: 'Directory with a Kokoro voice (model.onnx, voices.bin, tokens.txt, espeak-ng-data/)')
    ..addOption('output', help: 'Markdown report path', defaultsTo: 'docs/tts_benchmark.md');
  final args = parser.parse(arguments);

  final piperDir = args['piper-dir'] as String?;
  final kokoroDir = args['kokoro-dir'] as String?;
  if (piperDir == null || kokoroDir == null) {
    print(parser.usage);
    exit(1);
  }

  sherpa.initBindings(args['dylib-dir'] as String?);

  final results = <_EngineResult>[
    _benchmarkPiper('Piper (VITS)', piperDir),
    _benchmarkKokoro('Kokoro', kokoroDir),
  ];

  final report = _formatReport(results);
  print(report);
  File(args['output'] as String).writeAsStringSync(report);
}

File? _firstOnnxIn(Directory dir) {
  for (final entity in dir.listSync()) {
    if (entity is File && entity.path.toLowerCase().endsWith('.onnx')) return entity;
  }
  return null;
}

_EngineResult _benchmarkPiper(String name, String voiceDir) {
  final modelFile = _firstOnnxIn(Directory(voiceDir))!;
  final tts = sherpa.OfflineTts(
    sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: modelFile.path,
          tokens: '$voiceDir/tokens.txt',
          dataDir: '$voiceDir/espeak-ng-data',
        ),
        numThreads: 1,
      ),
    ),
  );
  final result = _runBenchmark(name, tts);
  tts.free();
  return result;
}

_EngineResult _benchmarkKokoro(String name, String voiceDir) {
  final tts = sherpa.OfflineTts(
    sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        kokoro: sherpa.OfflineTtsKokoroModelConfig(
          model: '$voiceDir/model.onnx',
          voices: '$voiceDir/voices.bin',
          tokens: '$voiceDir/tokens.txt',
          dataDir: '$voiceDir/espeak-ng-data',
          lang: 'en-us',
        ),
        numThreads: 1,
      ),
    ),
  );
  final result = _runBenchmark(name, tts);
  tts.free();
  return result;
}

_EngineResult _runBenchmark(String name, sherpa.OfflineTts tts) {
  final synthesisSeconds = <double>[];
  final audioSeconds = <double>[];
  for (final sentence in _sentences) {
    // Warm-up-free single measurement per sentence — this benchmarks real
    // cold-per-call latency, which is what a "Hear it" tap actually pays.
    final stopwatch = Stopwatch()..start();
    final audio = tts.generate(text: sentence);
    stopwatch.stop();
    synthesisSeconds.add(stopwatch.elapsedMicroseconds / 1e6);
    audioSeconds.add(audio.sampleRate == 0 ? 0 : audio.samples.length / audio.sampleRate);
  }
  return _EngineResult(name, synthesisSeconds, audioSeconds);
}

String _formatReport(List<_EngineResult> results) {
  final buffer = StringBuffer()
    ..writeln('# TTS engine benchmark (THE-42)')
    ..writeln()
    ..writeln('Piper vs. Kokoro synthesis speed, ${_sentences.length} sentences, single-threaded CPU, generated ${DateTime.now().toIso8601String()}.')
    ..writeln()
    ..writeln('| Engine | Total synthesis time | Total audio duration | Real-time factor (lower is faster) |')
    ..writeln('|---|---|---|---|');
  for (final r in results) {
    buffer.writeln(
      '| ${r.name} | ${r.totalSynthesisSeconds.toStringAsFixed(2)}s | ${r.totalAudioSeconds.toStringAsFixed(2)}s | ${r.realTimeFactor.toStringAsFixed(3)} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('Real-time factor = synthesis time / audio duration. Below 1.0 means synthesis is faster than real-time playback.');
  return buffer.toString();
}
