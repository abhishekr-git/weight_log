import 'package:isar/isar.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/calendar.dart';
import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../local/isar_service.dart';
import '../models/workout_models.dart';
import 'workout_mappers.dart';

class IsarWorkoutRepository implements WorkoutRepository {
  IsarWorkoutRepository(this._isarService);

  final IsarService _isarService;
  final _uuid = const Uuid();

  @override
  Future<List<WorkoutTemplate>> watchlessTemplates() async {
    final isar = await _isarService.db;
    final models =
        await isar.collection<WorkoutTemplateModel>().where().findAll();
    await Future.wait(models.map((template) => template.exercises.load()));
    return models
        .where((template) => !template.isArchived)
        .map((e) => e.toDomain())
        .toList()
      ..sort((a, b) => a.weekday.compareTo(b.weekday));
  }

  @override
  Stream<List<WorkoutTemplate>> watchTemplates() async* {
    final isar = await _isarService.db;
    yield await watchlessTemplates();
    await for (final _ in isar.collection<WorkoutTemplateModel>().watchLazy()) {
      yield await watchlessTemplates();
    }
  }

  @override
  Future<WorkoutTemplate> upsertTemplate({
    required int weekday,
    required String name,
    String? uid,
  }) async {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw const ValidationException('Weekday must be Monday through Sunday.');
    }
    if (name.trim().isEmpty) {
      throw const ValidationException('Workout name is required.');
    }

