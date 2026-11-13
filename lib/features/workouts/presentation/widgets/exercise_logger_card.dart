import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_settings.dart';
import '../../domain/entities/workout.dart';

class ExerciseLoggerCard extends ConsumerStatefulWidget {
  const ExerciseLoggerCard({
    required this.exercise,
    required this.sets,
    required this.performance,
    required this.onLogSet,
    required this.onUpdateSet,
    required this.onDeleteSet,
    required this.onExerciseActions,
    super.key,
  });

  final ExerciseTemplate exercise;
  final List<SetLog> sets;
  final AsyncValue<ExercisePerformance> performance;
  final Future<void> Function(double weight, int reps) onLogSet;
  final Future<void> Function(SetLog set, double weight, int reps) onUpdateSet;
  final Future<void> Function(SetLog set) onDeleteSet;
  final VoidCallback onExerciseActions;

  @override
  ConsumerState<ExerciseLoggerCard> createState() => _ExerciseLoggerCardState();
}

class _ExerciseLoggerCardState extends ConsumerState<ExerciseLoggerCard> {
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();
  bool _saving = false;

  SetLog? get _latestReference {
    if (widget.sets.isNotEmpty) return widget.sets.last;
    return widget.performance.valueOrNull?.previousSets.lastOrNull;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void didUpdateWidget(covariant ExerciseLoggerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sets.length != widget.sets.length ||
        oldWidget.performance.valueOrNull != widget.performance.valueOrNull) {
      _prefill();
    }
  }

  void _prefill() {
    final reference = _latestReference;
    if (reference == null) return;
    if (_weight.text.isEmpty) _weight.text = _formatWeight(reference.weight);
    if (_reps.text.isEmpty) _reps.text = reference.reps.toString();
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSystem = ref.watch(appSettingsProvider).unitSystem;
    final unit = unitLabel(unitSystem);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: widget.onExerciseActions,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.exercise.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${widget.sets.length} sets'),
                  IconButton(
                    tooltip: 'Exercise actions',
                    onPressed: widget.onExerciseActions,
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
              _PreviousPerformance(performance: widget.performance),
              if (widget.sets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final set in widget.sets)
                      Builder(builder: (context) {
                        final labels =
                            widget.performance.valueOrNull?.prLabelsFor(set) ??
                                const <String>[];
                        return InputChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#${set.setNumber}  ${_formatWeight(set.weight)} x ${set.reps}',
                              ),
                              if (labels.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: labels.join(', '),
                                  child: const Icon(
                                    Icons.workspace_premium,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showEditSetDialog(set),
                        );
                      }),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      focusNode: _weightFocus,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Weight',
                        hintText: _latestReference == null
                            ? null
                            : _formatWeight(_latestReference!.weight),
                        helperText: _latestReference == null
                            ? null
                            : 'Previous ${_formatWeight(_latestReference!.weight)} $unit',
                        suffixText: unit,
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _repsFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _reps,
                      focusNode: _repsFocus,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Reps',
                        hintText: _latestReference?.reps.toString(),
                        helperText: _latestReference == null
                            ? null
                            : 'Previous ${_latestReference!.reps}',
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox.square(
                    dimension: 58,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditSetDialog(SetLog set) async {
    final weight = TextEditingController(text: _formatWeight(set.weight));
    final reps = TextEditingController(text: set.reps.toString());
    final unitSystem = ref.read(appSettingsProvider).unitSystem;
    final unit = unitLabel(unitSystem);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit set #${set.setNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weight,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight',
                suffixText: unit,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reps,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await widget.onDeleteSet(set);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
          FilledButton(
            onPressed: () async {
              final nextWeight = double.tryParse(weight.text.trim());
              final nextReps = int.tryParse(reps.text.trim());
              if (nextWeight == null || nextReps == null) return;
              await widget.onUpdateSet(
                set,
                kilogramsFromDisplay(nextWeight, unitSystem),
                nextReps,
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weight.text.trim());
    final reps = int.tryParse(_reps.text.trim());
    if (weight == null || reps == null) return;
    final unitSystem = ref.read(appSettingsProvider).unitSystem;
    setState(() => _saving = true);
    try {
      await widget.onLogSet(kilogramsFromDisplay(weight, unitSystem), reps);
      _weight.clear();
      _reps.clear();
      _weightFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatWeight(double value) {
    return formatDisplayWeight(value, ref.read(appSettingsProvider).unitSystem);
  }
}

class _PreviousPerformance extends StatelessWidget {
  const _PreviousPerformance({required this.performance});

  final AsyncValue<ExercisePerformance> performance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings =
        ProviderScope.containerOf(context).read(appSettingsProvider);
    final unit = unitLabel(settings.unitSystem);
    return performance.when(
      data: (value) {
        if (value.previousSets.isEmpty &&
            value.highestWeight == null &&
            value.bestEstimatedOneRepMax == null) {
          return const SizedBox.shrink();
        }
        final previous = value.previousSets
            .map((set) =>
                '${_formatWeight(set.weight, settings.unitSystem)} $unit x ${set.reps}')
            .join('\n');
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (previous.isNotEmpty) ...[
                Text('Last time', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(previous),
              ],
              if (value.highestWeight != null) ...[
                const SizedBox(height: 8),
                Text(
                  'PR ${_formatWeight(value.highestWeight!.weight, settings.unitSystem)} $unit',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
              if (value.bestEstimatedOneRepMax != null)
                Text(
                  'Best est. 1RM ${_formatWeight(value.bestEstimatedOneRepMax!.estimatedOneRepMax, settings.unitSystem)} $unit',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatWeight(double value, UnitSystem unitSystem) {
    return formatDisplayWeight(value, unitSystem);
  }
}
