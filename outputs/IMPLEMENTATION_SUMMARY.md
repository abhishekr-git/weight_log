# WeightLog Implementation Summary

Built a Flutter app scaffold for WeightLog with:

- Clean Architecture boundaries: `domain`, `data`, and `presentation`.
- Repository Pattern via `WorkoutRepository` and `IsarWorkoutRepository`.
- Riverpod providers and session controller.
- Isar local models with code generation annotations.
- Offline-first weekly templates and workout logs.
- Fast set logging with automatic set numbers and previous-set prefill.
- Firestore backup service using anonymous Firebase Auth for Spark-plan-friendly sync.
- History, analytics, personal records, statistics, CSV export, and settings screens.
- Material Design 3 light/dark theme.

## Run in a Flutter SDK environment

```sh
flutter create . --platforms=android,ios,web,macos
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

## Enable Firebase cloud backup

```sh
dart pub global activate flutterfire_cli
flutterfire configure
```

Then configure Firestore security rules for per-user access under `users/{uid}`.
