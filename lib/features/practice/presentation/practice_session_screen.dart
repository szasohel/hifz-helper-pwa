import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../../core/audio/recitation_player.dart';
import '../../../core/audio/surah_audio_prefetcher.dart';
import '../../../core/data/quran_metadata.dart';
import '../../../core/data/quran_word_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/quran_sync_service.dart';
import '../../hifz_engine/models/hifz_tier_model.dart';
import '../../hifz_engine/providers/hifz_providers.dart';
import 'tier_length_settings_sheet.dart';
import '../../quran_reader/presentation/widgets/word_meaning_sheet.dart';
import '../../settings/providers/settings_provider.dart';

enum MaskMode {
  none, // Normal reading
  firstWord, // Only show first word of each ayah
  fullMask, // Mask all ayahs until tapped
}

class PracticeSessionScreen extends ConsumerStatefulWidget {
  final HifzTask? task;
  final List<HifzTask>? tasks;

  const PracticeSessionScreen({super.key, this.task, this.tasks})
    : assert(task != null || tasks != null, 'Provide a task or tasks');

  @override
  ConsumerState<PracticeSessionScreen> createState() =>
      _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends ConsumerState<PracticeSessionScreen> {
  final RecitationPlayer _player = RecitationPlayer();
  final QuranSyncService _syncService = QuranSyncService();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _ayahKeys = {};
  late final StreamSubscription<RecitationPlayerState> _playerSubscription;
  List<Map<String, dynamic>> _ayahs = [];
  Map<String, String> _fluencyMap = {};
  bool _isLoading = true;
  String? _loadedTaskKey;
  String? _loadingTaskKey;
  int _loadGeneration = 0;
  String? _activeAyahKey;
  final Map<int, StreamSubscription<AudioPrefetchProgress>> _prefetchSubs = {};
  final Map<int, AudioPrefetchProgress> _prefetchProgressBySurah = {};

  // Practice Modes
  MaskMode _maskMode = MaskMode.none;
  final Set<int> _revealedAyahs = {};
  int _audioReps = 1;
  bool _audioGap = false;

  List<HifzTask> get _sessionTasks => widget.tasks ?? [widget.task!];

  String _ayahKey(int surahNumber, int ayahNumber) =>
      '$surahNumber:$ayahNumber';

  Future<Map<String, String>> _loadFluencyForTasks(
    AppDatabase db,
    List<HifzTask> tasks,
  ) async {
    final fluency = <String, String>{};
    for (final task in tasks) {
      final values = await db.getFluencyForSurah(task.surahNumber);
      values.forEach((ayahNumber, status) {
        fluency[_ayahKey(task.surahNumber, ayahNumber)] = status;
      });
    }
    return fluency;
  }

  String _buildSessionTitle(HifzTask task, List<HifzTask> tasks) {
    if (tasks.length <= 1) {
      return '${task.surahNameEnglish} (${task.startAyah}-${task.endAyah})';
    }
    final totalAyahs = tasks.fold<int>(
      0,
      (sum, item) => sum + (item.endAyah - item.startAyah + 1),
    );
    return '${task.title} • ${tasks.length} parts • $totalAyahs ayahs';
  }

  String _buildSessionSubtitle(HifzTask task, List<HifzTask> tasks) {
    if (tasks.length <= 1) {
      return '${task.title} • ${ref.read(settingsProvider).activeScript.toUpperCase()}';
    }
    final first = tasks.first;
    final last = tasks.last;
    return '${first.surahNameEnglish} ${first.startAyah}-${first.endAyah} -> ${last.surahNameEnglish} ${last.startAyah}-${last.endAyah}';
  }

  List<HifzTask> _resolveSessionTasks(DailyTasksState state) {
    final resolved = <HifzTask>[];
    final groups = <HifzTierType, List<HifzTask>>{};
    for (final task in _sessionTasks) {
      groups.putIfAbsent(task.tierType, () => []).add(task);
    }

    for (final entry in groups.entries) {
      final original = entry.value;
      final currentTier = state.tasks
          .where(
            (task) =>
                task.tierType == entry.key &&
                task.targetDate == original.first.targetDate,
          )
          .toList();
      final originalStillPresent = original.every(
        (task) => currentTier.any((current) => current.id == task.id),
      );
      if (originalStillPresent) {
        resolved.addAll(
          currentTier.where((task) => original.any((item) => item.id == task.id)),
        );
      } else if (currentTier.isNotEmpty) {
        resolved.addAll(currentTier);
      } else {
        resolved.addAll(original);
      }
    }
    return resolved;
  }

  String _taskRangeKey(List<HifzTask> tasks) => tasks
      .map((task) => '${task.id}:${task.surahNumber}:${task.startAyah}-${task.endAyah}')
      .join('|');

  Map<String, dynamic>? _lookupSurahInfo(int surahNumber) {
    for (final surah in QuranMetadata.surahs) {
      if (surah['number'] == surahNumber) {
        return surah;
      }
    }
    return null;
  }

  Widget _buildCompactSurahHeader({
    required int surahNumber,
    required String surahNameEnglish,
    required String surahNameArabic,
    required String activeScript,
    required bool isDark,
  }) {
    final surahInfo = _lookupSurahInfo(surahNumber);
    final versesCount = surahInfo?['verses_count'] as int?;
    final revelationPlace = surahInfo?['revelation_place'] as String? ?? '';
    final isMakkah = revelationPlace.toLowerCase() == 'makkah';
    final showBasmala = surahNumber != 1 && surahNumber != 9;
    final titleColor = isDark ? AppTheme.goldAccent : AppTheme.primaryGreen;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.cardParchment,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.goldAccent.withAlpha(140),
              width: 1.4,
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: 8,
                left: 8,
                child: _PracticeHeaderOrnament(),
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: _PracticeHeaderOrnament(),
              ),
              const Positioned(
                bottom: 8,
                left: 8,
                child: _PracticeHeaderOrnament(),
              ),
              const Positioned(
                bottom: 8,
                right: 8,
                child: _PracticeHeaderOrnament(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                children: [
                  _PracticeInfoPill(
                    alignment: CrossAxisAlignment.start,
                    primary: 'Surah $surahNumber',
                    secondary: versesCount != null ? '$versesCount Ayahs' : surahNameEnglish,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkBg.withAlpha(120) : Colors.white.withAlpha(170),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.goldAccent.withAlpha(110)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'سُورَةُ $surahNameArabic',
                          maxLines: 1,
                          style: AppTheme.arabicStyle(
                            script: activeScript,
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            height: 1.35,
                            ornamental: true,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PracticeInfoPill(
                    alignment: CrossAxisAlignment.end,
                    primary: isMakkah ? 'Makki' : 'Madani',
                    secondary: isMakkah ? 'مكية' : 'مدنية',
                    isDark: isDark,
                  ),
                ],
                ),
              ),
            ],
          ),
        ),
        if (showBasmala) ...[
          const SizedBox(height: 4),
          Text(
            AppConstants.basmalaText,
            style: AppTheme.arabicStyle(
              script: activeScript,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: titleColor,
              height: 1.45,
              ornamental: true,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _playerSubscription = _player.stateStream.listen(_onPlayerStateChanged);
    _loadSessionData(_sessionTasks);
  }

  void _onPlayerStateChanged(RecitationPlayerState state) {
    final isActive =
        state.isPlaying || state.isLoading || state.isPauseGapActive;
    final ayahKey = isActive && state.currentAyahNumber > 0
        ? _ayahKey(state.currentSurahNumber, state.currentAyahNumber)
        : null;
    if (_activeAyahKey == ayahKey) return;

    if (mounted) setState(() => _activeAyahKey = ayahKey);
    if (ayahKey != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToAyah(ayahKey),
      );
    }
  }

  void _scrollToAyah(String ayahKey, {int attempt = 0}) {
    if (!mounted) return;
    final context = _ayahKeys[ayahKey]?.currentContext;
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
    final index = _ayahs.indexWhere(
      (ayah) =>
          _ayahKey(ayah['surah_number'] as int, ayah['ayah_number'] as int) ==
          ayahKey,
    );
    if (index == -1) return;
    final targetOffset = (index * 220.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToAyah(ayahKey, attempt: attempt + 1);
    });
  }

