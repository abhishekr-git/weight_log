class WorkoutTemplate {
  const WorkoutTemplate({
    required this.uid,
    required this.weekday,
    required this.name,
    required this.exercises,
    required this.updatedAt,
  });

  final String uid;
  final int weekday;
  final String name;
  final List<ExerciseTemplate> exercises;
  final DateTime updatedAt;
}

class ExerciseTemplate {
  const ExerciseTemplate({
    required this.uid,
    required this.name,
    required this.sortOrder,
  });

  final String uid;
  final String name;
  final int sortOrder;
}

class WorkoutLog {
  const WorkoutLog({
    required this.uid,
    required this.templateUid,
    required this.workoutDate,
    required this.startedAt,
    required this.sets,
    this.completedAt,
  });

  final String uid;
  final String templateUid;
  final DateTime workoutDate;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<SetLog> sets;
}

class SetLog {
  const SetLog({
    required this.uid,
    required this.workoutLogUid,
    required this.exerciseUid,
    required this.exerciseName,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.completedAt,
  });

  final String uid;
  final String workoutLogUid;
  final String exerciseUid;
  final String exerciseName;
  final int setNumber;
  final double weight;
  final int reps;
  final DateTime completedAt;

  double get volume => weight * reps;

  double get estimatedOneRepMax => weight * (1 + reps / 30);
}

class ExercisePerformance {
  const ExercisePerformance({
    required this.previousSets,
    this.highestWeight,
    this.highestVolume,
    this.mostReps,
    this.bestEstimatedOneRepMax,
  });

  final List<SetLog> previousSets;
  final SetLog? highestWeight;
  final SetLog? highestVolume;
  final SetLog? mostReps;
  final SetLog? bestEstimatedOneRepMax;

  bool isPr(SetLog set) {
    return prLabelsFor(set).isNotEmpty;
  }

  List<String> prLabelsFor(SetLog set) {
    final labels = <String>[];
    if (highestWeight == null || set.weight > highestWeight!.weight) {
      labels.add('Weight PR');
    }
    if (highestVolume == null || set.volume > highestVolume!.volume) {
      labels.add('Volume PR');
    }
    if (mostReps == null || set.reps > mostReps!.reps) {
      labels.add('Reps PR');
    }
    if (bestEstimatedOneRepMax == null ||
        set.estimatedOneRepMax > bestEstimatedOneRepMax!.estimatedOneRepMax) {
      labels.add('1RM PR');
    }
    return labels;
  }
}

class WorkoutOverview {
  const WorkoutOverview({
    required this.template,
    required this.date,
    this.log,
  });

  final WorkoutTemplate template;
  final DateTime date;
  final WorkoutLog? log;

  bool get isCompleted => log?.completedAt != null;
  int get completedSets => log?.sets.length ?? 0;
  int get totalExercises => template.exercises.length;
  double get progress {
    if (totalExercises == 0) return 0;
    final exercised =
        log?.sets.map((set) => set.exerciseUid).toSet().length ?? 0;
    return exercised / totalExercises;
  }

  int get estimatedMinutes =>
      totalExercises == 0 ? 0 : 10 + totalExercises * 10;
}
