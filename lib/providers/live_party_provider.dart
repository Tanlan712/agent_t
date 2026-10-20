import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/live_mapper.dart';
import '../logic/match_mapper.dart' show rankHidden;
import '../models/live_models.dart';
import '../models/riot_session.dart';
import '../services/live_client.dart';
import '../services/match_client.dart';
import '../services/riot_client.dart';
import 'recent_form_loader.dart' show RankStatus;
import 'riot_provider.dart';

enum LiveStatus { idle, loading, ready, noParty, error, loggedOut }

/// 即時對局的隊伍階段：頁面開著時定期讀取（只有 GET），並遵守成員的隱私開關。
class LivePartyProvider with ChangeNotifier {
  static const expiredMessage = '登入已過期，請重新登入';

  final LiveClient _live;
  final MatchClient _match;
  final RiotProvider _riot;

  /// AGENTS.md：即時對局的輪詢間隔至少 5 秒。
  final Duration interval;
  final Timer Function(Duration, void Function(Timer)) _periodic;

  LiveParty? _party;
  LiveStatus _status = LiveStatus.idle;
  String? _error;
  final Map<String, String> _names = {};

  /// 只快取確認過的結果（公開或隱藏）；查詢失敗的下一輪再試。
  final Map<String, RankStatus> _ranks = {};
  final Set<String> _rankFailed = {};
  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  LivePartyProvider(this._live, this._match, this._riot,
      {this.interval = const Duration(seconds: 10),
      Timer Function(Duration, void Function(Timer))? periodic})
      : assert(interval >= const Duration(seconds: 5)),
        _periodic = periodic ?? Timer.periodic;

  LiveParty? get party => _party;
  LiveStatus get status => _status;
  String? get error => _error;

  /// 成員的 Riot ID；隱藏名稱或還沒查到時為 null。
  String? name(String puuid) => _names[puuid];

  /// 他人牌位能不能顯示；自己永遠可以。
  RankStatus rankStatus(String puuid) {
    if (puuid == _riot.session?.puuid) return RankStatus.visible;
    if (_rankFailed.contains(puuid)) return RankStatus.unavailable;
    return _ranks[puuid] ?? RankStatus.pending;
  }

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
    if (_party == null) {
      _status = LiveStatus.loading;
      notifyListeners();
    }
    try {
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
      _names[s.puuid] = '${s.gameName}#${s.tagLine}';
      await _fillNames(s, party);
      await _fillRanks(s, party);
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

  /// 隱藏名稱的成員不查詢（AGENTS.md：不得去匿名化）；失敗時下一輪再試。
  Future<void> _fillNames(RiotSession s, LiveParty party) async {
    final ids = [
      for (final m in party.members)
        if (!m.isMe && !m.incognito && !_names.containsKey(m.puuid)) m.puuid,
    ];
    if (ids.isEmpty) return;
    try {
      _names.addAll(await _match.fetchNames(s, ids));
    } on RiotApiException catch (e) {
      if (e.statusCode == 401) rethrow;
    }
  }

  /// 他人牌位要先確認 MMR 的 IsActRankBadgeHidden 為公開。
  Future<void> _fillRanks(RiotSession s, LiveParty party) async {
    for (final m in party.members) {
      if (m.isMe || _ranks.containsKey(m.puuid)) continue;
      try {
        final mmr = await _match.fetchMmrJson(s, m.puuid);
        _ranks[m.puuid] =
            rankHidden(mmr) ? RankStatus.hidden : RankStatus.visible;
        _rankFailed.remove(m.puuid);
      } on RiotApiException catch (e) {
        if (e.statusCode == 401) rethrow;
        _rankFailed.add(m.puuid);
      }
    }
  }
}
