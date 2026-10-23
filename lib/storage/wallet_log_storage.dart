import 'package:shared_preferences/shared_preferences.dart';

import '../logic/purchase_history.dart';
import '../models/wallet_log.dart';
import 'prefs_json.dart';

/// 每個帳號（puuid）的錢包紀錄，只存在這個瀏覽器（localStorage）。
class WalletLogStorage {
  static const _key = 'wallet_log_v1';
  static const _purchasesKey = 'purchase_history_v1';

  final SharedPreferences _prefs;

  WalletLogStorage(this._prefs);

  Map<String, AccountWalletLog> load() => readPrefsJson(
        _prefs,
        _key,
        (json) => {
          for (final e in (json as Map<String, dynamic>).entries)
            e.key: AccountWalletLog.fromJson(e.value as Map<String, dynamic>),
        },
        <String, AccountWalletLog>{},
      );

  Future<void> save(Map<String, AccountWalletLog> logs) => writePrefsJson(
      _prefs, _key, {for (final e in logs.entries) e.key: e.value.toJson()});

  /// 從 Riot 官方購買紀錄匯入的資料（使用者決定 2026-10-23），依帳號分開。
  Map<String, ImportedPurchases> loadPurchases() => readPrefsJson(
        _prefs,
        _purchasesKey,
        (json) => {
          for (final e in (json as Map<String, dynamic>).entries)
            e.key: ImportedPurchases.fromJson(e.value as Map<String, dynamic>),
        },
        <String, ImportedPurchases>{},
      );

  Future<void> savePurchases(Map<String, ImportedPurchases> purchases) =>
      writePrefsJson(_prefs, _purchasesKey,
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
