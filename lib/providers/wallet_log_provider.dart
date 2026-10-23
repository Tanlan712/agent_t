import 'package:flutter/foundation.dart';

import '../logic/purchase_history.dart';
import '../logic/wallet_history.dart';
import '../models/riot_session.dart';
import '../models/wallet_log.dart';
import '../storage/wallet_log_storage.dart';

/// 錢包紀錄：Riot 沒有儲值紀錄的 API，所以每次同步錢包時記下餘額，比對前後找出儲值與花費。
/// 不另外送請求；只記得到有打開這個 App 的時段（使用者決定 2026-10-22）。
class WalletLogProvider with ChangeNotifier {
  final WalletLogStorage _storage;
  final DateTime Function() _now;
  final int max;
  Map<String, AccountWalletLog> _logs;
  Map<String, ImportedPurchases> _purchases;

  WalletLogProvider(this._storage,
      {DateTime Function() now = DateTime.now, this.max = 1000})
      : _now = now,
        _logs = _storage.load(),
        _purchases = _storage.loadPurchases();

  /// 最後一次從 Riot 官方購買紀錄匯入的資料；沒匯入過時為 null。
  ImportedPurchases? purchases(String puuid) => _purchases[puuid];

  /// 匯入官方購買紀錄（取代這個帳號之前匯入的）。
  Future<void> importPurchases(
      String puuid, List<PurchaseRecord> records) async {
    _purchases = {
      ..._purchases,
      puuid: ImportedPurchases(importedAt: _now(), records: records),
    };
    await _storage.savePurchases(_purchases);
    notifyListeners();
  }

  List<WalletSnapshot> snapshots(String puuid) =>
      _logs[puuid]?.snapshots ?? const [];

  /// [puuid] 的變化，由新到舊。
  List<WalletChange> changes(String puuid) => walletChanges(snapshots(puuid));

  /// 開始記錄的時間；還沒有紀錄時為 null。
  DateTime? since(String puuid) {
    final s = snapshots(puuid);
    return s.isEmpty ? null : s.first.at;
  }

  /// 同步錢包後呼叫：[ownedItems] 是已擁有的造型等級 ItemID。
  /// 餘額和已擁有造型都沒變時不新增紀錄。
  Future<void> record(
      String puuid, RiotWallet wallet, Set<String> ownedItems) async {
    final log = _logs[puuid] ?? const AccountWalletLog();
    final last = log.snapshots.isEmpty ? null : log.snapshots.last;
    final newItems = last == null
        ? const <String>[]
        : (ownedItems.difference(log.owned).toList()..sort());
    final same = last != null &&
        last.vp == wallet.vp &&
        last.radianite == wallet.radianite &&
        last.kingdom == wallet.kingdom &&
        newItems.isEmpty;
    if (same && setEquals(log.owned, ownedItems)) return;
    var list = log.snapshots;
    if (!same) {
      list = [
        ...list,
        WalletSnapshot(
          at: _now(),
          vp: wallet.vp,
          radianite: wallet.radianite,
          kingdom: wallet.kingdom,
          newItems: newItems,
        ),
      ];
      if (list.length > max) list = list.sublist(list.length - max);
    }
    _logs = {
      ..._logs,
      puuid: AccountWalletLog(snapshots: list, owned: ownedItems),
    };
    await _storage.save(_logs);
    notifyListeners();
  }

  /// 刪除 [puuid] 的所有紀錄。
  Future<void> clear(String puuid) async {
    _logs = {..._logs}..remove(puuid);
    _purchases = {..._purchases}..remove(puuid);
    await _storage.save(_logs);
    await _storage.savePurchases(_purchases);
    notifyListeners();
  }
}
