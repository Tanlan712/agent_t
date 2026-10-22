import '../models/wallet_log.dart';

/// 相鄰兩筆紀錄之間的變化，由新到舊。
List<WalletChange> walletChanges(List<WalletSnapshot> snapshots) => [
      for (var i = snapshots.length - 1; i > 0; i--)
        WalletChange(
          from: snapshots[i - 1].at,
          at: snapshots[i].at,
          vp: snapshots[i].vp - snapshots[i - 1].vp,
          radianite: snapshots[i].radianite - snapshots[i - 1].radianite,
          kingdom: snapshots[i].kingdom - snapshots[i - 1].kingdom,
          newItems: snapshots[i].newItems,
          vpBalance: snapshots[i].vp,
        ),
    ];

/// 開始記錄以來的 VP 合計：儲值（增加）與花費（減少，回傳正數）。
({int toppedUp, int spent}) vpTotals(Iterable<WalletChange> changes) {
  var up = 0, down = 0;
  for (final c in changes) {
    if (c.vp > 0) up += c.vp;
    if (c.vp < 0) down -= c.vp;
  }
  return (toppedUp: up, spent: down);
}
