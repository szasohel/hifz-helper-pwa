import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'app/constants.dart';
import 'app/theme.dart';
import 'core/services/quran_sync_service.dart';
import 'features/dashboard/presentation/daily_dashboard_screen.dart';
import 'features/settings/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the screen on while the app is in the foreground (OS stops applying it when backgrounded)
  unawaited(WakelockPlus.enable());

  // Ensure lightweight Surah directory (114 names/counts) is loaded in background
  final syncService = QuranSyncService();
  syncService.ensureSurahDirectoryLoaded();

  runApp(
    const ProviderScope(
      child: HifzHelperApp(),
    ),
  );
}

class HifzHelperApp extends ConsumerWidget {
  const HifzHelperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: settings.themeMode,
      home: const DailyDashboardScreen(),
    );
  }
}
