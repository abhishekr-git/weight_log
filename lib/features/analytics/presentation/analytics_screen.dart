import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_settings.dart';
import '../../workouts/presentation/controllers/workout_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(workoutStatsProvider);
    final unitSystem = ref.watch(appSettingsProvider).unitSystem;

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: stats.when(
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 760 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.75,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MetricCard(
                        label: 'Weekly Volume',
                        value: _lastVolume(value.weeklyVolume, unitSystem)),
                    _MetricCard(
                        label: 'Monthly Volume',
                        value: _lastVolume(value.monthlyVolume, unitSystem)),
                    _MetricCard(
                        label: 'Frequency',
                        value: '${_lastCount(value.workoutFrequency)}/wk'),
                    _MetricCard(
                        label: 'Avg Session',
                        value: '${value.averageSessionMinutes.round()}m'),
                    _MetricCard(
                        label: 'Avg Sets',
                        value: value.averageSets.toStringAsFixed(1)),
                    _MetricCard(
                        label: 'Avg Reps',
                        value: value.averageReps.toStringAsFixed(1)),
                    _MetricCard(
                        label: 'Streak', value: '${value.currentStreak}d'),
                    _MetricCard(
                        label: 'Total Volume',
                        value: displayWeight(value.totalVolume, unitSystem)
                            .toStringAsFixed(0)),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _ChartCard(
              title: 'Weekly Volume',
              values: value.weeklyVolume.values
                  .map((volume) => displayWeight(volume, unitSystem))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'Monthly Volume',
              values: value.monthlyVolume.values
                  .map((volume) => displayWeight(volume, unitSystem))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'Workout Frequency',
              values: value.workoutFrequency.values
                  .map((e) => e.toDouble())
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text('Personal records',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (value.personalRecords.isEmpty)
              const Text('Log workouts to build records.')
            else
              for (final entry in value.personalRecords.entries)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium),
                    title: Text(entry.key),
                    subtitle: Text(
                      '${formatDisplayWeight(entry.value.weight, unitSystem)} ${unitLabel(unitSystem)} x ${entry.value.reps} - est. 1RM ${formatDisplayWeight(entry.value.estimatedOneRepMax, unitSystem)} ${unitLabel(unitSystem)}',
                    ),
                  ),
                ),
            const SizedBox(height: 24),
            Text('Estimated 1RM Progress',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (value.estimatedOneRepMaxProgress.isEmpty)
              const Text('No 1RM trend yet.')
            else
              _ChartCard(
                title: value.estimatedOneRepMaxProgress.keys.first,
                values: value.estimatedOneRepMaxProgress.values.first
                    .map((set) => set.estimatedOneRepMax)
                    .map((oneRepMax) => displayWeight(oneRepMax, unitSystem))
                    .toList(),
              ),
          ],
        ),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  String _lastVolume(Map<DateTime, double> values, UnitSystem unitSystem) {
    if (values.isEmpty) return '0';
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return displayWeight(entries.last.value, unitSystem).toStringAsFixed(0);
  }

  int _lastCount(Map<DateTime, int> values) {
    if (values.isEmpty) return 0;
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.last.value;
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.values});

  final String title;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final chartValues = values.isEmpty ? [0.0] : values.take(12).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                  ),
                  barGroups: [
                    for (var i = 0; i < chartValues.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: chartValues[i] <= 0 ? 1 : chartValues[i],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child:
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ),
          ],
        ),
      ),
    );
  }
}
