DateTime nextLocalMidnight(DateTime now) {
  if (now.isUtc) {
    return DateTime.utc(now.year, now.month, now.day + 1);
  }
  return DateTime(now.year, now.month, now.day + 1);
}

String formatCountdown(Duration remaining) {
  final totalSeconds = remaining.inMilliseconds <= 0
      ? 0
      : (remaining.inMilliseconds + 999) ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String timeUntilNextLocalMidnight(DateTime now) {
  return formatCountdown(nextLocalMidnight(now).difference(now));
}
