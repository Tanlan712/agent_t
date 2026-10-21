import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../storage/settings_storage.dart';
import '../logic/eva_progress.dart';

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

  Future<void> setTheme({String? style, String? accent, String? brightness}) =>
      _save(_settings.copyWith(
          themeStyle: style, themeAccent: accent, themeBrightness: brightness));

  Future<void> setBackgroundMotion(bool value) =>
      _save(_settings.copyWith(backgroundMotion: value));

  /// EVA 本機狀態（劇集、彩蛋發現等）的更新。
  Future<void> updateEva(AppSettings Function(AppSettings) update) async {
    final next = update(_settings);
    // 沒有改變（例如已經記錄過的彩蛋）時不存檔、不通知。
    if (identical(next, _settings)) return;
    await _save(next);
  }

  Future<void> resetEva() => _save(clearEva(_settings));

  Future<void> _save(AppSettings next) async {
    _settings = next;
    await _storage.save(next);
    notifyListeners();
  }
}
