import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/live_mapper.dart';
import '../models/live_models.dart';
import '../models/riot_session.dart';
import '../services/live_client.dart';
import '../services/match_client.dart';
import '../services/riot_client.dart';
import 'riot_provider.dart';

enum LiveStatus { idle, loading, ready, noParty, error, loggedOut }

/// 目前所在的階段；優先順序：對局 > 選角 > 隊伍。
enum LivePhase { party, pregame, inGame }

/// 即時對局：頁面開著時定期讀取（只有 GET），依序判斷對局、選角、隊伍三個階段。
class LivePartyProvider with ChangeNotifier {
  static const expiredMessage = '登入已過期，請重新登入';

  final LiveClient _live;
  final MatchClient _match;
  final RiotProvider _riot;

  /// AGENTS.md：即時對局的輪詢間隔至少 5 秒。
  final Duration interval;
  final Timer Function(Duration, void Function(Timer)) _periodic;
  final DateTime Function() _now;

  LiveParty? _party;
  LiveMatch? _liveMatch;
  LivePregame? _pregame;
  DateTime? _pregameFetchedAt;
  LivePhase _phase = LivePhase.party;
  LiveStatus _status = LiveStatus.idle;
  String? _error;
  final Map<String, String> _names = {};

  /// name-service 已經查過的玩家（查過仍沒有名稱的顯示為未知玩家）。
  final Set<String> _namesAsked = {};

  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  LivePartyProvider(this._live, this._match, this._riot,
      {this.interval = const Duration(seconds: 10),
      Timer Function(Duration, void Function(Timer))? periodic,
      DateTime Function() now = DateTime.now})
      : assert(interval >= const Duration(seconds: 5)),
        _periodic = periodic ?? Timer.periodic,
        _now = now;

  LiveParty? get party => _party;
  LiveMatch? get match => _liveMatch;
  LivePregame? get pregame => _pregame;

  /// 讀到選角資料的時間；畫面用來倒數剩餘時間。
  DateTime? get pregameFetchedAt => _pregameFetchedAt;
  LivePhase get phase => _phase;
  LiveStatus get status => _status;
  String? get error => _error;

  /// 成員的 Riot ID；還沒查到時為 null。
  String? name(String puuid) => _names[puuid];

  /// 查過 name-service 但沒有名稱。
  bool nameMissing(String puuid) =>
      !_names.containsKey(puuid) && _namesAsked.contains(puuid);

  /// 立即更新一次，之後每 [interval] 更新。
  void start() {
    _timer?.cancel();
    _timer = _periodic(interval, (_) => refresh());
    refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> refresh() async {
    if (_busy || _disposed) return;
    final s = _riot.session;
    if (s == null || !_riot.isLoggedIn) {
      _status = LiveStatus.loggedOut;
      notifyListeners();
      return;
    }
    _busy = true;
    if (_status == LiveStatus.idle) {
      _status = LiveStatus.loading;
      notifyListeners();
    }
    try {
      _names[s.puuid] = '${s.gameName}#${s.tagLine}';
      // 對局中：顯示即時對戰（使用者決定，AGENTS.md 第 2 節）。
      final coreId = await _live.fetchCoreMatchId(s);
      if (_disposed) return;
      if (coreId != null) {
        final match =
            mapCoreGame(await _live.fetchCoreMatch(s, coreId), s.puuid);
        if (_disposed) return;
        await _fillNames(s, match.players.map((p) => p.puuid));
        if (_disposed) return;
        _liveMatch = match;
        _pregame = null;
        _phase = LivePhase.inGame;
        _status = LiveStatus.ready;
        _error = null;
        return;
      }
      _liveMatch = null;
      _pregame = null;
      final preId = await _live.fetchPregameMatchId(s);
      if (_disposed) return;
      if (preId != null) {
        final pre =
            mapPregame(await _live.fetchPregameMatch(s, preId), s.puuid);
        if (_disposed) return;
        await _fillNames(s, pre.allies.map((a) => a.puuid));
        if (_disposed) return;
        _pregame = pre;
        _pregameFetchedAt = _now();
        _phase = LivePhase.pregame;
        _status = LiveStatus.ready;
        _error = null;
        return;
      }
      _phase = LivePhase.party;
      final id = await _live.fetchPartyId(s);
      if (_disposed) return;
      if (id == null) {
        _party = null;
        _status = LiveStatus.noParty;
        _error = null;
        return;
      }
      final party = mapParty(await _live.fetchParty(s, id), s.puuid);
      if (_disposed) return;
      await _fillNames(s, party.members.map((m) => m.puuid));
      if (_disposed) return;
      _party = party;
      _status = LiveStatus.ready;
      _error = null;
    } on RiotApiException catch (e) {
      if (_disposed) return;
      if (e.statusCode == 401) {
        stop();
        _riot.logout();
        _party = null;
        _liveMatch = null;
        _status = LiveStatus.loggedOut;
        _error = expiredMessage;
      } else {
        _status = LiveStatus.error;
        _error = e.message;
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// 使用者決定（2026-10-21，AGENTS.md 第 2 節）：隱藏名稱的成員也查詢並顯示。
  /// 失敗時下一輪再試。
  Future<void> _fillNames(RiotSession s, Iterable<String> puuids) async {
    final ids = [
      for (final p in puuids)
        if (!_names.containsKey(p)) p,
    ];
    if (ids.isEmpty) return;
    try {
      _names.addAll(await _match.fetchNames(s, ids));
      _namesAsked.addAll(ids);
    } on RiotApiException catch (e) {
      if (e.statusCode == 401) rethrow;
    }
  }
}
