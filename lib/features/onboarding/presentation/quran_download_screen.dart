import 'package:flutter/material.dart';
import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../../core/services/quran_sync_service.dart';
import '../../dashboard/presentation/daily_dashboard_screen.dart';

class QuranDownloadScreen extends StatefulWidget {
  const QuranDownloadScreen({super.key});

  @override
  State<QuranDownloadScreen> createState() => _QuranDownloadScreenState();
}

class _QuranDownloadScreenState extends State<QuranDownloadScreen> {
  final QuranSyncService _syncService = QuranSyncService();
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = 'Ready to prepare your offline Quran library.';
  int _completedSurahs = 0;
  int _totalAyahs = 0;
  String? _errorMessage;

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusMessage = 'Connecting to UmmahAPI...';
    });

    _syncService.downloadAllQuran().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _progress = data.progress;
          _statusMessage = data.status;
          _completedSurahs = data.completedSurahs;
          _totalAyahs = data.totalAyahs;
        });

        if (data.progress >= 1.0) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DailyDashboardScreen()),
            );
          });
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download interrupted: $err. Please check your internet connection.';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryGreen.withAlpha(20),
              AppTheme.warmParchment,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withAlpha(60),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppTheme.goldAccent,
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppConstants.basmalaText,
                    style: AppTheme.arabicStyle(
                      fontSize: 26,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      ornamental: true,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Welcome to Hifz Helper',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B382B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your dedicated tool for self-memorization enforcing the classical Three-Tier process (Sabaq, Sabqi, Manzil).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.goldAccent.withAlpha(40),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.download_for_offline, color: AppTheme.primaryGreen),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Offline-First Storage',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      'One-time download: 114 Surahs, 6,236 Ayahs',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _isDownloading ? _progress : 0,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(_progress * 100).toInt()}%',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                              ),
                              Text(
                                '$_completedSurahs/114 Surahs ($_totalAyahs Ayahs)',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isDownloading ? null : _startDownload,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isDownloading
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Downloading Library...'),
                                      ],
                                    )
                                  : const Text(
                                      'Download Quran Data',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, color: AppTheme.goldAccent, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '0 API calls required for Quran reading once completed.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

