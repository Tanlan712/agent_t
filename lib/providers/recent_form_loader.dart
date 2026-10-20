import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../logic/match_mapper.dart';
import '../models/riot_session.dart';
import '../services/match_client.dart';
import '../services/riot_client.dart';
import 'match_detail_cache.dart';
import 'riot_provider.dart';

class FormGame {
  final String matchId;

  /// null 表示平手或無法判斷。
  final bool? won;
  final int acs;
  final String agentId;

  const FormGame(
      {required this.matchId,
      required this.won,
      required this.acs,
      required this.agentId});
}

class RecentForm {
  final List<FormGame> games;

  const RecentForm(this.games);

  double? get avgAcs => games.isEmpty
      ? null
      : games.fold<int>(0, (s, g) => s + g.acs) / games.length;
}

enum FormStatus { pending, loading, done, failed }

/// 他人牌位能不能顯示：還沒查、確認公開、對方隱藏、無法確認。
enum RankStatus { pending, visible, hidden, unavailable }

class PlayerRank {
  final RankStatus status;

  /// 確認公開時這季的競技牌位；沒有打競技時為 null。
  final int? seasonTier;

  const PlayerRank(this.status, [this.seasonTier]);

  static const pending = PlayerRank(RankStatus.pending);
}

/// 背景依序載入每位玩家最近幾場的表現：同時最多 [maxConcurrent] 個請求，
/// 429 與連線失敗依 Retry-After（沒有時 2s、4s、8s）重試最多 [maxRetries] 次。
class RecentFormLoader with ChangeNotifier {
  final MatchClient _client;
  final RiotProvider _riot;
  final MatchDetailCache _cache;
  final int maxConcurrent;
  final int games;
  final int maxRetries;
  final Future<void> Function(Duration) _delay;

  final Map<String, FormStatus> _status = {};
  final Map<String, RecentForm> _forms = {};
  final Queue<String> _queue = Queue();
  final Map<String, Set<Object>> _owners = {};
  final Map<String, (String, String?)> _targets = {};

  /// 「賽季|玩家」→ 這季的牌位與是否公開。
  final Map<String, PlayerRank> _ranks = {};

  /// 佇列鍵 → 需要另外查牌位的賽季。
  final Map<String, String> _rankSeason = {};
  static final _anonymous = Object();
  int _running = 0;
  bool _disposed = false;

  RecentFormLoader(this._client, this._riot, this._cache,
      {this.maxConcurrent = 2,
      this.games = 5,
      this.maxRetries = 3,
      Future<void> Function(Duration)? delay})
      : _delay = delay ?? Future<void>.delayed;

  /// 佇列與結果以「模式 + 玩家」為單位；[queue] 為 null 時不限模式。
  static String _key(String puuid, String? queue) => '${queue ?? ''}|$puuid';

  /// 尚未加入佇列的玩家視為 pending。
  FormStatus status(String puuid, {String? queue}) =>
      _status[_key(puuid, queue)] ?? FormStatus.pending;
  RecentForm? form(String puuid, {String? queue}) => _forms[_key(puuid, queue)];

  /// 玩家在 [seasonId] 那季的牌位狀態；還沒查時為 pending。
  PlayerRank rank(String puuid, String seasonId) =>
      _ranks['$seasonId|$puuid'] ?? PlayerRank.pending;

  /// 把 [puuids] 依序排到佇列最前面（目前畫面上的頁面優先）。
  /// 載入中或已完成的玩家略過；失敗的玩家重新排隊。
  /// [owner] 通常是頁面，[cancelPending] 只取消該頁要求的玩家。
  /// [queue] 指定時只查該模式的最近幾場（match-history 的 queue 參數）。
  /// [rankFor] 裡的玩家（除了自己的所有人）會另外查 [seasonId] 那季的牌位與是否公開。
  void request(List<String> puuids,
      {Object? owner,
      String? queue,
      String seasonId = '',
      Set<String> rankFor = const {}}) {
    final o = owner ?? _anonymous;
    final front = <String>[];
    for (final puuid in puuids) {
      final p = _key(puuid, queue);
      _targets[p] = (puuid, queue);
      if (rankFor.contains(puuid) && seasonId.isNotEmpty) {
        _rankSeason[p] = seasonId;
      }
      final st = _status[p];
      if (st == FormStatus.loading || st == FormStatus.done) continue;
      (_owners[p] ??= {}).add(o);
      if (front.contains(p)) continue;
      _queue.remove(p);
      _status[p] = FormStatus.pending;
      front.add(p);
    }
    for (final p in front.reversed) {
      _queue.addFirst(p);
    }
    _pump();
    _notify();
  }

