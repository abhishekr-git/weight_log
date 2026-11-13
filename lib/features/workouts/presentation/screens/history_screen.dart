import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app_settings.dart';
import '../../../../core/utils/calendar.dart';
import '../../domain/entities/workout.dart';
import '../controllers/service_providers.dart';
import '../controllers/workout_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider);
    final templates =
        ref.watch(weeklyTemplatesProvider).valueOrNull ?? const [];
    final unitSystem = ref.watch(appSettingsProvider).unitSystem;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: () async {
              final logs = await ref.read(workoutRepositoryProvider).history();
              final csv =
                  ref.read(csvExportServiceProvider).workoutHistory(logs);
              await Share.share(csv, subject: 'WeightLog workout history.csv');
            },
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: history.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No workouts logged yet.'));
          }
          final grouped = _groupByMonth(logs);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in grouped.entries) ...[
                Text(
                  DateFormat('yyyy MMMM').format(entry.key),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final log in entry.value)
                  _TimelineTile(
                    log: log,
                    title: _templateName(templates, log.templateUid),
                    unitSystem: unitSystem,
                    onTap: () => _showDetails(context, log, unitSystem),
                  ),
                const SizedBox(height: 18),
              ],
            ],
          );
        },
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Map<DateTime, List<WorkoutLog>> _groupByMonth(List<WorkoutLog> logs) {
    final grouped = <DateTime, List<WorkoutLog>>{};
    for (final log in logs) {
      final key = DateTime(log.workoutDate.year, log.workoutDate.month);
      grouped.putIfAbsent(key, () => []).add(log);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _templateName(List<WorkoutTemplate> templates, String uid) {
    final matches = templates.where((template) => template.uid == uid);
    return matches.isEmpty ? 'Workout' : matches.first.name;
  }

  void _showDetails(
      BuildContext context, WorkoutLog log, UnitSystem unitSystem) {
    final byExercise = <String, List<SetLog>>{};
    for (final set in log.sets) {
      byExercise.putIfAbsent(set.exerciseName, () => []).add(set);
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              compactDate(log.workoutDate),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            for (final entry in byExercise.entries) ...[
              Text(
                entry.key,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              for (final set
                  in entry.value
                    ..sort((a, b) => a.setNumber.compareTo(b.setNumber)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_weight(set.weight, unitSystem)} ${unitLabel(unitSystem)} x ${set.reps}',
                  ),
                ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  String _weight(double value, UnitSystem unitSystem) {
    return formatDisplayWeight(value, unitSystem);
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.log,
    required this.title,
    required this.unitSystem,
    required this.onTap,
  });

  final WorkoutLog log;
  final String title;
  final UnitSystem unitSystem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sets = log.sets.length;
    final volume = log.sets.fold<double>(0, (sum, set) => sum + set.volume);
    final displayedVolume = displayWeight(volume, unitSystem);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(DateFormat('EEE').format(log.workoutDate)),
              Text(
                DateFormat('d').format(log.workoutDate),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          title: Text(title),
          subtitle: Text(
            '${DateFormat('d MMM yyyy').format(log.workoutDate)} - $sets sets - ${displayedVolume.toStringAsFixed(0)} ${unitLabel(unitSystem)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
