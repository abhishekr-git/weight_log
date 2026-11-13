import 'package:flutter_test/flutter_test.dart';
import 'package:weightlog/features/workouts/domain/entities/workout.dart';
import 'package:weightlog/features/workouts/presentation/controllers/workout_providers.dart';

void main() {
  test('WorkoutStats aggregates set count, reps, volume, and records', () {
    final stats = WorkoutStats.fromLogs([
      WorkoutLog(
        uid: 'log-1',
        templateUid: 'template-1',
        workoutDate: DateTime.now(),
        startedAt: DateTime.now(),
        sets: [
          SetLog(
            uid: 'set-1',
            workoutLogUid: 'log-1',
            exerciseUid: 'bench',
            exerciseName: 'Bench Press',
            setNumber: 1,
            weight: 100,
            reps: 5,
            completedAt: DateTime.now(),
          ),
          SetLog(
            uid: 'set-2',
            workoutLogUid: 'log-1',
            exerciseUid: 'bench',
            exerciseName: 'Bench Press',
            setNumber: 2,
            weight: 105,
            reps: 3,
            completedAt: DateTime.now(),
          ),
        ],
      ),
    ]);

    expect(stats.totalSets, 2);
    expect(stats.totalReps, 8);
    expect(stats.totalVolume, 815);
    expect(stats.personalRecords['Bench Press']?.weight, 105);
  });
}
