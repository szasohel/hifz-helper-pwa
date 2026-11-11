import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../hifz_engine/providers/hifz_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(recentDailyActivityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: activity.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load activity: $error')),
        data: (rows) {
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final row in rows) {
            final date = row['activity_date'] as String;
            grouped.putIfAbsent(date, () => []).add(row);
          }

          if (grouped.isEmpty) {
            return const Center(child: Text('No activity recorded yet.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final date = DateTime.tryParse(entry.key);
              final heading = date == null
                  ? entry.key
                  : DateFormat('EEEE, d MMMM yyyy').format(date);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heading,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...entry.value.map(_buildActivityRow),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> row) {
    final completed = row['status'] == 'completed';
    final tier = (row['tier_type'] as String).toUpperCase();
    final range =
        '${row['surah_number']}:${row['start_ayah']}-${row['end_ayah']}';
    final completedAt = row['completed_at'] as String?;
    final time = completedAt == null
        ? ''
        : ' • ${DateFormat('h:mm a').format(DateTime.parse(completedAt).toLocal())}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 19,
            color: completed ? AppTheme.primaryGreen : Colors.grey,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text('$tier  $range', style: const TextStyle(fontSize: 13)),
          ),
          Text(
            completed ? 'Completed$time' : 'Not completed',
            style: TextStyle(
              fontSize: 12,
              color: completed ? AppTheme.primaryGreen : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
