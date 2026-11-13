import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_settings.dart';
import '../../workouts/presentation/controllers/service_providers.dart';
import '../../workouts/presentation/controllers/workout_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Dark'),
              ),
            ],
            selected: {ref.watch(appSettingsProvider).themeMode},
            onSelectionChanged: (value) => ref
                .read(appSettingsProvider.notifier)
                .setThemeMode(value.first),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Metric units'),
            subtitle:
                Text(unitLabel(ref.watch(appSettingsProvider).unitSystem)),
            value: ref.watch(appSettingsProvider).usesMetric,
            onChanged: (value) => ref
                .read(appSettingsProvider.notifier)
                .setUnitSystem(value ? UnitSystem.metric : UnitSystem.imperial),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share),
            title: const Text('Export CSV'),
            onTap: _exportCsv,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_page_outlined),
            title: const Text('Import Backup'),
            subtitle:
                const Text('Paste a WeightLog CSV backup to restore logs.'),
            onTap: _importBackup,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cloud Backup'),
            subtitle:
                const Text('Uses Firebase Spark plan and anonymous auth.'),
            value: ref.watch(appSettingsProvider).cloudBackupEnabled,
            onChanged: (value) => ref
                .read(appSettingsProvider.notifier)
                .setCloudBackupEnabled(value),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Sync now'),
            subtitle:
                const Text('Back up local templates and logs when online.'),
            trailing: _syncing
                ? const CircularProgressIndicator()
                : const Icon(Icons.chevron_right),
            onTap: _syncing ? null : _syncNow,
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Delete All Data'),
            subtitle:
                const Text('Remove all templates, exercises, sets, and logs.'),
            onTap: _deleteAllData,
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final logs = await ref.read(workoutRepositoryProvider).history();
    final csv = ref.read(csvExportServiceProvider).workoutHistory(logs);
    await Share.share(csv, subject: 'WeightLog workout history.csv');
  }

  Future<void> _syncNow() async {
    if (!ref.read(appSettingsProvider).cloudBackupEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud Backup is off.')),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      final didSync = await ref.read(syncServiceProvider).syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(didSync ? 'Backup complete.' : 'You are offline.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();
    final csv = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'CSV backup',
              hintText: 'date,exercise,set,weight,reps,volume',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (csv == null || csv.trim().isEmpty) return;
    try {
      final imported =
          await ref.read(workoutRepositoryProvider).importHistoryCsv(csv);
      ref.invalidate(weeklyTemplatesProvider);
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(workoutStatsProvider);
      ref.invalidate(workoutOverviewsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $imported sets.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
            'This removes every local workout, set, exercise, and template.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(workoutRepositoryProvider).deleteAllData();
    ref.invalidate(weeklyTemplatesProvider);
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(workoutStatsProvider);
    ref.invalidate(workoutOverviewsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All local data deleted.')));
  }
}
