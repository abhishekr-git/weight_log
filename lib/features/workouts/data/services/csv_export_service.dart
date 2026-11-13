import 'package:csv/csv.dart';

import '../../domain/entities/workout.dart';

class CsvExportService {
  String workoutHistory(List<WorkoutLog> logs) {
    final rows = <List<Object?>>[
      ['date', 'exercise', 'set', 'weight_kg', 'reps', 'volume_kg'],
      for (final log in logs)
        for (final set in log.sets)
          [
            log.workoutDate.toIso8601String(),
            set.exerciseName,
            set.setNumber,
            set.weight,
            set.reps,
            set.volume,
          ],
    ];
    return const ListToCsvConverter().convert(rows);
  }
}
