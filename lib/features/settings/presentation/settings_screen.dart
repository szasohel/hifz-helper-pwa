import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../hifz_engine/providers/hifz_providers.dart';
import '../../dashboard/presentation/widgets/hifz_setup_dialog.dart';
import '../providers/settings_provider.dart';
import 'activity_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final isStrict = ref.watch(strictModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Script Style Selection
          _buildSectionHeader('ARABIC SCRIPT & TYPOGRAPHY', Icons.font_download_outlined),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOptionTile(
                    title: 'Uthmani (Madani Standard)',
                    subtitle: 'The global standard Medina Mushaf script.',
                    isSelected: settings.activeScript == 'uthmani',
                    onTap: () => settingsNotifier.setScript('uthmani'),
                  ),
                  const Divider(height: 12),
                  _buildOptionTile(
                    title: 'Indo-Pak Script',
                    subtitle: 'Classic South Asian script with prominent diacritics.',
                    isSelected: settings.activeScript == 'indopak',
                    onTap: () => settingsNotifier.setScript('indopak'),
                  ),
                  const SizedBox(height: 14),
                  // Live Arabic Sample Preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBg : AppTheme.warmParchment,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.mushafBorder),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Preview (${settings.activeScript.toUpperCase()}):',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConstants.basmalaText,
                          style: AppTheme.arabicStyle(
                            script: settings.activeScript,
                            fontSize: 24,
                            color: isDark ? AppTheme.goldAccent : AppTheme.primaryGreen,
                            ornamental: true,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. Reciter Selection
          _buildSectionHeader('AUDIO RECITER', Icons.record_voice_over_outlined),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildOptionTile(
                    title: 'Mahmoud Khalil Al-Husary',
                    subtitle: 'Slow, deliberate Tajweed gold-standard for precise Hifz.',
                    isSelected: settings.activeReciter == AppConstants.reciterHusary,
                    onTap: () => settingsNotifier.setReciter(AppConstants.reciterHusary),
                  ),
                  const Divider(height: 12),
                  _buildOptionTile(
                    title: 'Mishary Rashid Alafasy',
                    subtitle: 'Melodious, clear recitation.',
                    isSelected: settings.activeReciter == AppConstants.reciterAlafasy,
                    onTap: () => settingsNotifier.setReciter(AppConstants.reciterAlafasy),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. Theme Mode (Day / Night)
          _buildSectionHeader('APPEARANCE & THEME', Icons.palette_outlined),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildOptionTile(
                    title: 'Day Mode (Warm Quranic Parchment)',
                    subtitle: 'Gentle antique cream page texture for daylight reading.',
                    isSelected: settings.themeMode == ThemeMode.light,
                    onTap: () => settingsNotifier.setThemeMode(ThemeMode.light),
                  ),
                  const Divider(height: 12),
                  _buildOptionTile(
                    title: 'Night Mode (Midnight Tahajjud)',
                    subtitle: 'Deep dark slate palette reducing eye strain in the dark.',
                    isSelected: settings.themeMode == ThemeMode.dark,
                    onTap: () => settingsNotifier.setThemeMode(ThemeMode.dark),
                  ),
                  const Divider(height: 12),
                  _buildOptionTile(
                    title: 'System Default',
                    subtitle: 'Follows system dark/light mode setting.',
                    isSelected: settings.themeMode == ThemeMode.system,
                    onTap: () => settingsNotifier.setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Hifz routine and personalization
          _buildSectionHeader('PERSONALIZED HIFZ ROUTINE', Icons.tune_outlined),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note, color: AppTheme.primaryGreen),
              title: const Text('Personalize Hifz Strategy', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Adjust progression, known Surahs, daily time, and Sabaq target.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => HifzSetupDialog.show(context),
            ),
          ),

          const SizedBox(height: 20),

          _buildSectionHeader('PROGRESS', Icons.insights_outlined),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_outlined, color: AppTheme.primaryGreen),
              title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Review your Manzil, Sabqi, and Sabaq activity for the last 30 days.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ActivityScreen()),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 4. Three-Tier Hifz Strictness
          _buildSectionHeader('HIFZ METHODOLOGY ENFORCEMENT', Icons.shield_outlined),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile.adaptive(
              value: isStrict,
              activeTrackColor: AppTheme.primaryGreen,
              title: const Text('Strict Three-Tier Locking', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                'Enforces the classical madrasah rule: you cannot mark new Sabaq done until today\'s Sabqi (recent revision) is completed.',
              ),
              onChanged: (_) => ref.read(strictModeProvider.notifier).toggle(),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryGreen : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.antiqueGold),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.antiqueGold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

