import 'package:flutter/foundation.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../models/riot_session.dart';
import '../services/match_client.dart';
import '../services/riot_client.dart';
import 'match_detail_cache.dart';
import 'riot_provider.dart';

class MatchEntry {
  final MatchRef ref;
  final MatchDetail? detail;
  final bool failed;

  const MatchEntry({required this.ref, this.detail, this.failed = false});
}

/// 對戰紀錄分頁與單場詳情；資料只放在記憶體。
class MatchHistoryProvider with ChangeNotifier {
  static const notLoggedInMessage = '請先登入 Riot';
  static const expiredMessage = '登入已過期，請重新登入';
  static const formatErrorMessage = '資料格式不符';

  final MatchClient _client;
  final RiotProvider _riot;
  final int pageSize;
  final int maxConcurrent;

  final List<MatchEntry> _entries = [];
  final Map<String, MatchDetail> _details = {};
  Map<String, int> _rr = {};
  RankInfo? _rank;
  int _total = 0;
  bool _isLoading = false;
  String? _error;
  int _generation = 0;
  String? _loadedFor;

  final MatchDetailCache cache;

  /// 要查看的玩家；null 表示自己（含牌位與 RR）。
  final String? focusPuuid;
  bool _disposed = false;

  MatchHistoryProvider(this._client, this._riot,
      {MatchDetailCache? cache,
      this.focusPuuid,
      this.pageSize = 10,
      this.maxConcurrent = 4})
      : cache = cache ?? MatchDetailCache();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// 自己的資料 401／403 都視為登入失效；查看他人時 403 只代表 Riot 不提供。
  bool _isAuthError(RiotApiException e) =>
      e.statusCode == 401 || (focusPuuid == null && e.statusCode == 403);

  List<MatchEntry> get entries => List.unmodifiable(_entries);
  bool get hasMore => _entries.length < _total;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RankInfo? get rank => _rank;
  List<int> get recentRr => _rr.values.take(5).toList();
  MatchDetail? detail(String matchId) => _details[matchId];

  /// 目前資料屬於哪個帳號（puuid）；換帳號時頁面據此重新載入。
  String? get loadedFor => _loadedFor;

  Future<void> loadFirstPage() async {
    // 每次重新載入換一個世代；舊世代還在進行的請求，結果一律丟棄。
    final gen = ++_generation;
    _entries.clear();
    _details.clear();
    _rr = {};
    _rank = null;
    _total = 0;
    _error = null;
    final s = _session();
    if (s == null) return;
    _loadedFor = s.puuid;
    await _guarded(gen, () async {
      if (focusPuuid == null) {
        // 牌位只是頁首資訊：失敗（非登入過期）時留空，不阻擋列表。
        final rank = await _optional(() => _client.fetchRank(s), null);
        final rr = await _optional(
            () => _client.fetchRrChanges(s, 20), <String, int>{});
        if (gen != _generation) return;
        _rank = rank;
        _rr = rr;
      }
      await _loadPage(s, 0, gen);
    });
  }

  Future<void> loadMore() async {
    if (_isLoading || !hasMore) return;
    final s = _session();
    if (s == null) return;
    final gen = _generation;
    await _guarded(gen, () => _loadPage(s, _entries.length, gen));
  }

  Future<T> _optional<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on RiotApiException catch (e) {
      if (_isAuthError(e)) rethrow;
      debugPrint('牌位資料取得失敗：${e.message}');
      return fallback;
    }
  }

  RiotSession? _session() {
    final s = _riot.session;
    if (s == null || !_riot.isLoggedIn) {
      _error = notLoggedInMessage;
      notifyListeners();
      return null;
    }
    return s;
  }

  Future<void> _guarded(int gen, Future<void> Function() body) async {
    _isLoading = true;
    notifyListeners();
    try {
      await body();
    } on RiotApiException catch (e) {
      if (gen == _generation) {
        if (_isAuthError(e)) {
          _riot.logout();
          // 讓同一個帳號重新登入後，頁面能再次觸發載入。
          _loadedFor = null;
          _error = expiredMessage;
        } else {
          _error = e.message;
        }
      }
    } catch (e) {
      debugPrint('對戰紀錄解析失敗：${e.runtimeType}');
      if (gen == _generation) _error = formatErrorMessage;
    } finally {
      if (gen == _generation) _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPage(RiotSession s, int start, int gen) async {
    final (refs, total) =
        await _client.fetchHistory(s, start, pageSize, puuid: focusPuuid);
    if (gen != _generation) return;
    _total = total;
    final results = List<MatchEntry?>.filled(refs.length, null);
    final fetched = <String, MatchDetail>{};
    RiotApiException? authError;
    var next = 0;

    // 固定數量的 worker 從佇列取場次，同時最多 maxConcurrent 個請求。
    Future<void> worker() async {
      while (next < refs.length && authError == null) {
        final i = next++;
        final ref = refs[i];
        try {
          final json = await cache.json(s, ref.matchId, _client);
          final d = mapMatchDetail(json, focusPuuid ?? s.puuid,
              selfPuuid: s.puuid, rrChange: _rr[ref.matchId]);
          fetched[ref.matchId] = d;
          results[i] = MatchEntry(ref: ref, detail: d);
        } on RiotApiException catch (e) {
          if (_isAuthError(e)) authError = e;
          results[i] = MatchEntry(ref: ref, failed: true);
        } catch (e) {
          debugPrint('對戰詳情解析失敗：${e.runtimeType}');
          results[i] = MatchEntry(ref: ref, failed: true);
        }
      }
    }

    final workers = refs.length < maxConcurrent ? refs.length : maxConcurrent;
    await Future.wait([for (var w = 0; w < workers; w++) worker()]);
    if (gen != _generation) return;
    if (authError != null) throw authError!;

    // 實測 match-details 沒有名稱：整頁的未知玩家一次向 name-service 查詢。
    final unnamed = {
      for (final d in fetched.values)
        for (final p in d.teams.values.expand((t) => t))
          if (p.riotId == unknownPlayerName) p.puuid,
    };
    final names = await _optional(
        () => _client.fetchNames(s, unnamed), <String, String>{});
    if (gen != _generation) return;
    if (names.isNotEmpty) {
      fetched.updateAll((_, d) => applyNames(d, names));
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final d = r?.detail;
        if (r != null && d != null) {
          results[i] =
              MatchEntry(ref: r.ref, detail: fetched[r.ref.matchId] ?? d);
        }
      }
    }

    _details.addAll(fetched);
    _entries.addAll(results.whereType<MatchEntry>());
  }
}
