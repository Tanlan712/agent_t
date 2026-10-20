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

/// 背景依序載入每位玩家最近幾場的表現：同時最多 [maxConcurrent] 個請求，
/// 429 依 Retry-After（沒有時 2s、4s、8s）重試最多 [maxRetries] 次。
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
  int _running = 0;
  bool _disposed = false;

  RecentFormLoader(this._client, this._riot, this._cache,
      {this.maxConcurrent = 2,
      this.games = 5,
      this.maxRetries = 3,
      Future<void> Function(Duration)? delay})
      : _delay = delay ?? Future<void>.delayed;

  /// 尚未加入佇列的玩家視為 pending。
  FormStatus status(String puuid) => _status[puuid] ?? FormStatus.pending;
  RecentForm? form(String puuid) => _forms[puuid];

  /// 依序加入佇列；已在佇列或已有結果的玩家略過。
  void request(List<String> puuids) {
    for (final p in puuids) {
      if (_status.containsKey(p)) continue;
      _status[p] = FormStatus.pending;
      _queue.add(p);
    }
    _pump();
    _notify();
  }

  /// 清空尚未開始的工作；之後可以再次 request。
  void cancelPending() {
    for (final p in _queue) {
      _status.remove(p);
    }
    _queue.clear();
    _notify();
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
      _running++;
      _run(p).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  Future<void> _run(String puuid) async {
    final s = _riot.session;
    if (s == null || !_riot.isLoggedIn) {
      _failAll(puuid);
      return;
    }
    _status[puuid] = FormStatus.loading;
    _notify();
    try {
      final form = await _load(s, puuid);
      if (_disposed) return;
      _forms[puuid] = form;
      _status[puuid] = FormStatus.done;
    } on RiotApiException catch (e) {
      if (_disposed) return;
      if (e.statusCode == 401) {
        _riot.logout();
        _failAll(puuid);
        return;
      }
      _status[puuid] = FormStatus.failed;
    } on _Cancelled {
      return;
    } catch (e) {
      debugPrint('最近戰績解析失敗：${e.runtimeType}');
      if (_disposed) return;
      _status[puuid] = FormStatus.failed;
    }
    _notify();
  }

  Future<RecentForm> _load(RiotSession s, String puuid) async {
    final (refs, _) =
        await _retry(() => _client.fetchHistory(s, 0, games, puuid: puuid));
    final result = <FormGame>[];
    for (final ref in refs) {
      final Map<String, dynamic> json;
      try {
        json = await _retry(() => _cache.json(s, ref.matchId, _client));
      } on RiotApiException catch (e) {
        // 單場失敗只略過那一場；登入過期與限流用盡才讓整列失敗。
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
        if (e.statusCode != 429 || attempt >= maxRetries) rethrow;
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
