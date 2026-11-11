enum HifzTierType {
  sabaq,   // New lesson
  sabqi,   // Recent revision (last 5-7 days)
  manzil,  // Distant revision (mastered portions)
}

enum FluencyLevel {
  unmarked,
  strong,   // Fluent without mistakes
  hesitant, // Needed a pause or prompt
  weak,     // Stumbled or made a major error
}

enum HifzRangeUnit { ayah, page, ruku, juz }

class HifzTierLengthSettings {
  final HifzRangeUnit sabaqUnit;
  final int sabaqCount;
  final int sabqiDays;
  final HifzRangeUnit manzilUnit;
  final int manzilCount;

  const HifzTierLengthSettings({
    this.sabaqUnit = HifzRangeUnit.ayah,
    this.sabaqCount = 5,
    this.sabqiDays = 5,
    this.manzilUnit = HifzRangeUnit.ruku,
    this.manzilCount = 4,
  });

  void validate() {
    if (sabaqCount <= 0 || manzilCount <= 0) {
      throw ArgumentError('Tier lengths must be positive.');
    }
    if (sabaqUnit == HifzRangeUnit.juz) {
      throw ArgumentError('Sabaq must use Ayah, Page, or Ruku.');
    }
    if (sabaqUnit == HifzRangeUnit.ayah &&
        !const {5, 7, 10, 12, 15}.contains(sabaqCount)) {
      throw ArgumentError('Ayah-based Sabaq must use an available preset.');
    }
    if (!const {5, 7, 10}.contains(sabqiDays)) {
      throw ArgumentError('Sabqi days must be 5, 7, or 10.');
    }
    if (manzilUnit == HifzRangeUnit.ayah) {
      throw ArgumentError('Manzil must use Ruku, Page, or Juz.');
    }
  }
}

class HifzTask {
  final int? id;
  final HifzTierType tierType;
  final String title;
  final int surahNumber;
  final String surahNameArabic;
  final String surahNameEnglish;
  final int startAyah;
  final int endAyah;
  final String targetDate;
  final bool isCompleted;
  final int targetReps;
  final int completedReps;
  final String? notes;
  final int? allocatedMinutes;
  final int? stepNumber;

  HifzTask({
    this.id,
    required this.tierType,
    required this.title,
    required this.surahNumber,
    required this.surahNameArabic,
    required this.surahNameEnglish,
    required this.startAyah,
    required this.endAyah,
    required this.targetDate,
    this.isCompleted = false,
    this.targetReps = 10,
    this.completedReps = 0,
    this.notes,
    this.allocatedMinutes,
    this.stepNumber,
  });

  HifzTask copyWith({
    int? id,
    HifzTierType? tierType,
    String? title,
    int? surahNumber,
    String? surahNameArabic,
    String? surahNameEnglish,
    int? startAyah,
    int? endAyah,
    String? targetDate,
    bool? isCompleted,
    int? targetReps,
    int? completedReps,
    String? notes,
    int? allocatedMinutes,
    int? stepNumber,
  }) {
    return HifzTask(
      id: id ?? this.id,
      tierType: tierType ?? this.tierType,
      title: title ?? this.title,
      surahNumber: surahNumber ?? this.surahNumber,
      surahNameArabic: surahNameArabic ?? this.surahNameArabic,
      surahNameEnglish: surahNameEnglish ?? this.surahNameEnglish,
      startAyah: startAyah ?? this.startAyah,
      endAyah: endAyah ?? this.endAyah,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      targetReps: targetReps ?? this.targetReps,
      completedReps: completedReps ?? this.completedReps,
      notes: notes ?? this.notes,
      allocatedMinutes: allocatedMinutes ?? this.allocatedMinutes,
      stepNumber: stepNumber ?? this.stepNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tier_type': tierType.name,
      'title': title,
      'surah_number': surahNumber,
      'start_ayah': startAyah,
      'end_ayah': endAyah,
      'target_date': targetDate,
      'is_completed': isCompleted ? 1 : 0,
      'target_reps': targetReps,
      'completed_reps': completedReps,
      'notes': notes,
    };
  }

  factory HifzTask.fromMap(Map<String, dynamic> map, {
    String surahArabic = '',
    String surahEnglish = '',
    int? allocatedMinutes,
    int? stepNumber,
  }) {
    return HifzTask(
      id: map['id'] as int?,
      tierType: HifzTierType.values.byName(map['tier_type'] as String),
      title: map['title'] as String? ?? '',
      surahNumber: map['surah_number'] as int,
      surahNameArabic: surahArabic,
      surahNameEnglish: surahEnglish,
      startAyah: map['start_ayah'] as int,
      endAyah: map['end_ayah'] as int,
      targetDate: map['target_date'] as String,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      targetReps: map['target_reps'] as int? ?? 10,
      completedReps: map['completed_reps'] as int? ?? 0,
      notes: map['notes'] as String?,
      allocatedMinutes: allocatedMinutes,
      stepNumber: stepNumber,
    );
  }
}

