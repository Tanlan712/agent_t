import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本機資料備份（規格 docs/superpowers/specs/2026-11-01-five-features-design.md §4）：
/// 把只存在這台裝置的紀錄與設定匯出成一個 JSON 檔，之後在同一台或另一台裝置還原。
/// **不含** token、Riot 登入 cookie（ssid）、帳號清單與快取（AGENTS.md 第 4 節）。

const backupFormat = 'agent-t-backup';
const backupVersion = 1;

/// 一類資料：顯示用名稱與符合的 key。
class BackupCategory {
  final String label;
  final bool Function(String key) matches;

  const BackupCategory(this.label, this.matches);
}

bool _exact(String key, String name) => key == name;

/// 可以備份的資料（白名單）；不在這裡的 key 一律不匯出、不還原。
final backupCategories = <BackupCategory>[
  BackupCategory('設定（主題、刷新時間、導覽順序）', (k) => _exact(k, 'settings')),
  BackupCategory('商店歷史', (k) => k.startsWith('shop_history_v1_')),
  BackupCategory('遇過的玩家', (k) => _exact(k, 'seen_players_v2')),
  BackupCategory('同場紀錄（遇過 N）', (k) => _exact(k, 'encounters_v1')),
  BackupCategory('通行證每日經驗', (k) => k.startsWith('pass_xp_v1_')),
  BackupCategory('官方購買紀錄', (k) => _exact(k, 'purchase_history_v1')),
  BackupCategory('造型實際定價', (k) => _exact(k, 'offer_prices_v1')),
  BackupCategory('願望清單', (k) => _exact(k, 'wishlist')),
  BackupCategory('App 更新設定', (k) => _exact(k, 'app_update_auto_check_v1')),
];

/// 絕對不能進備份的 key（登入資訊與帳號）；白名單之外的第二道保險。
bool _forbidden(String key) {
  final k = key.toLowerCase();
  return k.startsWith('riot') ||
      k.contains('token') ||
      k.contains('ssid') ||
      k.contains('cookie') ||
      k.contains('session');
}

bool isBackupKey(String key) =>
    !_forbidden(key) && backupCategories.any((c) => c.matches(key));

String? categoryOf(String key) {
  for (final c in backupCategories) {
    if (c.matches(key)) return c.label;
  }
  return null;
}

Object? _encodeValue(Object? v) => switch (v) {
      String s => {'t': 's', 'v': s},
      bool b => {'t': 'b', 'v': b},
      int i => {'t': 'i', 'v': i},
      double d => {'t': 'd', 'v': d},
      List<String> l => {'t': 'l', 'v': l},
      _ => null,
    };

/// 產生備份內容（JSON 物件）。
Map<String, dynamic> buildBackup(SharedPreferences prefs, DateTime now) {
  final data = <String, dynamic>{};
  final keys = prefs.getKeys().where(isBackupKey).toList()..sort();
  for (final k in keys) {
    final v = _encodeValue(prefs.get(k));
    if (v != null) data[k] = v;
  }
  return {
    'format': backupFormat,
    'version': backupVersion,
    'exportedAt': now.toUtc().toIso8601String(),
    'data': data,
  };
}

String encodeBackup(Map<String, dynamic> backup) => jsonEncode(backup);

/// 讀進來、檢查過的備份。
class BackupContents {
  final DateTime? exportedAt;

  /// key → 已解碼的值（String／bool／int／double／List<String>）。
  final Map<String, Object> values;

  const BackupContents({this.exportedAt, required this.values});

  /// 每一類有幾筆 key，給確認對話框顯示。
  Map<String, int> get summary {
    final out = <String, int>{};
    for (final k in values.keys) {
      final c = categoryOf(k);
      if (c != null) out[c] = (out[c] ?? 0) + 1;
    }
    return out;
  }
}

/// 解析備份檔；格式不對時丟出 [FormatException]（訊息給使用者看）。
/// 白名單以外的 key（例如被人加進去的 token）直接略過。
BackupContents parseBackup(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } catch (_) {
    throw const FormatException('這不是 Agent T 的備份檔');
  }
  if (json is! Map<String, dynamic> || json['format'] != backupFormat) {
    throw const FormatException('這不是 Agent T 的備份檔');
  }
  final version = json['version'];
  if (version is! int || version > backupVersion) {
    throw const FormatException('備份檔的版本較新，請先更新 App');
  }
  final data = json['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('備份檔內容損壞');
  }
  final values = <String, Object>{};
  for (final e in data.entries) {
    if (!isBackupKey(e.key)) continue;
    final v = e.value;
    if (v is! Map<String, dynamic>) continue;
    final raw = v['v'];
    final Object? decoded = switch (v['t']) {
      's' when raw is String => raw,
      'b' when raw is bool => raw,
      'i' when raw is int => raw,
      'd' when raw is num => raw.toDouble(),
      'l' when raw is List => [
          for (final x in raw)
            if (x is String) x
        ],
      _ => null,
    };
    if (decoded != null) values[e.key] = decoded;
  }
  final at = json['exportedAt'];
  return BackupContents(
      exportedAt: at is String ? DateTime.tryParse(at) : null, values: values);
}

/// 設定裡的遠端操作同意不跟著備份走：還原後一律要重新在設定頁同意（AGENTS.md 第 3 節）。
String _withoutRemoteConsent(String settingsJson) {
  try {
    final m = jsonDecode(settingsJson);
    if (m is! Map<String, dynamic>) return settingsJson;
    m['remoteControl'] = false;
    m['remoteControlSince'] = null;
    m['preferredAgent'] = null;
    return jsonEncode(m);
  } catch (_) {
    return settingsJson;
  }
}

/// 把備份寫回本機：備份裡有的 key 覆蓋，沒有的保留原樣。回傳寫入的筆數。
Future<int> restoreBackup(
    SharedPreferences prefs, BackupContents contents) async {
  var n = 0;
  for (final e in contents.values.entries) {
    final k = e.key;
    if (!isBackupKey(k)) continue;
    final v = e.value;
    final ok = switch (v) {
      String s => await prefs.setString(
          k, k == 'settings' ? _withoutRemoteConsent(s) : s),
      bool b => await prefs.setBool(k, b),
      int i => await prefs.setInt(k, i),
      double d => await prefs.setDouble(k, d),
      List<String> l => await prefs.setStringList(k, l),
      _ => false,
    };
    if (ok) n++;
  }
  return n;
}

/// 備份檔名，例如 `agent-t-backup-20261101.json`。
String backupFileName(DateTime now) {
  final l = now.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'agent-t-backup-${l.year}${two(l.month)}${two(l.day)}.json';
}
