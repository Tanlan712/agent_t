import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import 'prefs_json.dart';

class SettingsStorage {
  static const _key = 'settings';

  final SharedPreferences _prefs;

  SettingsStorage(this._prefs);

  AppSettings load() => readPrefsJson(
        _prefs,
        _key,
        (json) => AppSettings.fromJson(json as Map<String, dynamic>),
        const AppSettings(),
      );

  Future<void> save(AppSettings settings) =>
      writePrefsJson(_prefs, _key, settings.toJson());
}
