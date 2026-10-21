import 'collection_provider.dart';
import 'progress_provider.dart';
import 'riot_provider.dart';

/// 登入後（包括重新開頁時恢復登入）在背景預先讀取一次收藏、等級、通行證與任務。
/// 依序執行：收藏讀完才讀通行證，Riot 請求同時最多 2 個（AGENTS.md 第 3 節）。
class LoginPrefetcher {
  final RiotProvider _riot;
  final CollectionProvider _collection;
  final ProgressProvider _progress;
  String? _prefetchedFor;

  LoginPrefetcher(this._riot, this._collection, this._progress) {
    _riot.addListener(_onRiot);
    _onRiot();
  }

  void _onRiot() {
    final puuid = _riot.isLoggedIn ? _riot.session?.puuid : null;
    if (puuid == null) {
      _prefetchedFor = null;
      return;
    }
    if (puuid == _prefetchedFor) return;
    _prefetchedFor = puuid;
    _run();
  }

  Future<void> _run() async {
    await _collection.load();
    await _progress.load();
  }

  void dispose() => _riot.removeListener(_onRiot);
}
