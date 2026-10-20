import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../storage/settings_storage.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsStorage _storage;
  AppSettings _settings;

  SettingsProvider(this._storage) : _settings = _storage.load();

  AppSettings get settings => _settings;

  Future<void> setResetTime(int hour, int minute) =>
      _save(_settings.copyWith(resetHour: hour, resetMinute: minute));

  Future<void> setHighlightWishlist(bool value) =>
      _save(_settings.copyWith(highlightWishlist: value));

  Future<void> setLoginShard(String shard) =>
      _save(_settings.copyWith(loginShard: shard));

  Future<void> _save(AppSettings next) async {
    _settings = next;
    await _storage.save(next);
    notifyListeners();
  }
}
