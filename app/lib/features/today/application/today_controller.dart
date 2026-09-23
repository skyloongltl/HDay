import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/clock.dart';
import '../domain/today_overview.dart';
import '../domain/today_repository.dart';

final class TodayController extends StateNotifier<AsyncValue<TodayOverview>> {
  TodayController({required TodayRepository repository, required Clock clock})
      : _repository = repository,
        _clock = clock,
        super(const AsyncLoading());

  final TodayRepository _repository;
  final Clock _clock;

  Future<void> refresh() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() => _repository.load(_clock.today()));
    if (mounted) state = next;
  }
}
