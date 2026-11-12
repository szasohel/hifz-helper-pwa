import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../app/constants.dart';

class UmmahApiClient {
  final http.Client _client;

  UmmahApiClient({http.Client? client}) : _client = client ?? http.Client();

  // Only CORS-safelisted headers: a custom User-Agent forces a preflight that
  // ummahapi.com rejects, and browsers set User-Agent themselves anyway.
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
  };

  /// Fetch list of all 114 Surahs
  Future<List<Map<String, dynamic>>> fetchSurahs() async {
    final url = Uri.parse('${AppConstants.ummahApiBaseUrl}/surahs');
    final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final surahsList = data['data'] != null && data['data']['surahs'] != null
          ? data['data']['surahs']
          : data['surahs'];

      if (surahsList != null && surahsList is List) {
        return List<Map<String, dynamic>>.from(
          surahsList.map((x) => Map<String, dynamic>.from(x as Map)),
        );
      }
    }
    throw Exception('Failed to fetch surahs list from UmmahAPI: ${response.statusCode}');
  }

  /// Fetch full details and ayahs of a single Surah
  Future<Map<String, dynamic>> fetchSurah(int surahNumber, {String script = 'uthmani'}) async {
    final uri = Uri.parse('${AppConstants.ummahApiBaseUrl}/surah/$surahNumber${script == 'indopak' ? '?script=indopak' : ''}');
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data['data'] != null && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data']);
      }
      if (data['surah'] != null && data['surah'] is Map) {
        return Map<String, dynamic>.from(data);
      }
    }
    throw Exception('Failed to fetch surah $surahNumber from UmmahAPI: ${response.statusCode}');
  }

  /// Fetch word-by-word pronunciation and meaning for an Ayah
  Future<List<Map<String, dynamic>>> fetchAyahWords(int surahNumber, int ayahNumber) async {
    final url = Uri.parse('https://ummahapi.com/api/quran/words/$surahNumber/$ayahNumber');
    final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final wordsList = data['data']?['words'] ?? data['words'];
      if (wordsList != null && wordsList is List) {
        return List<Map<String, dynamic>>.from(
          wordsList.map((x) => Map<String, dynamic>.from(x as Map)),
        );
      }
    }
    return [];
  }

  void close() {
    _client.close();
  }
}
