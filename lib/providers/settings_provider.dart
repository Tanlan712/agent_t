import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/notification_service.dart';
import '../storage/settings_storage.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsStorage _storage;
  final NotificationService _notifications;
  AppSettings _settings;
  bool _permissionDenied = false;

  SettingsProvider(this._storage, this._notifications)
      : _settings = _storage.load();

  AppSettings get settings => _settings;
  bool get permissionDenied => _permissionDenied;

  Future<void> setNotifyEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _notifications.requestPermission();
      _permissionDenied = !granted;
      if (!granted) {
        notifyListeners();
        return;
      }
      await _save(_settings.copyWith(notifyEnabled: true));
      await _notifications.scheduleDaily(_settings.notifyHour, _settings.notifyMinute);
    } else {
      await _notifications.cancelDaily();
      await _save(_settings.copyWith(notifyEnabled: false));
    }
  }

  Future<void> setNotifyTime(int hour, int minute) async {
    await _save(_settings.copyWith(notifyHour: hour, notifyMinute: minute));
    if (_settings.notifyEnabled) {
      await _notifications.cancelDaily();
      await _notifications.scheduleDaily(hour, minute);
    }
  }

  Future<void> setHighlightWishlist(bool value) =>
      _save(_settings.copyWith(highlightWishlist: value));

  Future<void> _save(AppSettings next) async {
    _settings = next;
    await _storage.save(next);
    notifyListeners();
  }
}
