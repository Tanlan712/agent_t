import 'package:flutter/foundation.dart';

import '../logic/purchase_history.dart';
import '../storage/purchase_history_storage.dart';

/// 錢包紀錄：Riot 沒有儲值紀錄的 API，只能由使用者在手機 App 匯入官方購買紀錄
/// （使用者決定 2026-10-23，AGENTS.md 第 3 節）。
class PurchaseHistoryProvider with ChangeNotifier {
  final PurchaseHistoryStorage _storage;
  final DateTime Function() _now;
  Map<String, ImportedPurchases> _purchases;

  PurchaseHistoryProvider(this._storage,
      {DateTime Function() now = DateTime.now})
      : _now = now,
        _purchases = _storage.load();

  /// 最後一次匯入的資料；沒匯入過時為 null。
  ImportedPurchases? purchases(String puuid) => _purchases[puuid];

  /// 匯入官方購買紀錄（取代這個帳號之前匯入的）。
  Future<void> import(String puuid, List<PurchaseRecord> records) async {
    _purchases = {
      ..._purchases,
      puuid: ImportedPurchases(importedAt: _now(), records: records),
    };
    await _storage.save(_purchases);
    notifyListeners();
  }

  /// 刪除 [puuid] 匯入的紀錄。
  Future<void> clear(String puuid) async {
    _purchases = {..._purchases}..remove(puuid);
    await _storage.save(_purchases);
    notifyListeners();
  }
}
