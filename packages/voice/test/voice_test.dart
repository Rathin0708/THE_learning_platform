import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice/voice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('speak() on empty text is a no-op (skipped) and never touches the platform channel', () async {
    final service = TextToSpeechService();
    final result = await service.speak('', LanguageCode.english);
    expect(result, TtsResult.skipped);
  });

  group('PronunciationAnalyzer (THE-44)', () {
    final analyzer = PronunciationAnalyzer();

    test('full match scores 100% with every word marked correct', () {
      final result = analyzer.score('I want water', 'I want water');
      expect(result.percent, 100);
      expect(result.perWord.every((w) => w.matched), isTrue);
    });

    test('partial match scores proportionally and flags the missed word', () {
      final result = analyzer.score('I want water', 'I want juice');
      expect(result.percent, closeTo(66.67, 0.1));
      expect(result.perWord.firstWhere((w) => w.word == 'water').matched, isFalse);
      expect(result.perWord.firstWhere((w) => w.word == 'want').matched, isTrue);
    });

    test('is case-insensitive and punctuation-insensitive', () {
      final result = analyzer.score('Hello!', 'hello');
      expect(result.percent, 100);
    });

    test('no match scores 0%', () {
      final result = analyzer.score('want', 'completely different');
      expect(result.percent, 0);
    });

    test('empty expected text scores 0 rather than throwing', () {
      final result = analyzer.score('', 'anything');
      expect(result.percent, 0);
      expect(result.perWord, isEmpty);
    });
  });

  group('AudioPlayerService (THE-43)', () {
    test('playFile() with a blank path is a no-op (error) and never touches the platform channel', () async {
      final service = AudioPlayerService();
      final result = await service.playFile('');
      expect(result, AudioPlaybackResult.error);
    });
  });

  group('PiperTtsService (THE-41)', () {
    test('synthesize() on empty text is a no-op (error) without touching the model', () async {
      final service = PiperTtsService();
      final outcome = await service.synthesize('');
      expect(outcome.result, SherpaTtsResult.error);
    });

    test('synthesize() with no voice installed resolves to modelNotInstalled rather than throwing', () async {
      final service = PiperTtsService();
      final outcome = await service.synthesize('hello');
      expect(outcome.result, SherpaTtsResult.modelNotInstalled);
    });
  });

  group('KokoroTtsService (THE-42)', () {
    test('synthesize() on empty text is a no-op (error) without touching the model', () async {
      final service = KokoroTtsService();
      final outcome = await service.synthesize('');
      expect(outcome.result, SherpaTtsResult.error);
    });

    test('synthesize() with no voice installed resolves to modelNotInstalled rather than throwing', () async {
      final service = KokoroTtsService();
      final outcome = await service.synthesize('hello');
      expect(outcome.result, SherpaTtsResult.modelNotInstalled);
    });
  });
}
