import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../logic/shop_time.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/progress_provider.dart';
import '../../../providers/riot_provider.dart';
import '../../../providers/shop_provider.dart';

/// 資料來源的狀態：正常、未連線（未登入或尚未讀取）、失敗。
enum SourceLevel { ok, off, failed }

class SourceState {
  final String label;
  final SourceLevel level;

  const SourceState(this.label, this.level);
}

/// 規格 §4.3 的來源判定（純函式，方便測試）：
/// 未登入時商店與錢包是「未連線」，不算失敗；只有 provider 回報錯誤才是失敗。
List<SourceState> computeSources({
  required bool loggedIn,
  required bool dailyActive,
  required bool walletLoaded,
  required Map<String, String> collectionErrors,
  required String? progressError,
}) {
  SourceLevel when(bool ok) =>
      !loggedIn ? SourceLevel.off : (ok ? SourceLevel.ok : SourceLevel.off);
  return [
    SourceState('商店', when(dailyActive)),
    SourceState('錢包', when(walletLoaded)),
    SourceState(
        '收藏',
        collectionErrors.isNotEmpty
            ? SourceLevel.failed
            : (loggedIn ? SourceLevel.ok : SourceLevel.off)),
    SourceState(
        '通行證',
        progressError != null
            ? SourceLevel.failed
            : (loggedIn ? SourceLevel.ok : SourceLevel.off)),
  ];
}

/// 從現有 provider 彙整載入中與來源狀態；只讀狀態，不觸發任何載入。
abstract final class AppActivity {
  static bool loading(BuildContext context) =>
      context.watch<RiotProvider>().isBusy ||
      context.watch<CollectionProvider>().isLoading ||
      context.watch<ProgressProvider>().isLoading ||
      context.watch<CatalogProvider>().isLoading;

  static List<SourceState> sources(BuildContext context, {DateTime? now}) {
    final riot = context.watch<RiotProvider>();
    return computeSources(
      loggedIn: riot.isLoggedIn,
      dailyActive: isDailyActive(
          context.watch<ShopProvider>().shop, now ?? DateTime.now()),
      walletLoaded: riot.wallet != null,
      collectionErrors: context.watch<CollectionProvider>().errors,
      progressError: context.watch<ProgressProvider>().error,
    );
  }
}
