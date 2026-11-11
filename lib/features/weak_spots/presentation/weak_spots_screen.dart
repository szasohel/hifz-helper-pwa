import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/database/app_database.dart';

class WeakSpotsScreen extends StatefulWidget {
  const WeakSpotsScreen({super.key});

  @override
  State<WeakSpotsScreen> createState() => _WeakSpotsScreenState();
}

class _WeakSpotsScreenState extends State<WeakSpotsScreen> {
  List<Map<String, dynamic>> _weakAyahs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeakAyahs();
  }

  Future<void> _loadWeakAyahs() async {
    final list = await AppDatabase.instance.getWeakAyahs();
    if (mounted) {
      setState(() {
        _weakAyahs = list;
        _isLoading = false;
      });
    }
  }

  void _markResolved(int surahNum, int ayahNum) async {
    await AppDatabase.instance.resolveAyahFluency(surahNum, ayahNum);
    _loadWeakAyahs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ayah $surahNum:$ayahNum marked as Mastered!'),
          backgroundColor: AppTheme.fluencyMastered,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weak Spots & Mistakes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _weakAyahs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.fluencyMastered.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          size: 56,
                          color: AppTheme.fluencyMastered,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Weak Spots Recorded!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'When you flag hesitations or mistakes during practice sessions, they will automatically appear here for targeted review.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _weakAyahs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _weakAyahs[index];
                    final surahName = item['name_english'] as String;
                    final surahArabic = item['name_arabic'] as String;
                    final surahNum = item['surah_number'] as int;
                    final ayahNum = item['ayah_number'] as int;
                    final arabicText = item['arabic'] as String;
                    final mistakeCount = item['mistake_count'] as int;
                    final status = item['status'] as String;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (status == 'weak' ? AppTheme.fluencyWeak : AppTheme.fluencyHesitant)
                                        .withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$surahName ($surahArabic) • Ayah $ayahNum',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: status == 'weak' ? AppTheme.fluencyWeak : AppTheme.fluencyHesitant,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$mistakeCount mistake${mistakeCount > 1 ? 's' : ''}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              arabicText,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: AppTheme.arabicStyle(fontSize: 22, text: arabicText),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _markResolved(surahNum, ayahNum),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Mark Fluent'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.fluencyMastered,
                                    side: const BorderSide(color: AppTheme.fluencyMastered),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

