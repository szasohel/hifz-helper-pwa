import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../../core/audio/recitation_player.dart';
import '../../../core/audio/surah_audio_prefetcher.dart';
import '../../../core/services/quran_sync_service.dart';
import '../../hifz_engine/models/hifz_tier_model.dart';
import '../../practice/presentation/practice_session_screen.dart';
import '../../settings/providers/settings_provider.dart';
import 'widgets/mushaf_surah_header.dart';
import 'widgets/word_meaning_sheet.dart';

class SurahReaderScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> surah;

  const SurahReaderScreen({super.key, required this.surah});

  @override
  ConsumerState<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends ConsumerState<SurahReaderScreen> {
  final RecitationPlayer _player = RecitationPlayer();
  final QuranSyncService _syncService = QuranSyncService();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};
  late final StreamSubscription<RecitationPlayerState> _playerSubscription;
  List<Map<String, dynamic>> _ayahs = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _activeAyahNumber;
  AudioPrefetchProgress? _prefetchProgress;
  StreamSubscription<AudioPrefetchProgress>? _prefetchSub;

  @override
  void initState() {
    super.initState();
    _playerSubscription = _player.stateStream.listen(_onPlayerStateChanged);
    _loadAyahs();
  }

  void _onPlayerStateChanged(RecitationPlayerState state) {
    final isActive = state.isPlaying || state.isLoading || state.isPauseGapActive;
    final ayahNumber = isActive ? state.currentAyahNumber : null;
    if (_activeAyahNumber == ayahNumber) return;

    if (mounted) setState(() => _activeAyahNumber = ayahNumber);
    if (ayahNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAyah(ayahNumber));
    }
  }

  void _scrollToAyah(int ayahNumber, {int attempt = 0}) {
    if (!mounted) return;
    final context = _ayahKeys[ayahNumber]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.35,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      return;
    }

    if (attempt >= 4 || !_scrollController.hasClients) return;
    final index = _ayahs.indexWhere((ayah) => ayah['ayah_number'] == ayahNumber);
    if (index == -1) return;
    final targetOffset = (index * 190.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToAyah(ayahNumber, attempt: attempt + 1);
    });
  }

  Future<void> _loadAyahs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final surahNum = widget.surah['number'] as int;
    final settings = ref.read(settingsProvider);

    try {
      final ayahs = await _syncService.ensureSurahDownloaded(
        surahNum,
        script: settings.activeScript,
      );
      if (mounted) {
        setState(() {
          _ayahs = ayahs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not download Surah: $e. Please check your internet connection.';
          _isLoading = false;
        });
      }
    }
  }

  // Downloads every ayah's recitation for [reciterId] in one background pass so
  // future playback (single ayah or full surah) is instant and offline.
  void _prefetchReciterAudio(String reciterId) {
    if (_ayahs.isEmpty) return;
    final surahNum = widget.surah['number'] as int;
    final ayahNumbers = _ayahs.map((a) => a['ayah_number'] as int).toList();

    _prefetchSub?.cancel();
    _prefetchSub = SurahAudioPrefetcher.prefetch(
      surahNumber: surahNum,
      ayahNumbers: ayahNumbers,
      reciterId: reciterId,
    ).listen((progress) {
      if (!mounted) return;
      setState(() => _prefetchProgress = progress.isDone ? null : progress);
    });
  }

  @override
  void dispose() {
    _playerSubscription.cancel();
    _prefetchSub?.cancel();
    _scrollController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _launchPractice() {
    final surahNum = widget.surah['number'] as int;
    final versesCount = widget.surah['verses_count'] as int? ?? _ayahs.length;
    final task = HifzTask(
      tierType: HifzTierType.sabaq,
      title: 'Practice: ${widget.surah['name_english']}',
      surahNumber: surahNum,
      surahNameArabic: widget.surah['name_arabic'] as String? ?? '',
      surahNameEnglish: widget.surah['name_english'] as String? ?? '',
      startAyah: 1,
      endAyah: versesCount,
      targetDate: DateTime.now().toIso8601String().substring(0, 10),
      targetReps: 10,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PracticeSessionScreen(task: task)),
    );
  }

  String _toArabicDigits(int value) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    return value
        .toString()
        .split('')
        .map((digit) => eastern[western.indexOf(digit)])
        .join();
  }

  String _cleanTranslation(String text) {
    // Strips trailing footnote reference numbers (e.g. "...mercy.1")
    return text.replaceAll(RegExp(r'\s*\d+\s*$'), '').trim();
  }

  Widget _buildAyahEndMarker({
    required int ayahNum,
    required String activeScript,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 2),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: 0.78539816339,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isDark ? AppTheme.goldAccent : AppTheme.antiqueGold,
                    width: 1.1,
                  ),
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppTheme.goldAccent : AppTheme.antiqueGold,
                  width: 1.1,
                ),
              ),
            ),
            Text(
              _toArabicDigits(ayahNum),
              textAlign: TextAlign.center,
              style: AppTheme.arabicStyle(
                script: activeScript,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.goldAccent : AppTheme.antiqueGold,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onWordTapped(int ayahNum, int wordIndex, String word) {
    final settings = ref.read(settingsProvider);
    WordMeaningSheet.show(
      context,
      surahNumber: widget.surah['number'] as int,
      ayahNumber: ayahNum,
      wordPosition: wordIndex + 1, // 1-based index
      fallbackArabicWord: word,
      activeScript: settings.activeScript,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameEnglish = widget.surah['name_english'] as String? ?? '';
    final nameArabic = widget.surah['name_arabic'] as String? ?? '';
    final surahNum = widget.surah['number'] as int? ?? 1;
    final versesCount = widget.surah['verses_count'] as int? ?? _ayahs.length;
    final revelation = widget.surah['revelation_place'] as String? ?? 'makkah';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(nameEnglish, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(
              '${settings.activeScript.toUpperCase()} • ${AppConstants.recitersInfo[settings.activeReciter]?['name'] ?? 'Reciter'}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          // Script Selector (Uthmani vs Indo-Pak)
          PopupMenuButton<String>(
            tooltip: 'Select Arabic Script',
            icon: const Icon(Icons.font_download_outlined),
            onSelected: (script) => settingsNotifier.setScript(script),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'uthmani',
                child: Row(
                  children: [
                    Icon(
                      settings.activeScript == 'uthmani' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Uthmani (Madani)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'indopak',
                child: Row(
                  children: [
                    Icon(
                      settings.activeScript == 'indopak' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Indo-Pak Script'),
                  ],
                ),
              ),
            ],
          ),

          // Reciter Selector (Alafasy vs Husary)
          PopupMenuButton<String>(
            tooltip: 'Select Reciter',
            icon: const Icon(Icons.record_voice_over_outlined),
            onSelected: (reciter) {
              settingsNotifier.setReciter(reciter);
              _prefetchReciterAudio(reciter);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: AppConstants.reciterHusary,
                child: Row(
                  children: [
                    Icon(
                      settings.activeReciter == AppConstants.reciterHusary
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Al-Husary (Tajweed Master)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AppConstants.reciterAlafasy,
                child: Row(
                  children: [
                    Icon(
                      settings.activeReciter == AppConstants.reciterAlafasy
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Mishary Alafasy'),
                  ],
                ),
              ),
            ],
          ),

          // Day / Night Mode Toggle
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: isDark ? 'Switch to Day Mode' : 'Switch to Night Mode',
            onPressed: () => settingsNotifier.toggleDayNight(),
          ),

          // Launch Practice
          IconButton(
            icon: const Icon(Icons.fitness_center_rounded, color: AppTheme.goldAccent),
            tooltip: 'Practice this Surah',
            onPressed: _launchPractice,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryGreen),
                  const SizedBox(height: 18),
                  Text(
                    'Loading $nameEnglish...',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saving permanently to SQLite for 100% offline access.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _loadAyahs,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
              children: [
                if (_prefetchProgress != null) _buildPrefetchBanner(_prefetchProgress!),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _ayahs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return MushafSurahHeader(
                          surahNumber: surahNum,
                          nameArabic: nameArabic,
                          nameEnglish: nameEnglish,
                          versesCount: versesCount,
                          revelationPlace: revelation,
                          activeScript: settings.activeScript,
                        );
                      }

                      final ayah = _ayahs[index - 1];
                      final ayahNum = ayah['ayah_number'] as int;
                      final rawArabic = ayah['arabic'] as String;
                      final translation = _cleanTranslation(ayah['translation'] as String? ?? '');
                      final isActive = _activeAyahNumber == ayahNum;

                      return KeyedSubtree(
                        key: _ayahKeys.putIfAbsent(ayahNum, GlobalKey.new),
                        child: _buildMushafAyahRow(
                          ayah: ayah,
                          ayahNum: ayahNum,
                          rawArabic: rawArabic,
                          translation: translation,
                          activeScript: settings.activeScript,
                          isDark: isDark,
                          isActive: isActive,
                        ),
                      );
                    },
                  ),
                ),

                // Audio Bar Dock
                _buildAudioDock(settings.activeReciter),
              ],
            ),
    );
  }

  Widget _buildMushafAyahRow({
    required Map<String, dynamic> ayah,
    required int ayahNum,
    required String rawArabic,
    required String translation,
    required String activeScript,
    required bool isDark,
    required bool isActive,
  }) {
    final words = rawArabic.trim().split(RegExp(r'\s+'));
    final reciter = ref.read(settingsProvider).activeReciter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _player.playAyahs([ayah], reciterId: reciter);
          _prefetchReciterAudio(reciter);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.cardParchment,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? AppTheme.goldAccent
                  : (isDark ? AppTheme.darkBorder : AppTheme.mushafBorder),
              width: isActive ? 2 : 0.8,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: AppTheme.goldAccent.withAlpha(45), blurRadius: 12)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 6,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...List.generate(words.length, (wIdx) {
                      final word = words[wIdx];
                      return InkWell(
                        onTap: () => _onWordTapped(ayahNum, wIdx, word),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          child: Text(
                            word,
                            style: AppTheme.arabicStyle(
                              script: activeScript,
                              fontSize: 25,
                              color: isDark ? AppTheme.darkInk : AppTheme.quranInk,
                              text: word,
                            ),
                          ),
                        ),
                      );
                    }),
                    _buildAyahEndMarker(
                      ayahNum: ayahNum,
                      activeScript: activeScript,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              if (translation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  translation,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrefetchBanner(AudioPrefetchProgress progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: AppTheme.primaryGreen.withAlpha(18),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.ratio,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Caching recitation for offline use (${progress.completed}/${progress.total})',
            style: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioDock(String activeReciter) {
    return StreamBuilder<RecitationPlayerState>(
      stream: _player.stateStream,
      initialData: _player.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? RecitationPlayerState();
        final reciterName = AppConstants.recitersInfo[activeReciter]?['name'] ?? 'Reciter';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.primaryGreen,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                const Icon(Icons.headset, color: AppTheme.goldAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.isPlaying
                            ? 'Reciting: Ayah ${state.currentAyahNumber}'
                            : 'Audio: $reciterName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        activeReciter == AppConstants.reciterHusary
                            ? 'Tajweed Reference (Slow)'
                            : 'Melodious Recitation',
                        style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.white70),
                  onPressed: () => _player.stop(),
                ),
                FloatingActionButton.small(
                  backgroundColor: AppTheme.goldAccent,
                  foregroundColor: AppTheme.primaryGreen,
                  onPressed: () {
                    if (state.isPlaying) {
                      _player.pause();
                    } else {
                      _player.playAyahs(_ayahs, reciterId: activeReciter);
                      _prefetchReciterAudio(activeReciter);
                    }
                  },
                  child: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                        )
                      : Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
