import 'package:flutter/material.dart';
import '../../../../app/constants.dart';
import '../../../../app/theme.dart';

class MushafSurahHeader extends StatelessWidget {
  final int surahNumber;
  final String nameArabic;
  final String nameEnglish;
  final int versesCount;
  final String revelationPlace;
  final String activeScript;

  const MushafSurahHeader({
    super.key,
    required this.surahNumber,
    required this.nameArabic,
    required this.nameEnglish,
    required this.versesCount,
    required this.revelationPlace,
    this.activeScript = 'uthmani',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMakkah = revelationPlace.toLowerCase() == 'makkah';
    final titleColor = isDark ? AppTheme.goldAccent : AppTheme.primaryGreen;

    return Column(
      children: [
        // Traditional Mushaf Surah Banner / Unwan
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.cardParchment,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.goldAccent.withAlpha(150),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.goldAccent.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Stack(
            children: [
              const Positioned(
                top: 8,
                left: 8,
                child: _HeaderOrnament(),
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: _HeaderOrnament(),
              ),
              const Positioned(
                bottom: 8,
                left: 8,
                child: _HeaderOrnament(),
              ),
              const Positioned(
                bottom: 8,
                right: 8,
                child: _HeaderOrnament(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _InfoPill(
                      alignment: CrossAxisAlignment.start,
                      primary: 'Surah $surahNumber',
                      secondary: '$versesCount Ayahs',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkBg.withAlpha(120) : Colors.white.withAlpha(170),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.goldAccent.withAlpha(120),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'سُورَةُ $nameArabic',
                            maxLines: 1,
                            style: AppTheme.arabicStyle(
                              script: activeScript,
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                              height: 1.4,
                              ornamental: true,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _InfoPill(
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

        // Bismillah Banner (All except Al-Fatihah & At-Tawbah)
        if (surahNumber != 1 && surahNumber != 9)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBg : AppTheme.warmParchment,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppConstants.basmalaText,
              textAlign: TextAlign.center,
              style: AppTheme.arabicStyle(
                script: activeScript,
                fontSize: 26,
                color: titleColor,
                fontWeight: FontWeight.bold,
                height: 1.55,
                ornamental: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final CrossAxisAlignment alignment;
  final String primary;
  final String secondary;
  final bool isDark;

  const _InfoPill({
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

class _HeaderOrnament extends StatelessWidget {
  const _HeaderOrnament();

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

