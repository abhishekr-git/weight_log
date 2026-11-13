import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_settings.dart';
import '../../../../core/utils/calendar.dart';
import '../../domain/entities/workout.dart';
import '../controllers/service_providers.dart';
import '../controllers/workout_providers.dart';
import '../widgets/exercise_logger_card.dart';

class WorkoutSessionScreen extends ConsumerWidget {
  const WorkoutSessionScreen({required this.templateId, this.date, super.key});

  final String templateId;
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(weeklyTemplatesProvider);

    return templates.when(
      data: (items) {
        final template = items.firstWhere((item) => item.uid == templateId);
        final workoutDate = date ?? dayInCurrentWeek(template.weekday);
        final args = WorkoutSessionArgs(
            templateUid: template.uid, workoutDate: workoutDate);
        final session = ref.watch(activeSessionProvider(args));

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name),
                Text(
                  compactDate(workoutDate),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Add exercise',
                onPressed: () => _showExerciseSheet(context, ref, template.uid),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Finish workout',
                onPressed: () async {
                  await _confirmFinish(context, ref, args);
                },
                icon: const Icon(Icons.check_circle_outline),
              ),
            ],
          ),
          body: session.when(
            data: (log) => template.exercises.isEmpty
                ? _EmptyWorkout(
                    onAdd: () => _showExerciseSheet(context, ref, template.uid))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: template.exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exercise = template.exercises[index];
                      final sets = log.sets
                          .where((set) => set.exerciseUid == exercise.uid)
                          .toList();
                      final performance = ref.watch(
                        exercisePerformanceProvider(
                          ExercisePerformanceArgs(
                            exerciseUid: exercise.uid,
                            templateUid: template.uid,
                            workoutDate: workoutDate,
                          ),
                        ),
                      );
                      return ExerciseLoggerCard(
                        exercise: exercise,
                        sets: sets,
                        performance: performance,
                        onLogSet: (weight, reps) async {
                          await ref
                              .read(activeSessionProvider(args).notifier)
                              .logSet(
                                exercise: exercise,
                                weight: weight,
                                reps: reps,
                              );
                          if (ref
                              .read(appSettingsProvider)
                              .cloudBackupEnabled) {
                            unawaited(ref
                                .read(syncServiceProvider)
                                .syncNow()
                                .catchError((_) => false));
                          }
                        },
                        onUpdateSet: (set, weight, reps) => ref
                            .read(activeSessionProvider(args).notifier)
                            .updateSet(set: set, weight: weight, reps: reps),
                        onDeleteSet: (set) => ref
                            .read(activeSessionProvider(args).notifier)
                            .deleteSet(set),
                        onExerciseActions: () => _showExerciseActions(
                          context,
                          ref,
                          args,
                          template.uid,
                          exercise,
                        ),
                      );
                    },
                  ),
            error: (error, stackTrace) => Center(child: Text(error.toString())),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        );
      },
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text(error.toString()))),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }

  Future<void> _showExerciseSheet(
      BuildContext context, WidgetRef ref, String templateUid) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add exercise', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Exercise'),
              onSubmitted: (_) =>
                  _saveExercise(context, ref, templateUid, controller.text),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  _saveExercise(context, ref, templateUid, controller.text),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExercise(BuildContext context, WidgetRef ref,
      String templateUid, String name) async {
    await ref
        .read(workoutRepositoryProvider)
        .addExercise(templateUid: templateUid, exerciseName: name);
    ref.invalidate(weeklyTemplatesProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _showExerciseActions(
    BuildContext context,
    WidgetRef ref,
    WorkoutSessionArgs args,
    String templateUid,
    ExerciseTemplate exercise,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Exercise Name'),
              onTap: () async {
                Navigator.of(context).pop();
                await _renameExercise(context, ref, args, exercise);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate Exercise'),
              onTap: () async {
                await ref
                    .read(activeSessionProvider(args).notifier)
                    .duplicateExercise(
                        templateUid: templateUid, exercise: exercise);
                ref.invalidate(weeklyTemplatesProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Exercise'),
              onTap: () async {
                await ref
                    .read(activeSessionProvider(args).notifier)
                    .deleteExercise(exercise);
                ref.invalidate(weeklyTemplatesProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameExercise(
    BuildContext context,
    WidgetRef ref,
    WorkoutSessionArgs args,
    ExerciseTemplate exercise,
  ) async {
    final controller = TextEditingController(text: exercise.name);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit exercise'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Exercise name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(activeSessionProvider(args).notifier)
                  .renameExercise(exercise: exercise, name: controller.text);
              ref.invalidate(weeklyTemplatesProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFinish(
    BuildContext context,
    WidgetRef ref,
    WorkoutSessionArgs args,
  ) async {
    final log = ref.read(activeSessionProvider(args)).valueOrNull;
    if (log == null) return;
    final exercises = log.sets.map((set) => set.exerciseUid).toSet().length;
    final volume = log.sets.fold<double>(0, (sum, set) => sum + set.volume);
    final duration = DateTime.now().difference(log.startedAt).inMinutes;
    final unitSystem = ref.read(appSettingsProvider).unitSystem;
    final unit = unitLabel(unitSystem);
    final displayedVolume = displayWeight(volume, unitSystem);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercises: $exercises'),
            Text('Sets: ${log.sets.length}'),
            Text('Volume: ${displayedVolume.toStringAsFixed(0)} $unit'),
            Text('Duration: $duration min'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (shouldSave != true) return;
    await ref.read(activeSessionProvider(args).notifier).complete();
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(workoutStatsProvider);
    ref.invalidate(workoutOverviewsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _EmptyWorkout extends StatelessWidget {
  const _EmptyWorkout({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add first exercise'),
      ),
    );
  }
}
