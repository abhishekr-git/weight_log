import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/repositories/workout_repository.dart';
import 'cloud_backup_service.dart';

class SyncService {
  SyncService(this._repository, this._backupService, this._connectivity);

  final WorkoutRepository _repository;
  final CloudBackupService _backupService;
  final Connectivity _connectivity;

  Future<bool> syncNow() async {
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) return false;

    await _backupService.backup(
      templates: await _repository.watchlessTemplates(),
      logs: await _repository.history(),
    );
    return true;
  }
}
