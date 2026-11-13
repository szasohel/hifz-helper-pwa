import 'dart:math';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hifz_helper/app/constants.dart';
import 'package:hifz_helper/core/data/quran_ruku_metadata.dart';
import 'package:hifz_helper/core/data/quran_unit_metadata.dart';
import 'package:hifz_helper/core/database/app_database.dart';
import 'package:hifz_helper/features/hifz_engine/models/hifz_tier_model.dart';

class _AyahRange {
  final int surahNumber;
  final int startAyah;
  final int endAyah;

  const _AyahRange({
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
  });

  int get ayahCount => endAyah - startAyah + 1;

  bool canMergeWith(_AyahRange other) {
    return surahNumber == other.surahNumber && endAyah + 1 >= other.startAyah;
  }

  _AyahRange mergeWith(_AyahRange other) {
    return _AyahRange(
      surahNumber: surahNumber,
      startAyah: min(startAyah, other.startAyah),
      endAyah: max(endAyah, other.endAyah),
    );
  }
}

class ThreeTierScheduler {
  final AppDatabase _db;

  static const int _sabqiDays = 5;
  static const int _manzilRukuCount = 4;

  ThreeTierScheduler({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  String get todayIso => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<bool> isProfileConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyProfileConfigured) ?? false;
  }

