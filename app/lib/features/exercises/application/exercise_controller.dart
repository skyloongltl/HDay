import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/domain/app_failure.dart';
import '../domain/exercise.dart';
import 'exercise_providers.dart';

String newExerciseId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class ExerciseState {
  const ExerciseState({
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedEquipment,
    this.items = const [],
    this.recentItems = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.loadFailed = false,
    this.failure,
  });
  final String searchQuery;
  final String? selectedCategory;
  final String? selectedEquipment;
  final List<Exercise> items;
  final List<Exercise> recentItems;
  final bool isSaving;
  final bool isLoading;
  final bool loadFailed;
  final AppFailure? failure;
}

class ExerciseController extends AsyncNotifier<ExerciseState> {
  String searchQuery = '';
  String? selectedCategory;
  String? selectedEquipment;
  int _request = 0;
  bool _disposed = false;
  @override
  Future<ExerciseState> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return _read();
  }

  Future<ExerciseState> _read() async {
    try {
      final repository = await ref.read(exerciseRepositoryProvider.future);
      final items = await repository.search(
        query: searchQuery,
        category: selectedCategory,
        equipment: selectedEquipment,
      );
      final recent = await repository.recent();
      return ExerciseState(
        searchQuery: searchQuery,
        selectedCategory: selectedCategory,
        selectedEquipment: selectedEquipment,
        items: items,
        recentItems: recent,
      );
    } catch (error) {
      return _withFailure(error, loadFailed: true);
    }
  }

  ExerciseState _withFailure(
    Object error, {
    bool isSaving = false,
    bool loadFailed = false,
  }) {
    final previous = state.valueOrNull;
    return ExerciseState(
      searchQuery: searchQuery,
      selectedCategory: selectedCategory,
      selectedEquipment: selectedEquipment,
      items: previous?.items ?? [],
      recentItems: previous?.recentItems ?? [],
      isSaving: isSaving,
      loadFailed: loadFailed,
      failure: error is AppFailure
          ? error
          : const AppFailure(FailureCode.persistence),
    );
  }

  Future<void> reload() async {
    final request = ++_request;
    final previous = state.valueOrNull ?? const ExerciseState();
    state = AsyncData(
      ExerciseState(
        searchQuery: searchQuery,
        selectedCategory: selectedCategory,
        selectedEquipment: selectedEquipment,
        items: previous.items,
        recentItems: previous.recentItems,
        isSaving: previous.isSaving,
        isLoading: true,
      ),
    );
    final next = await _read();
    if (!_disposed && request == _request) state = AsyncData(next);
  }

  Future<void> search(String value) async {
    searchQuery = value;
    await reload();
  }

  Future<void> setCategory(String? value) async {
    if (value != null) ExerciseCategory.fromCode(value);
    selectedCategory = value;
    await reload();
  }

  Future<void> setEquipment(String? value) async {
    if (value != null) ExerciseEquipment.fromCode(value);
    selectedEquipment = value;
    await reload();
  }

  Future<void> save(Exercise exercise) => _write(exercise.id, () async {
        final repository = await ref.read(exerciseRepositoryProvider.future);
        final existing = await repository.find(exercise.id);
        final now = ref.read(clockProvider).nowUtc();
        await repository.save(
          Exercise(
            id: exercise.id,
            name: exercise.name,
            category: exercise.category,
            equipment: exercise.equipment,
            defaultUnit: exercise.defaultUnit,
            note: exercise.note,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
      });

  Future<void> delete(String id) => _write(id, () async {
        await (await ref.read(exerciseRepositoryProvider.future)).delete(id);
      });

  Future<void> _write(String id, Future<void> Function() action) async {
    if (state.valueOrNull?.isSaving ?? false) return;
    final previous = state.valueOrNull ?? const ExerciseState();
    state = AsyncData(
      ExerciseState(
        searchQuery: searchQuery,
        selectedCategory: selectedCategory,
        selectedEquipment: selectedEquipment,
        items: previous.items,
        recentItems: previous.recentItems,
        isSaving: true,
      ),
    );
    try {
      await action();
      ref.invalidate(exerciseByIdProvider(id));
      ref.invalidate(exercisePickerControllerProvider);
      await reload();
    } catch (error) {
      if (!_disposed) state = AsyncData(_withFailure(error));
    }
  }
}