    final isar = await _isarService.db;
    late WorkoutTemplateModel model;
    await isar.writeTxn(() async {
      final collection = isar.collection<WorkoutTemplateModel>();
      final existing = uid == null ? null : await _findTemplateByUid(isar, uid);
      model = existing ?? WorkoutTemplateModel();
      model
        ..uid = uid ?? _uuid.v4()
        ..weekday = weekday
        ..name = name.trim()
        ..createdAt = existing?.createdAt ?? DateTime.now()
        ..updatedAt = DateTime.now()
        ..dirty = true;
      await collection.put(model);
    });
    await model.exercises.load();
    return model.toDomain();
  }

  @override
  Future<void> addExercise({
    required String templateUid,
    required String exerciseName,
  }) async {
    if (exerciseName.trim().isEmpty) {
      throw const ValidationException('Exercise name is required.');
    }
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      final template = await _findTemplateByUid(isar, templateUid);
      if (template == null) throw const StorageException('Template not found.');
      await template.exercises.load();

      final exercise = ExerciseTemplateModel()
        ..uid = _uuid.v4()
        ..name = exerciseName.trim()
        ..sortOrder = template.exercises.length
        ..dirty = true;
      await isar.collection<ExerciseTemplateModel>().put(exercise);
      template.exercises.add(exercise);
      template
        ..updatedAt = DateTime.now()
        ..dirty = true;
      await template.exercises.save();
      await isar.collection<WorkoutTemplateModel>().put(template);
    });
  }

  @override
  Future<void> renameExercise({
    required String exerciseUid,
    required String name,
  }) async {
    if (name.trim().isEmpty) {
      throw const ValidationException('Exercise name is required.');
    }
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      final exercise = await _findExerciseByUid(isar, exerciseUid);
      if (exercise == null) throw const StorageException('Exercise not found.');
      exercise
        ..name = name.trim()
        ..dirty = true;
      await isar.collection<ExerciseTemplateModel>().put(exercise);

      final sets = await isar.collection<SetLogModel>().where().findAll();
      for (final set in sets.where((set) => set.exerciseUid == exerciseUid)) {
        set
          ..exerciseName = name.trim()
          ..dirty = true;
      }
      await isar
          .collection<SetLogModel>()
          .putAll(sets.where((set) => set.exerciseUid == exerciseUid).toList());
      await _touchTemplatesContainingExercise(isar, exerciseUid);
    });
  }

  @override
  Future<void> duplicateExercise({
    required String templateUid,
    required String exerciseUid,
  }) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      final template = await _findTemplateByUid(isar, templateUid);
      final source = await _findExerciseByUid(isar, exerciseUid);
      if (template == null || source == null) {
        throw const StorageException('Exercise not found.');
      }
      await template.exercises.load();
      final copy = ExerciseTemplateModel()
        ..uid = _uuid.v4()
        ..name = '${source.name} copy'
        ..sortOrder = template.exercises.length
        ..dirty = true;
      await isar.collection<ExerciseTemplateModel>().put(copy);
      template.exercises.add(copy);
      template
        ..updatedAt = DateTime.now()
        ..dirty = true;
      await template.exercises.save();
      await isar.collection<WorkoutTemplateModel>().put(template);
    });
  }

  @override
  Future<void> archiveExercise(String exerciseUid) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      final exercise = await _findExerciseByUid(isar, exerciseUid);
      if (exercise == null) return;
      exercise
        ..archivedAt = DateTime.now()
        ..dirty = true;
      await isar.collection<ExerciseTemplateModel>().put(exercise);
      final allSets = await isar.collection<SetLogModel>().where().findAll();
      final removedSets =
          allSets.where((set) => set.exerciseUid == exerciseUid).toList();
      await isar
          .collection<SetLogModel>()
          .deleteAll(removedSets.map((set) => set.id).toList());
      final logs = await isar.collection<WorkoutLogModel>().where().findAll();
      for (final log in logs) {
        await _renumberSets(isar, log.uid, exerciseUid);
        log.dirty = true;
        await isar.collection<WorkoutLogModel>().put(log);
      }
      await _touchTemplatesContainingExercise(isar, exerciseUid);
    });
  }

  @override
  Future<WorkoutLog> startOrGetWorkout({
    required String templateUid,
    required DateTime workoutDate,
  }) async {
    final isar = await _isarService.db;
    final targetDate = dateOnly(workoutDate);
    final existing = await _findLog(isar, templateUid, targetDate);
    if (existing != null) {
      await existing.sets.load();
      return existing.toDomain();
    }

    late WorkoutLogModel log;
    await isar.writeTxn(() async {
      log = WorkoutLogModel()
        ..uid = _uuid.v4()
        ..templateUid = templateUid
        ..workoutDate = targetDate
        ..startedAt = DateTime.now()
        ..dirty = true;
      await isar.collection<WorkoutLogModel>().put(log);
    });
    await log.sets.load();
    return log.toDomain();
  }

  @override
  Stream<WorkoutLog?> watchWorkoutLog(String workoutLogUid) async* {
    final isar = await _isarService.db;
    yield await _loadLogByUid(isar, workoutLogUid);
    await for (final _ in isar.collection<WorkoutLogModel>().watchLazy()) {
      yield await _loadLogByUid(isar, workoutLogUid);
    }
  }

  @override
  Future<SetLog?> previousSetForExercise(String exerciseUid) async {
    final isar = await _isarService.db;
    final sets = await isar.collection<SetLogModel>().where().findAll();
    final matches = sets.where((set) => set.exerciseUid == exerciseUid).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return matches.isEmpty ? null : matches.first.toDomain();
  }

  @override
  Future<ExercisePerformance> exercisePerformance({
    required String exerciseUid,
    required String templateUid,
    required DateTime workoutDate,
  }) async {
    final isar = await _isarService.db;
    final logs = await isar.collection<WorkoutLogModel>().where().findAll();
    await Future.wait(logs.map((log) => log.sets.load()));
    final earlierLogs = logs
        .where((log) =>
            log.templateUid == templateUid &&
            dateOnly(log.workoutDate).isBefore(dateOnly(workoutDate)))
        .toList()
      ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));

    final previousLog = earlierLogs.isEmpty ? null : earlierLogs.first;
    final previousSets = previousLog == null
        ? <SetLog>[]
        : previousLog.sets
            .where((set) => set.exerciseUid == exerciseUid)
            .map((set) => set.toDomain())
            .toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

    final allSets = logs
        .where(
            (log) => dateOnly(log.workoutDate).isBefore(dateOnly(workoutDate)))
        .expand((log) => log.sets)
        .where((set) => set.exerciseUid == exerciseUid)
        .map((set) => set.toDomain())
        .toList();

    SetLog? bestBy(num Function(SetLog set) selector) {
      if (allSets.isEmpty) return null;
      return allSets
          .reduce((best, set) => selector(set) > selector(best) ? set : best);
    }

    return ExercisePerformance(
      previousSets: previousSets,
      highestWeight: bestBy((set) => set.weight),
      highestVolume: bestBy((set) => set.volume),
      mostReps: bestBy((set) => set.reps),
      bestEstimatedOneRepMax: bestBy((set) => set.estimatedOneRepMax),
    );
  }

  @override
  Future<SetLog> logSet({
    required String workoutLogUid,
    required String exerciseUid,
    required String exerciseName,
    required double weight,
    required int reps,
  }) async {
    if (weight < 0 || reps <= 0) {
      throw const ValidationException(
          'Use a positive reps value and non-negative weight.');
    }

    final isar = await _isarService.db;
    late SetLogModel set;
    await isar.writeTxn(() async {
      final log = await _findLogByUid(isar, workoutLogUid);
      if (log == null) throw const StorageException('Workout log not found.');
      await log.sets.load();
      final nextSet =
          log.sets.where((s) => s.exerciseUid == exerciseUid).length + 1;
      set = SetLogModel()
        ..uid = _uuid.v4()
        ..workoutLogUid = workoutLogUid
        ..exerciseUid = exerciseUid
        ..exerciseName = exerciseName
        ..setNumber = nextSet
        ..weight = weight
        ..reps = reps
        ..completedAt = DateTime.now()
        ..dirty = true;
      await isar.collection<SetLogModel>().put(set);
      log.sets.add(set);
      log.dirty = true;
      await log.sets.save();
      await isar.collection<WorkoutLogModel>().put(log);
    });
    return set.toDomain();
  }

  @override
  Future<void> updateSet({
    required String setUid,
    required double weight,
    required int reps,
  }) async {
    if (weight < 0 || reps <= 0) {
      throw const ValidationException(
          'Use a positive reps value and non-negative weight.');
    }
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      final set = await _findSetByUid(isar, setUid);
      if (set == null) throw const StorageException('Set not found.');
      set
        ..weight = weight
        ..reps = reps
        ..dirty = true;
      await isar.collection<SetLogModel>().put(set);
      final log = await _findLogByUid(isar, set.workoutLogUid);
      if (log != null) {
        log.dirty = true;
        await isar.collection<WorkoutLogModel>().put(log);
      }
    });
  }

  @override
  Future<void> deleteSet(String setUid) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      final set = await _findSetByUid(isar, setUid);
      if (set == null) return;
      final workoutLogUid = set.workoutLogUid;
      final exerciseUid = set.exerciseUid;
      await isar.collection<SetLogModel>().delete(set.id);
      await _renumberSets(isar, workoutLogUid, exerciseUid);
      final log = await _findLogByUid(isar, workoutLogUid);
      if (log != null) {
        log.dirty = true;
        await isar.collection<WorkoutLogModel>().put(log);
      }
    });
  }

  @override
  Future<List<WorkoutLog>> history() async {
    final isar = await _isarService.db;
    final logs = await isar.collection<WorkoutLogModel>().where().findAll();
    await Future.wait(logs.map((log) => log.sets.load()));
    return logs.map((log) => log.toDomain()).toList()
      ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
  }

  @override
  Future<WorkoutLog?> logForTemplateDate({
    required String templateUid,
    required DateTime workoutDate,
  }) async {
    final isar = await _isarService.db;
    final log = await _findLog(isar, templateUid, dateOnly(workoutDate));
    if (log == null) return null;
    await log.sets.load();
    return log.toDomain();
  }

  @override
  Future<void> deleteAllData() async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.collection<SetLogModel>().clear();
      await isar.collection<WorkoutLogModel>().clear();
      await isar.collection<ExerciseTemplateModel>().clear();
      await isar.collection<WorkoutTemplateModel>().clear();
    });
  }

  @override
  Future<int> importHistoryCsv(String csv) async {
    final rows =
        const CsvToListConverter(shouldParseNumbers: false).convert(csv);
    if (rows.length <= 1) return 0;

    final isar = await _isarService.db;
    var importedSets = 0;
    await isar.writeTxn(() async {
      for (final row in rows.skip(1)) {
        if (row.length < 5) continue;
        final workoutDate = DateTime.tryParse(row[0].toString());
        final exerciseName = row[1].toString().trim();
        final weight = double.tryParse(row[3].toString());
        final reps = int.tryParse(row[4].toString());
        if (workoutDate == null ||
            exerciseName.isEmpty ||
            weight == null ||
            reps == null ||
            reps <= 0) {
          continue;
        }

        final template = await _findOrCreateImportedTemplate(
          isar,
          weekday: workoutDate.weekday,
        );
        final exercise = await _findOrCreateExercise(
          isar,
          template: template,
          exerciseName: exerciseName,
        );
        final log = await _findOrCreateLog(
          isar,
          templateUid: template.uid,
          workoutDate: workoutDate,
        );
        await log.sets.load();
        final set = SetLogModel()
          ..uid = _uuid.v4()
          ..workoutLogUid = log.uid
          ..exerciseUid = exercise.uid
          ..exerciseName = exercise.name
          ..setNumber =
              log.sets.where((set) => set.exerciseUid == exercise.uid).length +
                  1
          ..weight = weight
          ..reps = reps
          ..completedAt = DateTime.now()
          ..dirty = true;
        await isar.collection<SetLogModel>().put(set);
        log.sets.add(set);
        log
          ..completedAt ??= DateTime.now()
          ..dirty = true;
        await log.sets.save();
        await isar.collection<WorkoutLogModel>().put(log);
        importedSets++;
      }
    });
    return importedSets;
  }

  @override
  Future<void> completeWorkout(String workoutLogUid) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      final log = await _findLogByUid(isar, workoutLogUid);
      if (log == null) return;
      log
        ..completedAt = DateTime.now()
        ..dirty = true;
      await isar.collection<WorkoutLogModel>().put(log);
    });
  }

  Future<WorkoutTemplateModel?> _findTemplateByUid(
      Isar isar, String uid) async {
    final templates =
        await isar.collection<WorkoutTemplateModel>().where().findAll();
    return templates
        .cast<WorkoutTemplateModel?>()
        .firstWhere((e) => e?.uid == uid, orElse: () => null);
  }

  Future<ExerciseTemplateModel?> _findExerciseByUid(
      Isar isar, String uid) async {
    final exercises =
        await isar.collection<ExerciseTemplateModel>().where().findAll();
    return exercises
        .cast<ExerciseTemplateModel?>()
        .firstWhere((e) => e?.uid == uid, orElse: () => null);
  }

  Future<WorkoutLogModel?> _findLog(
      Isar isar, String templateUid, DateTime workoutDate) async {
    final logs = await isar.collection<WorkoutLogModel>().where().findAll();
    return logs.cast<WorkoutLogModel?>().firstWhere(
          (log) =>
              log?.templateUid == templateUid &&
              dateOnly(log!.workoutDate) == workoutDate,
          orElse: () => null,
        );
  }

  Future<WorkoutLogModel?> _findLogByUid(Isar isar, String uid) async {
    final logs = await isar.collection<WorkoutLogModel>().where().findAll();
    return logs
        .cast<WorkoutLogModel?>()
        .firstWhere((log) => log?.uid == uid, orElse: () => null);
  }

  Future<SetLogModel?> _findSetByUid(Isar isar, String uid) async {
    final sets = await isar.collection<SetLogModel>().where().findAll();
    return sets
        .cast<SetLogModel?>()
        .firstWhere((set) => set?.uid == uid, orElse: () => null);
  }

  Future<void> _renumberSets(
      Isar isar, String workoutLogUid, String exerciseUid) async {
    final sets = (await isar.collection<SetLogModel>().where().findAll())
        .where((set) =>
            set.workoutLogUid == workoutLogUid &&
            set.exerciseUid == exerciseUid)
        .toList()
      ..sort((a, b) {
        final byNumber = a.setNumber.compareTo(b.setNumber);
        return byNumber == 0
            ? a.completedAt.compareTo(b.completedAt)
            : byNumber;
      });
    for (var i = 0; i < sets.length; i++) {
      sets[i]
        ..setNumber = i + 1
        ..dirty = true;
    }
    await isar.collection<SetLogModel>().putAll(sets);
  }

  Future<void> _touchTemplatesContainingExercise(
      Isar isar, String exerciseUid) async {
    final templates =
        await isar.collection<WorkoutTemplateModel>().where().findAll();
    for (final template in templates) {
      await template.exercises.load();
      if (template.exercises.any((exercise) => exercise.uid == exerciseUid)) {
        template
          ..updatedAt = DateTime.now()
          ..dirty = true;
        await isar.collection<WorkoutTemplateModel>().put(template);
      }
    }
  }

  Future<WorkoutTemplateModel> _findOrCreateImportedTemplate(
    Isar isar, {
    required int weekday,
  }) async {
    final templates =
        await isar.collection<WorkoutTemplateModel>().where().findAll();
    final existing = templates.cast<WorkoutTemplateModel?>().firstWhere(
          (template) =>
              template?.weekday == weekday &&
              template?.name == '${weekdayLabel(weekday)} Workout',
          orElse: () => null,
        );
    if (existing != null) return existing;
    final now = DateTime.now();
    final template = WorkoutTemplateModel()
      ..uid = _uuid.v4()
      ..weekday = weekday
      ..name = '${weekdayLabel(weekday)} Workout'
      ..createdAt = now
      ..updatedAt = now
      ..dirty = true;
    await isar.collection<WorkoutTemplateModel>().put(template);
    return template;
  }

  Future<ExerciseTemplateModel> _findOrCreateExercise(
    Isar isar, {
    required WorkoutTemplateModel template,
    required String exerciseName,
  }) async {
    await template.exercises.load();
    final existing =
        template.exercises.cast<ExerciseTemplateModel?>().firstWhere(
              (exercise) =>
                  exercise?.archivedAt == null &&
                  exercise?.name.toLowerCase() == exerciseName.toLowerCase(),
              orElse: () => null,
            );
    if (existing != null) return existing;

    final exercise = ExerciseTemplateModel()
      ..uid = _uuid.v4()
      ..name = exerciseName
      ..sortOrder = template.exercises.length
      ..dirty = true;
    await isar.collection<ExerciseTemplateModel>().put(exercise);
    template.exercises.add(exercise);
    template
      ..updatedAt = DateTime.now()
      ..dirty = true;
    await template.exercises.save();
    await isar.collection<WorkoutTemplateModel>().put(template);
    return exercise;
  }

  Future<WorkoutLogModel> _findOrCreateLog(
    Isar isar, {
    required String templateUid,
    required DateTime workoutDate,
  }) async {
    final existing = await _findLog(isar, templateUid, dateOnly(workoutDate));
    if (existing != null) return existing;
    final log = WorkoutLogModel()
      ..uid = _uuid.v4()
      ..templateUid = templateUid
      ..workoutDate = dateOnly(workoutDate)
      ..startedAt = DateTime.now()
      ..dirty = true;
    await isar.collection<WorkoutLogModel>().put(log);
    return log;
  }

  Future<WorkoutLog?> _loadLogByUid(Isar isar, String uid) async {
    final log = await _findLogByUid(isar, uid);
    if (log == null) return null;
    await log.sets.load();
    return log.toDomain();
  }
}
