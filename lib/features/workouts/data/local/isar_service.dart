import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/workout_models.dart';

class IsarService {
  IsarService._();

  static final IsarService instance = IsarService._();

  Isar? _isar;

  Future<Isar> get db async {
    final current = _isar;
    if (current != null && current.isOpen) return current;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        WorkoutTemplateModelSchema,
        ExerciseTemplateModelSchema,
        WorkoutLogModelSchema,
        SetLogModelSchema,
      ],
      directory: dir.path,
      inspector: false,
    );
    return _isar!;
  }
}