  Future<void> _loadSessionData(List<HifzTask> tasks) async {
    final taskKey = _taskRangeKey(tasks);
    if (_loadedTaskKey == taskKey || _loadingTaskKey == taskKey) return;
    _loadingTaskKey = taskKey;
    final loadGeneration = ++_loadGeneration;
    final db = AppDatabase.instance;
    final settings = ref.read(settingsProvider);

    try {
      final ayahs = <Map<String, dynamic>>[];
      for (final task in tasks) {
        await _syncService.ensureSurahDownloaded(
          task.surahNumber,
          script: settings.activeScript,
        );

        final rangeAyahs = await db.getAyahsRange(
          task.surahNumber,
          task.startAyah,
          task.endAyah,
        );
        ayahs.addAll(rangeAyahs);
      }
      final fluency = await _loadFluencyForTasks(db, tasks);

      if (mounted && loadGeneration == _loadGeneration) {
        setState(() {
          _ayahs = ayahs;
          _fluencyMap = fluency;
          _isLoading = false;
          _loadedTaskKey = taskKey;
          _loadingTaskKey = null;
          _ayahKeys.clear();
          _revealedAyahs.clear();
        });
      }
    } catch (e) {
      if (mounted && loadGeneration == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _loadingTaskKey = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download practice ayahs: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _playerSubscription.cancel();
    for (final sub in _prefetchSubs.values) {
      sub.cancel();
    }
    _scrollController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _onIncrementRep() async {
    final notifier = ref.read(dailyTasksProvider.notifier);
    final tasks = _resolveSessionTasks(ref.read(dailyTasksProvider));
    final error = tasks.length > 1
        ? await notifier.incrementRepetitionBatch(
            tasks.map((task) => task.id!).toList(),
          )
        : await notifier.incrementRepetition(tasks.first.id!);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.deepOrange.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _editTierLengths() async {
    final scheduler = ref.read(schedulerProvider);
    final initialSettings = await scheduler.getTierLengthSettings();
    if (!mounted) return;

    final updatedSettings = await showTierLengthSettingsSheet(
      context,
      initialSettings,
    );
    if (updatedSettings == null) return;

    final affectedTiers = <HifzTierType>{};
    if (updatedSettings.sabaqUnit != initialSettings.sabaqUnit ||
        updatedSettings.sabaqCount != initialSettings.sabaqCount) {
      affectedTiers.add(HifzTierType.sabaq);
    }
    if (updatedSettings.sabqiDays != initialSettings.sabqiDays) {
      affectedTiers.add(HifzTierType.sabqi);
    }
    if (updatedSettings.manzilUnit != initialSettings.manzilUnit ||
        updatedSettings.manzilCount != initialSettings.manzilCount) {
      affectedTiers.add(HifzTierType.manzil);
    }
    if (affectedTiers.isEmpty) return;

    try {
      await ref.read(dailyTasksProvider.notifier).applyTierLengthSettings(
        settings: updatedSettings,
        affectedTiers: affectedTiers,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update lesson lengths: $error')),
        );
      }
    }
  }

  void _onSetFluency(int surahNum, int ayahNum, String status) async {
    final isMistake = status == 'weak' || status == 'hesitant';
    await AppDatabase.instance.updateAyahFluency(
      surahNum,
      ayahNum,
      status,
      isMistake: isMistake,
    );
    setState(() {
      _fluencyMap[_ayahKey(surahNum, ayahNum)] = status;
    });
  }

  void _onWordTapped(int surahNum, int ayahNum, int wordPosition, String word) {
    if (_maskMode != MaskMode.none && !_revealedAyahs.contains(ayahNum)) return;
    final settings = ref.read(settingsProvider);
    WordMeaningSheet.show(
      context,
      surahNumber: surahNum,
      ayahNumber: ayahNum,
      wordPosition: wordPosition,
      fallbackArabicWord: word,
      activeScript: settings.activeScript,
    );
  }

  String _getProcessedArabicText(String fullText, int ayahNum) {
    if (_maskMode == MaskMode.none || _revealedAyahs.contains(ayahNum)) {
      return fullText;
    }
    if (_maskMode == MaskMode.firstWord) {
      final words = fullText.trim().split(RegExp(r'\s+'));
      if (words.isNotEmpty) {
        return '${words.first}  • • • • • • • •';
      }
    }
    return '• • • • • • • • • • • • • • • • • •';
  }

  String _cleanTranslation(String text) {
    // Strips trailing footnote reference numbers (e.g. "...mercy.1")
    return text.replaceAll(RegExp(r'\s*\d+\s*$'), '').trim();
  }

  // Downloads every ayah's recitation for [surahNumber] + [reciterId] in one
  // background pass so future playback (single ayah or full surah) is instant.
  void _prefetchReciterAudioForSurah(int surahNumber, String reciterId) {
    final ayahNumbers = _ayahs
        .where((a) => a['surah_number'] == surahNumber)
        .map((a) => a['ayah_number'] as int)
        .toList();
    if (ayahNumbers.isEmpty) return;

    _prefetchSubs[surahNumber]?.cancel();
    _prefetchSubs[surahNumber] = SurahAudioPrefetcher.prefetch(
      surahNumber: surahNumber,
      ayahNumbers: ayahNumbers,
      reciterId: reciterId,
    ).listen((progress) {
      if (!mounted) return;
      setState(() {
        if (progress.isDone) {
          _prefetchProgressBySurah.remove(surahNumber);
        } else {
          _prefetchProgressBySurah[surahNumber] = progress;
        }
      });
    });
  }

  void _prefetchReciterAudio(String reciterId) {
    final surahNumbers = _ayahs.map((a) => a['surah_number'] as int).toSet();
    for (final surahNumber in surahNumbers) {
      _prefetchReciterAudioForSurah(surahNumber, reciterId);
    }
  }

  AudioPrefetchProgress? get _aggregatedPrefetchProgress {
    if (_prefetchProgressBySurah.isEmpty) return null;
    var completed = 0;
    var total = 0;
    for (final progress in _prefetchProgressBySurah.values) {
      completed += progress.completed;
      total += progress.total;
    }
    return AudioPrefetchProgress(completed, total);
  }

  void _playAyah(Map<String, dynamic> ayah) {
    final reciter = ref.read(settingsProvider).activeReciter;
    _player.playAyahs([ayah], reciterId: reciter);
    _prefetchReciterAudioForSurah(ayah['surah_number'] as int, reciter);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final tasksState = ref.watch(dailyTasksProvider);
    final liveSessionTasks = _resolveSessionTasks(tasksState);
    ref.listen(dailyTasksProvider, (previous, next) {
      final nextTasks = _resolveSessionTasks(next);
      if (_taskRangeKey(nextTasks) != _loadedTaskKey) {
        unawaited(_loadSessionData(nextTasks));
      }
    });
    final liveTask = liveSessionTasks.first;
    final completedReps = liveSessionTasks
        .map((task) => task.completedReps)
        .reduce((a, b) => a < b ? a : b);
    final isCompleted = liveSessionTasks.every((task) => task.isCompleted);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              _buildSessionTitle(liveTask, liveSessionTasks),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_buildSessionSubtitle(liveTask, liveSessionTasks)} • ${settings.activeScript.toUpperCase()}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Change lesson lengths',
            icon: const Icon(Icons.tune),
            onPressed: _editTierLengths,
          ),
          IconButton(
            icon: Icon(
              isCompleted ? Icons.check_circle : Icons.check_circle_outline,
              color: isCompleted ? AppTheme.fluencyMastered : Colors.grey,
            ),
            onPressed: () async {
              final notifier = ref.read(dailyTasksProvider.notifier);
              final err = liveSessionTasks.length > 1
                  ? await notifier.toggleTaskCompletedBatch(
                      liveSessionTasks.map((task) => task.id!).toList(),
                    )
                  : await notifier.toggleTaskCompleted(liveTask.id!);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err),
                    backgroundColor: Colors.deepOrange.shade800,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Repetition Counter & Guidance
                _buildRepetitionHeader(
                  liveTask,
                  completedReps,
                  isCompleted,
                  isDark,
                ),

                // 2. Self-Testing Mask Toolbar
                _buildMaskToolbar(isDark),

                // Background recitation caching indicator (non-blocking)
                if (_aggregatedPrefetchProgress != null)
                  _buildPrefetchBanner(_aggregatedPrefetchProgress!),

                // 3. Ayahs List with Word-Click and Fluency Controls
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _ayahs.length,
                    separatorBuilder: (_, _) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final ayah = _ayahs[index];
                      final surahNum = ayah['surah_number'] as int;
                      final ayahNum = ayah['ayah_number'] as int;
                      final rawArabic = ayah['arabic'] as String;
                      final translation = _cleanTranslation(ayah['translation'] as String? ?? '');
                      final isRevealed = _revealedAyahs.contains(ayahNum);
                      final fluency =
                          _fluencyMap[_ayahKey(surahNum, ayahNum)] ??
                          'unmarked';
                      final isActive =
                          _activeAyahKey == _ayahKey(surahNum, ayahNum);
                      final previousSurah = index > 0
                          ? _ayahs[index - 1]['surah_number'] as int
                          : null;
                      final showSurahHeader = previousSurah != surahNum;
                      final surahNameEnglish = liveSessionTasks
                          .firstWhere(
                            (task) => task.surahNumber == surahNum,
                            orElse: () => liveTask,
                          )
                          .surahNameEnglish;
                      final surahNameArabic = liveSessionTasks
                          .firstWhere(
                            (task) => task.surahNumber == surahNum,
                            orElse: () => liveTask,
                          )
                          .surahNameArabic;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showSurahHeader)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildCompactSurahHeader(
                                surahNumber: surahNum,
                                surahNameEnglish: surahNameEnglish,
                                surahNameArabic: surahNameArabic,
                                activeScript: settings.activeScript,
                                isDark: isDark,
                              ),
                            ),
                          KeyedSubtree(
                            key: _ayahKeys.putIfAbsent(
                              _ayahKey(surahNum, ayahNum),
                              GlobalKey.new,
                            ),
                            child: _buildAyahCard(
                              ayah: ayah,
                              surahNum: surahNum,
                              ayahNum: ayahNum,
                              rawArabic: rawArabic,
                              translation: translation,
                              isRevealed: isRevealed,
                              fluency: fluency,
                              activeScript: settings.activeScript,
                              isDark: isDark,
                              isActive: isActive,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 4. Audio Controller with Reciter Switching (only while active)
                StreamBuilder<RecitationPlayerState>(
                  stream: _player.stateStream,
                  initialData: _player.currentState,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? RecitationPlayerState();
                    final isActive = state.isPlaying ||
                        state.isLoading ||
                        state.isPauseGapActive;
                    if (!isActive) return const SizedBox.shrink();
                    return _buildAudioPlayerDock(settings.activeReciter);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildRepetitionHeader(
    HifzTask task,
    int completedReps,
    bool isCompleted,
    bool isDark,
  ) {
    final progress = (task.targetReps > 0)
        ? (completedReps / task.targetReps).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardParchment,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.mushafBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Repetitions: $completedReps / ${task.targetReps}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.fluencyMastered.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.fluencyMastered,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withAlpha(50),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.completedReps < 4
                      ? '🎧 Step 1: Listen with Qari (Husary/Alafasy)'
                      : task.completedReps < 11
                      ? '📖 Step 2: Recite 10x with text (tap words for meaning)'
                      : '🧠 Step 3: Recite from memory (Mask mode)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          InkWell(
            onTap: _onIncrementRep,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    '+1 Rep',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaskToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_off,
            size: 16,
            color: AppTheme.goldAccent,
          ),
          const SizedBox(width: 6),
          const Text(
            'Mask:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                _buildMaskOption('Normal', MaskMode.none, isDark),
                const SizedBox(width: 4),
                _buildMaskOption('1st Word', MaskMode.firstWord, isDark),
                const SizedBox(width: 4),
                _buildMaskOption('Full Mask', MaskMode.fullMask, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaskOption(String label, MaskMode mode, bool isDark) {
    final isSelected = _maskMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _maskMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryGreen
                : (isDark ? Colors.white.withAlpha(15) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildAyahCard({
    required Map<String, dynamic> ayah,
    required int surahNum,
    required int ayahNum,
    required String rawArabic,
    required String translation,
    required bool isRevealed,
    required String fluency,
    required String activeScript,
    required bool isDark,
    required bool isActive,
  }) {
    final isMasked = _maskMode != MaskMode.none && !isRevealed;
    final words = tokenizeQuranWords(rawArabic);

    Color fluencyColor = Colors.transparent;
    if (fluency == 'strong') {
      fluencyColor = AppTheme.fluencyMastered.withAlpha(20);
    }
    if (fluency == 'hesitant') {
      fluencyColor = AppTheme.fluencyHesitant.withAlpha(25);
    }
    if (fluency == 'weak') fluencyColor = AppTheme.fluencyWeak.withAlpha(25);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _playAyah(ayah),
        child: Container(
      decoration: BoxDecoration(
        color: fluencyColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppTheme.goldAccent
              : (isDark ? AppTheme.darkBorder : AppTheme.mushafBorder),
          width: isActive ? 2 : 0.6,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.goldAccent.withAlpha(45),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryGreen, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$ayahNum',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.check_circle,
                  size: 20,
                  color: fluency == 'strong'
                      ? AppTheme.fluencyMastered
                      : Colors.grey.shade400,
                ),
                tooltip: 'Mark Fluent (Green)',
                onPressed: () => _onSetFluency(surahNum, ayahNum, 'strong'),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.help,
                  size: 20,
                  color: fluency == 'hesitant'
                      ? AppTheme.fluencyHesitant
                      : Colors.grey.shade400,
                ),
                tooltip: 'Mark Hesitant (Yellow)',
                onPressed: () => _onSetFluency(surahNum, ayahNum, 'hesitant'),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.cancel,
                  size: 20,
                  color: fluency == 'weak'
                      ? AppTheme.fluencyWeak
                      : Colors.grey.shade400,
                ),
                tooltip: 'Mark Mistake (Red)',
                onPressed: () => _onSetFluency(surahNum, ayahNum, 'weak'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ayah Text: Clickable Words if unmasked; Tap to Reveal if masked
          if (isMasked)
            GestureDetector(
              onTap: () {
                setState(() => _revealedAyahs.add(ayahNum));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _getProcessedArabicText(rawArabic, ayahNum),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: AppTheme.arabicStyle(
                        script: activeScript,
                        fontSize: 24,
                        color: Colors.grey.shade500,
                        text: _getProcessedArabicText(rawArabic, ayahNum),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '🔒 Tap verse to reveal text',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.antiqueGold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                spacing: 5,
                runSpacing: 6,
                children: List.generate(words.length, (wIdx) {
                  final token = words[wIdx];
                  final word = token.text;
                  return InkWell(
                    onTap: token.wordPosition == null
                        ? null
                        : () => _onWordTapped(surahNum, ayahNum, token.wordPosition!, word),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 2,
                      ),
                      child: Text(
                        word,
                        style: AppTheme.arabicStyle(
                          script: activeScript,
                          fontSize: 24,
                          color: isDark ? AppTheme.darkInk : AppTheme.quranInk,
                          text: word,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

          if (!isMasked && translation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              translation,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayerDock(String activeReciter) {
    return StreamBuilder<RecitationPlayerState>(
      stream: _player.stateStream,
      initialData: _player.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? RecitationPlayerState();
        final reciterName =
            AppConstants.recitersInfo[activeReciter]?['name'] ?? 'Reciter';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(color: AppTheme.primaryGreen),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Recitation Status & Current Ayah (Full width)
                Row(
                  children: [
                    const Icon(
                      Icons.record_voice_over,
                      color: AppTheme.goldAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.isPauseGapActive
                            ? '🗣️ Your turn to recite!'
                            : state.isPlaying
                            ? state.currentAyahNumber == 0
                                ? 'Listening: Basmala (${state.currentRepetition}/${state.targetRepetitions})'
                                : 'Listening: Ayah ${state.currentAyahNumber} (${state.currentRepetition}/${state.targetRepetitions})'
                            : 'Audio: $reciterName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Bottom Row: Playback Controls on Left, Loop & Gap Pause on Right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Play / Pause / Stop
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'dock_play_btn',
                          backgroundColor: AppTheme.goldAccent,
                          foregroundColor: AppTheme.primaryGreen,
                          onPressed: () {
                            if (state.isPlaying) {
                              _player.pause();
                            } else {
                              _player.playAyahs(
                                _ayahs,
                                repsPerAyah: _audioReps,
                                enableUserGap: _audioGap,
                                reciterId: activeReciter,
                                includeOpeningBasmala: true,
                              );
                              _prefetchReciterAudio(activeReciter);
                            }
                          },
                          child: state.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryGreen,
                                  ),
                                )
                              : Icon(
                                  state.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.stop, color: Colors.white70),
                          tooltip: 'Stop Recitation',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _player.stop(),
                        ),
                      ],
                    ),
                    // Loop Reps Dropdown & Gap Pause Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _audioReps,
                            dropdownColor: AppTheme.primaryGreen,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            underline: const SizedBox(),
                            isDense: true,
                            items: [1, 3, 5, 10].map((r) {
                              return DropdownMenuItem<int>(
                                value: r,
                                child: Text('${r}x loop'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _audioReps = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _audioGap = !_audioGap),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _audioGap
                                  ? AppTheme.goldAccent
                                  : Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _audioGap
                                      ? Icons.pause_circle_filled
                                      : Icons.pause_circle_outline,
                                  size: 13,
                                  color: _audioGap
                                      ? Colors.black87
                                      : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Gap Pause',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: _audioGap
                                        ? Colors.black87
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PracticeInfoPill extends StatelessWidget {
  final CrossAxisAlignment alignment;
  final String primary;
  final String secondary;
  final bool isDark;

  const _PracticeInfoPill({
    required this.alignment,
    required this.primary,
    required this.secondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.goldAccent.withAlpha(isDark ? 28 : 22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldAccent.withAlpha(90)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: [
          Text(
            primary,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.goldAccent : AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            secondary,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeHeaderOrnament extends StatelessWidget {
  const _PracticeHeaderOrnament();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.78539816339,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.goldAccent.withAlpha(140)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppTheme.goldAccent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
