import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/cloud_backup_service.dart';
import '../../data/services/csv_export_service.dart';
import '../../data/services/sync_service.dart';
import 'workout_providers.dart';

final csvExportServiceProvider = Provider((ref) => CsvExportService());

final cloudBackupServiceProvider = Provider((ref) => CloudBackupService());

final syncServiceProvider = Provider((ref) {
  return SyncService(
    ref.watch(workoutRepositoryProvider),
    ref.watch(cloudBackupServiceProvider),
    Connectivity(),
  );
});
