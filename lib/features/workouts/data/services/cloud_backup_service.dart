import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/workout.dart';

class CloudBackupService {
  CloudBackupService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> backup({
    required List<WorkoutTemplate> templates,
    required List<WorkoutLog> logs,
  }) async {
    try {
      final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
      if (user == null) {
        throw const SyncException('Could not create backup identity.');
      }

      final batch = _firestore.batch();
      final root = _firestore.collection('users').doc(user.uid);
      batch.set(root, {'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));

      for (final template in templates) {
        batch.set(root.collection('templates').doc(template.uid), {
          'weekday': template.weekday,
          'name': template.name,
          'updatedAt': template.updatedAt.toIso8601String(),
          'exercises': [
            for (final exercise in template.exercises)
              {
                'uid': exercise.uid,
                'name': exercise.name,
                'sortOrder': exercise.sortOrder,
              },
          ],
        });
      }

      for (final log in logs) {
        batch.set(root.collection('workoutLogs').doc(log.uid), {
          'templateUid': log.templateUid,
          'workoutDate': log.workoutDate.toIso8601String(),
          'startedAt': log.startedAt.toIso8601String(),
          'completedAt': log.completedAt?.toIso8601String(),
          'sets': [
            for (final set in log.sets)
              {
                'uid': set.uid,
                'exerciseUid': set.exerciseUid,
                'exerciseName': set.exerciseName,
                'setNumber': set.setNumber,
                'weight': set.weight,
                'reps': set.reps,
                'completedAt': set.completedAt.toIso8601String(),
              },
          ],
        });
      }

      await batch.commit();
    } catch (error) {
      throw SyncException('Firestore backup failed.', error);
    }
  }
}
