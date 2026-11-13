import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/calendar.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';

class WeeklyScheduleScreen extends ConsumerWidget {
  const WeeklyScheduleScreen({super.key});

  static const _visibleWeeks = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(weeklyTemplatesProvider);
    final overviews = ref.watch(workoutOverviewsProvider(_visibleWeeks));

    return Scaffold(
      appBar: AppBar(
        title: const Text('WeightLog'),
        actions: [
          IconButton(
            tooltip: 'Add workout',
            onPressed: () =>
                _showTemplateSheet(context, ref, DateTime.now().weekday),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: templates.when(
        data: (items) {
          final overviewItems =
              overviews.valueOrNull ?? const <WorkoutOverview>[];
          final start = startOfWeek(DateTime.now());
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _visibleWeeks,
            itemBuilder: (context, weekIndex) {
              final weekStart = start.add(Duration(days: weekIndex * 7));
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week ${weekIndex + 1}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    for (var day = 0; day < 7; day++) ...[
                      Builder(
                        builder: (context) {
                          final date = weekStart.add(Duration(days: day));
                          final weekday = date.weekday;
                          final template = _templateFor(items, weekday);
                          final overview = template == null
                              ? null
                              : overviewItems.where((item) {
                                  return item.template.uid == template.uid &&
                                      dateOnly(item.date) == dateOnly(date);
                                }).firstOrNull;
                          return _DayTile(
                            weekday: weekday,
                            date: date,
                            template: template,
                            overview: overview,
                            onCreate: () =>
                                _showTemplateSheet(context, ref, weekday),
                            onStart: template == null
                                ? null
                                : () => context.push(
                                      '/workout/${template.uid}?date=${dateOnly(date).toIso8601String()}',
                                    ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              );
            },
          );
        },
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  WorkoutTemplate? _templateFor(List<WorkoutTemplate> templates, int weekday) {
    final matches = templates.where((item) => item.weekday == weekday);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _showTemplateSheet(
      BuildContext context, WidgetRef ref, int weekday) async {
    final controller =
        TextEditingController(text: '${weekdayLabel(weekday)} Workout');
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
            Text('Workout template',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (_) =>
                  _saveTemplate(context, ref, weekday, controller.text),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  _saveTemplate(context, ref, weekday, controller.text),
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTemplate(
      BuildContext context, WidgetRef ref, int weekday, String name) async {
    await ref
        .read(workoutRepositoryProvider)
        .upsertTemplate(weekday: weekday, name: name);
    ref.invalidate(weeklyTemplatesProvider);
    ref.invalidate(workoutOverviewsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.weekday,
    required this.date,
    required this.template,
    required this.overview,
    required this.onCreate,
    required this.onStart,
  });

  final int weekday;
  final DateTime date;
  final WorkoutTemplate? template;
  final WorkoutOverview? overview;
  final VoidCallback onCreate;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = overview?.isCompleted ?? false;
    final progress = overview?.progress ?? 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      child: Card(
        color: completed
            ? Colors.green.withValues(alpha: 0.18)
            : template == null
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  weekdayLabel(weekday),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (completed)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(compactDate(date)),
                if (template != null) ...[
                  const SizedBox(height: 4),
                  Text(template!.name),
                  Text(
                    '${template!.exercises.length} exercises - estimated ${overview?.estimatedMinutes ?? template!.exercises.length * 10 + 10} min',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress.clamp(0, 1)),
                  const SizedBox(height: 4),
                  Text(completed
                      ? 'Completed'
                      : 'Progress ${(progress * 100).round()}%'),
                ] else
                  const Text('No workout planned'),
              ],
            ),
          ),
          trailing: FilledButton.tonalIcon(
            onPressed: template == null ? onCreate : onStart,
            icon: Icon(template == null ? Icons.add : Icons.play_arrow),
            label: Text(template == null ? 'Plan' : 'Start'),
          ),
        ),
      ),
    );
  }
}
