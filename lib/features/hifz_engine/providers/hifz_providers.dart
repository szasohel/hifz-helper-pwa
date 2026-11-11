import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hifz_helper/app/constants.dart';
import 'package:hifz_helper/core/database/app_database.dart';
import 'package:hifz_helper/features/hifz_engine/models/hifz_tier_model.dart';
import 'package:hifz_helper/features/hifz_engine/services/three_tier_scheduler.dart';

// Database & Scheduler Providers
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final schedulerProvider = Provider<ThreeTierScheduler>(
  (ref) => ThreeTierScheduler(db: ref.watch(databaseProvider)),
);
final recentDailyActivityProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(databaseProvider).getRecentDailyActivity(),
);

// Strict Mode Provider
class StrictModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(AppConstants.keyStrictMode) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyStrictMode, state);
  }
}

final strictModeProvider = NotifierProvider<StrictModeNotifier, bool>(
  StrictModeNotifier.new,
);

// Today's Three-Tier Tasks State
class DailyTasksState {
  final bool isLoading;
  final List<HifzTask> tasks;
  final String? errorMessage;

  DailyTasksState({
    this.isLoading = false,
    this.tasks = const [],
    this.errorMessage,
  });

  DailyTasksState copyWith({
    bool? isLoading,
    List<HifzTask>? tasks,
    String? errorMessage,
  }) {
    return DailyTasksState(
      isLoading: isLoading ?? this.isLoading,
      tasks: tasks ?? this.tasks,
      errorMessage: errorMessage,
    );
  }
}

class DailyTasksNotifier extends Notifier<DailyTasksState> {
  String? _validateCompletionForTasks(List<HifzTask> tasksToComplete) {
    final isStrict = ref.read(strictModeProvider);
    final scheduler = ref.read(schedulerProvider);
    final wouldCompleteSabaq = tasksToComplete.any(
      (task) => task.tierType == HifzTierType.sabaq,
    );

    if (!wouldCompleteSabaq) return null;
    return scheduler.validateSabaqCompletion(state.tasks, isStrict);
  }

  Future<void> _logCompletedTasks(List<HifzTask> tasks) async {
    final db = ref.read(databaseProvider);
    for (final task in tasks) {
      await db.saveDailyActivity(
        date: task.targetDate,
        tierType: task.tierType.name,
        surahNumber: task.surahNumber,
        startAyah: task.startAyah,
        endAyah: task.endAyah,
      );
      await db.markDailyActivityComplete(
        date: task.targetDate,
        tierType: task.tierType.name,
        surahNumber: task.surahNumber,
        startAyah: task.startAyah,
        endAyah: task.endAyah,
      );
      await db.logHifzSession(
        task.tierType.name,
        task.surahNumber,
        task.startAyah,
        task.endAyah,
        task.targetReps,
        date: task.targetDate,
      );
    }
    ref.invalidate(recentDailyActivityProvider);
  }

  Future<void> _reopenCompletedTasks(List<HifzTask> tasks) async {
    final db = ref.read(databaseProvider);
    for (final task in tasks) {
      await db.markDailyActivityPending(
        date: task.targetDate,
        tierType: task.tierType.name,
        surahNumber: task.surahNumber,
        startAyah: task.startAyah,
        endAyah: task.endAyah,
      );
      await db.deleteHifzSession(
        date: task.targetDate,
        tierType: task.tierType.name,
        surahNumber: task.surahNumber,
        startAyah: task.startAyah,
        endAyah: task.endAyah,
      );
    }
    ref.invalidate(recentDailyActivityProvider);
  }

  @override
  DailyTasksState build() {
    Future.microtask(() async {
      // Skip auto-generation until the user finishes onboarding, otherwise
      // default (Al-Fatihah) tasks get persisted for today and race with the
      // profile-based tasks generated right after the setup dialog is saved.
      final scheduler = ref.read(schedulerProvider);
      if (await scheduler.isProfileConfigured()) {
        await loadTodayTasks();
      } else {
        state = state.copyWith(isLoading: false);
      }
    });
    return DailyTasksState(isLoading: true);
  }

  Future<void> loadTodayTasks() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final scheduler = ref.read(schedulerProvider);
      final tasks = await scheduler.getOrGenerateTodayTasks();
      state = state.copyWith(isLoading: false, tasks: tasks);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> applyTierLengthSettings({
    required HifzTierLengthSettings settings,
    required Set<HifzTierType> affectedTiers,
  }) async {
    final scheduler = ref.read(schedulerProvider);
    final tasks = await scheduler.applyTierLengthSettings(
      settings: settings,
      affectedTiers: affectedTiers,
    );
    state = state.copyWith(isLoading: false, tasks: tasks, errorMessage: null);
  }

