import 'package:shared_preferences/shared_preferences.dart';

import '../logic/purchase_history.dart';
import 'prefs_json.dart';

/// 從 Riot 官方購買紀錄匯入的資料（使用者決定 2026-10-23），依帳號（puuid）分開，只存在這支手機。
class PurchaseHistoryStorage {
  static const _key = 'purchase_history_v1';

  final SharedPreferences _prefs;

  PurchaseHistoryStorage(this._prefs);

  Map<String, ImportedPurchases> load() => readPrefsJson(
        _prefs,
        _key,
        (json) => {
          for (final e in (json as Map<String, dynamic>).entries)
            e.key: ImportedPurchases.fromJson(e.value as Map<String, dynamic>),
        },
        <String, ImportedPurchases>{},
      );

  Future<void> save(Map<String, ImportedPurchases> purchases) => writePrefsJson(
      _prefs,
      _key,
      {for (final e in purchases.entries) e.key: e.value.toJson()});
}

/// 一個帳號最後一次匯入的官方購買紀錄。
class ImportedPurchases {
  final DateTime importedAt;
  final List<PurchaseRecord> records;

  const ImportedPurchases({required this.importedAt, required this.records});

  factory ImportedPurchases.fromJson(Map<String, dynamic> json) =>
      ImportedPurchases(
        importedAt: DateTime.parse(json['importedAt'] as String),
        records: [
          for (final r in json['records'] as List)
            PurchaseRecord.fromJson(r as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
        'importedAt': importedAt.toIso8601String(),
        'records': [for (final r in records) r.toJson()],
      };
}
