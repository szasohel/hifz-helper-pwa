import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hifz_companion.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      path = filePath;
    } else {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Surahs Table
    await db.execute('''
      CREATE TABLE surahs (
        number INTEGER PRIMARY KEY,
        name_arabic TEXT NOT NULL,
        name_english TEXT NOT NULL,
        verses_count INTEGER NOT NULL,
        revelation_place TEXT
      )
    ''');

    // 2. Ayahs Table (with both Uthmani & Indo-Pak texts)
    await db.execute('''
      CREATE TABLE ayahs (
        id INTEGER PRIMARY KEY,
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        arabic TEXT NOT NULL,
        arabic_indopak TEXT,
        translation TEXT,
        audio_url TEXT,
        page_number INTEGER,
        juz_number INTEGER,
        FOREIGN KEY (surah_number) REFERENCES surahs (number)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_ayahs_surah ON ayahs(surah_number, ayah_number)',
    );
    await db.execute('CREATE INDEX idx_ayahs_page ON ayahs(page_number)');
    await db.execute('CREATE INDEX idx_ayahs_juz ON ayahs(juz_number)');

    // 3. Three-Tier Tasks Table
    await db.execute('''
      CREATE TABLE three_tier_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tier_type TEXT NOT NULL,
        title TEXT NOT NULL,
        surah_number INTEGER NOT NULL,
        start_ayah INTEGER NOT NULL,
        end_ayah INTEGER NOT NULL,
        target_date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        target_reps INTEGER NOT NULL DEFAULT 10,
        completed_reps INTEGER NOT NULL DEFAULT 0,
        notes TEXT
      )
    ''');

    // 4. Ayah Fluency & Mistakes Table
    await db.execute('''
      CREATE TABLE ayah_fluency (
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'unmarked',
        mistake_count INTEGER NOT NULL DEFAULT 0,
        last_practiced TEXT,
        PRIMARY KEY (surah_number, ayah_number)
      )
    ''');

    // 5. Memorization Sessions Log
    await db.execute('''
      CREATE TABLE hifz_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        tier_type TEXT NOT NULL,
        surah_number INTEGER NOT NULL,
        start_ayah INTEGER NOT NULL,
        end_ayah INTEGER NOT NULL,
        reps INTEGER NOT NULL
      )
    ''');

    // 6. Word-by-Word Pronunciation & Meaning Cache
    await db.execute('''
      CREATE TABLE ayah_words (
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        position INTEGER NOT NULL,
        arabic TEXT NOT NULL,
        transliteration TEXT,
        translation TEXT,
        PRIMARY KEY (surah_number, ayah_number, position)
      )
    ''');

    await _createDailyActivityTable(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE ayahs ADD COLUMN arabic_indopak TEXT');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ayah_words (
          surah_number INTEGER NOT NULL,
          ayah_number INTEGER NOT NULL,
          position INTEGER NOT NULL,
          arabic TEXT NOT NULL,
          transliteration TEXT,
          translation TEXT,
          PRIMARY KEY (surah_number, ayah_number, position)
        )
      ''');
    }
    if (oldVersion < 3) {
      await _createDailyActivityTable(db);
    }
  }

  Future<void> _createDailyActivityTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_hifz_activity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_date TEXT NOT NULL,
        tier_type TEXT NOT NULL,
        surah_number INTEGER NOT NULL,
        start_ayah INTEGER NOT NULL,
        end_ayah INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        completed_at TEXT,
        UNIQUE(activity_date, tier_type, surah_number, start_ayah, end_ayah)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_activity_date ON daily_hifz_activity(activity_date DESC)',
    );
  }

  // Query Methods
  Future<List<Map<String, dynamic>>> getSurahs() async {
    final db = await database;
    return await db.query('surahs', orderBy: 'number ASC');
  }

  Future<Map<String, dynamic>?> getSurah(int surahNumber) async {
    final db = await database;
    final res = await db.query(
      'surahs',
      where: 'number = ?',
      whereArgs: [surahNumber],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getAyahsForSurah(int surahNumber) async {
    final db = await database;
    return await db.query(
      'ayahs',
      where: 'surah_number = ?',
      whereArgs: [surahNumber],
      orderBy: 'ayah_number ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAyahsRange(
    int surahNumber,
    int startAyah,
    int endAyah,
  ) async {
    final db = await database;
    return await db.query(
      'ayahs',
      where: 'surah_number = ? AND ayah_number >= ? AND ayah_number <= ?',
      whereArgs: [surahNumber, startAyah, endAyah],
      orderBy: 'ayah_number ASC',
    );
  }

  Future<int> getAyahCountInDatabase() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM ayahs');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> batchInsertSurahs(List<Map<String, dynamic>> surahs) async {
    final db = await database;
    final batch = db.batch();
    for (final s in surahs) {
      batch.insert('surahs', s, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> batchInsertAyahs(List<Map<String, dynamic>> ayahs) async {
    final db = await database;
    final batch = db.batch();
    for (final a in ayahs) {
      batch.insert('ayahs', a, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // Word-level caching & retrieval
  Future<List<Map<String, dynamic>>> getCachedWords(int surah, int ayah) async {
    final db = await database;
    return await db.query(
      'ayah_words',
      where: 'surah_number = ? AND ayah_number = ?',
      whereArgs: [surah, ayah],
      orderBy: 'position ASC',
    );
  }

  Future<void> cacheWords(
    int surah,
    int ayah,
    List<Map<String, dynamic>> words,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final w in words) {
      final pos = w['position'] as int? ?? 1;
      final arabic = w['arabic'] as String? ?? '';
      final transliteration = w['transliteration'] is Map
          ? (w['transliteration']['text'] as String? ?? '')
          : (w['transliteration'] as String? ?? '');
      final translation = w['translation'] as String? ?? '';

      batch.insert('ayah_words', {
        'surah_number': surah,
        'ayah_number': ayah,
        'position': pos,
        'arabic': arabic,
        'transliteration': transliteration,
        'translation': translation,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // Fluency updates
  Future<void> updateAyahFluency(
    int surah,
    int ayah,
    String status, {
    bool isMistake = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawInsert(
      '''
      INSERT INTO ayah_fluency (surah_number, ayah_number, status, mistake_count, last_practiced)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(surah_number, ayah_number) DO UPDATE SET
        status = excluded.status,
        mistake_count = mistake_count + ?,
        last_practiced = excluded.last_practiced
    ''',
      [surah, ayah, status, isMistake ? 1 : 0, now, isMistake ? 1 : 0],
    );
  }

  Future<void> resolveAyahFluency(int surah, int ayah) async {
    final db = await database;
    await db.update(
      'ayah_fluency',
      {
        'status': 'strong',
        'mistake_count': 0,
        'last_practiced': DateTime.now().toIso8601String(),
      },
      where: 'surah_number = ? AND ayah_number = ?',
      whereArgs: [surah, ayah],
    );
  }

  Future<Map<int, String>> getFluencyForSurah(int surahNumber) async {
    final db = await database;
    final list = await db.query(
      'ayah_fluency',
      where: 'surah_number = ?',
      whereArgs: [surahNumber],
    );
    final map = <int, String>{};
    for (var row in list) {
      map[row['ayah_number'] as int] = row['status'] as String;
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getWeakAyahs() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, f.status, f.mistake_count, s.name_english, s.name_arabic 
      FROM ayah_fluency f
      JOIN ayahs a ON a.surah_number = f.surah_number AND a.ayah_number = f.ayah_number
      JOIN surahs s ON s.number = a.surah_number
      WHERE f.status IN ('hesitant', 'weak') OR f.mistake_count > 0
      ORDER BY f.mistake_count DESC, f.last_practiced DESC
    ''');
  }

  // Tasks Management
  Future<List<Map<String, dynamic>>> getTasksForDate(String dateIso) async {
    final db = await database;
    return await db.query(
      'three_tier_tasks',
      where: 'target_date = ?',
      whereArgs: [dateIso],
      orderBy: "CASE tier_type WHEN 'manzil' THEN 1 WHEN 'sabqi' THEN 2 WHEN 'sabaq' THEN 3 END, id ASC",
    );
  }

  Future<int> insertTask(Map<String, dynamic> task) async {
    final db = await database;
    return await db.insert('three_tier_tasks', task);
  }

  Future<void> updateTaskProgress(
    int taskId,
    int completedReps,
    bool isCompleted,
  ) async {
    final db = await database;
    await db.update(
      'three_tier_tasks',
      {'completed_reps': completedReps, 'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> saveDailyActivity({
    required String date,
    required String tierType,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    final db = await database;
    await db.insert('daily_hifz_activity', {
      'activity_date': date,
      'tier_type': tierType,
      'surah_number': surahNumber,
      'start_ayah': startAyah,
      'end_ayah': endAyah,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getActivityForDate(String date) async {
    final db = await database;
    return db.query(
      'daily_hifz_activity',
      where: 'activity_date = ?',
      whereArgs: [date],
      orderBy: "CASE tier_type WHEN 'manzil' THEN 1 WHEN 'sabqi' THEN 2 WHEN 'sabaq' THEN 3 END, id ASC",
    );
  }

  Future<void> markDailyActivityComplete({
    required String date,
    required String tierType,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    final db = await database;
    await db.update(
      'daily_hifz_activity',
      {'status': 'completed', 'completed_at': DateTime.now().toIso8601String()},
      where: '''activity_date = ? AND tier_type = ? AND surah_number = ?
          AND start_ayah = ? AND end_ayah = ?''',
      whereArgs: [date, tierType, surahNumber, startAyah, endAyah],
    );
  }

  Future<void> markDailyActivityPending({
    required String date,
    required String tierType,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    final db = await database;
    await db.update(
      'daily_hifz_activity',
      {'status': 'pending', 'completed_at': null},
      where: '''activity_date = ? AND tier_type = ? AND surah_number = ?
          AND start_ayah = ? AND end_ayah = ?''',
      whereArgs: [date, tierType, surahNumber, startAyah, endAyah],
    );
  }

  Future<void> deleteHifzSession({
    required String date,
    required String tierType,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    final db = await database;
    await db.delete(
      'hifz_logs',
      where: '''date = ? AND tier_type = ? AND surah_number = ?
          AND start_ayah = ? AND end_ayah = ?''',
      whereArgs: [date, tierType, surahNumber, startAyah, endAyah],
    );
  }

  Future<List<Map<String, dynamic>>> getLatestActivityForTier(
    String tierType,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT * FROM daily_hifz_activity
      WHERE tier_type = ?
        AND activity_date = (
          SELECT MAX(activity_date) FROM daily_hifz_activity WHERE tier_type = ?
        )
      ORDER BY id ASC
    ''',
      [tierType, tierType],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentDailyActivity({
    int days = 30,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT * FROM daily_hifz_activity
      WHERE activity_date >= date('now', ?)
      ORDER BY activity_date DESC,
        CASE tier_type WHEN 'manzil' THEN 1 WHEN 'sabqi' THEN 2 WHEN 'sabaq' THEN 3 END,
        id ASC
    ''',
      ['-${days - 1} days'],
    );
  }

  Future<void> logHifzSession(
    String tierType,
    int surah,
    int startAyah,
    int endAyah,
    int reps, {
    String? date,
  }) async {
    final db = await database;
    await db.insert('hifz_logs', {
      'date': date ?? DateTime.now().toIso8601String().substring(0, 10),
      'tier_type': tierType,
      'surah_number': surah,
      'start_ayah': startAyah,
      'end_ayah': endAyah,
      'reps': reps,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentSabaqLogs(
    int days, {
    required String beforeDate,
  }) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT surah_number, start_ayah, end_ayah, date
      FROM hifz_logs
      WHERE tier_type = 'sabaq' AND date < ? AND date >= date(?, ?)
      GROUP BY date, surah_number, start_ayah, end_ayah
      ORDER BY date DESC, MAX(id) DESC
    ''',
      [beforeDate, beforeDate, '-$days days'],
    );
  }

  Future<int?> getLastLoggedSurahForTier(String tierType) async {
    final db = await database;
    final res = await db.rawQuery(
      '''
      SELECT surah_number FROM hifz_logs
      WHERE tier_type = ?
      ORDER BY id DESC
      LIMIT 1
    ''',
      [tierType],
    );
    if (res.isNotEmpty) {
      return res.first['surah_number'] as int?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getLatestLogsForTier(
    String tierType,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT surah_number, start_ayah, end_ayah, date
      FROM hifz_logs
      WHERE tier_type = ?
        AND date = (
          SELECT MAX(date)
          FROM hifz_logs
          WHERE tier_type = ?
        )
      ORDER BY id ASC
    ''',
      [tierType, tierType],
    );
  }
}
