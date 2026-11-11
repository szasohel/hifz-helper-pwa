import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/constants.dart';
import '../../../../app/theme.dart';
import '../../../../core/data/quran_metadata.dart';
import '../../../../core/database/app_database.dart';
import '../../../hifz_engine/models/hifz_tier_model.dart';
import '../../../hifz_engine/providers/hifz_providers.dart';
import '../../../hifz_engine/services/three_tier_scheduler.dart';

class HifzSetupDialog extends ConsumerStatefulWidget {
  const HifzSetupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HifzSetupDialog(),
    );
  }

  @override
  ConsumerState<HifzSetupDialog> createState() => _HifzSetupDialogState();
}

class _HifzSetupDialogState extends ConsumerState<HifzSetupDialog> {
  final Set<int> _selectedKnownSurahs = {};
  int _targetSabaqSurah = 1;
  int _targetSabaqAyah = 1;
  String _hifzDirection = AppConstants.directionLastToFirst;
  int _dailyTimeMinutes = 60;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allSurahs = [];
  final TextEditingController _ayahCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _ayahCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final db = AppDatabase.instance;
    final scheduler = ref.read(schedulerProvider);
    var surahs = await db.getSurahs();
    if (surahs.isEmpty) {
      surahs = QuranMetadata.surahs;
    }
    final known = await scheduler.getKnownSurahs();
    final sabaqSurah = await scheduler.getCurrentSabaqSurah();
    final sabaqAyah = await scheduler.getCurrentSabaqAyah();
    final direction = await scheduler.getHifzDirection();
    final timeCommitment = await scheduler.getDailyTimeCommitment();

