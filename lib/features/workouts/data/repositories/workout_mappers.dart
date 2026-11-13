import '../../domain/entities/workout.dart';
import '../models/workout_models.dart';

extension WorkoutTemplateMapper on WorkoutTemplateModel {
  WorkoutTemplate toDomain() {
    return WorkoutTemplate(
      uid: uid,
      weekday: weekday,
      name: name,
      updatedAt: updatedAt,
      exercises: exercises
          .where((exercise) => exercise.archivedAt == null)
          .map((exercise) => exercise.toDomain())
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }
}

extension ExerciseTemplateMapper on ExerciseTemplateModel {
  ExerciseTemplate toDomain() {
    return ExerciseTemplate(uid: uid, name: name, sortOrder: sortOrder);
  }
}

extension WorkoutLogMapper on WorkoutLogModel {
  WorkoutLog toDomain() {
    return WorkoutLog(
      uid: uid,
      templateUid: templateUid,
      workoutDate: workoutDate,
      startedAt: startedAt,
      completedAt: completedAt,
      sets: sets.map((set) => set.toDomain()).toList()
        ..sort((a, b) {
          final exercise = a.exerciseName.compareTo(b.exerciseName);
          if (exercise != 0) return exercise;
          return a.setNumber.compareTo(b.setNumber);
        }),
    );
  }
}

extension SetLogMapper on SetLogModel {
  SetLog toDomain() {
    return SetLog(
      uid: uid,
      workoutLogUid: workoutLogUid,
      exerciseUid: exerciseUid,
      exerciseName: exerciseName,
      setNumber: setNumber,
      weight: weight,
      reps: reps,
      completedAt: completedAt,
    );
  }
}
