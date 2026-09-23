import 'app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> read();

  Future<void> save(AppSettings settings);
}
