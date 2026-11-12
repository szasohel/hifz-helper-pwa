/// A displayed token, with a 1-based lexical word position when applicable.
class QuranWordToken {
  const QuranWordToken(this.text, this.wordPosition);

  final String text;
  final int? wordPosition;
}

// Arabic letters, not vowel marks, waqf signs, punctuation or verse numbers.
final _arabicLetter = RegExp(
  r'[\u0620-\u064A\u066E-\u066F\u0671-\u06D3\u06D5\u06EE-\u06EF\u06FA-\u06FC\u06FF\u0750-\u077F\u08A0-\u08C9]',
);

/// Preserve all visible signs but count only words for meaning lookup.
/// Attached pause signs remain part of the word they annotate.
List<QuranWordToken> tokenizeQuranWords(String arabic) {
  var position = 0;
  return RegExp(r'\S+').allMatches(arabic).map((match) {
    final text = match.group(0)!;
    return QuranWordToken(
      text,
      _arabicLetter.hasMatch(text) ? ++position : null,
    );
  }).toList();
}

/// Missing positions must never fall back to another word's meaning.
Map<String, dynamic>? findQuranWord(
  List<Map<String, dynamic>> words,
  int position,
) {
  for (final word in words) {
    if (word['position'] == position) return word;
  }
  return null;
}