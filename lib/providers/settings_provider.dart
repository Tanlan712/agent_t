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

  /// 側欄順序；空的列表代表恢復預設。
  Future<void> setNavOrder(List<String> routes) =>
      _save(_settings.copyWith(navOrder: List.unmodifiable(routes)));

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

  /// 同意（記下時間）或撤回遠端操作；撤回時一併清除預選特務。
  Future<void> setRemoteControl(bool enabled, {DateTime? now}) =>
      _save(_settings.withRemote(
          enabled: enabled,
          since: (now ?? DateTime.now()).toIso8601String(),
          preferredAgent: _settings.preferredAgent));

  /// 預選特務；null 代表取消。未同意遠端操作時不會儲存。
  Future<void> setPreferredAgent(String? agentId) async {
    if (!_settings.remoteControl) return;
    await _save(_settings.withRemote(
        enabled: true,
        since: _settings.remoteControlSince,
        preferredAgent: agentId?.toLowerCase()));
  }

  Future<void> resetEva() => _save(clearEva(_settings));

  Future<void> _save(AppSettings next) async {
    _settings = next;
    await _storage.save(next);
    notifyListeners();
  }
}
