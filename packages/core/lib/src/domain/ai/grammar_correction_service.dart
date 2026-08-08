import 'local_llm_engine.dart';

class GrammarCorrectionResult {
  final String original;
  final String corrected;
  final String explanation;
  final String hindiTranslation;
  final String tamilTranslation;

  const GrammarCorrectionResult({
    required this.original,
    required this.corrected,
    required this.explanation,
    required this.hindiTranslation,
    required this.tamilTranslation,
  });
}

/// Thrown when the local LLM's response doesn't follow the required
/// format. Surfacing this honestly (rather than guessing/half-filling
/// fields) matters more for a small on-device model, which won't always
/// follow instructions as reliably as a hosted large model.
class LocalLlmResponseFormatException implements Exception {
  final String rawResponse;
  LocalLlmResponseFormatException(this.rawResponse);
  @override
  String toString() => 'LocalLlmResponseFormatException: model response did not match the '
      'required CORRECTED/EXPLANATION/HINDI/TAMIL format. Raw response:\n$rawResponse';
}

/// Engine B's grammar-correction feature (THE-54, spec 7.3): corrects a
/// learner's English sentence, explains why, and mirrors the corrected
/// sentence in Hindi and Tamil. Pure orchestration logic — prompt
/// construction and response parsing — with no FFI dependency, so it's
/// fully unit-testable against a fake [LocalLlmEngine].
class GrammarCorrectionService {
  final LocalLlmEngine engine;
  GrammarCorrectionService(this.engine);

  static const _fieldOrder = ['CORRECTED', 'EXPLANATION', 'HINDI', 'TAMIL'];

  String buildPrompt(String learnerInput) {
    return '<|im_start|>system\n'
        'You are a precise language tutor correcting a learner\'s English sentence. '
        'Respond with EXACTLY these four lines and nothing else, no extra commentary:\n'
        'CORRECTED: <the corrected English sentence>\n'
        'EXPLANATION: <one short sentence explaining the grammar mistake, in English>\n'
        'HINDI: <the corrected sentence translated to Hindi>\n'
        'TAMIL: <the corrected sentence translated to Tamil>\n'
        '<|im_end|>\n'
        '<|im_start|>user\n$learnerInput<|im_end|>\n'
        '<|im_start|>assistant\n';
  }

  GrammarCorrectionResult parseResponse(String original, String rawResponse) {
    final fields = <String, String>{};
    for (final line in rawResponse.split('\n')) {
      final trimmed = line.trim();
      for (final key in _fieldOrder) {
        if (trimmed.startsWith('$key:')) {
          fields[key] = trimmed.substring(key.length + 1).trim();
        }
      }
    }

    if (_fieldOrder.any((k) => !fields.containsKey(k) || fields[k]!.isEmpty)) {
      throw LocalLlmResponseFormatException(rawResponse);
    }

    return GrammarCorrectionResult(
      original: original,
      corrected: fields['CORRECTED']!,
      explanation: fields['EXPLANATION']!,
      hindiTranslation: fields['HINDI']!,
      tamilTranslation: fields['TAMIL']!,
    );
  }

  /// Runs the full correct-and-explain flow (spec 7.3's worked example:
  /// "I am go market yesterday" -> "I went to the market yesterday" plus
  /// explanation, mirrored in Hindi and Tamil).
  Future<GrammarCorrectionResult> correct(String learnerInput) async {
    if (!engine.isReady) {
      throw StateError('LocalLlmEngine is not initialized — call initialize() first.');
    }
    final response = await engine.generate(buildPrompt(learnerInput));
    return parseResponse(learnerInput, response);
  }
}
