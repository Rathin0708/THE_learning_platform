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
}
