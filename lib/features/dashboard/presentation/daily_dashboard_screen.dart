import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../daily_countdown.dart';
import '../../hifz_engine/models/hifz_tier_model.dart';
import '../../hifz_engine/providers/hifz_providers.dart';
import '../../practice/presentation/practice_session_screen.dart';
import '../../quran_reader/presentation/surah_list_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/providers/settings_provider.dart';
import '../../weak_spots/presentation/weak_spots_screen.dart';
import 'widgets/hifz_setup_dialog.dart';

class DailyDashboardScreen extends ConsumerStatefulWidget {
  const DailyDashboardScreen({super.key});

  @override
  ConsumerState<DailyDashboardScreen> createState() =>
      _DailyDashboardScreenState();
}

class _DailyDashboardScreenState extends ConsumerState<DailyDashboardScreen>
    with WidgetsBindingObserver {
  late DateTime _now;
  late DateTime _lastObservedDate;
  Timer? _countdownTimer;
  HifzTierLengthSettings? _tierLengthSettings;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _lastObservedDate = DateTime(_now.year, _now.month, _now.day);
    WidgetsBinding.instance.addObserver(this);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
    unawaited(_loadTierLengthSettings());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isConfigured = await ref
          .read(schedulerProvider)
          .isProfileConfigured();
      if (mounted && !isConfigured) {
        await HifzSetupDialog.show(context);
      }
    });
  }

  Future<void> _loadTierLengthSettings() async {
    final settings = await ref.read(schedulerProvider).getTierLengthSettings();
    if (mounted) setState(() => _tierLengthSettings = settings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateClock();
    }
  }

  void _updateClock() {
    if (!mounted) return;

    final now = DateTime.now();
    final observedDate = DateTime(now.year, now.month, now.day);
    final dateChanged = !_lastObservedDate.isAtSameMomentAs(observedDate);

    setState(() {
      _now = now;
      if (dateChanged) _lastObservedDate = observedDate;
    });

    if (dateChanged) {
      unawaited(ref.read(dailyTasksProvider.notifier).loadTodayTasks());
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final tasksState = ref.watch(dailyTasksProvider);
    ref.listen(dailyTasksProvider, (previous, next) {
      if (previous?.tasks != next.tasks) {
        unawaited(_loadTierLengthSettings());
      }
    });
    final isStrictMode = ref.watch(strictModeProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final timeLeft = timeUntilNextLocalMidnight(_now);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final manzilTasks = tasksState.tasks
        .where((t) => t.tierType == HifzTierType.manzil)
        .toList();
    final sabqiTasks = tasksState.tasks
        .where((t) => t.tierType == HifzTierType.sabqi)
        .toList();
    final sabaqTasks = tasksState.tasks
        .where((t) => t.tierType == HifzTierType.sabaq)
        .toList();

    final isManzilDone =
        manzilTasks.isNotEmpty && manzilTasks.every((t) => t.isCompleted);
    final isSabqiDone =
        sabqiTasks.isNotEmpty && sabqiTasks.every((t) => t.isCompleted);
    // Sabaq is locked in strict mode until BOTH Manzil and Sabqi are completed!
    final isSabaqLocked = isStrictMode && (!isManzilDone || !isSabqiDone);

    final completedCount = tasksState.tasks.where((t) => t.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hifz Helper'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? 'Day Mode' : 'Night Mode',
            onPressed: () => settingsNotifier.toggleDayNight(),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Quran Explorer (Offline)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SurahListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.report_problem_outlined,
              color: AppTheme.fluencyHesitant,
            ),
            tooltip: 'Weak Spots & Mistakes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WeakSpotsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Preferences',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: tasksState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(dailyTasksProvider.notifier).loadTodayTasks();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  // Slim progress banner (ring + time left)
                  _buildHeaderBanner(
                    completedCount,
                    tasksState.tasks.length,
                    timeLeft,
                  ),

                  const SizedBox(height: 10),

                  _buildManzilSection(
                    context: context,
                    ref: ref,
                    tasks: manzilTasks,
                  ),

                  if (manzilTasks.isNotEmpty) const SizedBox(height: 8),

                  _buildTierSection(
                    context: context,
                    ref: ref,
                    tasks: sabqiTasks,
                    badgeBuilder: (task) =>
                        'STEP 2 • SABQI (${task.allocatedMinutes ?? 0}m ~ 30%)',
                    badgeColor: Colors.amber.shade800,
                    icon: Icons.shield_outlined,
                    memoryLabel: 'Recent Memory',
                    subtitle: '',
                    isLocked: false,
                  ),

                  if (sabqiTasks.isNotEmpty) const SizedBox(height: 8),

                  _buildTierSection(
                    context: context,
                    ref: ref,
                    tasks: sabaqTasks,
                    badgeBuilder: (task) => isSabaqLocked
                        ? 'LOCKED (FINISH STEPS 1 & 2)'
                        : 'STEP 3 • SABAQ (${task.allocatedMinutes ?? 0}m ~ 20%)',
                    badgeColor: isSabaqLocked
                        ? Colors.red.shade700
                        : AppTheme.primaryGreen,
                    icon: isSabaqLocked
                        ? Icons.lock_outline
                        : Icons.auto_stories_outlined,
                    memoryLabel: 'New Lesson',
                    subtitle: isSabaqLocked
                        ? 'Traditional Madrasah Rule: Complete every Manzil and Sabqi portion before unlocking new Sabaq.'
                        : '',
                    isLocked: isSabaqLocked,
                  ),

                  const SizedBox(height: 16),

                  // Three-Tier Methodology Guide Card
                  _buildMethodologyCard(_tierLengthSettings),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildTierSection({
    required BuildContext context,
    required WidgetRef ref,
    required List<HifzTask> tasks,
    required String Function(HifzTask task) badgeBuilder,
    required Color badgeColor,
    required IconData icon,
    required String memoryLabel,
    required String subtitle,
    required bool isLocked,
  }) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var index = 0; index < tasks.length; index++) ...[
          _buildTierCard(
            context: context,
            ref: ref,
            task: tasks[index],
            badgeText: badgeBuilder(tasks[index]),
            badgeColor: badgeColor,
            icon: icon,
            memoryLabel: memoryLabel,
            subtitle: subtitle,
            isLocked: isLocked,
          ),
          if (index < tasks.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildManzilSection({
    required BuildContext context,
    required WidgetRef ref,
    required List<HifzTask> tasks,
  }) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalMinutes = tasks.fold<int>(
      0,
      (sum, task) => sum + (task.allocatedMinutes ?? 0),
    );
    final completed = tasks.every((task) => task.isCompleted);
    final repsDone = tasks
        .map((task) => task.completedReps)
        .reduce((a, b) => a < b ? a : b);
    final targetReps = tasks.first.targetReps;
    final rangesSummary = tasks
        .map(
          (task) =>
              '${task.surahNameEnglish} ${task.startAyah}-${task.endAyah}',
        )
        .join('  •  ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: completed
            ? const BorderSide(color: AppTheme.fluencyMastered, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync, size: 14, color: Colors.teal.shade700),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'STEP 1 • MANZIL ($totalMinutes m ~ 50%)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (completed) ...[
                  const SizedBox(width: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppTheme.fluencyMastered,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.fluencyMastered,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Long-term Memory — $rangesSummary',
              child: Row(
                children: [
                  const Text(
                    'Long-term Memory',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Text(
                    '  •  ',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Flexible(
                    child: Text(
                      rangesSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: targetReps > 0
                          ? (repsDone / targetReps).clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completed
                            ? AppTheme.fluencyMastered
                            : AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$repsDone / $targetReps reps',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PracticeSessionScreen(tasks: tasks),
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                backgroundColor: completed
                    ? Colors.grey.shade200
                    : AppTheme.primaryGreen,
                foregroundColor: completed ? Colors.black87 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                completed ? 'Review Again' : 'Start Session',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(int completed, int total, String timeLeft) {
    final progress = total > 0 ? (completed / total) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, Color(0xFF09422C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withAlpha(40),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.goldAccent,
                  ),
                  strokeWidth: 4,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Text(
            '$completed/$total done',
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.schedule_outlined,
            size: 15,
            color: Colors.white.withAlpha(200),
          ),
          const SizedBox(width: 5),
          Text(
            timeLeft,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required BuildContext context,
    required WidgetRef ref,
    required HifzTask task,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required String memoryLabel,
    required String subtitle,
    required bool isLocked,
  }) {
    final progress = (task.targetReps > 0)
        ? (task.completedReps / task.targetReps).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: task.isCompleted
            ? const BorderSide(color: AppTheme.fluencyMastered, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: badgeColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (task.isCompleted) ...[
                  const SizedBox(width: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppTheme.fluencyMastered,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.fluencyMastered,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Tooltip(
              message:
                  '$memoryLabel — ${task.surahNameEnglish} (Ayahs ${task.startAyah} - ${task.endAyah})',
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      memoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Text(
                    '  •  ',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Flexible(
                    child: Text(
                      '${task.surahNameEnglish} (${task.startAyah}-${task.endAyah})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isLocked
                            ? Colors.grey
                            : AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Tooltip(
                message: subtitle,
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isLocked
                        ? Colors.red.shade800
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.isCompleted
                            ? AppTheme.fluencyMastered
                            : AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${task.completedReps} / ${task.targetReps} reps',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isLocked
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PracticeSessionScreen(task: task),
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                backgroundColor: task.isCompleted
                    ? Colors.grey.shade200
                    : AppTheme.primaryGreen,
                foregroundColor: task.isCompleted
                    ? Colors.black87
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                task.isCompleted
                    ? 'Review Again'
                    : isLocked
                    ? 'Locked (Finish Steps 1 & 2 First)'
                    : 'Start Session',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodologyCard(HifzTierLengthSettings? settings) {
    final manzilLength = settings == null
        ? 'a customizable amount'
        : '${settings.manzilCount} ${_unitLabel(settings.manzilUnit, settings.manzilCount)}';
    final sabqiDays = settings?.sabqiDays;
    final sabaqLength = settings == null
        ? 'a customizable amount'
        : '${settings.sabaqCount} ${_unitLabel(settings.sabaqUnit, settings.sabaqCount)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardParchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppTheme.goldAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The Three-Tier Process Explained',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _methodologyItem(
            'Step 1: Manzil (Distant Revision ~ 50% Time)',
            'Reviews previously memorized Quran, moving forward $manzilLength per day. '
                'Length and unit are customizable in Lesson Length settings.',
          ),
          const SizedBox(height: 6),
          _methodologyItem(
            'Step 2: Sabqi (Recent Revision ~ 30% Time)',
            'Recites the previous ${sabqiDays ?? 'several'} day${sabqiDays == 1 ? '' : 's'} of sabaq '
                'to cement them into long-term memory before new intake.',
          ),
          const SizedBox(height: 6),
          _methodologyItem(
            'Step 3: Sabaq (New Lesson ~ 20% Time)',
            'Daily new lesson sized $sabaqLength. Locked in strict mode until both '
                'Manzil and Sabqi are completed.',
          ),
        ],
      ),
    );
  }

  String _unitLabel(HifzRangeUnit unit, int count) {
    final plural = count != 1;
    return switch (unit) {
      HifzRangeUnit.ayah => plural ? 'ayahs' : 'ayah',
      HifzRangeUnit.page => plural ? 'pages' : 'page',
      HifzRangeUnit.ruku => plural ? 'rukus' : 'ruku',
      HifzRangeUnit.juz => plural ? 'juz parts' : 'juz',
    };
  }

  Widget _methodologyItem(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.primaryGreen,
          ),
        ),
        Text(
          desc,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
