import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../models/riot_session.dart';
import '../services/match_client.dart';
import '../services/riot_client.dart';
import '../storage/form_game_storage.dart';
import 'match_detail_cache.dart';
import 'riot_provider.dart';

/// 只看一般與競技：對戰紀錄不帶 queue 參數讀取，再略過其他模式。
const standardQueues = 'competitive,unrated';
const _standardQueueIds = {'competitive', 'unrated'};

class FormGame {
  final String matchId;

  /// null 表示平手或無法判斷。
  final bool? won;
  final int acs;
  final String agentId;
  final int kills;
  final int deaths;
  final int assists;

  /// 表現分數（scores.TempValueF，0～500）；Riot 沒有提供時為 null。
  final double? rating;
  final double? headshotPercent;
  final String queueId;
  final DateTime? startTime;

  /// 這場每把槍的擊殺數（武器 uuid 小寫；不含技能與炸彈）。
  final Map<String, int> weaponKills;

  const FormGame({
    required this.matchId,
    required this.won,
    required this.acs,
    required this.agentId,
    this.kills = 0,
    this.deaths = 0,
    this.assists = 0,
    this.rating,
    this.headshotPercent,
    this.queueId = '',
    this.startTime,
    this.weaponKills = const {},
  });
}

/// 一位特務在最近幾場的表現（擅長特務用）。
class AgentForm {
  final String agentId;
  final int games;
  final int wins;
  final double avgAcs;

  const AgentForm(
      {required this.agentId,
      required this.games,
      required this.wins,
      required this.avgAcs});
}

class RecentForm {
  final List<FormGame> games;

  const RecentForm(this.games);

  double? get avgAcs => games.isEmpty
      ? null
      : games.fold<int>(0, (s, g) => s + g.acs) / games.length;

  /// 有勝負的場次中贏的比例（平手不算）。
  double? get winRate {
    final decided = games.where((g) => g.won != null).toList();
    if (decided.isEmpty) return null;
    return decided.where((g) => g.won == true).length / decided.length;
  }

  /// 總擊殺 ÷ 總死亡（沒有死亡時用 1）。
  double? get avgKd {
    if (games.isEmpty) return null;
    final k = games.fold<int>(0, (s, g) => s + g.kills);
    final d = games.fold<int>(0, (s, g) => s + g.deaths);
    return k / (d == 0 ? 1 : d);
  }

  /// 擅長的特務：依場數、再依平均 ACS 由高到低。
  List<AgentForm> get agentForms {
    final by = <String, List<FormGame>>{};
    for (final g in games) {
      if (g.agentId.isEmpty) continue;
      (by[g.agentId.toLowerCase()] ??= []).add(g);
    }
    return [
      for (final e in by.entries)
        AgentForm(
          agentId: e.key,
          games: e.value.length,
          wins: e.value.where((g) => g.won == true).length,
          avgAcs: e.value.fold<int>(0, (a, g) => a + g.acs) / e.value.length,
        ),
    ]..sort((a, b) => a.games != b.games
        ? b.games.compareTo(a.games)
        : b.avgAcs.compareTo(a.avgAcs));
  }