  /// 取消 [owner] 要求、且沒有其他頁面還需要的尚未開始的玩家；
  /// 沒有指定 [owner] 時取消全部。被取消的玩家狀態仍是 pending，畫面不變，
  /// 所以不通知（頁面 dispose 時呼叫，樹已鎖定）。
  void cancelPending({Object? owner}) {
    final dropped = <String>[];
    for (final p in _queue) {
      final owners = _owners[p];
      if (owner != null && owners != null) {
        owners.remove(owner);
        if (owners.isNotEmpty) continue;
      }
      dropped.add(p);
    }
    for (final p in dropped) {
      _queue.remove(p);
      _status.remove(p);
      _owners.remove(p);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _queue.clear();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _pump() {
    while (!_disposed && _running < maxConcurrent && _queue.isNotEmpty) {
      final p = _queue.removeFirst();
      _owners.remove(p);
      _running++;
      _run(p).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  Future<void> _run(String key) async {
    final s = _riot.session;
    if (s == null || !_riot.isLoggedIn) {
      _failAll(key);
      return;
    }
    _status[key] = FormStatus.loading;
    _notify();
    try {
      final (puuid, queue) = _targets[key]!;
      final season = _rankSeason.remove(key);
      if (season != null) await _loadRank(s, puuid, season);
      final form = await _load(s, puuid, queue);
      if (_disposed) return;
      _forms[key] = form;
      _status[key] = FormStatus.done;
    } on RiotApiException catch (e) {
      if (_disposed) return;
      if (e.statusCode == 401) {
        _riot.logout();
        _failAll(key);
        return;
      }
      _status[key] = FormStatus.failed;
    } on _Cancelled {
      return;
    } catch (e) {
      debugPrint('最近戰績解析失敗：${e.runtimeType}');
      if (_disposed) return;
      _status[key] = FormStatus.failed;
    }
    _notify();
  }

  /// 牌位只是補充資訊：失敗（401 以外）時維持未知，不影響最近戰績。
  Future<void> _loadRank(RiotSession s, String puuid, String season) async {
    final k = '$season|$puuid';
    if (_ranks.containsKey(k)) return;
    try {
      final mmr = await _retry(() => _client.fetchMmrJson(s, puuid));
      // 使用者決定（2026-10-21）：隱藏牌位的玩家也直接顯示。
      _ranks[k] = PlayerRank(RankStatus.visible, seasonTier(mmr, season));
    } on RiotApiException catch (e) {
      if (e.statusCode == 401) rethrow;
      // 無法確認對方是否公開：一律不顯示。
      _ranks[k] = const PlayerRank(RankStatus.unavailable);
    } catch (_) {
      _ranks[k] = const PlayerRank(RankStatus.unavailable);
    }
    _notify();
  }

  Future<RecentForm> _load(RiotSession s, String puuid, String? queue) async {
    final (refs, _) = await _retry(
        () => _client.fetchHistory(s, 0, games, puuid: puuid, queue: queue));
    final result = <FormGame>[];
    for (final ref in refs) {
      final Map<String, dynamic> json;
      try {
        json = await _retry(() => _cache.json(s, ref.matchId, _client));
      } on RiotApiException catch (e) {
        // 單場失敗（含連線失敗用盡）只略過那一場；登入過期與限流用盡
        // 才讓整列失敗。
        if (e.statusCode == 401 || e.statusCode == 429) rethrow;
        continue;
      }
      final d = mapMatchDetail(json, puuid, selfPuuid: s.puuid);
      final line =
          d.teams.values.expand((t) => t).where((l) => l.puuid == puuid);
      if (line.isEmpty) continue;
      result.add(FormGame(
        matchId: ref.matchId,
        won: d.summary.won,
        acs: line.first.acs,
        agentId: line.first.agentId,
      ));
    }
    return RecentForm(result);
  }

  Future<T> _retry<T>(Future<T> Function() call) async {
    for (var attempt = 0;; attempt++) {
      if (_disposed) throw const _Cancelled();
      try {
        return await call();
      } on RiotApiException catch (e) {
        // 瀏覽器裡限流回應可能沒有 CORS 標頭，只會看到連線失敗（沒有狀態碼），
        // 所以也一併退避重試。
        final retryable = e.statusCode == 429 || e.statusCode == null;
        if (!retryable || attempt >= maxRetries) rethrow;
        await _delay(e.retryAfter ?? Duration(seconds: 2 << attempt));
      }
    }
  }

  /// 登入失效：目前這位與佇列中的玩家都標成失敗。
  void _failAll(String current) {
    _status[current] = FormStatus.failed;
    for (final p in _queue) {
      _status[p] = FormStatus.failed;
    }
    _queue.clear();
    _notify();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