  Future<String?> incrementRepetition(int taskId) async {
    final taskIndex = state.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return null;

    final task = state.tasks[taskIndex];
    final db = ref.read(databaseProvider);

    // If task is Sabaq, check if Sabqi is finished when completing
    final nextReps = task.completedReps + 1;
    final willComplete = nextReps >= task.targetReps;

    if (willComplete) {
      final validationError = _validateCompletionForTasks([task]);
      if (validationError != null) {
        return validationError;
      }
    }

    final updatedTask = task.copyWith(
      completedReps: nextReps,
      isCompleted: willComplete,
    );

    await db.updateTaskProgress(taskId, nextReps, willComplete);

    if (willComplete && !task.isCompleted) {
      await _logCompletedTasks([updatedTask]);
    }

    final newTasks = List<HifzTask>.from(state.tasks);
    newTasks[taskIndex] = updatedTask;
    state = state.copyWith(tasks: newTasks);
    return null;
  }

  Future<String?> incrementRepetitionBatch(List<int> taskIds) async {
    final indexes = taskIds
        .map((taskId) => state.tasks.indexWhere((task) => task.id == taskId))
        .where((index) => index != -1)
        .toList();
    if (indexes.isEmpty) return null;

    final selectedTasks = indexes.map((index) => state.tasks[index]).toList();
    final nextTasks = <HifzTask>[];
    final newlyCompleted = <HifzTask>[];
    for (final task in selectedTasks) {
      final nextReps = task.completedReps + 1;
      final willComplete = nextReps >= task.targetReps;
      final updated = task.copyWith(
        completedReps: nextReps,
        isCompleted: willComplete,
      );
      nextTasks.add(updated);
      if (willComplete && !task.isCompleted) {
        newlyCompleted.add(updated);
      }
    }

    if (newlyCompleted.isNotEmpty) {
      final validationError = _validateCompletionForTasks(newlyCompleted);
      if (validationError != null) {
        return validationError;
      }
    }

    final db = ref.read(databaseProvider);
    for (var index = 0; index < selectedTasks.length; index++) {
      final original = selectedTasks[index];
      final updated = nextTasks[index];
      await db.updateTaskProgress(
        original.id!,
        updated.completedReps,
        updated.isCompleted,
      );
    }
    await _logCompletedTasks(newlyCompleted);

    final newTasks = List<HifzTask>.from(state.tasks);
    for (var index = 0; index < indexes.length; index++) {
      newTasks[indexes[index]] = nextTasks[index];
    }
    state = state.copyWith(tasks: newTasks);
    return null;
  }

  Future<String?> toggleTaskCompleted(int taskId) async {
    final taskIndex = state.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return null;

    final task = state.tasks[taskIndex];
    final db = ref.read(databaseProvider);
    final targetCompleted = !task.isCompleted;

    if (targetCompleted) {
      final validationError = _validateCompletionForTasks([task]);
      if (validationError != null) {
        return validationError;
      }
    }

    final updatedTask = task.copyWith(
      isCompleted: targetCompleted,
      completedReps: targetCompleted ? task.targetReps : 0,
    );

    await db.updateTaskProgress(
      taskId,
      updatedTask.completedReps,
      targetCompleted,
    );

    if (targetCompleted) {
      await _logCompletedTasks([updatedTask]);
    } else {
      await _reopenCompletedTasks([task]);
    }

    final newTasks = List<HifzTask>.from(state.tasks);
    newTasks[taskIndex] = updatedTask;
    state = state.copyWith(tasks: newTasks);
    return null;
  }

  Future<String?> toggleTaskCompletedBatch(List<int> taskIds) async {
    final indexes = taskIds
        .map((taskId) => state.tasks.indexWhere((task) => task.id == taskId))
        .where((index) => index != -1)
        .toList();
    if (indexes.isEmpty) return null;

    final selectedTasks = indexes.map((index) => state.tasks[index]).toList();
    final targetCompleted = selectedTasks.any((task) => !task.isCompleted);

    if (targetCompleted) {
      final validationError = _validateCompletionForTasks(selectedTasks);
      if (validationError != null) {
        return validationError;
      }
    }

    final updatedTasks = <HifzTask>[];
    final newlyCompleted = <HifzTask>[];
    for (final task in selectedTasks) {
      final updated = task.copyWith(
        isCompleted: targetCompleted,
        completedReps: targetCompleted ? task.targetReps : 0,
      );
      updatedTasks.add(updated);
      if (targetCompleted && !task.isCompleted) {
        newlyCompleted.add(updated);
      }
    }

    final db = ref.read(databaseProvider);
    for (var index = 0; index < selectedTasks.length; index++) {
      final updated = updatedTasks[index];
      await db.updateTaskProgress(
        updated.id!,
        updated.completedReps,
        updated.isCompleted,
      );
    }

    if (targetCompleted) {
      await _logCompletedTasks(newlyCompleted);
    } else {
      await _reopenCompletedTasks(selectedTasks);
    }

    final newTasks = List<HifzTask>.from(state.tasks);
    for (var index = 0; index < indexes.length; index++) {
      newTasks[indexes[index]] = updatedTasks[index];
    }
    state = state.copyWith(tasks: newTasks);
    return null;
  }
}

final dailyTasksProvider =
    NotifierProvider<DailyTasksNotifier, DailyTasksState>(
      DailyTasksNotifier.new,
    );
