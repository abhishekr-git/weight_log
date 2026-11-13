import '../entities/workout.dart';

abstract interface class WorkoutRepository {
  Future<List<WorkoutTemplate>> watchlessTemplates();
  Stream<List<WorkoutTemplate>> watchTemplates();
  Future<WorkoutTemplate> upsertTemplate({
    required int weekday,
    required String name,
    String? uid,
  });
  Future<void> addExercise({
    required String templateUid,
    required String exerciseName,
  });
  Future<void> renameExercise({
    required String exerciseUid,
    required String name,
  });
  Future<void> duplicateExercise({
    required String templateUid,
    required String exerciseUid,
  });
  Future<void> archiveExercise(String exerciseUid);
  Future<WorkoutLog> startOrGetWorkout({
    required String templateUid,
    required DateTime workoutDate,
  });
  Stream<WorkoutLog?> watchWorkoutLog(String workoutLogUid);
  Future<SetLog?> previousSetForExercise(String exerciseUid);
  Future<ExercisePerformance> exercisePerformance({
    required String exerciseUid,
    required String templateUid,
    required DateTime workoutDate,
  });
  Future<SetLog> logSet({
    required String workoutLogUid,
    required String exerciseUid,
    required String exerciseName,
    required double weight,
    required int reps,
  });
  Future<void> updateSet({
    required String setUid,
    required double weight,
    required int reps,
  });
  Future<void> deleteSet(String setUid);
  Future<List<WorkoutLog>> history();
  Future<WorkoutLog?> logForTemplateDate({
    required String templateUid,
    required DateTime workoutDate,
  });
  Future<void> deleteAllData();
  Future<int> importHistoryCsv(String csv);
  Future<void> completeWorkout(String workoutLogUid);
}
