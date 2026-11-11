import 'dart:async';

import '../../app/constants.dart';
import 'audio_cache.dart';

/// Progress snapshot for a background surah audio prefetch.
class AudioPrefetchProgress {
  final int completed;
  final int total;

  const AudioPrefetchProgress(this.completed, this.total);

  bool get isDone => total == 0 || completed >= total;
  double get ratio => total == 0 ? 1.0 : completed / total;
}

/// Downloads every ayah's recitation for a given surah + reciter in the
/// background (bounded concurrency) so subsequent playback never hits the
/// network again. Files are cached permanently by [AudioCache] and never
/// deleted. Safe to call repeatedly: an in-flight prefetch for the same
/// surah+reciter is reused instead of starting duplicate downloads.
class SurahAudioPrefetcher {
  static const int _concurrency = 4;

  static final Map<String, StreamController<AudioPrefetchProgress>> _controllers = {};
  static final Set<String> _active = {};

  static String _key(int surahNumber, String reciterId) => '$surahNumber-$reciterId';

  static Stream<AudioPrefetchProgress> prefetch({
    required int surahNumber,
    required List<int> ayahNumbers,
    required String reciterId,
  }) {
    final key = _key(surahNumber, reciterId);
    final controller = _controllers.putIfAbsent(
      key,
      () => StreamController<AudioPrefetchProgress>.broadcast(),
    );

    if (!_active.contains(key) && ayahNumbers.isNotEmpty) {
      _active.add(key);
      unawaited(_run(surahNumber, ayahNumbers, reciterId, key, controller));
    }

    return controller.stream;
  }

  static bool isActive(int surahNumber, String reciterId) =>
      _active.contains(_key(surahNumber, reciterId));

  static Future<void> _run(
    int surahNumber,
    List<int> ayahNumbers,
    String reciterId,
    String key,
    StreamController<AudioPrefetchProgress> controller,
  ) async {
    final total = ayahNumbers.length;
    var completed = 0;
    controller.add(AudioPrefetchProgress(completed, total));

    final queue = List<int>.from(ayahNumbers);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final ayahNum = queue.removeAt(0);
        final url = AppConstants.getAudioUrl(reciterId, surahNumber, ayahNum);
        try {
          await AudioCache.getOrDownload(url);
        } catch (_) {
          // Ignore individual failures; playback will retry lazily on-demand.
        }
        completed++;
        controller.add(AudioPrefetchProgress(completed, total));
      }
    }

    await Future.wait(List.generate(_concurrency.clamp(1, total), (_) => worker()));

    _active.remove(key);
  }
}
