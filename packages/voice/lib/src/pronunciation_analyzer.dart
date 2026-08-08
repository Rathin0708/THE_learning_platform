/// Word-level pronunciation scoring (THE-44): compares an ASR transcript
/// against the expected word/sentence and returns a per-word check mark
/// plus an overall percentage.
///
/// Deliberately word-level only — per spec 7.4/12, phoneme-level accuracy
/// must not be marketed as accurate without a dedicated evaluation model,
/// which does not exist in this app. This class has no notion of
/// phonemes at all, so there's no risk of overstating what it measures.
class PronunciationAnalyzer {
  PronunciationScore score(String expected, String recognized) {
    final expectedWords = _tokenize(expected);
    final recognizedWords = _tokenize(recognized).toSet();

    if (expectedWords.isEmpty) {
      return const PronunciationScore(perWord: [], percent: 0);
    }

    final perWord = [
      for (final word in expectedWords) WordMatch(word: word, matched: recognizedWords.contains(word)),
    ];
    final matchedCount = perWord.where((w) => w.matched).length;
    final percent = (matchedCount / expectedWords.length) * 100;

    return PronunciationScore(perWord: perWord, percent: percent);
  }

  List<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();
}

class WordMatch {
  final String word;
  final bool matched;
  const WordMatch({required this.word, required this.matched});
}

class PronunciationScore {
  final List<WordMatch> perWord;
  final double percent;
  const PronunciationScore({required this.perWord, required this.percent});
}
