/// Domain entities for the Content database (read-only, shipped with the app).
/// Field names mirror the Content JSON Schema / DB schema in the engineering
/// spec section 4.1 / 5.
library;

enum LanguageCode { english, tamil, hindi }

extension LanguageCodeX on LanguageCode {
  String get code => switch (this) {
        LanguageCode.english => 'en',
        LanguageCode.tamil => 'ta',
        LanguageCode.hindi => 'hi',
      };

  static LanguageCode fromCode(String code) => switch (code) {
        'en' => LanguageCode.english,
        'ta' => LanguageCode.tamil,
        'hi' => LanguageCode.hindi,
        _ => throw ArgumentError('Unknown language code: $code'),
      };
}

class WordEntity {
  final int id;
  final LanguageCode language;
  final String word;
  final String normalizedWord;
  final String partOfSpeech;
  final String level;
  final String category;
  final double frequency;
  final int difficulty;

  const WordEntity({
    required this.id,
    required this.language,
    required this.word,
    required this.normalizedWord,
    required this.partOfSpeech,
    required this.level,
    required this.category,
    required this.frequency,
    required this.difficulty,
  });
}

/// A single sense-level translation between two words (spec 4.5: word -> sense -> context -> translation).
class TranslationEntity {
  final int id;
  final int sourceWordId;
  final int targetWordId;
  final String meaning;
  final String context;

  const TranslationEntity({
    required this.id,
    required this.sourceWordId,
    required this.targetWordId,
    required this.meaning,
    required this.context,
  });
}

class SentenceEntity {
  final int id;
  final String level;
  final String category;
  final LanguageCode sourceLanguage;
  final String sourceText;

  const SentenceEntity({
    required this.id,
    required this.level,
    required this.category,
    required this.sourceLanguage,
    required this.sourceText,
  });
}

class SentenceTranslationEntity {
  final int sentenceId;
  final LanguageCode language;
  final String translatedText;

  const SentenceTranslationEntity({
    required this.sentenceId,
    required this.language,
    required this.translatedText,
  });
}

class PronunciationEntity {
  final int id;
  final int contentId;
  final LanguageCode language;
  final String? ipa;
  final String? tamilPronunciation;
  final String? englishPronunciation;
  final String? audioAsset;

  const PronunciationEntity({
    required this.id,
    required this.contentId,
    required this.language,
    this.ipa,
    this.tamilPronunciation,
    this.englishPronunciation,
    this.audioAsset,
  });
}

class ExampleEntity {
  final int id;
  final int? wordId;
  final int? sentenceId;
  final String context;
  final String meaning;

  const ExampleEntity({
    required this.id,
    this.wordId,
    this.sentenceId,
    required this.context,
    required this.meaning,
  });
}

class GrammarTopicEntity {
  final int id;
  final String level;
  final String topic;
  final String explanation;
  final String examples;

  const GrammarTopicEntity({
    required this.id,
    required this.level,
    required this.topic,
    required this.explanation,
    required this.examples,
  });
}

class ConversationEntity {
  final int id;
  final String level;
  final String scenario;
  final String title;

  const ConversationEntity({
    required this.id,
    required this.level,
    required this.scenario,
    required this.title,
  });
}

class ConversationLineEntity {
  final int id;
  final int conversationId;
  final String speaker;
  final String text;
  final String translation;
  final String? expectedResponse;

  const ConversationLineEntity({
    required this.id,
    required this.conversationId,
    required this.speaker,
    required this.text,
    required this.translation,
    this.expectedResponse,
  });
}

class QuizQuestionEntity {
  final int id;
  final String level;
  final String type;
  final String question;
  final String answer;
  final List<String> options;

  const QuizQuestionEntity({
    required this.id,
    required this.level,
    required this.type,
    required this.question,
    required this.answer,
    this.options = const [],
  });
}

/// A fully expanded word, ready for the Word Detail screen (spec 9.2).
class WordDetail {
  final WordEntity word;
  final Map<LanguageCode, String> translations;
  final PronunciationEntity? pronunciation;
  final List<ExampleEntity> examples;

  const WordDetail({
    required this.word,
    required this.translations,
    this.pronunciation,
    this.examples = const [],
  });
}

class SearchResult {
  final WordEntity word;
  final Map<LanguageCode, String> translations;

  const SearchResult({required this.word, required this.translations});
}
