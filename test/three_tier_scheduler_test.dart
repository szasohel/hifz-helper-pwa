import 'package:flutter_test/flutter_test.dart';
import 'package:hifz_helper/app/constants.dart';
import 'package:hifz_helper/core/database/app_database.dart';
import 'package:hifz_helper/core/data/quran_unit_metadata.dart';
import 'package:hifz_helper/features/hifz_engine/models/hifz_tier_model.dart';
import 'package:hifz_helper/features/hifz_engine/services/three_tier_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    final db = await AppDatabase.instance.database;
    await db.delete('three_tier_tasks');
    await db.delete('daily_hifz_activity');
    await db.delete('hifz_logs');
    await db.delete('ayah_fluency');
    await db.delete('ayah_words');
    await db.delete('ayahs');
    await db.delete('surahs');
  });

  group('ThreeTierScheduler Strict Enforcement Tests', () {
    final scheduler = ThreeTierScheduler();

    test('Strict mode blocks Sabaq completion if Step 1: Manzil is incomplete', () {
      final tasks = [
        HifzTask(
          id: 1,
          tierType: HifzTierType.manzil,
          title: 'Step 1: Manzil',
          surahNumber: 1,
          surahNameArabic: 'الفاتحة',
          surahNameEnglish: 'Al-Fatihah',
          startAyah: 1,
          endAyah: 7,
          targetDate: '2026-09-06',
          isCompleted: false, // Incomplete!
        ),
        HifzTask(
          id: 2,
          tierType: HifzTierType.sabqi,
          title: 'Step 2: Sabqi',
          surahNumber: 67,
          surahNameArabic: 'الملك',
          surahNameEnglish: 'Al-Mulk',
          startAyah: 1,
          endAyah: 10,
          targetDate: '2026-09-06',
          isCompleted: true,
        ),
        HifzTask(
          id: 3,
          tierType: HifzTierType.sabaq,
          title: 'Step 3: Sabaq',
          surahNumber: 67,
          surahNameArabic: 'الملك',
          surahNameEnglish: 'Al-Mulk',
          startAyah: 11,
          endAyah: 20,
          targetDate: '2026-09-06',
          isCompleted: false,
        ),
      ];

      final error = scheduler.validateSabaqCompletion(tasks, true);
      expect(error, isNotNull);
      expect(error, contains('Step 1: Manzil'));
    });

    test('Strict mode blocks Sabaq completion if Step 2: Sabqi is incomplete', () {
      final tasks = [
        HifzTask(
          id: 1,
          tierType: HifzTierType.manzil,
          title: 'Step 1: Manzil',
          surahNumber: 1,
          surahNameArabic: 'الفاتحة',
          surahNameEnglish: 'Al-Fatihah',
          startAyah: 1,
          endAyah: 7,
          targetDate: '2026-09-06',
          isCompleted: true, // Manzil is done
        ),
        HifzTask(
          id: 2,
          tierType: HifzTierType.sabqi,
          title: 'Step 2: Sabqi',
          surahNumber: 67,
          surahNameArabic: 'الملك',
          surahNameEnglish: 'Al-Mulk',
          startAyah: 1,
          endAyah: 10,
          targetDate: '2026-09-06',
          isCompleted: false, // Sabqi NOT done!
        ),
        HifzTask(
          id: 3,
          tierType: HifzTierType.sabaq,
          title: 'Step 3: Sabaq',
          surahNumber: 67,
          surahNameArabic: 'الملك',
          surahNameEnglish: 'Al-Mulk',
          startAyah: 11,
          endAyah: 20,
          targetDate: '2026-09-06',
          isCompleted: false,
        ),
      ];

      final error = scheduler.validateSabaqCompletion(tasks, true);
      expect(error, isNotNull);
      expect(error, contains('Step 2: Sabqi'));
    });

    test('Strict mode permits Sabaq completion once BOTH Manzil and Sabqi are completed', () {
      final tasks = [
        HifzTask(
          id: 1,
          tierType: HifzTierType.manzil,
          title: 'Step 1: Manzil',
          surahNumber: 1,
          surahNameArabic: 'الفاتحة',
          surahNameEnglish: 'Al-Fatihah',
          startAyah: 1,
          endAyah: 7,
          targetDate: '2026-09-06',
          isCompleted: true, // Completed!
        ),
        HifzTask(
          id: 2,
          tierType: HifzTierType.sabqi,
          title: 'Step 2: Sabqi',
          surahNumber: 67,
          surahNameArabic: 'الملك',
          surahNameEnglish: 'Al-Mulk',
          startAyah: 1,
          endAyah: 10,
          targetDate: '2026-09-06',
          isCompleted: true, // Completed!
        ),
        HifzTask(
          id: 3,
          tierType: HifzTierType.sabaq,
          title: 'Step 3: Sabaq',
          surahNumber: 67,
          surahNameArabic: 'الملك',
          surahNameEnglish: 'Al-Mulk',
          startAyah: 11,
          endAyah: 20,
          targetDate: '2026-09-06',
          isCompleted: false,
        ),
      ];

      final error = scheduler.validateSabaqCompletion(tasks, true);
      expect(error, isNull);
    });

    test('Flexible mode (strictMode = false) never blocks Sabaq completion', () {
      final tasks = [
        HifzTask(
          id: 1,
          tierType: HifzTierType.manzil,
          title: 'Step 1: Manzil',
          surahNumber: 1,
          surahNameArabic: 'الفاتحة',
          surahNameEnglish: 'Al-Fatihah',
          startAyah: 1,
          endAyah: 7,
          targetDate: '2026-09-06',
          isCompleted: false,
        ),
        HifzTask(
          id: 2,
          tierType: HifzTierType.sabqi,
          title: 'Step 2: Sabqi',
          surahNumber: 67,
          surahNameArabic: 'الملك',
          surahNameEnglish: 'Al-Mulk',
          startAyah: 1,
          endAyah: 10,
          targetDate: '2026-09-06',
          isCompleted: false,
        ),
      ];

      final error = scheduler.validateSabaqCompletion(tasks, false);
      expect(error, isNull);
    });
  });

  group('Time Allocation Split Tests (50% Manzil, 30% Sabqi, 20% Sabaq)', () {
    test('60 minutes standard session', () {
      final splits = ThreeTierScheduler.calculateTimeSplit(60);
      expect(splits[HifzTierType.manzil], equals(30)); // 50%
      expect(splits[HifzTierType.sabqi], equals(18));  // 30%
      expect(splits[HifzTierType.sabaq], equals(12));  // 20%
      expect(splits.values.reduce((a, b) => a + b), equals(60));
    });

    test('30 minutes short session', () {
      final splits = ThreeTierScheduler.calculateTimeSplit(30);
      expect(splits[HifzTierType.manzil], equals(15)); // 50%
      expect(splits[HifzTierType.sabqi], equals(9));   // 30%
      expect(splits[HifzTierType.sabaq], equals(6));   // 20%
      expect(splits.values.reduce((a, b) => a + b), equals(30));
    });

    test('45 minutes session', () {
      final splits = ThreeTierScheduler.calculateTimeSplit(45);
      expect(splits[HifzTierType.manzil], equals(23));
      expect(splits[HifzTierType.sabqi], equals(14));
      expect(splits[HifzTierType.sabaq], equals(8));
      expect(splits.values.reduce((a, b) => a + b), equals(45));
    });
  });

  group('Directional Progression Tests', () {
    test('Last to First (Juz 30 -> Baqarah) sequence', () {
      // 1 (Al-Fatihah) -> 114 (An-Nas)
      expect(ThreeTierScheduler.getNextSurahInDirection(1, AppConstants.directionLastToFirst), equals(114));
      // 114 -> 113 (Al-Falaq)
      expect(ThreeTierScheduler.getNextSurahInDirection(114, AppConstants.directionLastToFirst), equals(113));
      // 80 ('Abasa) -> 79 (An-Nazi'at)
      expect(ThreeTierScheduler.getNextSurahInDirection(80, AppConstants.directionLastToFirst), equals(79));
      // 3 (Ali 'Imran) -> 2 (Al-Baqarah)
      expect(ThreeTierScheduler.getNextSurahInDirection(3, AppConstants.directionLastToFirst), equals(2));
    });

    test('First to Last (Fatiha -> Baqarah -> Nas) sequence', () {
      // 1 -> 2
      expect(ThreeTierScheduler.getNextSurahInDirection(1, AppConstants.directionFirstToLast), equals(2));
      // 2 -> 3
      expect(ThreeTierScheduler.getNextSurahInDirection(2, AppConstants.directionFirstToLast), equals(3));
      // 113 -> 114
      expect(ThreeTierScheduler.getNextSurahInDirection(113, AppConstants.directionFirstToLast), equals(114));
    });
  });

  group('Hifz Profile & Custom Known Surahs Tests', () {
    final scheduler = ThreeTierScheduler();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves and loads user-selected known Surahs, direction, and targets', () async {
      final known = [1, 112, 113, 114];
      await scheduler.saveHifzProfile(
        knownSurahs: known,
        currentSabaqSurah: 80,
        currentSabaqAyah: 11,
        direction: AppConstants.directionLastToFirst,
        dailyTimeCommitment: 90,
        dailySabaqTarget: 7,
      );

      final loadedKnown = await scheduler.getKnownSurahs();
      final loadedSurah = await scheduler.getCurrentSabaqSurah();
      final loadedAyah = await scheduler.getCurrentSabaqAyah();
      final loadedDirection = await scheduler.getHifzDirection();
      final loadedTime = await scheduler.getDailyTimeCommitment();
      final loadedTarget = await scheduler.getDailySabaqTarget();

      expect(loadedKnown, equals([1, 112, 113, 114]));
      expect(loadedSurah, equals(80));
      expect(loadedAyah, equals(11));
      expect(loadedDirection, equals(AppConstants.directionLastToFirst));
      expect(loadedTime, equals(90));
      expect(loadedTarget, equals(7));
    });
  });

  group('Independent Tier Length Settings Tests', () {
    final scheduler = ThreeTierScheduler();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('uses current tier defaults without changing the Hifz profile', () async {
      final settings = await scheduler.getTierLengthSettings();

      expect(settings.sabaqUnit, HifzRangeUnit.ayah);
      expect(settings.sabaqCount, 5);
      expect(settings.sabqiDays, 5);
      expect(settings.manzilUnit, HifzRangeUnit.ruku);
      expect(settings.manzilCount, 4);
      expect(await scheduler.isProfileConfigured(), isFalse);
    });

    test('round-trips independent range units and counts', () async {
      const settings = HifzTierLengthSettings(
        sabaqUnit: HifzRangeUnit.page,
        sabaqCount: 3,
        sabqiDays: 10,
        manzilUnit: HifzRangeUnit.juz,
        manzilCount: 2,
      );

      await scheduler.saveTierLengthSettings(settings);

      final loaded = await scheduler.getTierLengthSettings();
      expect(loaded.sabaqUnit, settings.sabaqUnit);
      expect(loaded.sabaqCount, settings.sabaqCount);
      expect(loaded.sabqiDays, settings.sabqiDays);
      expect(loaded.manzilUnit, settings.manzilUnit);
      expect(loaded.manzilCount, settings.manzilCount);
      expect(await scheduler.isProfileConfigured(), isFalse);
    });

    test('rejects invalid tier settings', () async {
      const settings = HifzTierLengthSettings(sabqiDays: 6);

      await expectLater(
        scheduler.saveTierLengthSettings(settings),
        throwsArgumentError,
      );
    });
  });

  group('Quran Page and Juz Metadata Tests', () {
    test('covers all 604 pages and 30 juz across 6,236 ayahs', () {
      expect(QuranUnitMetadata.pageAyahCounts, hasLength(604));
      expect(QuranUnitMetadata.juzAyahCounts, hasLength(30));
      expect(QuranUnitMetadata.pageAyahCounts.reduce((a, b) => a + b), 6236);
      expect(QuranUnitMetadata.juzAyahCounts.reduce((a, b) => a + b), 6236);
    });

    test('counts the unit containing the selected start ayah', () {
      expect(
        QuranUnitMetadata.endOffsetForUnits(
          unit: HifzRangeUnit.page,
          startOffset: 0,
          count: 1,
        ),
        6,
      );
      expect(
        QuranUnitMetadata.endOffsetForUnits(
          unit: HifzRangeUnit.juz,
          startOffset: 148,
          count: 1,
        ),
        258,
      );
    });
  });

  group('Directional Sabqi & Sequential Manzil Rotation Tests', () {
    test('Sabqi correctly selects preceding Surah At-Tariq (86) when Sabaq is Al-Buruj (85)', () {
      // User memorized 1 (Al-Fatihah), and 114 down to 86 (At-Tariq)
      final known = [1, ...List.generate(29, (i) => 86 + i)]; // 1, 86..114
      
      final preceding = ThreeTierScheduler.getPrecedingKnownSurah(
        currentSabaqSurah: 85, // Al-Buruj
        knownSurahs: known,
        direction: AppConstants.directionLastToFirst,
      );

      // Sabqi must be 86 (At-Tariq), NOT 114 (An-Nas)!
      expect(preceding, equals(86));
    });

    test('Sabqi selects Al-Fatihah (1) when current Sabaq is An-Nas (114) in lastToFirst', () {
      final preceding = ThreeTierScheduler.getPrecedingKnownSurah(
        currentSabaqSurah: 114,
        knownSurahs: [1],
        direction: AppConstants.directionLastToFirst,
      );

      expect(preceding, equals(1));
    });

    test('Sabqi selects preceding Surah in firstToLast mode', () {
      final preceding = ThreeTierScheduler.getPrecedingKnownSurah(
        currentSabaqSurah: 5,
        knownSurahs: [1, 2, 3, 4],
        direction: AppConstants.directionFirstToLast,
      );

      expect(preceding, equals(4));
    });

    test('Manzil starts at oldest mastered Surah An-Nas (114) and excludes Sabqi At-Tariq (86)', () {
      final known = [1, ...List.generate(29, (i) => 86 + i)]; // 1, 86..114

      final manzilSurah = ThreeTierScheduler.determineManzilSurah(
        knownSurahs: known,
        sabaqSurah: 85, // Al-Buruj
        sabqiSurah: 86, // At-Tariq
        direction: AppConstants.directionLastToFirst,
        lastLoggedManzilSurah: null, // Fresh setup
      );

      // Starts from the beginning of mastered Juz 30: An-Nas (114)
      expect(manzilSurah, equals(114));
    });

    test('Manzil rotates sequentially to next mastered Surah', () {
      final known = [1, ...List.generate(29, (i) => 86 + i)]; // 1, 86..114

      final nextManzil = ThreeTierScheduler.determineManzilSurah(
        knownSurahs: known,
        sabaqSurah: 85,
        sabqiSurah: 86,
        direction: AppConstants.directionLastToFirst,
        lastLoggedManzilSurah: 114, // Previous was An-Nas
      );

      // Rotates sequentially to Al-Falaq (113)!
      expect(nextManzil, equals(113));
    });
  });

  group('Windowed Revision Generation Tests', () {
    final scheduler = ThreeTierScheduler(db: AppDatabase.instance);

    Future<void> seedSurahs(List<(int, String, String, int)> surahs) async {
      final db = await AppDatabase.instance.database;
      for (final surah in surahs) {
        await db.insert('surahs', {
          'number': surah.$1,
          'name_arabic': surah.$2,
          'name_english': surah.$3,
          'verses_count': surah.$4,
          'revelation_place': 'Makkah',
        });
      }
    }

    Future<void> clearTodayTasks() async {
      final db = await AppDatabase.instance.database;
      await db.delete('three_tier_tasks');
    }

    String dateDaysAgo(int days) => DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);

    test('Sabqi uses the previous 5 days of sabaq ayahs', () async {
      await seedSurahs([
        (80, 'عبس', 'Abasa', 40),
      ]);

      final db = await AppDatabase.instance.database;
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(5),
        'tier_type': 'sabaq',
        'surah_number': 80,
        'start_ayah': 1,
        'end_ayah': 5,
        'reps': 15,
      });
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(4),
        'tier_type': 'sabaq',
        'surah_number': 80,
        'start_ayah': 6,
        'end_ayah': 10,
        'reps': 15,
      });
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(3),
        'tier_type': 'sabaq',
        'surah_number': 80,
        'start_ayah': 11,
        'end_ayah': 15,
        'reps': 15,
      });
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(2),
        'tier_type': 'sabaq',
        'surah_number': 80,
        'start_ayah': 16,
        'end_ayah': 20,
        'reps': 15,
      });
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(1),
        'tier_type': 'sabaq',
        'surah_number': 80,
        'start_ayah': 21,
        'end_ayah': 25,
        'reps': 15,
      });

      await scheduler.saveHifzProfile(
        knownSurahs: const [],
        currentSabaqSurah: 80,
        currentSabaqAyah: 1,
        direction: AppConstants.directionFirstToLast,
        dailyTimeCommitment: 60,
        dailySabaqTarget: 5,
      );

      final tasks = await scheduler.getOrGenerateTodayTasks();
      final sabqiTasks = tasks.where((task) => task.tierType == HifzTierType.sabqi).toList();
      final sabaqTask = tasks.firstWhere((task) => task.tierType == HifzTierType.sabaq);

      expect(sabaqTask.startAyah, equals(26));
      expect(sabaqTask.endAyah, equals(30));
      expect(sabqiTasks, hasLength(1));
      expect(sabqiTasks.first.surahNumber, equals(80));
      expect(sabqiTasks.first.startAyah, equals(1));
      expect(sabqiTasks.first.endAyah, equals(25));
    });

    test('Sabaq can use a page count from the current starting ayah', () async {
      await seedSurahs([
        (1, 'الفاتحة', 'Al-Fatihah', 7),
        (2, 'البقرة', 'Al-Baqarah', 286),
      ]);
      await scheduler.saveHifzProfile(
        knownSurahs: const [],
        currentSabaqSurah: 2,
        currentSabaqAyah: 1,
        direction: AppConstants.directionFirstToLast,
      );
      await scheduler.saveTierLengthSettings(
        const HifzTierLengthSettings(
          sabaqUnit: HifzRangeUnit.page,
          sabaqCount: 2,
        ),
      );

      final tasks = await scheduler.getOrGenerateTodayTasks();
      final sabaqTasks = tasks
          .where((task) => task.tierType == HifzTierType.sabaq)
          .toList();

      expect(sabaqTasks, hasLength(1));
      expect(sabaqTasks.single.surahNumber, 2);
      expect(sabaqTasks.single.startAyah, 1);
      expect(sabaqTasks.single.endAyah, 16);
    });

    test('Sabaq can use consecutive ruku boundaries', () async {
      await seedSurahs([
        (1, 'الفاتحة', 'Al-Fatihah', 7),
        (2, 'البقرة', 'Al-Baqarah', 286),
      ]);
      await scheduler.saveHifzProfile(
        knownSurahs: const [],
        currentSabaqSurah: 2,
        currentSabaqAyah: 30,
        direction: AppConstants.directionFirstToLast,
      );
      await scheduler.saveTierLengthSettings(
        const HifzTierLengthSettings(
          sabaqUnit: HifzRangeUnit.ruku,
          sabaqCount: 2,
        ),
      );

      final tasks = await scheduler.getOrGenerateTodayTasks();
      final sabaqTasks = tasks
          .where((task) => task.tierType == HifzTierType.sabaq)
          .toList();

      expect(sabaqTasks, hasLength(1));
      expect(sabaqTasks.single.surahNumber, 2);
      expect(sabaqTasks.single.startAyah, 30);
      expect(sabaqTasks.single.endAyah, 46);
    });

    test('changing Sabaq length preserves completed other tiers and resets active reps', () async {
      await seedSurahs([
        (1, 'الفاتحة', 'Al-Fatihah', 7),
        (2, 'البقرة', 'Al-Baqarah', 286),
      ]);
      await scheduler.saveHifzProfile(
        knownSurahs: const [1],
        currentSabaqSurah: 2,
        currentSabaqAyah: 1,
        direction: AppConstants.directionFirstToLast,
      );

      final before = await scheduler.getOrGenerateTodayTasks();
      final sabqi = before.singleWhere((task) => task.tierType == HifzTierType.sabqi);
      final manzil = before.singleWhere((task) => task.tierType == HifzTierType.manzil);
      final sabaq = before.singleWhere((task) => task.tierType == HifzTierType.sabaq);
      final db = await AppDatabase.instance.database;

      for (final task in [sabqi, manzil]) {
        await AppDatabase.instance.updateTaskProgress(
          task.id!,
          task.targetReps,
          true,
        );
        await AppDatabase.instance.markDailyActivityComplete(
          date: task.targetDate,
          tierType: task.tierType.name,
          surahNumber: task.surahNumber,
          startAyah: task.startAyah,
          endAyah: task.endAyah,
        );
      }
      await AppDatabase.instance.updateTaskProgress(sabaq.id!, 3, false);

      final after = await scheduler.applyTierLengthSettings(
        settings: const HifzTierLengthSettings(sabaqCount: 7),
        affectedTiers: {HifzTierType.sabaq},
      );
      final updatedSabqi = after.singleWhere((task) => task.tierType == HifzTierType.sabqi);
      final updatedManzil = after.singleWhere((task) => task.tierType == HifzTierType.manzil);
      final updatedSabaq = after.singleWhere((task) => task.tierType == HifzTierType.sabaq);

      expect(updatedSabqi.id, sabqi.id);
      expect(updatedSabqi.isCompleted, isTrue);
      expect(updatedManzil.id, manzil.id);
      expect(updatedManzil.isCompleted, isTrue);
      expect(updatedSabaq.id, isNot(sabaq.id));
      expect(updatedSabaq.startAyah, 1);
      expect(updatedSabaq.endAyah, 7);
      expect(updatedSabaq.completedReps, 0);
      expect(await db.query('hifz_logs'), isEmpty);
    });

    test('Manzil can select one page or one juz', () async {
      await seedSurahs([
        (1, 'الفاتحة', 'Al-Fatihah', 7),
        (2, 'البقرة', 'Al-Baqarah', 286),
        (3, 'آل عمران', 'Ali Imran', 200),
      ]);
      await scheduler.saveHifzProfile(
        knownSurahs: const [1, 2],
        currentSabaqSurah: 3,
        currentSabaqAyah: 1,
        direction: AppConstants.directionFirstToLast,
      );

      await scheduler.saveTierLengthSettings(
        const HifzTierLengthSettings(
          manzilUnit: HifzRangeUnit.page,
          manzilCount: 1,
        ),
      );
      final pageTasks = await scheduler.getOrGenerateTodayTasks();
      final pageManzil = pageTasks
          .where((task) => task.tierType == HifzTierType.manzil)
          .toList();
      expect(pageManzil, hasLength(1));
      expect(pageManzil.single.surahNumber, 1);
      expect(pageManzil.single.startAyah, 1);
      expect(pageManzil.single.endAyah, 7);

      final juzTasks = await scheduler.applyTierLengthSettings(
        settings: const HifzTierLengthSettings(
          manzilUnit: HifzRangeUnit.juz,
          manzilCount: 1,
        ),
        affectedTiers: {HifzTierType.manzil},
      );
      final juzManzil = juzTasks
          .where((task) => task.tierType == HifzTierType.manzil)
          .toList();
      expect(juzManzil.map((task) => task.surahNumber).toList(), [1, 2]);
      expect(juzManzil.first.startAyah, 1);
      expect(juzManzil.first.endAyah, 7);
      expect(juzManzil.last.startAyah, 1);
      expect(juzManzil.last.endAyah, 141);
    });

    test('strategy changes reset today tasks/activity but preserve logs', () async {
      await seedSurahs([
        (1, 'الفاتحة', 'Al-Fatihah', 7),
        (2, 'البقرة', 'Al-Baqarah', 286),
      ]);
      await scheduler.saveHifzProfile(
        knownSurahs: const [1],
        currentSabaqSurah: 2,
        currentSabaqAyah: 1,
      );
      await scheduler.saveTierLengthSettings(
        const HifzTierLengthSettings(
          sabaqUnit: HifzRangeUnit.page,
          sabaqCount: 3,
          sabqiDays: 10,
          manzilUnit: HifzRangeUnit.juz,
          manzilCount: 2,
        ),
      );
      await scheduler.getOrGenerateTodayTasks();
      final db = await AppDatabase.instance.database;
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(1),
        'tier_type': 'sabaq',
        'surah_number': 1,
        'start_ayah': 1,
        'end_ayah': 5,
        'reps': 15,
      });

      await scheduler.saveHifzProfile(
        knownSurahs: const [1],
        currentSabaqSurah: 2,
        currentSabaqAyah: 8,
      );

      expect(await db.query('three_tier_tasks'), isEmpty);
      expect(await db.query('daily_hifz_activity'), isEmpty);
      expect(await db.query('hifz_logs'), hasLength(1));
      final settings = await scheduler.getTierLengthSettings();
      expect(settings.sabaqUnit, HifzRangeUnit.page);
      expect(settings.sabaqCount, 3);
      expect(settings.sabqiDays, 10);
      expect(settings.manzilUnit, HifzRangeUnit.juz);
      expect(settings.manzilCount, 2);
    });

    test('Manzil advances through 4 rukus and wraps after reaching sabaq', () async {
      await seedSurahs([
        (1, 'الفاتحة', 'Al-Fatihah', 7),
        (2, 'البقرة', 'Al-Baqarah', 286),
        (3, 'آل عمران', 'Ali Imran', 200),
      ]);

      await scheduler.saveHifzProfile(
        knownSurahs: const [1, 2],
        currentSabaqSurah: 3,
        currentSabaqAyah: 16,
        direction: AppConstants.directionFirstToLast,
        dailyTimeCommitment: 60,
        dailySabaqTarget: 5,
      );

      final firstPass = await scheduler.getOrGenerateTodayTasks();
      final firstManzil = firstPass.where((task) => task.tierType == HifzTierType.manzil).toList();

      expect(firstManzil.length, equals(2));
      expect(firstManzil[0].surahNumber, equals(1));
      expect(firstManzil[0].startAyah, equals(1));
      expect(firstManzil[0].endAyah, equals(7));
      expect(firstManzil[1].surahNumber, equals(2));
      expect(firstManzil[1].startAyah, equals(1));
      expect(firstManzil[1].endAyah, equals(29));

      final db = await AppDatabase.instance.database;
      for (final task in firstManzil) {
        await db.insert('hifz_logs', {
          'date': '2026-09-06',
          'tier_type': 'manzil',
          'surah_number': task.surahNumber,
          'start_ayah': task.startAyah,
          'end_ayah': task.endAyah,
          'reps': task.targetReps,
        });
        await AppDatabase.instance.saveDailyActivity(
          date: task.targetDate,
          tierType: task.tierType.name,
          surahNumber: task.surahNumber,
          startAyah: task.startAyah,
          endAyah: task.endAyah,
        );
        await AppDatabase.instance.markDailyActivityComplete(
          date: task.targetDate,
          tierType: task.tierType.name,
          surahNumber: task.surahNumber,
          startAyah: task.startAyah,
          endAyah: task.endAyah,
        );
      }
      await clearTodayTasks();

      final secondPass = await scheduler.getOrGenerateTodayTasks();
      final secondManzil = secondPass.where((task) => task.tierType == HifzTierType.manzil).toList();

      expect(secondManzil.length, equals(1));
      expect(secondManzil[0].surahNumber, equals(2));
      expect(secondManzil[0].startAyah, equals(30));
      expect(secondManzil[0].endAyah, equals(61));

      await db.delete('hifz_logs', where: "tier_type = 'manzil'");
      await db.insert('hifz_logs', {
        'date': '2026-09-07',
        'tier_type': 'manzil',
        'surah_number': 3,
        'start_ayah': 10,
        'end_ayah': 15,
        'reps': 2,
      });
      await clearTodayTasks();

      final thirdPass = await scheduler.getOrGenerateTodayTasks();
      final thirdManzil = thirdPass.where((task) => task.tierType == HifzTierType.manzil).toList();

      expect(thirdManzil.length, greaterThanOrEqualTo(2));
      expect(thirdManzil[0].surahNumber, equals(1));
      expect(thirdManzil[0].startAyah, equals(1));
      expect(thirdManzil[0].endAyah, equals(7));
      expect(thirdManzil[1].surahNumber, equals(2));
      expect(thirdManzil[1].startAyah, equals(1));
      expect(thirdManzil[1].endAyah, equals(29));
    });

    test('An untouched day repeats every tier instead of advancing', () async {
      await seedSurahs([
        (1, 'الفاتحة', 'Al-Fatihah', 7),
        (2, 'البقرة', 'Al-Baqarah', 286),
      ]);

      await scheduler.saveHifzProfile(
        knownSurahs: const [1],
        currentSabaqSurah: 2,
        currentSabaqAyah: 1,
        direction: AppConstants.directionFirstToLast,
        dailyTimeCommitment: 60,
        dailySabaqTarget: 5,
      );

      final firstPass = await scheduler.getOrGenerateTodayTasks();
      await clearTodayTasks();
      final repeatedPass = await scheduler.getOrGenerateTodayTasks();

      final firstRanges = firstPass
          .map((task) => '${task.tierType.name}:${task.surahNumber}:${task.startAyah}-${task.endAyah}')
          .toList();
      final repeatedRanges = repeatedPass
          .map((task) => '${task.tierType.name}:${task.surahNumber}:${task.startAyah}-${task.endAyah}')
          .toList();
      expect(repeatedRanges, equals(firstRanges));
    });

    test('Manzil and Sabqi display front to back in last-to-first hifz mode', () async {
      await seedSurahs([
        (84, 'الانشقاق', 'Al-Inshiqaq', 25),
        (85, 'البروج', 'Al-Buruj', 22),
        (86, 'الطارق', 'At-Tariq', 17),
        (87, 'الأعلى', 'Al-Ala', 19),
      ]);

      final db = await AppDatabase.instance.database;
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(3),
        'tier_type': 'sabaq',
        'surah_number': 87,
        'start_ayah': 1,
        'end_ayah': 5,
        'reps': 15,
      });
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(2),
        'tier_type': 'sabaq',
        'surah_number': 86,
        'start_ayah': 1,
        'end_ayah': 5,
        'reps': 15,
      });
      await db.insert('hifz_logs', {
        'date': dateDaysAgo(1),
        'tier_type': 'sabaq',
        'surah_number': 85,
        'start_ayah': 1,
        'end_ayah': 5,
        'reps': 15,
      });

      await scheduler.saveHifzProfile(
        knownSurahs: const [87, 86],
        currentSabaqSurah: 85,
        currentSabaqAyah: 6,
        direction: AppConstants.directionLastToFirst,
        dailyTimeCommitment: 60,
        dailySabaqTarget: 5,
      );

      final tasks = await scheduler.getOrGenerateTodayTasks();
      final sabqiTasks = tasks.where((task) => task.tierType == HifzTierType.sabqi).toList();
      final manzilTasks = tasks.where((task) => task.tierType == HifzTierType.manzil).toList();

      expect(sabqiTasks.length, equals(3));
      expect(sabqiTasks.map((task) => task.surahNumber).toList(), equals([85, 86, 87]));

      expect(manzilTasks.map((task) => task.surahNumber).toList(), equals([85, 86, 87]));
      expect(manzilTasks[0].startAyah, equals(1));
      expect(manzilTasks[0].endAyah, equals(5));
      expect(manzilTasks[1].startAyah, equals(1));
      expect(manzilTasks[1].endAyah, equals(17));
      expect(manzilTasks[2].startAyah, equals(1));
      expect(manzilTasks[2].endAyah, equals(19));
    });
  });
}



