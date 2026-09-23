import '../../../core/domain/local_date.dart';
import 'today_overview.dart';

abstract interface class TodayRepository {
  Future<TodayOverview> load(LocalDate date);
}
