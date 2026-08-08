import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'text_to_speech_service.dart';

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) => TextToSpeechService());
