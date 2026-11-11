import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hifz_helper/core/database/app_database.dart';
import 'package:hifz_helper/features/hifz_engine/models/hifz_tier_model.dart';
import 'package:hifz_helper/features/hifz_engine/providers/hifz_providers.dart';
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
    await db.delete('surahs');
    await db.insert('surahs', {
      'number': 1,
      'name_arabic': 'الفاتحة',
      'name_english': 'Al-Fatihah',
      'verses_count': 7,
      'revelation_place': 'Makkah',
    });
    await db.insert('surahs', {
      'number': 2,
      'name_arabic': 'البقرة',
      'name_english': 'Al-Baqarah',
      'verses_count': 286,
      'revelation_place': 'Madinah',
    });
  });

  test(
    'single and batch completion update live activity and undo cleanly',
    () async {
      final db = AppDatabase.instance;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final tasks = [
        HifzTask(
          tierType: HifzTierType.manzil,
          title: 'Manzil',
          surahNumber: 1,
          surahNameArabic: 'الفاتحة',
          surahNameEnglish: 'Al-Fatihah',
          startAyah: 1,
          endAyah: 7,
          targetDate: today,
          targetReps: 1,
        ),
        HifzTask(
          tierType: HifzTierType.sabqi,
          title: 'Sabqi',
          surahNumber: 1,
          surahNameArabic: 'الفاتحة',
          surahNameEnglish: 'Al-Fatihah',
          startAyah: 1,
          endAyah: 7,
          targetDate: today,
          targetReps: 1,
        ),
        HifzTask(
          tierType: HifzTierType.sabaq,
          title: 'Sabaq',
          surahNumber: 2,
          surahNameArabic: 'البقرة',
          surahNameEnglish: 'Al-Baqarah',
          startAyah: 1,
          endAyah: 2,
          targetDate: today,
          targetReps: 1,
        ),
      ];

      final taskIds = <HifzTierType, int>{};
      for (final task in tasks) {
        taskIds[task.tierType] = await db.insertTask(task.toMap());
        await db.saveDailyActivity(
          date: today,
          tierType: task.tierType.name,
          surahNumber: task.surahNumber,
          startAyah: task.startAyah,
          endAyah: task.endAyah,
        );
      }

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyTasksProvider.notifier);
      await notifier.loadTodayTasks();
      final before = await container.read(recentDailyActivityProvider.future);
      expect(before.every((row) => row['status'] == 'pending'), isTrue);

      await notifier.incrementRepetitionBatch([
        taskIds[HifzTierType.manzil]!,
        taskIds[HifzTierType.sabqi]!,
      ]);
      await notifier.toggleTaskCompleted(taskIds[HifzTierType.manzil]!);
      await notifier.toggleTaskCompletedBatch([
        taskIds[HifzTierType.manzil]!,
        taskIds[HifzTierType.sabqi]!,
      ]);
      await notifier.incrementRepetition(taskIds[HifzTierType.sabaq]!);

      final completedActivity = await container.read(
        recentDailyActivityProvider.future,
      );
      expect(
        completedActivity.every((row) => row['status'] == 'completed'),
        isTrue,
      );
      final completedLogs = await (await db.database).query('hifz_logs');
      expect(completedLogs, hasLength(3));
      expect(completedLogs.every((row) => row['date'] == today), isTrue);

      await notifier.toggleTaskCompleted(taskIds[HifzTierType.sabaq]!);

      final reopenedActivity = await container.read(
        recentDailyActivityProvider.future,
      );
      final sabaqActivity = reopenedActivity.singleWhere(
        (row) => row['tier_type'] == 'sabaq',
      );
      expect(sabaqActivity['status'], 'pending');
      expect(sabaqActivity['completed_at'], isNull);

      final remainingLogs = await (await db.database).query('hifz_logs');
      expect(remainingLogs, hasLength(2));
      expect(remainingLogs.every((row) => row['tier_type'] != 'sabaq'), isTrue);
    },
  );
}
