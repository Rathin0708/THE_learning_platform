/// Matches a learner's spoken/typed reply against a scenario's
/// expected_response (THE-47, spec 6.1/7.3: "scenario -> intent ->
/// expected phrases -> response").
///
/// expected_response values in the content are sometimes free-form
/// templates rather than a literal phrase to repeat verbatim (e.g. "My
/// name is ..." — a learner would say "My name is Rathin", not the
/// literal string "..."). A strict equality/substring match would reject
/// every genuinely correct answer to those prompts, so this does a
/// tolerant word-overlap match instead: placeholder tokens ("...", "___")
/// are stripped, and the reply is accepted if enough of the remaining
/// significant words are present, regardless of order or extra words.
class ConversationResponseMatcher {
  static const _placeholderPattern = r'\.\.\.|_+';

  ConversationMatchResult match(String expectedResponse, String reply, {double threshold = 0.5}) {
    final expectedWords = _significantWords(expectedResponse);
    if (expectedWords.isEmpty) {
      // Nothing concrete to check against (e.g. expected_response was
      // only a placeholder) — treat any non-empty reply as accepted
      // rather than failing something we can't meaningfully grade.
      return ConversationMatchResult(matched: reply.trim().isNotEmpty, overlapRatio: 1.0);
    }

    final replyWords = _significantWords(reply).toSet();
    final overlap = expectedWords.where(replyWords.contains).length;
    final ratio = overlap / expectedWords.length;

    return ConversationMatchResult(matched: ratio >= threshold, overlapRatio: ratio);
  }

  List<String> _significantWords(String text) {
    final withoutPlaceholders = text.replaceAll(RegExp(_placeholderPattern), ' ');
    return withoutPlaceholders
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .toList();
  }
}

class ConversationMatchResult {
  final bool matched;
  final double overlapRatio;
  const ConversationMatchResult({required this.matched, required this.overlapRatio});
}
