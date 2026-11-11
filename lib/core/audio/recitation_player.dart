import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../app/constants.dart';
import 'audio_cache.dart';

class RecitationPlayerState {
  final bool isPlaying;
  final bool isLoading;
  final int currentSurahNumber;
  final int currentAyahNumber;
  final int currentRepetition;
  final int targetRepetitions;
  final bool isPauseGapActive;
  final String reciterId;

  RecitationPlayerState({
    this.isPlaying = false,
    this.isLoading = false,
    this.currentSurahNumber = 1,
    this.currentAyahNumber = 1,
    this.currentRepetition = 1,
    this.targetRepetitions = 1,
    this.isPauseGapActive = false,
    this.reciterId = AppConstants.reciterHusary,
  });

  RecitationPlayerState copyWith({
    bool? isPlaying,
    bool? isLoading,
    int? currentSurahNumber,
    int? currentAyahNumber,
    int? currentRepetition,
    int? targetRepetitions,
    bool? isPauseGapActive,
    String? reciterId,
  }) {
    return RecitationPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      currentSurahNumber: currentSurahNumber ?? this.currentSurahNumber,
      currentAyahNumber: currentAyahNumber ?? this.currentAyahNumber,
      currentRepetition: currentRepetition ?? this.currentRepetition,
      targetRepetitions: targetRepetitions ?? this.targetRepetitions,
      isPauseGapActive: isPauseGapActive ?? this.isPauseGapActive,
      reciterId: reciterId ?? this.reciterId,
    );
  }
}

class RecitationPlayer {
  final AudioPlayer _player = AudioPlayer();
  final _stateController = StreamController<RecitationPlayerState>.broadcast();

  RecitationPlayerState _state = RecitationPlayerState();
  Stream<RecitationPlayerState> get stateStream => _stateController.stream;
  RecitationPlayerState get currentState => _state;

  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = 0;
  int _repsPerAyah = 1;
  int _currentRep = 1;
  bool _enableUserGap = false;
  String _activeReciter = AppConstants.reciterHusary;
  bool _isCancelled = false;

  RecitationPlayer() {
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.loading ||
          playerState.processingState == ProcessingState.buffering) {
        _updateState(_state.copyWith(isLoading: true));
      } else {
        _updateState(_state.copyWith(
          isLoading: false,
          isPlaying: playerState.playing,
        ));
      }
    });
  }

  void _updateState(RecitationPlayerState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  Future<void> playAyahs(
    List<Map<String, dynamic>> ayahs, {
    int repsPerAyah = 1,
    bool enableUserGap = false,
    int startIndex = 0,
    String reciterId = AppConstants.reciterHusary,
    bool includeOpeningBasmala = false,
  }) async {
    if (ayahs.isEmpty) return;
    _playlist = includeOpeningBasmala
        ? _buildPlaylistWithOpeningBasmala(ayahs, reciterId: reciterId)
        : ayahs;
    _repsPerAyah = repsPerAyah;
    _enableUserGap = enableUserGap;
    _activeReciter = reciterId;
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    _currentRep = 1;
    _isCancelled = false;

    _updateState(_state.copyWith(reciterId: reciterId));
    await _playCurrentVerse();
  }

  List<Map<String, dynamic>> _buildPlaylistWithOpeningBasmala(
    List<Map<String, dynamic>> ayahs, {
    required String reciterId,
  }) {
    final playlist = <Map<String, dynamic>>[];
    int? previousSurah;

    for (final ayah in ayahs) {
      final surahNum = ayah['surah_number'] as int? ?? 1;
      final ayahNum = ayah['ayah_number'] as int? ?? 1;
      final startsNewSurah = previousSurah != surahNum;

      if (startsNewSurah && ayahNum == 1 && surahNum != 1 && surahNum != 9) {
        playlist.add({
          'surah_number': surahNum,
          'ayah_number': 0,
          'audio_url': AppConstants.getAudioUrl(reciterId, 1, 1),
          'is_basmala': true,
        });
      }

      playlist.add(ayah);
      previousSurah = surahNum;
    }

    return playlist;
  }

  Future<void> _playCurrentVerse() async {
    if (_isCancelled || _currentIndex >= _playlist.length) {
      await stop();
      return;
    }

    final ayah = _playlist[_currentIndex];
    final surahNum = ayah['surah_number'] as int? ?? 1;
    final ayahNum = ayah['ayah_number'] as int? ?? 1;

    // Always derive the URL from the currently selected reciter so switching
    // reciters mid-session takes effect immediately (ignore any cached
    // audio_url, which may belong to a different reciter).
    final audioUrl = AppConstants.getAudioUrl(
      _activeReciter,
      surahNum,
      ayahNum == 0 ? 1 : ayahNum,
    );

    _updateState(_state.copyWith(
      isPlaying: true,
      isLoading: true,
      currentSurahNumber: surahNum,
      currentAyahNumber: ayahNum,
      currentRepetition: _currentRep,
      targetRepetitions: _repsPerAyah,
      isPauseGapActive: false,
      reciterId: _activeReciter,
    ));

    try {
        final cachedPath = await AudioCache.getOrDownload(audioUrl);
        final duration = cachedPath != null
          ? await _player.setFilePath(cachedPath)
          : await _player.setUrl(audioUrl);
      _updateState(_state.copyWith(isLoading: false));
      await _player.play();

      // Wait until track completes
      await _player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed || _isCancelled,
      );

      if (_isCancelled) return;

      // Silent gap for user to repeat
      if (_enableUserGap && duration != null) {
        _updateState(_state.copyWith(isPauseGapActive: true, isPlaying: false));
        await Future.delayed(duration);
        if (_isCancelled) return;
        _updateState(_state.copyWith(isPauseGapActive: false));
      }

      if (_currentRep < _repsPerAyah) {
        _currentRep++;
        await _playCurrentVerse();
      } else {
        _currentRep = 1;
        _currentIndex++;
        if (_currentIndex < _playlist.length) {
          await _playCurrentVerse();
        } else {
          await stop();
        }
      }
    } catch (e) {
      debugPrint('Error playing recitation: $e');
      _moveToNext();
    }
  }

  void _moveToNext() {
    _currentRep = 1;
    _currentIndex++;
    if (_currentIndex < _playlist.length) {
      _playCurrentVerse();
    } else {
      stop();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _updateState(_state.copyWith(isPlaying: false));
  }

  Future<void> resume() async {
    await _player.play();
    _updateState(_state.copyWith(isPlaying: true));
  }

  Future<void> stop() async {
    _isCancelled = true;
    await _player.stop();
    _updateState(_state.copyWith(
      isPlaying: false,
      isLoading: false,
      isPauseGapActive: false,
    ));
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
  }
}
