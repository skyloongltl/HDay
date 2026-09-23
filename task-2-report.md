# Task 2 Report

- `ExerciseRepository.save` updates an existing exercise by ID and inserts only when no row exists. It does not use `ConflictAlgorithm.replace`, so foreign-key child rows remain intact.
- `WorkoutRepository.deleteActive` scopes deletion to the requested ID and active statuses (`preparing`, `active`, `resting`, and `finishing`). Explicitly targeting a saved or discarded session raises `StateError` and leaves the row intact.
- `AppDatabase.open` now uses the public `OpenDatabaseOptions` API, so its callbacks work with any injected `DatabaseFactory`, including `databaseFactoryFfi`.
- Verification: `flutter test test/data -r expanded` passes after the API fix.
