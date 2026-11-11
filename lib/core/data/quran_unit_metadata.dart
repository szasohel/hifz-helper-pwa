import 'package:hifz_helper/features/hifz_engine/models/hifz_tier_model.dart';
import 'package:hifz_helper/core/data/quran_metadata.dart';

class QuranUnitMetadata {
  static const String _pageAyahLengths = '''
0705110805081109040807070505080407070708070408100607050504060608050405060304080304040305050507010409
0607070808070909070608090807061108080504080807060806060503050403070407070806090507050307040808060706
0707080805030304040406080505040507070606060706080505070810090809080709050809040709080607060504050608
1111080706080610060806080916100706060604040708090811080809080705070908060607070605050407070707040707
0706070506050706080605080911080908100909080707090908080909100709110910100808070609110609080908080508
0510060806050806090910151620192015081208081210080708060908081007101011110908091110081111050707110808
1309141311141313131219152514131211111512101014110913150909111105100807080809090806171015171515151410
1007040507100503050909121112121019202123282523242321130913091108131210080807070807091107071008090708
0707111110090809091011080906110910060907080508070408110707080908090908071208061315131416132427252624
2729161016192210051110090709110708090908070909081108110909090808100507091307121211141313161821201309
1010090608071108100909060805050707152016242123171826182421222224272734262308070605060510040607080506
0709080707090905070705121419271826282915181315191830282620253130253142292528272232302327292627121821
17141415
''';

  static const String _juzAyahLengths = '''
0148011101260131012401100149014201590127015101700154022701850269019002020339017101780169035701750246
01950399013704310564
''';

  static final List<int> pageAyahCounts = _decodeLengths(_pageAyahLengths, 2);
  static final List<int> juzAyahCounts = _decodeLengths(_juzAyahLengths, 4);
  static final List<int> pageStartOffsets = _buildStartOffsets(pageAyahCounts);
  static final List<int> juzStartOffsets = _buildStartOffsets(juzAyahCounts);
  static final List<int> surahStartOffsets = _buildSurahStartOffsets();

  static List<int> _decodeLengths(String encoded, int width) {
    final digits = encoded.replaceAll(RegExp(r'\s'), '');
    final lengths = <int>[];
    for (var index = 0; index < digits.length; index += width) {
      lengths.add(int.parse(digits.substring(index, index + width)));
    }
    return lengths;
  }

  static List<int> _buildStartOffsets(List<int> lengths) {
    final offsets = <int>[];
    var offset = 0;
    for (final length in lengths) {
      offsets.add(offset);
      offset += length;
    }
    return offsets;
  }

  static List<int> _buildSurahStartOffsets() {
    var offset = 0;
    return QuranMetadata.surahs
        .map((surah) {
          final startOffset = offset;
          offset += surah['verses_count'] as int;
          return startOffset;
        })
        .toList(growable: false);
  }

  static int offsetForAyah(int surahNumber, int ayahNumber) {
    final surah = QuranMetadata.surahs[surahNumber - 1];
    final verseCount = surah['verses_count'] as int;
    if (ayahNumber < 1 || ayahNumber > verseCount) {
      throw ArgumentError('The ayah number is outside the selected Surah.');
    }
    return surahStartOffsets[surahNumber - 1] + ayahNumber - 1;
  }

  static List<int> splitGlobalRange(int startOffset, int endOffset) {
    if (startOffset < 0 || endOffset < startOffset || endOffset >= 6236) {
      throw ArgumentError('The global ayah range is invalid.');
    }

    final ranges = <int>[];
    for (var index = 0; index < QuranMetadata.surahs.length; index++) {
      final surah = QuranMetadata.surahs[index];
      final surahStart = surahStartOffsets[index];
      final surahEnd = surahStart + (surah['verses_count'] as int) - 1;
      final rangeStart = startOffset > surahStart ? startOffset : surahStart;
      final rangeEnd = endOffset < surahEnd ? endOffset : surahEnd;
      if (rangeStart <= rangeEnd) {
        ranges.addAll([
          surah['number'] as int,
          rangeStart - surahStart + 1,
          rangeEnd - surahStart + 1,
        ]);
      }
    }
    return ranges;
  }

  static int endOffsetForUnits({
    required HifzRangeUnit unit,
    required int startOffset,
    required int count,
  }) {
    final lengths = switch (unit) {
      HifzRangeUnit.page => pageAyahCounts,
      HifzRangeUnit.juz => juzAyahCounts,
      _ => throw ArgumentError('Only Page and Juz have Mushaf unit metadata.'),
    };
    if (startOffset < 0 || startOffset >= 6236 || count <= 0) {
      throw ArgumentError('The starting ayah and unit count must be valid.');
    }

    final startIndex = _unitIndexContaining(lengths, startOffset);
    final endIndex = (startIndex + count - 1).clamp(0, lengths.length - 1);
    final starts = unit == HifzRangeUnit.page
        ? pageStartOffsets
        : juzStartOffsets;
    return starts[endIndex] + lengths[endIndex] - 1;
  }

  static int _unitIndexContaining(List<int> lengths, int offset) {
    var currentStart = 0;
    for (var index = 0; index < lengths.length; index++) {
      final currentEnd = currentStart + lengths[index] - 1;
      if (offset <= currentEnd) return index;
      currentStart = currentEnd + 1;
    }
    return lengths.length - 1;
  }
}
