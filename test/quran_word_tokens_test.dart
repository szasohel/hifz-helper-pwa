import 'package:flutter_test/flutter_test.dart';
import 'package:hifz_helper/core/data/quran_word_tokens.dart';

void main() {
  test('standalone pause marks do not shift following word meanings', () {
    final tokens = tokenizeQuranWords('ذَٰلِكَ ۛ الْكِتَابُ ۖ لَا رَيْبَ ۚ فِيهِ');
    expect(tokens.map((t) => t.wordPosition), [1, null, 2, null, 3, 4, null, 5]);
    expect(tokens[4].text, 'لَا');
    final meanings = [
      {'position': 3, 'translation': 'no'},
      {'position': 4, 'translation': 'doubt'},
    ];
    expect(findQuranWord(meanings, tokens[4].wordPosition!)?['translation'], 'no');
  });

  test('line breaks and attached signs preserve word positions', () {
    final tokens = tokenizeQuranWords('  قُلْ\nهُوَۖ\tاللَّهُ  أَحَدٌ  ');
    expect(tokens.map((t) => t.wordPosition), [1, 2, 3, 4]);
    expect(tokens[1].text, 'هُوَۖ');
  });

  test('IndoPak letters count while standalone signs and numbers do not', () {
    final tokens = tokenizeQuranWords('یَـٰٓأَیُّهَا ۚ الَّذِیْنَ ۩ ۝ ١ ۞');
    expect(tokens.map((t) => t.wordPosition), [1, null, 2, null, null, null, null]);
  });

  test('empty text produces no tokens', () {
    expect(tokenizeQuranWords(' \n\t'), isEmpty);
  });

  test('missing meaning never falls back to the first word', () {
    expect(findQuranWord([{'position': 1, 'translation': 'first'}], 2), isNull);
    expect(findQuranWord([], 1), isNull);
    expect(findQuranWord([{'translation': 'missing position'}], 1), isNull);
  });
}