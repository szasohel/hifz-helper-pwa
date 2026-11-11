import 'audio_cache_stub.dart'
    if (dart.library.io) 'audio_cache_io.dart' as implementation;

class AudioCache {
  static Future<String?> getOrDownload(String url) {
    return implementation.getOrDownload(url);
  }
}