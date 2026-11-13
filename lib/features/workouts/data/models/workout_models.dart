import 'package:isar/isar.dart';

part 'workout_models.g.dart';

@collection
class WorkoutTemplateModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uid;

  @Index()
  late int weekday;

  late String name;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isArchived = false;
  bool dirty = true;

  final exercises = IsarLinks<ExerciseTemplateModel>();
}

@collection
class ExerciseTemplateModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uid;

  late String name;
  int sortOrder = 0;
  DateTime? archivedAt;
  bool dirty = true;
}

@collection
class WorkoutLogModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uid;

  @Index()
  late String templateUid;

  @Index()
  late DateTime workoutDate;

  late DateTime startedAt;
  DateTime? completedAt;
  bool dirty = true;

  final sets = IsarLinks<SetLogModel>();
}

@collection
class SetLogModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uid;

  @Index()
  late String workoutLogUid;

  @Index()
  late String exerciseUid;

  late String exerciseName;
  late int setNumber;
  late double weight;
  late int reps;
  late DateTime completedAt;
  bool dirty = true;

  double get volume => weight * reps;
}
