class AppConstants {
  static const String appName = 'Hifz Helper';
  static const String ummahApiBaseUrl = 'https://ummahapi.com/api/quran';
  
  // Storage keys
  static const String keyQuranDownloaded = 'is_quran_downloaded';
  static const String keyStrictMode = 'is_strict_mode_enabled';
  static const String keyDailySabaqAyahs = 'daily_sabaq_ayah_count';
  static const String keySabqiDays = 'sabqi_window_days';
  static const String keyManzilPortion = 'manzil_daily_portion';
  static const String keySabaqRangeUnit = 'sabaq_range_unit';
  static const String keyManzilRangeUnit = 'manzil_range_unit';
  static const String keyTierLengthSettingsMigrated = 'tier_length_settings_migrated';
  static const String keyActiveScript = 'active_arabic_script'; // 'uthmani' or 'indopak'
  static const String keyActiveReciter = 'active_reciter_id';    // 'alafasy' or 'husary'
  static const String keyThemeMode = 'app_theme_mode';          // 'light', 'dark', 'system'

  // User Hifz Profile keys
  static const String keyProfileConfigured = 'is_hifz_profile_configured';
  static const String keyKnownSurahs = 'user_known_surahs_csv';
  static const String keyCurrentSabaqSurah = 'user_current_sabaq_surah';
  static const String keyCurrentSabaqAyah = 'user_current_sabaq_ayah';
  static const String keyHifzDirection = 'user_hifz_direction'; // 'lastToFirst' or 'firstToLast'
  static const String keyDailyTimeCommitment = 'user_daily_time_commitment_minutes'; // int e.g. 60
  static const String keyDailySabaqTarget = 'user_daily_sabaq_target_ayahs'; // int e.g. 5

  // Hifz Directions
  static const String directionLastToFirst = 'lastToFirst';
  static const String directionFirstToLast = 'firstToLast';

  // Reciter IDs and Names
  static const String reciterAlafasy = 'alafasy';
  static const String reciterHusary = 'husary';

  static const Map<String, Map<String, String>> recitersInfo = {
    reciterAlafasy: {
      'name': 'Mishary Rashid Alafasy',
      'arabicName': 'مشاري بن راشد العفاسي',
      'folder': 'Alafasy_128kbps',
      'description': 'Melodious & clear recitation',
    },
    reciterHusary: {
      'name': 'Mahmoud Khalil Al-Husary',
      'arabicName': 'محمود خليل الحصري',
      'folder': 'Husary_128kbps',
      'description': 'The golden standard for Tajweed precision & Hifz',
    },
  };

  static const String basmalaText = 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ';

  static String getAudioUrl(String reciterId, int surahNumber, int ayahNumber) {
    final folder = recitersInfo[reciterId]?['folder'] ?? 'Alafasy_128kbps';
    final sStr = surahNumber.toString().padLeft(3, '0');
    final aStr = ayahNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$sStr$aStr.mp3';
  }
  
  // 7 Classical Manzils of the Quran
  static const List<Map<String, dynamic>> classicalManzils = [
    {'manzil': 1, 'name': 'Manzil 1', 'startSurah': 1, 'startAyah': 1, 'endSurah': 4, 'endAyah': 176, 'desc': 'Al-Fatihah to An-Nisa'},
    {'manzil': 2, 'name': 'Manzil 2', 'startSurah': 5, 'startAyah': 1, 'endSurah': 9, 'endAyah': 129, 'desc': 'Al-Ma\'idah to At-Tawbah'},
    {'manzil': 3, 'name': 'Manzil 3', 'startSurah': 10, 'startAyah': 1, 'endSurah': 16, 'endAyah': 128, 'desc': 'Yunus to An-Nahl'},
    {'manzil': 4, 'name': 'Manzil 4', 'startSurah': 17, 'startAyah': 1, 'endSurah': 25, 'endAyah': 77, 'desc': 'Al-Isra to Al-Furqan'},
    {'manzil': 5, 'name': 'Manzil 5', 'startSurah': 26, 'startAyah': 1, 'endSurah': 36, 'endAyah': 83, 'desc': 'Ash-Shu\'ara to Ya-Sin'},
    {'manzil': 6, 'name': 'Manzil 6', 'startSurah': 37, 'startAyah': 1, 'endSurah': 49, 'endAyah': 18, 'desc': 'As-Saffat to Al-Hujurat'},
    {'manzil': 7, 'name': 'Manzil 7', 'startSurah': 50, 'startAyah': 1, 'endSurah': 114, 'endAyah': 6, 'desc': 'Qaf to An-Nas'},
  ];
}
