# WeightLog

WeightLog is a production-oriented Flutter workout tracker scaffolded with Clean Architecture, Repository Pattern, Riverpod, Isar local persistence, and Firebase Firestore sync hooks.

## MVP included

- Weekly Monday-Sunday workout templates that repeat every week while showing real calendar dates.
- Custom workout/exercise management.
- Fast workout logging with automatic set numbers.
- Previous matching workout set auto-fill.
- Local auto-save after each completed set.
- History, basic analytics, personal records, stats, CSV export, settings, and Firestore sync surface.

## Free personal-use stack

- Flutter and Dart.
- Riverpod for state management.
- Isar for offline local database.
- Firebase Spark plan for Auth and Firestore backup/sync.

## Setup

```sh
flutter create . --platforms=android,ios,web,macos
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Firebase is optional for local-only use. To enable cloud sync, configure Firebase with FlutterFire:

```sh
dart pub global activate flutterfire_cli
flutterfire configure
```

That generates `lib/firebase_options.dart`. The app detects this at startup via the normal Firebase initialization path once the file is added.
