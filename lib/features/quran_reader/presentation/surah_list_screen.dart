import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/services/quran_sync_service.dart';
import 'surah_reader_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  final QuranSyncService _syncService = QuranSyncService();
  List<Map<String, dynamic>> _surahs = [];
  List<Map<String, dynamic>> _filtered = [];
  Set<int> _downloadedSurahs = {};
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  Future<void> _loadSurahs() async {
    final list = await _syncService.ensureSurahDirectoryLoaded();
    final downloaded = await _syncService.getDownloadedSurahNumbers();
    if (mounted) {
      setState(() {
        _surahs = list;
        _filtered = list;
        _downloadedSurahs = downloaded;
        _isLoading = false;
      });
    }
  }

  void _filter(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filtered = _surahs);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filtered = _surahs.where((s) {
        final eng = (s['name_english'] as String).toLowerCase();
        final arabic = s['name_arabic'] as String;
        final num = s['number'].toString();
        return eng.contains(q) || arabic.contains(q) || num == q;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Directory'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Search Surah by name or number...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen),
                      filled: true,
                      fillColor: AppTheme.cardParchment,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.primaryGreen,
                    onRefresh: () async {
                      QuranSyncService.clearMemoryCache();
                      await _loadSurahs();
                    },
                    child: _filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_outlined,
                                      size: 54,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchCtrl.text.isEmpty
                                          ? 'No Surahs found'
                                          : 'No matching Surah found',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        setState(() => _isLoading = true);
                                        QuranSyncService.clearMemoryCache();
                                        await _loadSurahs();
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Reload Surahs'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final surah = _filtered[index];
                              final number = surah['number'] as int;
                              final nameEng = surah['name_english'] as String;
                              final nameArabic = surah['name_arabic'] as String;
                              final versesCount = surah['verses_count'] as int;
                              final revelation = surah['revelation_place'] as String? ?? '';
                              final isDownloaded = _downloadedSurahs.contains(number);

                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen.withAlpha(20),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$number',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          nameEng,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isDownloaded) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.fluencyMastered.withAlpha(25),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check, size: 10, color: AppTheme.fluencyMastered),
                                              SizedBox(width: 2),
                                              Text(
                                                'Offline',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.fluencyMastered,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text('$versesCount Ayahs • ${revelation.toUpperCase()}'),
                                  trailing: Text(
                                    nameArabic,
                                    style: AppTheme.arabicStyle(fontSize: 20, color: AppTheme.primaryGreen),
                                  ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SurahReaderScreen(surah: surah),
                                      ),
                                    );
                                    // Refresh downloaded set when returning
                                    final updated = await _syncService.getDownloadedSurahNumbers();
                                    if (mounted) setState(() => _downloadedSurahs = updated);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