    if (mounted) {
      setState(() {
        _allSurahs = surahs;
        _selectedKnownSurahs.addAll(known);
        _targetSabaqSurah = sabaqSurah;
        _targetSabaqAyah = sabaqAyah;
        _hifzDirection = direction;
        _dailyTimeMinutes = timeCommitment;
        _ayahCtrl.text = '$_targetSabaqAyah';
        _isLoading = false;
      });
    }
  }

  void _suggestNextSabaq() {
    if (_hifzDirection == AppConstants.directionLastToFirst) {
      if (_selectedKnownSurahs.isEmpty || !_selectedKnownSurahs.contains(1)) {
        _targetSabaqSurah = 1;
        _targetSabaqAyah = 1;
      } else {
        int nextSurah = 114;
        for (int i = 114; i >= 2; i--) {
          if (!_selectedKnownSurahs.contains(i)) {
            nextSurah = i;
            break;
          }
        }
        _targetSabaqSurah = nextSurah;
        _targetSabaqAyah = 1;
      }
    } else {
      if (_selectedKnownSurahs.isEmpty) {
        _targetSabaqSurah = 1;
        _targetSabaqAyah = 1;
      } else {
        int nextSurah = 1;
        for (int i = 1; i <= 114; i++) {
          if (!_selectedKnownSurahs.contains(i)) {
            nextSurah = i;
            break;
          }
        }
        _targetSabaqSurah = nextSurah;
        _targetSabaqAyah = 1;
      }
    }
    _ayahCtrl.text = '$_targetSabaqAyah';
  }

  void _applyPreset(String preset) {
    setState(() {
      _selectedKnownSurahs.clear();
      if (preset == 'juz30') {
        _selectedKnownSurahs.add(1); // Al-Fatihah
        for (int i = 78; i <= 114; i++) {
          _selectedKnownSurahs.add(i);
        }
      } else if (preset == 'last10') {
        _selectedKnownSurahs.add(1); // Al-Fatihah
        for (int i = 105; i <= 114; i++) {
          _selectedKnownSurahs.add(i);
        }
      } else if (preset == 'popular') {
        _selectedKnownSurahs.addAll([1, 18, 36, 55, 56, 67]);
      } else if (preset == 'none') {
        _selectedKnownSurahs.clear();
      }
      _suggestNextSabaq();
    });
  }

  void _saveProfile() async {
    final scheduler = ref.read(schedulerProvider);
    await scheduler.saveHifzProfile(
      knownSurahs: _selectedKnownSurahs.toList()..sort(),
      currentSabaqSurah: _targetSabaqSurah,
      currentSabaqAyah: _targetSabaqAyah,
      direction: _hifzDirection,
      dailyTimeCommitment: _dailyTimeMinutes,
    );

    await ref.read(dailyTasksProvider.notifier).loadTodayTasks();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hifz Routine personalized successfully!'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeSplit = ThreeTierScheduler.calculateTimeSplit(_dailyTimeMinutes);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardParchment,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppTheme.primaryGreen, size: 24),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Personalize Hifz Strategy',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure learning direction, time allocation, and starting lessons.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SECTION 1: Direction
                          const Text(
                            '1. Progression Path (Hifz Direction)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _hifzDirection = AppConstants.directionLastToFirst;
                                      _suggestNextSabaq();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _hifzDirection == AppConstants.directionLastToFirst
                                          ? AppTheme.primaryGreen.withAlpha(25)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _hifzDirection == AppConstants.directionLastToFirst
                                            ? AppTheme.primaryGreen
                                            : Colors.grey.shade300,
                                        width: _hifzDirection == AppConstants.directionLastToFirst ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _hifzDirection == AppConstants.directionLastToFirst
                                                  ? Icons.radio_button_checked
                                                  : Icons.radio_button_off,
                                              size: 16,
                                              color: _hifzDirection == AppConstants.directionLastToFirst
                                                  ? AppTheme.primaryGreen
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 6),
                                            const Flexible(
                                              child: Text(
                                                'Last to First',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Juz 30 ➔ Baqarah\n(Madrasah standard)',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _hifzDirection = AppConstants.directionFirstToLast;
                                      _suggestNextSabaq();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _hifzDirection == AppConstants.directionFirstToLast
                                          ? AppTheme.primaryGreen.withAlpha(25)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _hifzDirection == AppConstants.directionFirstToLast
                                            ? AppTheme.primaryGreen
                                            : Colors.grey.shade300,
                                        width: _hifzDirection == AppConstants.directionFirstToLast ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _hifzDirection == AppConstants.directionFirstToLast
                                                  ? Icons.radio_button_checked
                                                  : Icons.radio_button_off,
                                              size: 16,
                                              color: _hifzDirection == AppConstants.directionFirstToLast
                                                  ? AppTheme.primaryGreen
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 6),
                                            const Flexible(
                                              child: Text(
                                                'First to Last',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fatiha ➔ Baqarah ➔ Nas\n(Front to back)',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // SECTION 2: Time Commitment & Targets
                          const Text(
                            '2. Daily Time Commitment & Three-Tier Allocation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [30, 45, 60, 90, 120].map((mins) {
                              final isSelected = _dailyTimeMinutes == mins;
                              return ChoiceChip(
                                label: Text('$mins min', style: const TextStyle(fontSize: 12)),
                                selected: isSelected,
                                selectedColor: AppTheme.primaryGreen.withAlpha(40),
                                onSelected: (sel) {
                                  if (sel) setState(() => _dailyTimeMinutes = mins);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),

                          // Live 50% / 30% / 20% Breakdown Card
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primaryGreen.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text('Step 1: Manzil', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text('${timeSplit[HifzTierType.manzil]}m (50%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                                      const Text('Distant Rev', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 28, color: Colors.grey.shade300),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text('Step 2: Sabqi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text('${timeSplit[HifzTierType.sabqi]}m (30%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.goldAccent)),
                                      const Text('Recent Rev', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 28, color: Colors.grey.shade300),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text('Step 3: Sabaq', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text('${timeSplit[HifzTierType.sabaq]}m (20%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                                      const Text('New Lesson', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Divider(height: 28),

                          // SECTION 3: Known Surahs Presets
                          const Text(
                            '3. What have you already memorized?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                label: const Text('🌟 Starting Fresh', style: TextStyle(fontSize: 11)),
                                onPressed: () => _applyPreset('none'),
                              ),
                              ActionChip(
                                label: const Text('📖 Juz 30 (Juz Amma)', style: TextStyle(fontSize: 11)),
                                onPressed: () => _applyPreset('juz30'),
                              ),
                              ActionChip(
                                label: const Text('🔟 Last 10 Surahs', style: TextStyle(fontSize: 11)),
                                onPressed: () => _applyPreset('last10'),
                              ),
                              ActionChip(
                                label: const Text('👑 Popular Surahs', style: TextStyle(fontSize: 11)),
                                onPressed: () => _applyPreset('popular'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Text(
                            'Selected: ${_selectedKnownSurahs.length} Surahs already memorized',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),

                          const SizedBox(height: 6),

                          // Collapsible Checklist for Custom Surah Selection
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text('Custom Selection (Pick specific Surahs)', style: TextStyle(fontSize: 12)),
                              tilePadding: EdgeInsets.zero,
                              children: [
                                Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListView.builder(
                                    itemCount: _allSurahs.length,
                                    itemBuilder: (context, index) {
                                      final s = _allSurahs[index];
                                      final num = s['number'] as int;
                                      final name = s['name_english'] as String;
                                      final isSelected = _selectedKnownSurahs.contains(num);

                                      return CheckboxListTile(
                                        dense: true,
                                        value: isSelected,
                                        activeColor: AppTheme.primaryGreen,
                                        title: Text('$num. $name', style: const TextStyle(fontSize: 13)),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedKnownSurahs.add(num);
                                            } else {
                                              _selectedKnownSurahs.remove(num);
                                            }
                                            _suggestNextSabaq();
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 28),

                          // SECTION 4: Sabaq Starting Point
                          const Text(
                            '4. Today\'s Sabaq Starting Point',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your next lesson starts here. For example, if you know up to \'Abasa Ayah 10, start from Ayah 11.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  initialValue: _allSurahs.any((s) => s['number'] == _targetSabaqSurah)
                                      ? _targetSabaqSurah
                                      : (_allSurahs.isNotEmpty ? _allSurahs.first['number'] as int : 1),
                                  decoration: InputDecoration(
                                    labelText: 'Current Surah',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: _allSurahs.map((s) {
                                    final num = s['number'] as int;
                                    final name = s['name_english'] as String;
                                    return DropdownMenuItem<int>(
                                      value: num,
                                      child: Text('$num. $name', style: const TextStyle(fontSize: 13)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _targetSabaqSurah = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _ayahCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Start Ayah',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  onChanged: (val) {
                                    final n = int.tryParse(val);
                                    if (n != null && n > 0) _targetSabaqAyah = n;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save & Rebuild Hifz Routine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}


