/// Shared result type for [PiperTtsService] and [KokoroTtsService]
/// (THE-41/THE-42) — deliberately has no sherpa_onnx/dart:ffi import so
/// both the real and web-stub implementations of each service can use it.
enum SherpaTtsResult { synthesized, modelNotInstalled, error }

class SherpaTtsOutcome {
  final SherpaTtsResult result;

  /// Path to the generated WAV file, present only when [result] is
  /// [SherpaTtsResult.synthesized]. Callers hand this to
  /// [AudioPlayerService.playFile].
  final String? audioFilePath;

  const SherpaTtsOutcome(this.result, this.audioFilePath);
}