  Future<List<int>> getKnownSurahs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyKnownSurahs) ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').map((s) => int.tryParse(s.trim()) ?? 1).toList();
  }

  Future<int> getCurrentSabaqSurah() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyCurrentSabaqSurah) ?? 1;
  }

  Future<int> getCurrentSabaqAyah() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyCurrentSabaqAyah) ?? 1;
  }

  Future<String> getHifzDirection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyHifzDirection) ?? AppConstants.directionLastToFirst;
  }

  Future<int> getDailyTimeCommitment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyDailyTimeCommitment) ?? 60;
  }

  Future<int> getDailySabaqTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyDailySabaqTarget) ?? 5;
  }

  Future<HifzTierLengthSettings> getTierLengthSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(AppConstants.keyTierLengthSettingsMigrated) ?? false)) {
      final oldSabaqCount =
          prefs.getInt(AppConstants.keyDailySabaqAyahs) ??
          prefs.getInt(AppConstants.keyDailySabaqTarget) ??
          5;
      final oldSabqiDays = prefs.getInt(AppConstants.keySabqiDays) ?? _sabqiDays;
      final oldManzilCount =
          prefs.getInt(AppConstants.keyManzilPortion) ?? _manzilRukuCount;
      final migratedSettings = HifzTierLengthSettings(
        sabaqCount:
            HifzTierLengthSettings.sabaqAyahPresets.contains(oldSabaqCount)
            ? oldSabaqCount
            : 5,
        sabqiDays: const {5, 7, 10}.contains(oldSabqiDays) ? oldSabqiDays : 5,
        manzilCount: oldManzilCount > 0 ? oldManzilCount : _manzilRukuCount,
      );
      await saveTierLengthSettings(migratedSettings);
      return migratedSettings;
    }

    final settings = HifzTierLengthSettings(
      sabaqUnit: HifzRangeUnit.values.firstWhere(
        (unit) => unit.name == prefs.getString(AppConstants.keySabaqRangeUnit),
        orElse: () => HifzRangeUnit.ayah,
      ),
      sabaqCount: prefs.getInt(AppConstants.keyDailySabaqAyahs) ?? 5,
      sabqiDays: prefs.getInt(AppConstants.keySabqiDays) ?? _sabqiDays,
      manzilUnit: HifzRangeUnit.values.firstWhere(
        (unit) => unit.name == prefs.getString(AppConstants.keyManzilRangeUnit),
        orElse: () => HifzRangeUnit.ruku,
      ),
      manzilCount: prefs.getInt(AppConstants.keyManzilPortion) ?? _manzilRukuCount,
    );
    settings.validate();
    return settings;
  }

  Future<void> saveTierLengthSettings(HifzTierLengthSettings settings) async {
    settings.validate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySabaqRangeUnit, settings.sabaqUnit.name);
    await prefs.setInt(AppConstants.keyDailySabaqAyahs, settings.sabaqCount);
    await prefs.setInt(AppConstants.keySabqiDays, settings.sabqiDays);
    await prefs.setString(AppConstants.keyManzilRangeUnit, settings.manzilUnit.name);
    await prefs.setInt(AppConstants.keyManzilPortion, settings.manzilCount);
    await prefs.setBool(AppConstants.keyTierLengthSettingsMigrated, true);
  }

  Future<List<HifzTask>> applyTierLengthSettings({
    required HifzTierLengthSettings settings,
    required Set<HifzTierType> affectedTiers,
  }) async {
    settings.validate();
    await saveTierLengthSettings(settings);

    final date = todayIso;
    final existingRows = await _db.getTasksForDate(date);
    if (existingRows.isEmpty) return _generateDailyTasks(date);

    final existingTasks = <HifzTask>[];
    for (final row in existingRows) {
      final surah = await _db.getSurah(row['surah_number'] as int);
      final tier = HifzTierType.values.byName(row['tier_type'] as String);
      existingTasks.add(
        HifzTask.fromMap(
          row,
          surahArabic: surah?['name_arabic'] as String? ?? '',
          surahEnglish: surah?['name_english'] as String? ?? '',
          stepNumber: tier == HifzTierType.manzil
              ? 1
              : (tier == HifzTierType.sabqi ? 2 : 3),
        ),
      );
    }

    final db = await _db.database;
    for (final tier in affectedTiers) {
      final unfinished = existingTasks
          .where((task) => task.tierType == tier && !task.isCompleted)
          .toList();
      if (unfinished.isEmpty) continue;

      await db.delete(
        'three_tier_tasks',
        where: 'target_date = ? AND tier_type = ? AND is_completed = 0',
        whereArgs: [date, tier.name],
      );
      await db.delete(
        'daily_hifz_activity',
        where: "activity_date = ? AND tier_type = ? AND status != 'completed'",
        whereArgs: [date, tier.name],
      );

      await _generateDailyTasks(
        date,
        tiersToCreate: {tier},
        startingSabaq: tier == HifzTierType.sabaq ? unfinished.first : null,
        preservedCompletedTasks: existingTasks
            .where((task) => task.tierType == tier && task.isCompleted)
            .toList(),
      );
    }

    return getOrGenerateTodayTasks();
  }

  /// Calculates the Madrasah standard 50% Manzil, 30% Sabqi, 20% Sabaq time split
  static Map<HifzTierType, int> calculateTimeSplit(int totalMinutes) {
    final manzil = (totalMinutes * 0.50).round();
    final sabqi = (totalMinutes * 0.30).round();
    final sabaq = totalMinutes - manzil - sabqi;
    return {
      HifzTierType.manzil: manzil,
      HifzTierType.sabqi: sabqi,
      HifzTierType.sabaq: sabaq,
    };
  }

  /// Orders Surahs according to their memorization progression order
  /// In lastToFirst: 114, 113, 112, ..., 2, then 1 (or 1 at start)
  static List<int> orderSurahsByDirection(Iterable<int> surahs, String direction) {
    final list = surahs.toList();
    if (direction == AppConstants.directionLastToFirst) {
      list.sort((a, b) {
        if (a == 1 && b != 1) return 1; // Put 1 at the end of the Juz Amma cycle
        if (b == 1 && a != 1) return -1;
        return b.compareTo(a); // Descending: 114 down to 2
      });
      return list;
    } else {
      list.sort(); // Ascending: 1 up to 114
      return list;
    }
  }

  /// Returns the immediately preceding Surah in the learning sequence
  /// In lastToFirst: user memorized 114, 113, ..., 86. Next is 85.
  /// The preceding Surah is 86 (the minimum known number > currentSabaqSurah)!
  /// In firstToLast: user memorized 1, 2, 3, 4. Next is 5.
  /// The preceding Surah is 4 (the maximum known number < currentSabaqSurah)!
  static int getPrecedingKnownSurah({
    required int currentSabaqSurah,
    required List<int> knownSurahs,
    required String direction,
  }) {
    if (knownSurahs.isEmpty) return currentSabaqSurah;

    if (direction == AppConstants.directionLastToFirst) {
      // Find known surahs that precede currentSabaqSurah in lastToFirst path (number > currentSabaqSurah)
      final candidates = knownSurahs.where((s) => s > currentSabaqSurah).toList();
      if (candidates.isNotEmpty) {
        candidates.sort(); // ascending: lowest number > currentSabaqSurah is the closest predecessor
        return candidates.first;
      }
      // If sabaqSurah is 114, predecessor is 1 (Al-Fatihah) if known
      if (currentSabaqSurah == 114 && knownSurahs.contains(1)) return 1;

      // Fallback: lowest non-1 known surah
      final nonOne = knownSurahs.where((s) => s != 1).toList();
      if (nonOne.isNotEmpty) {
        nonOne.sort();
        return nonOne.first;
      }
      return knownSurahs.first;
    } else {
      // In firstToLast: predecessor has number < currentSabaqSurah
      final candidates = knownSurahs.where((s) => s < currentSabaqSurah).toList();
      if (candidates.isNotEmpty) {
        candidates.sort();
        return candidates.last; // highest number < currentSabaqSurah
      }
      return knownSurahs.first;
    }
  }

  /// Selects the Manzil Surah from the pool of mastered Surahs, excluding current Sabaq and Sabqi.
  /// Rotates sequentially starting from the oldest mastered Surahs (114 in lastToFirst, 1 in firstToLast).
  static int determineManzilSurah({
    required List<int> knownSurahs,
    required int sabaqSurah,
    required int sabqiSurah,
    required String direction,
    int? lastLoggedManzilSurah,
  }) {
    // 1. Exclude today's Sabaq and Sabqi from Manzil pool
    final pool = knownSurahs.where((s) => s != sabqiSurah && s != sabaqSurah).toList();
    if (pool.isEmpty) {
      return knownSurahs.contains(1) ? 1 : (knownSurahs.isNotEmpty ? knownSurahs.first : 1);
    }

    // 2. Order pool according to memorization history (oldest mastered portion first)
    final orderedPool = orderSurahsByDirection(pool, direction);

    // 3. Rotate sequentially based on last completed Manzil log
    if (lastLoggedManzilSurah != null) {
      final lastIdx = orderedPool.indexOf(lastLoggedManzilSurah);
      if (lastIdx != -1) {
        return orderedPool[(lastIdx + 1) % orderedPool.length];
      }
    }

    // Fresh setup / Day 1: Start with the oldest mastered Surah
    return orderedPool.first;
  }

  /// Calculates the next Surah based on Hifz direction
  /// In lastToFirst: 1 (Al-Fatihah) -> 114 -> 113 -> ... -> 2 (Al-Baqarah)
  /// In firstToLast: 1 -> 2 -> 3 -> ... -> 114
  static int getNextSurahInDirection(int currentSurah, String direction) {
    if (direction == AppConstants.directionLastToFirst) {
      if (currentSurah == 1) return 114;
      if (currentSurah > 2) return currentSurah - 1;
      return 1; // Completed entire Quran!
    } else {
      if (currentSurah < 114) return currentSurah + 1;
      return 1; // Completed entire Quran!
    }
  }

  static int countAyahs(Iterable<_AyahRange> ranges) {
    return ranges.fold(0, (total, range) => total + range.ayahCount);
  }

  /// If only 1-2 ayahs remain to finish the surah, pull them into today's Sabaq
  /// so the surah completes cleanly and tomorrow starts fresh on the next surah.
  static int _extendSabaqEndNearSurahBoundary(int naiveEnd, int totalAyahs) {
    final remaining = totalAyahs - naiveEnd;
    if (remaining > 0 && remaining <= 2) return totalAyahs;
    return naiveEnd;
  }

  static List<_AyahRange> mergeAdjacentRanges(Iterable<_AyahRange> ranges) {
    final merged = <_AyahRange>[];
    for (final range in ranges) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }

      final last = merged.last;
      if (last.canMergeWith(range)) {
        merged[merged.length - 1] = last.mergeWith(range);
      } else {
        merged.add(range);
      }
    }
    return merged;
  }

  static List<_AyahRange> orderRangesForDisplay(Iterable<_AyahRange> ranges) {
    final ordered = ranges.toList();
    ordered.sort((a, b) {
      final surahCompare = a.surahNumber.compareTo(b.surahNumber);
      if (surahCompare != 0) return surahCompare;
      return a.startAyah.compareTo(b.startAyah);
    });
    return ordered;
  }

  static int? findAyahOffset(
    List<_AyahRange> ranges,
    int surahNumber,
    int ayahNumber,
  ) {
    var offset = 0;
    for (final range in ranges) {
      if (range.surahNumber == surahNumber && ayahNumber >= range.startAyah && ayahNumber <= range.endAyah) {
        return offset + (ayahNumber - range.startAyah);
      }
      offset += range.ayahCount;
    }
    return null;
  }

  static List<_AyahRange> _rukuSegmentsForMemorizedRanges(Iterable<_AyahRange> ranges) {
    final segments = <_AyahRange>[];
    for (final range in ranges) {
      final rukus = QuranRukuMetadata.overlapping(
        surahNumber: range.surahNumber,
        startAyah: range.startAyah,
        endAyah: range.endAyah,
      );
      for (final ruku in rukus) {
        final startAyah = max(ruku.startAyah, range.startAyah);
        final endAyah = min(ruku.endAyah, range.endAyah);
        if (endAyah >= startAyah) {
          segments.add(_AyahRange(
            surahNumber: range.surahNumber,
            startAyah: startAyah,
            endAyah: endAyah,
          ));
        }
      }
    }
    return segments;
  }

  static List<_AyahRange> sliceRanges(
    List<_AyahRange> ranges,
    int startOffset,
    int length,
  ) {
    if (ranges.isEmpty || length <= 0) return const [];

    final sliced = <_AyahRange>[];
    var remaining = length;
    var offset = 0;

    for (final range in ranges) {
      final rangeStartOffset = offset;
      final rangeEndOffset = offset + range.ayahCount;

      if (rangeEndOffset <= startOffset) {
        offset = rangeEndOffset;
        continue;
      }

      final localStart = max(startOffset - rangeStartOffset, 0);
      final takeCount = min(range.ayahCount - localStart, remaining);
      if (takeCount > 0) {
        sliced.add(_AyahRange(
          surahNumber: range.surahNumber,
          startAyah: range.startAyah + localStart,
          endAyah: range.startAyah + localStart + takeCount - 1,
        ));
        remaining -= takeCount;
      }

      if (remaining <= 0) break;
      offset = rangeEndOffset;
    }

    return sliced;
  }

  static List<int> splitMinutesAcrossRanges(int totalMinutes, List<_AyahRange> ranges) {
    if (ranges.isEmpty) return const [];
    if (ranges.length == 1) return [totalMinutes];

    final totalAyahs = countAyahs(ranges);
    if (totalAyahs <= 0) {
      return List<int>.filled(ranges.length - 1, 0)..add(totalMinutes);
    }

    final allocations = List<int>.filled(ranges.length, 0);
    final fractions = <MapEntry<int, double>>[];
    var allocated = 0;

    for (var index = 0; index < ranges.length; index++) {
      final exact = totalMinutes * ranges[index].ayahCount / totalAyahs;
      allocations[index] = exact.floor();
      allocated += allocations[index];
      fractions.add(MapEntry(index, exact - allocations[index]));
    }

    fractions.sort((a, b) => b.value.compareTo(a.value));
    var remainder = totalMinutes - allocated;
    var cursor = 0;
    while (remainder > 0 && fractions.isNotEmpty) {
      allocations[fractions[cursor].key] += 1;
      remainder -= 1;
      cursor = (cursor + 1) % fractions.length;
    }

    return allocations;
  }

  Future<List<_AyahRange>> _buildMemorizedRanges({
    required List<int> knownSurahs,
    required int sabaqSurah,
    required int sabaqStart,
    required String direction,
  }) async {
    final surahPool = {...knownSurahs};
    if (sabaqStart > 1) {
      surahPool.add(sabaqSurah);
    }

    final orderedSurahs = orderSurahsByDirection(surahPool, direction);
    final ranges = <_AyahRange>[];

    for (final surah in orderedSurahs) {
      final surahInfo = await _db.getSurah(surah);
      final totalAyahs = surahInfo?['verses_count'] as int? ?? 0;
      if (totalAyahs <= 0) continue;

      if (surah == sabaqSurah) {
        final endAyah = min(sabaqStart - 1, totalAyahs);
        if (endAyah >= 1) {
          ranges.add(_AyahRange(surahNumber: surah, startAyah: 1, endAyah: endAyah));
        }
      } else {
        ranges.add(_AyahRange(surahNumber: surah, startAyah: 1, endAyah: totalAyahs));
      }
    }

    return ranges;
  }

  Future<List<_AyahRange>> _buildSabqiRanges({
    required List<Map<String, dynamic>> recentLogs,
    required List<_AyahRange> repeatedRanges,
    required List<int> knownSurahs,
    required int sabaqSurah,
    required int sabaqStart,
    required int sabaqEnd,
    required String direction,
  }) async {
    if (repeatedRanges.isNotEmpty) return orderRangesForDisplay(repeatedRanges);

    if (recentLogs.isNotEmpty) {
      final ranges = recentLogs
          .toList()
          .reversed
          .map(
            (log) => _AyahRange(
              surahNumber: log['surah_number'] as int,
              startAyah: log['start_ayah'] as int,
              endAyah: log['end_ayah'] as int,
            ),
          )
          .toList();
      return orderRangesForDisplay(mergeAdjacentRanges(ranges));
    }

    if (sabaqStart > 1) {
      return orderRangesForDisplay([
        _AyahRange(surahNumber: sabaqSurah, startAyah: 1, endAyah: sabaqStart - 1),
      ]);
    }

    if (knownSurahs.isNotEmpty) {
      final sabqiSurah = getPrecedingKnownSurah(
        currentSabaqSurah: sabaqSurah,
        knownSurahs: knownSurahs,
        direction: direction,
      );
      final knownInfo = await _db.getSurah(sabqiSurah);
      final endAyah = knownInfo?['verses_count'] as int? ?? 10;
      return orderRangesForDisplay([
        _AyahRange(surahNumber: sabqiSurah, startAyah: 1, endAyah: endAyah),
      ]);
    }

    return orderRangesForDisplay([
      _AyahRange(surahNumber: sabaqSurah, startAyah: 1, endAyah: sabaqEnd),
    ]);
  }

  Future<List<_AyahRange>> _buildManzilRanges({
    required List<_AyahRange> repeatedRanges,
    required List<int> knownSurahs,
    required int sabaqSurah,
    required int sabaqStart,
    required int sabaqEnd,
    required String direction,
    required List<_AyahRange> sabqiRanges,
    required HifzRangeUnit unit,
    required int unitCount,
  }) async {
    if (repeatedRanges.isNotEmpty) return orderRangesForDisplay(repeatedRanges);

    final memorizedRanges = await _buildMemorizedRanges(
      knownSurahs: knownSurahs,
      sabaqSurah: sabaqSurah,
      sabaqStart: sabaqStart,
      direction: direction,
    );

    if (memorizedRanges.isEmpty) {
      return orderRangesForDisplay([
        _AyahRange(surahNumber: sabaqSurah, startAyah: 1, endAyah: sabaqEnd),
      ]);
    }

    final manzilUnits = _buildManzilUnits(
      ranges: memorizedRanges,
      unit: unit,
      direction: direction,
    );
    if (manzilUnits.isEmpty) {
      return orderRangesForDisplay(memorizedRanges);
    }

    // Manzil must never drift into the Sabqi (recent revision) zone. Find the
    // earliest ruku index touched by Sabqi and cap Manzil's pool right before it.
    int? sabqiBoundaryIndex;
    for (final range in sabqiRanges) {
      final index = _findUnitIndex(manzilUnits, range.surahNumber, range.startAyah);
      if (index != null && (sabqiBoundaryIndex == null || index < sabqiBoundaryIndex)) {
        sabqiBoundaryIndex = index;
      }
    }

    final availableUnits = (sabqiBoundaryIndex != null && sabqiBoundaryIndex > 0)
        ? manzilUnits.sublist(0, sabqiBoundaryIndex)
        : manzilUnits;

    if (availableUnits.isEmpty) {
      return orderRangesForDisplay(manzilUnits.expand((unit) => unit));
    }

    final windowLength = min(unitCount, availableUnits.length);
    final maxStartIndex = max(availableUnits.length - windowLength, 0);

    var nextStartIndex = 0;
    final latestManzilLogs = await _db.getLatestLogsForTier('manzil');
    if (latestManzilLogs.isNotEmpty) {
      final startIndexes = <int>[];
      final endIndexes = <int>[];

      for (final log in latestManzilLogs) {
        final surahNumber = log['surah_number'] as int;
        final startAyah = log['start_ayah'] as int;
        final endAyah = log['end_ayah'] as int;
        final startIndex = _findUnitIndex(availableUnits, surahNumber, startAyah);
        final endIndex = _findUnitIndex(availableUnits, surahNumber, endAyah);
        if (startIndex != null && endIndex != null) {
          startIndexes.add(startIndex);
          endIndexes.add(endIndex);
        }
      }

      if (startIndexes.isNotEmpty && endIndexes.isNotEmpty) {
        final previousWindowStart = startIndexes.reduce(min);
        final previousWindowEnd = endIndexes.reduce(max);
        // Once Manzil touches the Sabqi boundary, loop back to the oldest memorized section.
        if (previousWindowEnd >= availableUnits.length - 1) {
          nextStartIndex = 0;
        } else {
          nextStartIndex = min(previousWindowStart + windowLength, maxStartIndex);
        }
      }
    }

    final window = availableUnits
        .sublist(nextStartIndex, nextStartIndex + windowLength)
        .expand((unitRanges) => unitRanges);
    return orderRangesForDisplay(mergeAdjacentRanges(window));
  }

  List<List<_AyahRange>> _buildManzilUnits({
    required List<_AyahRange> ranges,
    required HifzRangeUnit unit,
    required String direction,
  }) {
    if (unit == HifzRangeUnit.ruku) {
      return _rukuSegmentsForMemorizedRanges(ranges)
          .map((range) => [range])
          .toList();
    }

    final starts = unit == HifzRangeUnit.page
        ? QuranUnitMetadata.pageStartOffsets
        : QuranUnitMetadata.juzStartOffsets;
    final lengths = unit == HifzRangeUnit.page
        ? QuranUnitMetadata.pageAyahCounts
        : QuranUnitMetadata.juzAyahCounts;
    final units = <List<_AyahRange>>[];

    for (var unitIndex = 0; unitIndex < starts.length; unitIndex++) {
      final unitStart = starts[unitIndex];
      final unitEnd = unitStart + lengths[unitIndex] - 1;
      final unitRanges = <_AyahRange>[];
      for (final range in ranges) {
        final rangeStart = QuranUnitMetadata.offsetForAyah(
          range.surahNumber,
          range.startAyah,
        );
        final rangeEnd = QuranUnitMetadata.offsetForAyah(
          range.surahNumber,
          range.endAyah,
        );
        final overlapStart = max(unitStart, rangeStart);
        final overlapEnd = min(unitEnd, rangeEnd);
        if (overlapStart <= overlapEnd) {
          unitRanges.addAll(
            _rangesFromGlobalRange(overlapStart, overlapEnd),
          );
        }
      }
      if (unitRanges.isNotEmpty) units.add(unitRanges);
    }

    if (direction == AppConstants.directionLastToFirst) {
      return units.reversed.toList();
    }
    return units;
  }

  int? _findUnitIndex(
    List<List<_AyahRange>> units,
    int surahNumber,
    int ayahNumber,
  ) {
    for (var index = 0; index < units.length; index++) {
      if (units[index].any(
        (range) =>
            range.surahNumber == surahNumber &&
            ayahNumber >= range.startAyah &&
            ayahNumber <= range.endAyah,
      )) {
        return index;
      }
    }
    return null;
  }

  List<_AyahRange> _rangesFromGlobalRange(int startOffset, int endOffset) {
    final segments = QuranUnitMetadata.splitGlobalRange(startOffset, endOffset);
    return [
      for (var index = 0; index < segments.length; index += 3)
        _AyahRange(
          surahNumber: segments[index],
          startAyah: segments[index + 1],
          endAyah: segments[index + 2],
        ),
    ];
  }

  int _endOffsetForRukus(int startOffset, int count) {
    final rukus = QuranRukuMetadata.all.toList()
      ..sort((left, right) {
        final leftOffset = QuranUnitMetadata.offsetForAyah(
          left.surahNumber,
          left.startAyah,
        );
        final rightOffset = QuranUnitMetadata.offsetForAyah(
          right.surahNumber,
          right.startAyah,
        );
        return leftOffset.compareTo(rightOffset);
      });
    final startIndex = rukus.indexWhere((ruku) {
      final first = QuranUnitMetadata.offsetForAyah(ruku.surahNumber, ruku.startAyah);
      final last = QuranUnitMetadata.offsetForAyah(ruku.surahNumber, ruku.endAyah);
      return startOffset >= first && startOffset <= last;
    });
    if (startIndex < 0) return startOffset;
    final endIndex = min(startIndex + count - 1, rukus.length - 1);
    final ruku = rukus[endIndex];
    return QuranUnitMetadata.offsetForAyah(ruku.surahNumber, ruku.endAyah);
  }

  Future<List<HifzTask>> _buildTierTasks({
    required HifzTierType tierType,
    required List<_AyahRange> ranges,
    required String date,
    required String title,
    required String notes,
    required int targetReps,
    required int stepNumber,
    required int totalMinutes,
  }) async {
    final minuteSplits = splitMinutesAcrossRanges(totalMinutes, ranges);
    final tasks = <HifzTask>[];

    for (var index = 0; index < ranges.length; index++) {
      final range = ranges[index];
      final surahInfo = await _db.getSurah(range.surahNumber);
      final partSuffix = ranges.length > 1 ? ' - Part ${index + 1}' : '';

      tasks.add(HifzTask(
        tierType: tierType,
        stepNumber: stepNumber,
        allocatedMinutes: minuteSplits[index],
        title: '$title$partSuffix',
        surahNumber: range.surahNumber,
        surahNameArabic: surahInfo?['name_arabic'] as String? ?? 'سورة',
        surahNameEnglish: surahInfo?['name_english'] as String? ?? 'Surah ${range.surahNumber}',
        startAyah: range.startAyah,
        endAyah: range.endAyah,
        targetDate: date,
        targetReps: targetReps,
        notes: notes,
      ));
    }

    return tasks;
  }

  /// Save personalized Hifz Profile and regenerate today's schedule
  Future<void> saveHifzProfile({
    required List<int> knownSurahs,
    required int currentSabaqSurah,
    required int currentSabaqAyah,
    String direction = AppConstants.directionLastToFirst,
    int dailyTimeCommitment = 60,
    int dailySabaqTarget = 5,
  }) async {
    await getTierLengthSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyProfileConfigured, true);
    await prefs.setString(AppConstants.keyKnownSurahs, knownSurahs.join(','));
    await prefs.setInt(AppConstants.keyCurrentSabaqSurah, currentSabaqSurah);
    await prefs.setInt(AppConstants.keyCurrentSabaqAyah, currentSabaqAyah);
    await prefs.setString(AppConstants.keyHifzDirection, direction);
    await prefs.setInt(AppConstants.keyDailyTimeCommitment, dailyTimeCommitment);
    await prefs.setInt(AppConstants.keyDailySabaqTarget, dailySabaqTarget);

    // A strategy change resets today's tasks and activity, but keeps history.
    final db = await _db.database;
    await db.delete('three_tier_tasks', where: 'target_date = ?', whereArgs: [todayIso]);
    await db.delete(
      'daily_hifz_activity',
      where: 'activity_date = ?',
      whereArgs: [todayIso],
    );
  }

  /// Returns today's tasks ordered as:
  /// Step 1: Manzil (50% time)
  /// Step 2: Sabqi (30% time)
  /// Step 3: Sabaq (20% time)
  Future<List<HifzTask>> getOrGenerateTodayTasks() async {
    final date = todayIso;
    final totalMinutes = await getDailyTimeCommitment();
    final timeSplits = calculateTimeSplit(totalMinutes);

    final existingRows = await _db.getTasksForDate(date);

    if (existingRows.isNotEmpty) {
      final tasks = <HifzTask>[];
      for (final row in existingRows) {
        final surah = await _db.getSurah(row['surah_number'] as int);
        final tier = HifzTierType.values.byName(row['tier_type'] as String);
        final step = tier == HifzTierType.manzil ? 1 : (tier == HifzTierType.sabqi ? 2 : 3);
        final minutes = timeSplits[tier];

        tasks.add(HifzTask.fromMap(
          row,
          surahArabic: surah?['name_arabic'] as String? ?? '',
          surahEnglish: surah?['name_english'] as String? ?? '',
          stepNumber: step,
          allocatedMinutes: minutes,
        ));
      }
      // Guarantee order: Step 1 (Manzil), Step 2 (Sabqi), Step 3 (Sabaq)
      tasks.sort((a, b) => (a.stepNumber ?? 0).compareTo(b.stepNumber ?? 0));
      return tasks;
    }

    // Otherwise, generate tasks for today
    return await _generateDailyTasks(date);
  }

  Future<List<HifzTask>> _generateDailyTasks(
    String date, {
    Set<HifzTierType>? tiersToCreate,
    HifzTask? startingSabaq,
    List<HifzTask> preservedCompletedTasks = const [],
  }) async {
    final tierSettings = await getTierLengthSettings();
    final recentLogs = await _db.getRecentSabaqLogs(
      tierSettings.sabqiDays,
      beforeDate: date,
    );
    final repeatedSabaq = tiersToCreate?.contains(HifzTierType.sabaq) == true
      ? <_AyahRange>[]
      : await _getIncompleteActivityRanges(HifzTierType.sabaq);
    final repeatedSabqi = tiersToCreate?.contains(HifzTierType.sabqi) == true
      ? <_AyahRange>[]
      : await _getIncompleteActivityRanges(HifzTierType.sabqi);
    final repeatedManzil = tiersToCreate?.contains(HifzTierType.manzil) == true
      ? <_AyahRange>[]
      : await _getIncompleteActivityRanges(HifzTierType.manzil);
    final knownSurahs = await getKnownSurahs();
    final profileSabaqSurah = await getCurrentSabaqSurah();
    final profileSabaqAyah = await getCurrentSabaqAyah();
    final direction = await getHifzDirection();
    final dailyTarget = tierSettings.sabaqCount;
    final totalMinutes = await getDailyTimeCommitment();
    final timeSplits = calculateTimeSplit(totalMinutes);
    
    // 1. Determine Sabaq (New Lesson)
    int sabaqSurah = profileSabaqSurah;
    int sabaqStart = profileSabaqAyah;
    int sabaqEnd;
    const int targetReps = 15;

    if (repeatedSabaq.isNotEmpty) {
      sabaqSurah = repeatedSabaq.first.surahNumber;
      sabaqStart = repeatedSabaq.first.startAyah;
      sabaqEnd = repeatedSabaq.first.endAyah;
    } else if (recentLogs.isNotEmpty) {
      final last = recentLogs.first;
      final lastSurah = last['surah_number'] as int;
      final lastEnd = last['end_ayah'] as int;

      final surahData = await _db.getSurah(lastSurah);
      final totalAyahs = surahData?['verses_count'] as int? ?? 30;

      if (lastEnd < totalAyahs) {
        sabaqSurah = lastSurah;
        sabaqStart = lastEnd + 1;
        sabaqEnd = _extendSabaqEndNearSurahBoundary(
          (sabaqStart + dailyTarget - 1).clamp(sabaqStart, totalAyahs),
          totalAyahs,
        );
      } else {
        sabaqSurah = getNextSurahInDirection(lastSurah, direction);
        sabaqStart = 1;
        final nextSurahData = await _db.getSurah(sabaqSurah);
        final nextTotal = nextSurahData?['verses_count'] as int? ?? 30;
        sabaqEnd = _extendSabaqEndNearSurahBoundary(
          (sabaqStart + dailyTarget - 1).clamp(sabaqStart, nextTotal),
          nextTotal,
        );
      }
    } else {
      final surahData = await _db.getSurah(sabaqSurah);
      final totalAyahs = surahData?['verses_count'] as int? ?? 30;
      sabaqEnd = _extendSabaqEndNearSurahBoundary(
        (sabaqStart + dailyTarget - 1).clamp(sabaqStart, totalAyahs),
        totalAyahs,
      );
    }

    if (startingSabaq != null) {
      sabaqSurah = startingSabaq.surahNumber;
      sabaqStart = startingSabaq.startAyah;
    }

    final sabaqRanges = <_AyahRange>[];
    if (repeatedSabaq.isNotEmpty && startingSabaq == null) {
      sabaqRanges.addAll(repeatedSabaq);
    } else {
      final startOffset = QuranUnitMetadata.offsetForAyah(sabaqSurah, sabaqStart);
      final surahInfo = await _db.getSurah(sabaqSurah);
      final totalAyahs = surahInfo?['verses_count'] as int? ?? sabaqStart;
      final endOffset = switch (tierSettings.sabaqUnit) {
        HifzRangeUnit.ayah => min(
          startOffset + tierSettings.sabaqCount - 1,
          QuranUnitMetadata.offsetForAyah(sabaqSurah, totalAyahs),
        ),
        HifzRangeUnit.ruku => _endOffsetForRukus(
          startOffset,
          tierSettings.sabaqCount,
        ),
        HifzRangeUnit.page || HifzRangeUnit.juz =>
          QuranUnitMetadata.endOffsetForUnits(
            unit: tierSettings.sabaqUnit,
            startOffset: startOffset,
            count: tierSettings.sabaqCount,
          ),
      };
      sabaqRanges.addAll(_rangesFromGlobalRange(startOffset, endOffset));
    }
    if (sabaqRanges.isNotEmpty) {
      sabaqSurah = sabaqRanges.first.surahNumber;
      sabaqStart = sabaqRanges.first.startAyah;
      sabaqEnd = sabaqRanges.first.endAyah;
    }
    final completedSabaqRanges = _excludeCompletedRanges(
      sabaqRanges,
      preservedCompletedTasks
          .where((task) => task.tierType == HifzTierType.sabaq)
          .toList(),
    );

    final sabaqTasks = await _buildTierTasks(
      tierType: HifzTierType.sabaq,
      ranges: completedSabaqRanges,
      date: date,
      title: 'Step 3: Sabaq (New Lesson)',
      notes: 'New memorization. Listen 3x, recite with text 10x, blind recall 5x.',
      targetReps: targetReps,
      stepNumber: 3,
      totalMinutes: timeSplits[HifzTierType.sabaq] ?? 0,
    );

    final sabqiRanges = await _buildSabqiRanges(
      recentLogs: recentLogs,
      repeatedRanges: repeatedSabqi,
      knownSurahs: knownSurahs,
      sabaqSurah: sabaqSurah,
      sabaqStart: sabaqStart,
      sabaqEnd: sabaqEnd,
      direction: direction,
    );
    final completedSabqiRanges = _excludeCompletedRanges(
      sabqiRanges,
      preservedCompletedTasks
          .where((task) => task.tierType == HifzTierType.sabqi)
          .toList(),
    );
    final sabqiTasks = await _buildTierTasks(
      tierType: HifzTierType.sabqi,
      ranges: completedSabqiRanges,
      date: date,
      title: 'Step 2: Sabqi (Recent Revision)',
      notes: 'Review the previous ${tierSettings.sabqiDays} days of sabaq before taking new memorization.',
      targetReps: 5,
      stepNumber: 2,
      totalMinutes: timeSplits[HifzTierType.sabqi] ?? 0,
    );

    final manzilRanges = await _buildManzilRanges(
      repeatedRanges: repeatedManzil,
      knownSurahs: knownSurahs,
      sabaqSurah: sabaqSurah,
      sabaqStart: sabaqStart,
      sabaqEnd: sabaqEnd,
      direction: direction,
      sabqiRanges: sabqiRanges,
      unit: tierSettings.manzilUnit,
      unitCount: tierSettings.manzilCount,
    );
    final completedManzilRanges = _excludeCompletedRanges(
      manzilRanges,
      preservedCompletedTasks
          .where((task) => task.tierType == HifzTierType.manzil)
          .toList(),
    );
    final manzilTasks = await _buildTierTasks(
      tierType: HifzTierType.manzil,
      ranges: completedManzilRanges,
      date: date,
      title: 'Step 1: Manzil (Distant Revision)',
      notes: 'Review ${tierSettings.manzilCount} ${tierSettings.manzilUnit.name} units of previously memorized Quran.',
      targetReps: 2,
      stepNumber: 1,
      totalMinutes: timeSplits[HifzTierType.manzil] ?? 0,
    );

    final generatedTasks = <HifzTask>[
      ...manzilTasks,
      ...sabqiTasks,
      ...sabaqTasks,
    ];
    final savedTasks = <HifzTask>[];
    final tasksToSave = tiersToCreate == null
      ? generatedTasks
      : generatedTasks.where((task) => tiersToCreate.contains(task.tierType));
    for (final task in tasksToSave) {
      final id = await _db.insertTask(task.toMap());
      await _db.saveDailyActivity(
        date: date,
        tierType: task.tierType.name,
        surahNumber: task.surahNumber,
        startAyah: task.startAyah,
        endAyah: task.endAyah,
      );
      savedTasks.add(task.copyWith(id: id));
    }

    return savedTasks;
  }

  List<_AyahRange> _excludeCompletedRanges(
    List<_AyahRange> ranges,
    List<HifzTask> completedTasks,
  ) {
    var remainingRanges = ranges;
    for (final completed in completedTasks) {
      final nextRanges = <_AyahRange>[];
      for (final range in remainingRanges) {
        if (range.surahNumber != completed.surahNumber ||
            completed.endAyah < range.startAyah ||
            completed.startAyah > range.endAyah) {
          nextRanges.add(range);
          continue;
        }
        if (completed.startAyah > range.startAyah) {
          nextRanges.add(_AyahRange(
            surahNumber: range.surahNumber,
            startAyah: range.startAyah,
            endAyah: completed.startAyah - 1,
          ));
        }
        if (completed.endAyah < range.endAyah) {
          nextRanges.add(_AyahRange(
            surahNumber: range.surahNumber,
            startAyah: completed.endAyah + 1,
            endAyah: range.endAyah,
          ));
        }
      }
      remainingRanges = nextRanges;
    }
    return remainingRanges;
  }

  Future<List<_AyahRange>> _getIncompleteActivityRanges(HifzTierType tier) async {
    final rows = await _db.getLatestActivityForTier(tier.name);
    if (rows.isEmpty || rows.any((row) => row['status'] != 'completed')) {
      return rows
          .map(
            (row) => _AyahRange(
              surahNumber: row['surah_number'] as int,
              startAyah: row['start_ayah'] as int,
              endAyah: row['end_ayah'] as int,
            ),
          )
          .toList();
    }
    return const [];
  }

  /// Checks if the user is allowed to complete Sabaq today.
  /// If strictMode is true, BOTH Manzil and Sabqi MUST be completed first!
  String? validateSabaqCompletion(List<HifzTask> tasks, bool strictMode) {
    if (!strictMode) return null;

    final manzilTasks = tasks.where((t) => t.tierType == HifzTierType.manzil).toList();
    if (manzilTasks.any((task) => !task.isCompleted)) {
      return 'Traditional Madrasah Rule: You must complete Step 1: Manzil (Distant Revision) before finishing new Sabaq!';
    }

    final sabqiTasks = tasks.where((t) => t.tierType == HifzTierType.sabqi).toList();
    if (sabqiTasks.any((task) => !task.isCompleted)) {
      return 'Traditional Madrasah Rule: You must complete Step 2: Sabqi (Recent Revision) before finishing new Sabaq!';
    }

    return null;
  }
}
