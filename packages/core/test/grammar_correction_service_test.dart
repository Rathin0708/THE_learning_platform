import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

class FakeLocalLlmEngine implements LocalLlmEngine {
  String? nextResponse;
  bool ready = true;
  String? lastPrompt;

  @override
  bool get isReady => ready;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<String> generate(String prompt) async {
    lastPrompt = prompt;
    return nextResponse ?? '';
  }
}

void main() {
  late FakeLocalLlmEngine engine;
  late GrammarCorrectionService service;

  setUp(() {
    engine = FakeLocalLlmEngine();
    service = GrammarCorrectionService(engine);
  });

  test('spec 7.3 worked example: parses a well-formed model response into a structured result', () async {
    engine.nextResponse = 'CORRECTED: I went to the market yesterday.\n'
        'EXPLANATION: Use the past tense "went" for a completed action that happened yesterday.\n'
        'HINDI: मैं कल बाजार गया था।\n'
        'TAMIL: நான் நேற்று சந்தைக்குச் சென்றேன்.';

    final result = await service.correct('I am go market yesterday');

    expect(result.original, 'I am go market yesterday');
    expect(result.corrected, 'I went to the market yesterday.');
    expect(result.explanation, contains('past tense'));
    expect(result.hindiTranslation, isNotEmpty);
    expect(result.tamilTranslation, isNotEmpty);
  });

  test('sends the learner input through a real ChatML prompt asking for the 4-field format', () async {
    engine.nextResponse = 'CORRECTED: x\nEXPLANATION: x\nHINDI: x\nTAMIL: x';
    await service.correct('He go home');
    expect(engine.lastPrompt, contains('He go home'));
    expect(engine.lastPrompt, contains('CORRECTED:'));
    expect(engine.lastPrompt, contains('<|im_start|>'));
  });

  test('throws LocalLlmResponseFormatException (not a fabricated/partial result) when a field is missing', () async {
    engine.nextResponse = 'CORRECTED: I went to the market yesterday.\nEXPLANATION: past tense needed.';
    expect(() => service.correct('I am go market yesterday'), throwsA(isA<LocalLlmResponseFormatException>()));
  });

  test('throws LocalLlmResponseFormatException on empty/garbage output', () async {
    engine.nextResponse = 'sorry, I cannot help with that.';
    expect(() => service.correct('I am go market yesterday'), throwsA(isA<LocalLlmResponseFormatException>()));
  });

  test('throws StateError instead of calling generate() when the engine is not ready', () async {
    engine.ready = false;
    expect(() => service.correct('I am go market yesterday'), throwsStateError);
  });

  test('tolerates leading/trailing whitespace and extra blank lines around fields', () async {
    engine.nextResponse = '\n\n  CORRECTED:   I went to the market yesterday.  \n'
        '\nEXPLANATION: past tense.\nHINDI: मैं गया।\nTAMIL: நான் சென்றேன்.\n\n';
    final result = await service.correct('I am go market yesterday');
    expect(result.corrected, 'I went to the market yesterday.');
  });
}
