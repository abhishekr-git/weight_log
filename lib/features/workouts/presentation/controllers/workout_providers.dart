import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/calendar.dart';
import '../../data/local/isar_service.dart';
import '../../data/repositories/isar_workout_repository.dart';
import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return IsarWorkoutRepository(IsarService.instance);
});

final weeklyTemplatesProvider = StreamProvider<List<WorkoutTemplate>>((ref) {
  return ref.watch(workoutRepositoryProvider).watchTemplates();
});

final workoutHistoryProvider = FutureProvider<List<WorkoutLog>>((ref) {
  return ref.watch(workoutRepositoryProvider).history();
});

final workoutLogProvider =
    StreamProvider.family<WorkoutLog?, String>((ref, uid) {
  return ref.watch(workoutRepositoryProvider).watchWorkoutLog(uid);
});

final workoutOverviewsProvider =
    FutureProvider.family<List<WorkoutOverview>, int>((ref, weekCount) async {
  final templates = await ref.watch(weeklyTemplatesProvider.future);
  final repository = ref.watch(workoutRepositoryProvider);
  final now = DateTime.now();
  final start = startOfWeek(now);
  final overviews = <WorkoutOverview>[];
  for (var week = 0; week < weekCount; week++) {
    for (final template in templates) {
      final date = start.add(Duration(days: week * 7 + template.weekday - 1));
      final log = await repository.logForTemplateDate(
        templateUid: template.uid,
        workoutDate: date,
      );
      overviews.add(WorkoutOverview(template: template, date: date, log: log));
    }
  }
  return overviews..sort((a, b) => a.date.compareTo(b.date));
});

final exercisePerformanceProvider =
    FutureProvider.family<ExercisePerformance, ExercisePerformanceArgs>(
        (ref, args) {
  return ref.watch(workoutRepositoryProvider).exercisePerformance(
        exerciseUid: args.exerciseUid,
        templateUid: args.templateUid,
        workoutDate: args.workoutDate,
      );
});

class ExercisePerformanceArgs {
  const ExercisePerformanceArgs({
    required this.exerciseUid,
    required this.templateUid,
    required this.workoutDate,
  });

  final String exerciseUid;
  final String templateUid;
  final DateTime workoutDate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExercisePerformanceArgs &&
            other.exerciseUid == exerciseUid &&
            other.templateUid == templateUid &&
            dateOnly(other.workoutDate) == dateOnly(workoutDate);
  }

  @override
  int get hashCode =>
      Object.hash(exerciseUid, templateUid, dateOnly(workoutDate));
}

final activeSessionProvider = StateNotifierProvider.autoDispose.family<
    WorkoutSessionController,
    AsyncValue<WorkoutLog>,
    WorkoutSessionArgs>((ref, args) {
  return WorkoutSessionController(ref.watch(workoutRepositoryProvider), args)
    ..load();
});

class WorkoutSessionArgs {
  const WorkoutSessionArgs(
      {required this.templateUid, required this.workoutDate});

  final String templateUid;
  final DateTime workoutDate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkoutSessionArgs &&
            other.templateUid == templateUid &&
            dateOnly(other.workoutDate) == dateOnly(workoutDate);
  }

  @override
  int get hashCode => Object.hash(templateUid, dateOnly(workoutDate));
}

class WorkoutSessionController extends StateNotifier<AsyncValue<WorkoutLog>> {
  WorkoutSessionController(this._repository, this._args)
      : super(const AsyncLoading());

  final WorkoutRepository _repository;
  final WorkoutSessionArgs _args;

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.startOrGetWorkout(
        templateUid: _args.templateUid,
        workoutDate: dateOnly(_args.workoutDate),
      ),
    );
  }

  Future<void> logSet({
    required ExerciseTemplate exercise,
    required double weight,
    required int reps,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _repository.logSet(
      workoutLogUid: current.uid,
      exerciseUid: exercise.uid,
      exerciseName: exercise.name,
      weight: weight,
      reps: reps,
    );
    state = AsyncData(
      await _repository.startOrGetWorkout(
        templateUid: _args.templateUid,
        workoutDate: _args.workoutDate,
      ),
    );
  }

  Future<void> updateSet({
    required SetLog set,
    required double weight,
    required int reps,
  }) async {
    await _repository.updateSet(setUid: set.uid, weight: weight, reps: reps);
    await _reload();
  }

  Future<void> deleteSet(SetLog set) async {
    await _repository.deleteSet(set.uid);
    await _reload();
  }

  Future<SetLog?> previousFor(ExerciseTemplate exercise) {
    return _repository.previousSetForExercise(exercise.uid);
  }

  Future<void> renameExercise({
    required ExerciseTemplate exercise,
    required String name,
  }) async {
    await _repository.renameExercise(exerciseUid: exercise.uid, name: name);
    await _reload();
  }

  Future<void> duplicateExercise({
    required String templateUid,
    required ExerciseTemplate exercise,
  }) async {
    await _repository.duplicateExercise(
      templateUid: templateUid,
      exerciseUid: exercise.uid,
    );
    await _reload();
  }

  Future<void> deleteExercise(ExerciseTemplate exercise) async {
    await _repository.archiveExercise(exercise.uid);
    await _reload();
  }

  Future<void> complete() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _repository.completeWorkout(current.uid);
    await _reload();
  }

  Future<void> _reload() async {
    state = AsyncData(
      await _repository.startOrGetWorkout(
        templateUid: _args.templateUid,
        workoutDate: _args.workoutDate,
      ),
    );
  }
}

