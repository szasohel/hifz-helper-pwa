import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/ummah_api_client.dart';

class WordMeaningSheet extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;
  final int wordPosition; // 1-indexed
  final String fallbackArabicWord;
  final String activeScript;

  const WordMeaningSheet({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.wordPosition,
    required this.fallbackArabicWord,
    this.activeScript = 'uthmani',
  });

  static Future<void> show(
    BuildContext context, {
    required int surahNumber,
    required int ayahNumber,
    required int wordPosition,
    required String fallbackArabicWord,
    String activeScript = 'uthmani',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordMeaningSheet(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        wordPosition: wordPosition,
        fallbackArabicWord: fallbackArabicWord,
        activeScript: activeScript,
      ),
    );
  }

  @override
  State<WordMeaningSheet> createState() => _WordMeaningSheetState();
}

class _WordMeaningSheetState extends State<WordMeaningSheet> {
  bool _isLoading = true;
  String _arabic = '';
  String _transliteration = '';
  String _meaning = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _arabic = widget.fallbackArabicWord;
    _loadWordDetails();
  }

  Future<void> _loadWordDetails() async {
    final db = AppDatabase.instance;
    // 1. Try local cache first
    final cached = await db.getCachedWords(widget.surahNumber, widget.ayahNumber);
    if (cached.isNotEmpty) {
      final match = cached.firstWhere(
        (w) => (w['position'] as int) == widget.wordPosition,
        orElse: () => cached.first,
      );
      if (mounted) {
        setState(() {
          _arabic = match['arabic'] as String? ?? widget.fallbackArabicWord;
          _transliteration = match['transliteration'] as String? ?? '';
          _meaning = match['translation'] as String? ?? '';
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Fetch from UmmahAPI
    try {
      final client = UmmahApiClient();
      final words = await client.fetchAyahWords(widget.surahNumber, widget.ayahNumber);
      if (words.isNotEmpty) {
        await db.cacheWords(widget.surahNumber, widget.ayahNumber, words);
        final match = words.firstWhere(
          (w) => (w['position'] as int? ?? 1) == widget.wordPosition,
          orElse: () => words.first,
        );

        if (mounted) {
          setState(() {
            _arabic = match['arabic'] as String? ?? widget.fallbackArabicWord;
            final translit = match['transliteration'];
            _transliteration = translit is Map
                ? (translit['text'] as String? ?? '')
                : (translit as String? ?? '');
            _meaning = match['translation'] as String? ?? '';
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Online pronunciation lookup unavailable offline.';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardParchment,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Surah ${widget.surahNumber}:${widget.ayahNumber} • Word ${widget.wordPosition}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                  tooltip: 'Copy Word',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '$_arabic - $_meaning'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied word to clipboard')),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Arabic Word Calligraphy
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBg : AppTheme.warmParchment,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.mushafBorder,
                  width: 1,
                ),
              ),
              child: Text(
                _arabic,
                textAlign: TextAlign.center,
                style: AppTheme.arabicStyle(
                  script: widget.activeScript,
                  fontSize: 36,
                  color: isDark ? AppTheme.darkInk : AppTheme.quranInk,
                  text: _arabic,
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              // Pronunciation Section
              if (_transliteration.isNotEmpty)
                _buildInfoRow(
                  icon: Icons.record_voice_over_outlined,
                  title: 'Pronunciation (Phonetic)',
                  value: _transliteration,
                  color: AppTheme.antiqueGold,
                ),

              const SizedBox(height: 12),

              // Meaning Section
              if (_meaning.isNotEmpty)
                _buildInfoRow(
                  icon: Icons.translate_rounded,
                  title: 'Word Meaning',
                  value: _meaning,
                  color: AppTheme.primaryGreen,
                ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