  /// 常用的槍：最近幾場每把槍的擊殺加總，由多到少。
  List<(String weapon, int kills)> get weaponKills {
    final total = <String, int>{};
    for (final g in games) {
      for (final e in g.weaponKills.entries) {
        total[e.key] = (total[e.key] ?? 0) + e.value;
      }
    }
    return [for (final e in total.entries) (e.key, e.value)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  double? get avgHeadshot {
    final hs = [
      for (final g in games)
        if (g.headshotPercent case final h?) h
    ];
    return hs.isEmpty ? null : hs.reduce((a, b) => a + b) / hs.length;
  }
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

  /// 每位玩家的場次讀完後呼叫，例如記錄和自己同場過的玩家。
  final void Function(Iterable<MatchDetail> details)? onDetails;

  /// 自己已結束場次的摘要快取：有存的場次不再抓 match-details。
  final FormGameStorage? store;

  final Map<String, FormStatus> _status = {};
  final Map<String, RecentForm> _forms = {};
  final Queue<String> _queue = Queue();
  final Map<String, Set<Object>> _owners = {};
  final Map<String, (String, String?, int)> _targets = {};

  /// 「賽季|玩家」→ 這季的牌位與是否公開。
  final Map<String, PlayerRank> _ranks = {};

  /// 佇列鍵 → 需要另外查牌位的賽季。
  final Map<String, String> _rankSeason = {};

  /// 玩家 → 完整的 MMR（目前牌位、歷史最高用）；只放在記憶體。
  final Map<String, Map<String, dynamic>> _mmr = {};
  final Map<String, FormStatus> _profileStatus = {};

  /// MMR 是獨立的佇列工作（不綁在某個場數的戰績上）：鍵是 `profile|玩家`。
  static const _profilePrefix = 'profile|';
  static final _anonymous = Object();
  int _running = 0;
  bool _disposed = false;

  RecentFormLoader(this._client, this._riot, this._cache,
      {this.maxConcurrent = 2,
      this.games = 5,
      this.maxRetries = 3,
      this.onDetails,
      this.store,
      Future<void> Function(Duration)? delay})
      : _delay = delay ?? Future<void>.delayed;

  /// 佇列與結果以「模式 + 玩家」為單位；[queue] 為 null 時不限模式。
  /// 場數不是預設值時另外快取（例如即時對局的小號判斷要 10 場）。
  String _key(String puuid, String? queue, int? count) =>
      count == null || count == games
          ? '${queue ?? ''}|$puuid'
          : '${queue ?? ''}#$count|$puuid';

  /// 尚未加入佇列的玩家視為 pending。
  FormStatus status(String puuid, {String? queue, int? games}) =>
      _status[_key(puuid, queue, games)] ?? FormStatus.pending;
  RecentForm? form(String puuid, {String? queue, int? games}) =>
      _forms[_key(puuid, queue, games)];

  /// 玩家在 [seasonId] 那季的牌位狀態；還沒查時為 pending。
  PlayerRank rank(String puuid, String seasonId) =>
      _ranks['$seasonId|$puuid'] ?? PlayerRank.pending;

  /// 玩家的 MMR 讀取狀態與內容（[request] 的 profileFor）。
  FormStatus profileStatus(String puuid) =>
      _profileStatus[puuid] ?? FormStatus.pending;
  Map<String, dynamic>? mmr(String puuid) => _mmr[puuid];

  /// 清掉這位玩家所有已完成或失敗的結果（例如按「從 Riot 同步」）；之後要再 [request]。
  /// 正在讀取中的不受影響。
  void forget(String puuid) {
    final keys = [
      for (final e in _targets.entries)
        if (e.value.$1 == puuid) e.key
    ];
    for (final k in keys) {
      if (_status[k] == FormStatus.loading) continue;
      _status.remove(k);
      _forms.remove(k);
    }
    if (_profileStatus[puuid] != FormStatus.loading) {
      _profileStatus.remove(puuid);
      _mmr.remove(puuid);
    }
    _notify();
  }

  /// 把 [puuids] 依序排到佇列最前面（目前畫面上的頁面優先）。
  /// 載入中或已完成的玩家略過；失敗的玩家重新排隊。
  /// [owner] 通常是頁面，[cancelPending] 只取消該頁要求的玩家。
  /// [queue] 指定時只查該模式的最近幾場（match-history 的 queue 參數）。
  /// [rankFor] 裡的玩家（除了自己的所有人）會另外查 [seasonId] 那季的牌位與是否公開。
  void request(List<String> puuids,
      {Object? owner,
      String? queue,
      String seasonId = '',
      Set<String> rankFor = const {},
      Set<String> profileFor = const {},
      int? games}) {
    final o = owner ?? _anonymous;
    final front = <String>[];
    for (final puuid in puuids) {
      final p = _key(puuid, queue, games);
      _targets[p] = (puuid, queue, games ?? this.games);
      if (rankFor.contains(puuid) && seasonId.isNotEmpty) {
        _rankSeason[p] = seasonId;
      }
      if (profileFor.contains(puuid)) {
        final ps = _profileStatus[puuid];
        if (ps != FormStatus.loading && ps != FormStatus.done) {
          final k = '$_profilePrefix$puuid';
          (_owners[k] ??= {}).add(o);
          _queue.remove(k);
          _profileStatus[puuid] = FormStatus.pending;
          if (!front.contains(k)) front.add(k);
        }
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
      if (p.startsWith(_profilePrefix)) {
        _profileStatus.remove(p.substring(_profilePrefix.length));
      }
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
    if (key.startsWith(_profilePrefix)) {
      try {
        await _loadProfile(s, key.substring(_profilePrefix.length));
      } on RiotApiException {
        // _loadProfile 只在 401 時拋出：登出並讓排隊中的工作失敗。
        if (_disposed) return;
        _riot.expire();
        _failAll(key);
      } on _Cancelled {
        return;
      }
      return;
    }
    _status[key] = FormStatus.loading;
    _notify();
    try {
      final (puuid, queue, count) = _targets[key]!;
      final season = _rankSeason.remove(key);
      if (season != null) await _loadRank(s, puuid, season);
      final form = await _load(s, puuid, queue, count);
      if (_disposed) return;
      _forms[key] = form;
      _status[key] = FormStatus.done;
    } on RiotApiException catch (e) {
      if (_disposed) return;
      if (e.statusCode == 401) {
        _riot.expire();
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

  /// MMR 只是補充資訊：失敗（401 以外）時標成 failed，不影響最近戰績。
  Future<void> _loadProfile(RiotSession s, String puuid) async {
    _profileStatus[puuid] = FormStatus.loading;
    _notify();
    try {
      _mmr[puuid] = await _retry(() => _client.fetchMmrJson(s, puuid));
      _profileStatus[puuid] = FormStatus.done;
    } on RiotApiException catch (e) {
      _profileStatus[puuid] = FormStatus.failed;
      _notify();
      if (e.statusCode == 401) rethrow;
      return;
    } on _Cancelled {
      rethrow;
    } catch (_) {
      _profileStatus[puuid] = FormStatus.failed;
    }
    _notify();
  }

  Future<RecentForm> _load(
      RiotSession s, String puuid, String? queue, int count) async {
    final standard = queue == standardQueues;
    final (refs, _) = await _retry(() => _client.fetchHistory(s, 0, count,
        puuid: puuid, queue: standard ? null : queue));
    final result = <FormGame>[];
    final details = <MatchDetail>[];
    final store = puuid == s.puuid ? this.store : null;
    final saved = store?.load(puuid) ?? const <String, FormGame>{};
    final fresh = <FormGame>[];
    for (final ref in refs) {
      if (standard && !_standardQueueIds.contains(ref.queueId)) continue;
      if (saved[ref.matchId] case final g?) {
        result.add(g);
        continue;
      }
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
      details.add(d);
      final line =
          d.teams.values.expand((t) => t).where((l) => l.puuid == puuid);
      if (line.isEmpty) continue;
      final l = line.first;
      final game = FormGame(
        matchId: ref.matchId,
        won: d.summary.won,
        acs: l.acs,
        agentId: l.agentId,
        kills: l.kills,
        deaths: l.deaths,
        assists: l.assists,
        rating: l.rating,
        headshotPercent: l.headshotPercent,
        queueId: ref.queueId,
        startTime: ref.startTime,
        weaponKills: _weaponKills(d.kills, puuid),
      );
      result.add(game);
      fresh.add(game);
    }
    if (details.isNotEmpty) onDetails?.call(details);
    if (fresh.isNotEmpty) await store?.save(puuid, fresh);
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
    void fail(String k) {
      if (k.startsWith(_profilePrefix)) {
        _profileStatus[k.substring(_profilePrefix.length)] = FormStatus.failed;
      } else {
        _status[k] = FormStatus.failed;
      }
    }

    fail(current);
    for (final p in _queue) {
      fail(p);
    }
    _queue.clear();
    _notify();
  }
}

Map<String, int> _weaponKills(List<KillEvent> kills, String puuid) {
  final out = <String, int>{};
  for (final k in kills) {
    if (k.killer == puuid && k.victim != puuid && k.isWeapon) {
      out[k.damageItem] = (out[k.damageItem] ?? 0) + 1;
    }
  }
  return out;
}

class _Cancelled implements Exception {
  const _Cancelled();
}