final workoutStatsProvider = FutureProvider<WorkoutStats>((ref) async {
  final logs = await ref.watch(workoutRepositoryProvider).history();
  return WorkoutStats.fromLogs(logs);
});

class WorkoutStats {
  const WorkoutStats({
    required this.totalSets,
    required this.totalReps,
    required this.totalVolume,
    required this.currentStreak,
    required this.personalRecords,
    required this.weeklyVolume,
    required this.monthlyVolume,
    required this.workoutFrequency,
    required this.averageSessionMinutes,
    required this.averageSets,
    required this.averageReps,
    required this.estimatedOneRepMaxProgress,
  });

  final int totalSets;
  final int totalReps;
  final double totalVolume;
  final int currentStreak;
  final Map<String, SetLog> personalRecords;
  final Map<DateTime, double> weeklyVolume;
  final Map<DateTime, double> monthlyVolume;
  final Map<DateTime, int> workoutFrequency;
  final double averageSessionMinutes;
  final double averageSets;
  final double averageReps;
  final Map<String, List<SetLog>> estimatedOneRepMaxProgress;

  factory WorkoutStats.fromLogs(List<WorkoutLog> logs) {
    final sets = logs.expand((log) => log.sets).toList();
    final records = <String, SetLog>{};
    for (final set in sets) {
      final current = records[set.exerciseName];
      if (current == null ||
          set.weight > current.weight ||
          set.volume > current.volume) {
        records[set.exerciseName] = set;
      }
    }

    final weeklyVolume = <DateTime, double>{};
    final monthlyVolume = <DateTime, double>{};
    final workoutFrequency = <DateTime, int>{};
    final oneRepMaxProgress = <String, List<SetLog>>{};
    var totalSessionMinutes = 0;

    for (final log in logs) {
      final week = startOfWeek(log.workoutDate);
      final month = DateTime(log.workoutDate.year, log.workoutDate.month);
      final volume = log.sets.fold<double>(0, (sum, set) => sum + set.volume);
      weeklyVolume[week] = (weeklyVolume[week] ?? 0) + volume;
      monthlyVolume[month] = (monthlyVolume[month] ?? 0) + volume;
      workoutFrequency[week] = (workoutFrequency[week] ?? 0) + 1;
      if (log.completedAt != null) {
        totalSessionMinutes +=
            log.completedAt!.difference(log.startedAt).inMinutes;
      }
      for (final set in log.sets) {
        oneRepMaxProgress.putIfAbsent(set.exerciseName, () => []).add(set);
      }
    }

    final uniqueDates = logs
        .map((log) => dateOnly(log.workoutDate))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    var streak = 0;
    var cursor = dateOnly(DateTime.now());
    for (final date in uniqueDates) {
      if (date == cursor || date == cursor.subtract(const Duration(days: 1))) {
        streak++;
        cursor = date.subtract(const Duration(days: 1));
      }
    }

    return WorkoutStats(
      totalSets: sets.length,
      totalReps: sets.fold(0, (sum, set) => sum + set.reps),
      totalVolume: sets.fold(0, (sum, set) => sum + set.volume),
      currentStreak: streak,
      personalRecords: records,
      weeklyVolume: weeklyVolume,
      monthlyVolume: monthlyVolume,
      workoutFrequency: workoutFrequency,
      averageSessionMinutes:
          logs.isEmpty ? 0 : totalSessionMinutes / logs.length,
      averageSets: logs.isEmpty ? 0 : sets.length / logs.length,
      averageReps: sets.isEmpty
          ? 0
          : sets.fold<int>(0, (sum, set) => sum + set.reps) / sets.length,
      estimatedOneRepMaxProgress: oneRepMaxProgress,
    );
  }
}
