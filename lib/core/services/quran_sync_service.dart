import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/constants.dart';
import '../data/quran_metadata.dart';
import '../database/app_database.dart';
import '../network/ummah_api_client.dart';

class DownloadProgress {
  final double progress;
  final String status;
  final int completedSurahs;
  final int totalSurahs;
  final int totalAyahs;

  DownloadProgress({
    required this.progress,
    required this.status,
    required this.completedSurahs,
    required this.totalSurahs,
    required this.totalAyahs,
  });
}

class QuranSyncService {
  final UmmahApiClient _apiClient;
  final AppDatabase _db;

  // In-memory caches to prevent repetitive disk/network operations
  static List<Map<String, dynamic>>? _inMemorySurahsCache;
  static final Map<String, List<Map<String, dynamic>>> _inMemoryAyahsCache = {};

  QuranSyncService({UmmahApiClient? apiClient, AppDatabase? db})
      : _apiClient = apiClient ?? UmmahApiClient(),
        _db = db ?? AppDatabase.instance;

  /// In-memory cache reset (useful when refreshing storage or testing)
  static void clearMemoryCache() {
    _inMemorySurahsCache = null;
    _inMemoryAyahsCache.clear();
  }

  /// Ensures the 114 Surah directory/catalog is stored in SQLite & in-memory.
  /// Even if storage was cleared or network is down, seeds immediately from QuranMetadata!
  Future<List<Map<String, dynamic>>> ensureSurahDirectoryLoaded() async {
    // 1. Check in-memory
    if (_inMemorySurahsCache != null && _inMemorySurahsCache!.isNotEmpty) {
      return _inMemorySurahsCache!;
    }

    // 2. Check local SQLite
    var surahs = await _db.getSurahs();
    if (surahs.isEmpty) {
      // Storage wiped or fresh install: seed from static QuranMetadata immediately!
      await _db.batchInsertSurahs(QuranMetadata.surahs);
      surahs = await _db.getSurahs();
    }

    if (surahs.isNotEmpty) {
      _inMemorySurahsCache = surahs;
    }

    // 3. Try async sync with API to update if newer info available
    try {
      final rawList = await _apiClient.fetchSurahs();
      if (rawList.isNotEmpty) {
        final formattedSurahs = rawList.map((s) => {
          'number': s['number'],
          'name_arabic': s['name_arabic'] ?? '',
          'name_english': s['name_english'] ?? '',
          'verses_count': s['verses_count'] ?? s['ayah_count'] ?? 0,
          'revelation_place': s['revelation_place'] ?? '',
        }).toList();

        await _db.batchInsertSurahs(formattedSurahs);
        surahs = await _db.getSurahs();
        _inMemorySurahsCache = surahs;
      }
    } catch (e) {
      // Fallback: Return what we already seeded in SQLite & in-memory
    }

    return surahs.isNotEmpty ? surahs : QuranMetadata.surahs;
  }

  /// Checks if a specific Surah's ayahs are already cached locally in SQLite
  Future<bool> isSurahDownloaded(int surahNumber) async {
    final ayahs = await _db.getAyahsForSurah(surahNumber);
    return ayahs.isNotEmpty;
  }

  /// Returns the set of Surah numbers that are currently saved offline in SQLite
  Future<Set<int>> getDownloadedSurahNumbers() async {
    final db = await _db.database;
    final res = await db.rawQuery('SELECT DISTINCT surah_number FROM ayahs');
    return res.map((row) => row['surah_number'] as int).toSet();
  }

  /// On-demand: Ensures a specific Surah is downloaded and saved in SQLite.
  /// If already in memory or SQLite, returns immediately with 0 network calls!
  Future<List<Map<String, dynamic>>> ensureSurahDownloaded(
    int surahNumber, {
    String script = 'uthmani',
  }) async {
    final cacheKey = '$surahNumber-$script';

    // 0. Check in-memory cache first
    if (_inMemoryAyahsCache.containsKey(cacheKey) && _inMemoryAyahsCache[cacheKey]!.isNotEmpty) {
      return _inMemoryAyahsCache[cacheKey]!;
    }

    // 1. Check local SQLite cache
    final localAyahs = await _db.getAyahsForSurah(surahNumber);
    if (localAyahs.isNotEmpty) {
      _inMemoryAyahsCache[cacheKey] = localAyahs;
      return localAyahs;
    }

    // 2. Fetch on-demand from UmmahAPI
    final surahData = await _apiClient.fetchSurah(surahNumber, script: script);
    final verses = surahData['verses'] as List? ?? [];

    if (verses.isNotEmpty) {
      final ayahsToInsert = <Map<String, dynamic>>[];

      for (final v in verses) {
        final ayahNum = v['ayah'] as int? ?? 1;
        final arabicText = v['arabic'] as String? ?? '';
        final trans = v['translations'] != null
            ? (v['translations']['sahih_international'] as String? ?? '')
            : '';
        final audio = v['audio'] != null
            ? (v['audio']['ayah_audio'] as String? ?? '')
            : '';

        ayahsToInsert.add({
          'id': surahNumber * 1000 + ayahNum,
          'surah_number': surahNumber,
          'ayah_number': ayahNum,
          'arabic': arabicText,
          'arabic_indopak': script == 'indopak' ? arabicText : null,
          'translation': trans,
          'audio_url': audio,
          'page_number': 1,
          'juz_number': 1,
        });
      }

      await _db.batchInsertAyahs(ayahsToInsert);
    }

    final savedAyahs = await _db.getAyahsForSurah(surahNumber);
    if (savedAyahs.isNotEmpty) {
      _inMemoryAyahsCache[cacheKey] = savedAyahs;
    }
    return savedAyahs;
  }

  /// Optional: bulk downloader for users who still wish to download all 114 Surahs in one go
  Stream<DownloadProgress> downloadAllQuran() async* {
    yield DownloadProgress(
      progress: 0.0,
      status: 'Fetching Surahs directory...',
      completedSurahs: 0,
      totalSurahs: 114,
      totalAyahs: 0,
    );

    final surahList = await ensureSurahDirectoryLoaded();
    int totalAyahsInserted = 0;
    int completedSurahs = 0;
    const totalSurahs = 114;

    for (int i = 1; i <= totalSurahs; i++) {
      try {
        final ayahs = await ensureSurahDownloaded(i);
        totalAyahsInserted += ayahs.length;
      } catch (_) {}

      completedSurahs++;
      final progressVal = completedSurahs / totalSurahs;
      final currentSurahName = surahList.firstWhere(
        (s) => s['number'] == i,
        orElse: () => {'name_english': 'Surah $i'},
      )['name_english'];

      yield DownloadProgress(
        progress: progressVal,
        status: 'Cached $currentSurahName ($completedSurahs/114)',
        completedSurahs: completedSurahs,
        totalSurahs: totalSurahs,
        totalAyahs: totalAyahsInserted,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyQuranDownloaded, true);
  }
}
