import 'package:flutter/foundation.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../models/riot_session.dart';
import '../services/match_client.dart';
import '../services/riot_client.dart';
import 'match_detail_cache.dart';
import 'riot_provider.dart';
import 'riot_retry.dart';

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
  static const notProvidedMessage = 'Riot 不提供這位玩家的紀錄';

  final MatchClient _client;
  final RiotProvider _riot;
  final int pageSize;
  final int maxConcurrent;

  final List<MatchEntry> _entries = [];
  final Map<String, MatchDetail> _details = {};
  final Map<String, int> _rr = {};

  /// 已讀過的競技更新場次（含定級、沒有 RR 的），用來判斷還要不要往下讀。
  final Set<String> _rrSeen = {};
  bool _rrDone = false;
  Map<String, dynamic>? _mmr;
  RankInfo? _rank;
  bool _rankLoading = false;
  int _total = 0;
  bool _isLoading = false;
  String? _error;
  int _generation = 0;
  String? _loadedFor;

  final MatchDetailCache cache;

  /// 要查看的玩家；null 表示自己。牌位與 RR 兩者都會讀。
  final String? focusPuuid;

  /// 每頁載入完成（已補上名稱）後呼叫，例如記錄遇過的玩家。
  final void Function(Iterable<MatchDetail> details)? onDetails;
  bool _disposed = false;

  /// 重試前的等待；測試傳入立即完成的版本。
  final Future<void> Function(Duration) _delay;

  MatchHistoryProvider(this._client, this._riot,
      {MatchDetailCache? cache,
      this.focusPuuid,
      this.onDetails,
      this.pageSize = 10,
      this.maxConcurrent = 4,
      Future<void> Function(Duration)? delay})
      : cache = cache ?? MatchDetailCache(),
        _delay = delay ?? Future<void>.delayed;

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

  /// 牌位（MMR）還在讀取中；畫面據此顯示「讀取中」而不是「未定級」。
  bool get rankLoading => _rankLoading;

  /// 焦點玩家的 MMR 原始資料（歷史最高、本幕戰績用）；讀不到時為 null。
  Map<String, dynamic>? get mmr => _mmr;
  List<int> get recentRr => _rr.values.take(5).toList();
  MatchDetail? detail(String matchId) => _details[matchId];

  /// 目前資料屬於哪個帳號（puuid）；換帳號時頁面據此重新載入。
  String? get loadedFor => _loadedFor;

  Future<void> loadFirstPage() async {
    // 每次重新載入換一個世代；舊世代還在進行的請求，結果一律丟棄。
    final gen = ++_generation;
    _entries.clear();
    _details.clear();
    _rr.clear();
    _rrSeen.clear();
    _rrDone = false;
    _mmr = null;
    _rank = null;
    _rankLoading = false;
    _total = 0;
    _error = null;
    final s = _session();
    if (s == null) return;
    _loadedFor = s.puuid;
    await _guarded(gen, () async {
      // 牌位只是頁首資訊：和列表同時讀、各自顯示；失敗（非登入過期）時留空，不阻擋列表。
      final profile = _loadProfile(s, gen);
      await _loadPage(s, 0, gen);
      if (await profile case final e?) throw e;
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

  /// 讀焦點玩家的 MMR；不丟出例外，登入失效時回傳該例外交給呼叫端處理。
  Future<RiotApiException?> _loadProfile(RiotSession s, int gen) async {
    _rankLoading = true;
    try {
      final mmr = await _optional<Map<String, dynamic>?>(
          () => withRiotRetry(
              () => _client.fetchMmrJson(s, focusPuuid ?? s.puuid),
              delay: _delay),
          null);
      if (gen != _generation) return null;
      _mmr = mmr;
      _rank = mmr == null ? null : mapRank(mmr);
      return null;
    } on RiotApiException catch (e) {
      return e;
    } catch (e) {
      debugPrint('牌位解析失敗：${e.runtimeType}');
      return null;
    } finally {
      if (gen == _generation) {
        _rankLoading = false;
        notifyListeners();
      }
    }
  }

  /// 補讀競技更新，直到這一頁的競技場次都有 RR（或 Riot 沒有更多）；最多讀 3 批。
  Future<void> _ensureRr(RiotSession s, List<MatchRef> refs, int gen) async {
    for (var i = 0; i < 3 && !_rrDone; i++) {
      final missing = refs.any(
          (r) => r.queueId == 'competitive' && !_rrSeen.contains(r.matchId));
      if (!missing) return;
      const n = MatchClient.maxUpdatesRange;
      final page = await _optional<(Map<String, int>, List<String>)?>(
          () => withRiotRetry(
              () =>
                  _client.fetchRrPage(s, _rrSeen.length, n, puuid: focusPuuid),
              delay: _delay),
          null);
      if (gen != _generation) return;
      if (page == null) {
        _rrDone = true;
        return;
      }
      final (rr, ids) = page;
      _rr.addAll(rr);
      _rrSeen.addAll(ids);
      if (ids.length < n) _rrDone = true;
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
          _riot.expire();
          // 讓同一個帳號重新登入後，頁面能再次觸發載入。
          _loadedFor = null;
          _error = expiredMessage;
        } else if (focusPuuid != null && e.statusCode == 403) {
          _error = notProvidedMessage;
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
    // 網頁上限流回應沒有 CORS 標頭，只會看到「連線失敗」；查看他人時尤其容易遇到，
    // 所以列表與單場都依 AGENTS.md 第 3 節退避重試。
    final (refs, total) = await withRiotRetry(
        () => _client.fetchHistory(s, start, pageSize, puuid: focusPuuid),
        delay: _delay);
    if (gen != _generation) return;
    _total = total;
    // 先放骨架卡片，每讀完一場就換上，不用等整頁（一頁 20 場）都讀完才顯示。
    final base = _entries.length;
    _entries.addAll([for (final r in refs) MatchEntry(ref: r)]);
    notifyListeners();
    final fetched = <String, MatchDetail>{};
    RiotApiException? authError;
    var next = 0;

    void put(int i, MatchEntry e) {
      if (gen != _generation) return;
      _entries[base + i] = e;
      notifyListeners();
    }

    // 固定數量的 worker 從佇列取場次，同時最多 maxConcurrent 個請求。
    Future<void> worker() async {
      while (next < refs.length && authError == null && gen == _generation) {
        final i = next++;
        final ref = refs[i];
        try {
          final json = await withRiotRetry(
              () => cache.json(s, ref.matchId, _client),
              delay: _delay);
          final d = mapMatchDetail(json, focusPuuid ?? s.puuid,
              selfPuuid: s.puuid, rrChange: _rr[ref.matchId]);
          fetched[ref.matchId] = d;
          put(i, MatchEntry(ref: ref, detail: d));
        } on RiotApiException catch (e) {
          if (_isAuthError(e)) authError = e;
          put(i, MatchEntry(ref: ref, failed: true));
        } catch (e) {
          debugPrint('對戰詳情解析失敗：${e.runtimeType}');
          put(i, MatchEntry(ref: ref, failed: true));
        }
      }
    }

    final workers = refs.length < maxConcurrent ? refs.length : maxConcurrent;
    await Future.wait([for (var w = 0; w < workers; w++) worker()]);
    if (gen != _generation) return;
    if (authError != null) {
      // 還沒讀到的場次不留骨架。
      _entries.removeRange(base, _entries.length);
      throw authError!;
    }

    // 實測 match-details 沒有名稱：整頁的未知玩家一次向 name-service 查詢。
    final unnamed = {
      for (final d in fetched.values)
        for (final p in d.teams.values.expand((t) => t))
          if (p.riotId == unknownPlayerName) p.puuid,
    };
    final names = await _optional(
        () => _client.fetchNames(s, unnamed), <String, String>{});
    if (gen != _generation) return;
    if (names.isNotEmpty) fetched.updateAll((_, d) => applyNames(d, names));
    _details.addAll(fetched);
    _refresh(base, refs.length);
    if (fetched.isNotEmpty) onDetails?.call(fetched.values);
    notifyListeners();

    // 每場 RR 最後補上：列表已經可以看，RR 讀到後再填進卡片。
    await _ensureRr(s, refs, gen);
    if (gen != _generation) return;
    _refresh(base, refs.length);
  }

  /// 把 [_details]（已補名稱）與已讀到的 RR 套回這一頁的列表。
  void _refresh(int base, int count) {
    for (var i = base; i < base + count && i < _entries.length; i++) {
      final e = _entries[i];
      var d = _details[e.ref.matchId];
      if (d == null) continue;
      final rr = _rr[e.ref.matchId];
      if (rr != null && d.summary.rrChange != rr) {
        d = MatchDetail(
            summary: d.summary.withRr(rr),
            teams: d.teams,
            rounds: d.rounds,
            kills: d.kills);
        _details[e.ref.matchId] = d;
      }
      _entries[i] = MatchEntry(ref: e.ref, detail: d);
    }
  }
}
