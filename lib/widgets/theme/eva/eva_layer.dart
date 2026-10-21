import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../logic/eva_progress.dart';
import '../../../providers/match_history_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../shell/nav/eva_nav.dart';
import '../../../shell/nav_items.dart';
import '../../../theme/eva_names.dart';
import '../../../theme/nav_labels_en.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/progress_provider.dart';
import '../../../theme/app_palette.dart';
import 'egg_detector.dart';
import 'eva_data_eggs.dart';
import 'eva_documents.dart';
import 'eva_overlays.dart';
import 'eva_terminal.dart';

/// 讓子元件（EVA 側欄的品牌字）回報點擊。
class EvaEggScope extends InheritedWidget {
  final VoidCallback onBrandTap;

  /// 品牌字按右鍵或長按：開啟機密文件庫（E12）。
  final VoidCallback onBrandSecondary;

  const EvaEggScope(
      {super.key,
      required this.onBrandTap,
      required this.onBrandSecondary,
      required super.child});

  static EvaEggScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EvaEggScope>();

  @override
  bool updateShouldNotify(EvaEggScope oldWidget) => false;
}

/// EVA 系列的彩蛋與常駐互動層（規格 §4.4）：包住殼層，負責鍵盤序列、連點、閒置、
/// 點擊波紋與各覆蓋畫面。只讀已經在記憶體裡的資料，不觸發任何載入。
/// 殼層一律包這一層（[enabled] 只在 EVA 風格為 true），切換風格時樹的結構不變。
class EvaLayer extends StatefulWidget {
  final String currentRoute;
  final bool enabled;
  final Widget child;

  const EvaLayer(
      {super.key,
      required this.currentRoute,
      this.enabled = true,
      required this.child});

  static String? _pendingTitleCard;

  /// 從導覽切頁前呼叫；新頁面的 EvaLayer 會播放標題卡（R2）。
  static void requestTitleCard(String route) =>
      _pendingTitleCard = canonicalRoute(route);

  @override
  State<EvaLayer> createState() => _EvaLayerState();
}

class _EvaLayerState extends State<EvaLayer> {
  late final EggDetector _detector;
  Widget? _overlay;
  Timer? _close;
  final _ripples = <(Key, Offset)>[];
  final _refused = <(Key, Offset)>[];
  DateTime? _lastTap;
  Offset? _lastTapAt;
  int _seq = 0;
  bool _boot = false;
  final _timers = <Timer>[];

  void _later(Duration d, VoidCallback f) => _timers.add(Timer(d, () {
        if (mounted) f();
      }));
  bool _atBottom = false;
  final _failures = {
    'catalog': FailureCounter(),
    'matches': FailureCounter(),
    'progress': FailureCounter(),
  };

  bool get _eggsOn =>
      widget.enabled && context.read<SettingsProvider>().settings.evaEnabled;
  bool get _still => MediaQuery.disableAnimationsOf(context);
  bool get _isCurrent => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  void initState() {
    super.initState();
    // 立刻建立：閒置計時從頁面出現就開始。
    _detector = EggDetector(onEgg: _onEgg);
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeTitleCard();
      _startup();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _detector.dispose();
    _close?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _maybeTitleCard() {
    final pending = EvaLayer._pendingTitleCard;
    final route = canonicalRoute(widget.currentRoute);
    if (!mounted || pending != route) return;
    EvaLayer._pendingTitleCard = null;
    if (!widget.enabled) return;
    if (!context.read<SettingsProvider>().settings.evaTitleCards) return;
    if (navNumberOf(route) == null) return;
    final settings = context.read<SettingsProvider>().settings;
    final story = evaStoryNames[route];
    _show(
        TitleCardOverlay(
            episode: episodeOf(settings),
            finale: isFinale(settings),
            route: route,
            pageCode: 'EPISODE:${twoDigits(episodeOf(settings))} / '
                '${story?.$2 ?? navLabelsEn[route] ?? ''}'),
        const Duration(milliseconds: 600));
  }

  /// 每天第一次開啟的開機自檢（E10）、首頁的使徒接近（E3）、夜間／紀念日（E6／E19）。
  void _startup() {
    if (!mounted || !_eggsOn) return;
    final settings = context.read<SettingsProvider>();
    final now = DateTime.now();
    final today = dayKey(now);
    final special = codeLineOverride(now);
    if (special != null) {
      settings.updateEva((s) =>
          recordEgg(s, special.startsWith('ANNIVERSARY') ? 'E19' : 'E6'));
    }
    var delay = Duration.zero;
    if (settings.settings.evaBootDate != today) {
      settings
          .updateEva((s) => recordEgg(s.copyWith(evaBootDate: today), 'E10'));
      setState(() => _boot = true);
      _later(const Duration(milliseconds: 800),
          () => setState(() => _boot = false));
      delay = const Duration(milliseconds: 900);
    }
    if (canonicalRoute(widget.currentRoute) != '/') return;
    final catalog = context.read<CatalogProvider>();
    final tier = angelTier(context
        .read<ShopProvider>()
        .shop
        .daily
        .map((e) => catalog.skinById(e.skinUuid)?.tier));
    if (tier == null || settings.settings.evaSeenUltraDate == today) return;
    final (next, n) = recordAngel(settings.settings, now);
    settings.updateEva((_) => recordEgg(next, 'E3'));
    _later(
        delay,
        () => _show(
            AngelOverlay(number: n, tier: tier), const Duration(seconds: 3)));
  }

  /// E16：同一個 provider 連續失敗的次數（取最大）。
  int _failureCount(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final matches = context.watch<MatchHistoryProvider>();
    final progress = context.watch<ProgressProvider>();
    _failures['catalog']!
        .update(loading: catalog.isLoading, error: catalog.error);
    _failures['matches']!
        .update(loading: matches.isLoading, error: matches.error);
    _failures['progress']!
        .update(loading: progress.isLoading, error: progress.error);
    return _failures.values.map((c) => c.count).reduce((a, b) => a > b ? a : b);
  }

  /// 20 個彩蛋全部發現後只顯示一次「補完完了」。
  void _maybeFinale() {
    if (!mounted || !_isCurrent || _overlay != null) return;
    final settings = context.read<SettingsProvider>();
    final s = settings.settings;
    if (!allEggsFound(s) || s.evaFoundEggs.contains('FINALE')) return;
    settings.updateEva((s) => recordEgg(s, 'FINALE'));
    _show(const FinaleOverlay(), const Duration(seconds: 4));
  }

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    if (m.axis != Axis.vertical) return false;
    // 只看頁面內容的捲動，不看 EVA 側欄。
    if (n.context?.findAncestorWidgetOfExactType<EvaNav>() != null) {
      return false;
    }
    final bottom = m.maxScrollExtent > 0 && m.extentAfter <= 1;
    if (bottom != _atBottom) {
      setState(() => _atBottom = bottom);
      if (bottom && _eggsOn) {
        context.read<SettingsProvider>().updateEva((s) => recordEgg(s, 'E17'));
      }
    }
    return false;
  }

  void _show(Widget overlay, Duration? autoClose, {String? egg}) {
    _close?.cancel();
    setState(() => _overlay = overlay);
    if (autoClose != null) _close = Timer(autoClose, _hide);
    if (egg != null) {
      context.read<SettingsProvider>().updateEva((s) => recordEgg(s, egg));
    }
  }

  void _hide() {
    _close?.cancel();
    if (mounted && _overlay != null) setState(() => _overlay = null);
  }

  bool _inEditable() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted || !_isCurrent || !widget.enabled) {
      return false;
    }
    // 任何按鍵（包括在輸入框打字）都算活動，重新計算閒置。
    _detector.activity();
    if (_overlay is DummyOverlay) {
      _hide();
      return false;
    }
    if (_overlay != null && e.logicalKey == LogicalKeyboardKey.escape) {
      _hide();
      return true;
    }
    if (_inEditable() || !_eggsOn) return false;
    _detector.key(e.logicalKey, e.character);
    return false;
  }

  void _onEgg(EggEvent event) {
    if (!mounted || !_isCurrent || !_eggsOn) return;
    if (event == EggEvent.idle && !widget.enabled) return;
    const three = Duration(seconds: 3);
    switch (event) {
      case EggEvent.konami:
        _show(const PatternOverlay(), three, egg: 'E1');
      case EggEvent.konamiBA:
        _show(EpisodeOverlay(date: DateTime.now()), three, egg: 'E20');
      case EggEvent.magi:
        final wish = context.read<WishlistProvider>().uuids;
        final matched = context
            .read<ShopProvider>()
            .shop
            .daily
            .where((e) => wish.contains(e.skinUuid))
            .length;
        _show(MagiOverlay(matched: matched), const Duration(milliseconds: 3200),
            egg: 'E2');
      case EggEvent.idle:
        if (_overlay == null) _show(const DummyOverlay(), null, egg: 'E4');
      case EggEvent.sync:
        final results = context
            .read<MatchHistoryProvider>()
            .entries
            .map((e) => e.detail?.summary.won);
        _show(SyncOverlay(ratio: syncRatioOf(results)), three, egg: 'E5');
      case EggEvent.terminal:
        _show(EvaTerminal(onExit: _hide), null, egg: 'E11');
    }
  }

  void _activity() {
    if (!widget.enabled) return;
    _detector.activity();
    if (_overlay is DummyOverlay) _hide();
  }

  void _onTapUp(TapUpDetails d) {
    final now = DateTime.now();
    final at = d.localPosition;
    final last = _lastTap, lastAt = _lastTapAt;
    _lastTap = now;
    _lastTapAt = at;
    if (!_still) {
      final key = ValueKey('ripple-${_seq++}');
      setState(() => _ripples.add((key, at)));
    }
    final isDouble = last != null &&
        lastAt != null &&
        now.difference(last) < const Duration(milliseconds: 350) &&
        (at - lastAt).distance < 40;
    if (isDouble && _eggsOn) {
      _lastTap = null;
      final key = ValueKey('refused-${_seq++}');
      setState(() => _refused.add((key, at)));
      context.read<SettingsProvider>().updateEva((s) => recordEgg(s, 'E7'));
      _later(const Duration(seconds: 2),
          () => setState(() => _refused.removeWhere((r) => r.$1 == key)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 讀設定讓開關改變時重建。
    final eggsOn = widget.enabled &&
        context.select<SettingsProvider, bool>((s) => s.settings.evaEnabled);
    final found = context
        .select<SettingsProvider, int>((s) => s.settings.evaFoundEggs.length);
    if (eggsOn && found >= evaEggIds.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFinale());
    }
    final failures = eggsOn ? _failureCount(context) : 0;
    return EvaEggScope(
      onBrandTap: () {
        if (_eggsOn) _detector.tapBrand();
      },
      onBrandSecondary: () {
        if (_eggsOn) _show(EvaArchive(onClose: _hide), null, egg: 'E12');
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _activity(),
        onPointerMove: (_) => _activity(),
        onPointerHover: (_) => _activity(),
        onPointerSignal: (_) => _activity(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: widget.enabled ? _onTapUp : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: widget.child,
              ),
              if (eggsOn && _atBottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: const ValueKey('lcl-fill'),
                      tween: Tween(begin: 0, end: 1),
                      duration: _still
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      builder: (context, t, _) => Container(
                        height: 28 * t,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              (context.palette.frame ?? context.palette.primary)
                                  .withOpacity(0.15),
                              (context.palette.frame ?? context.palette.primary)
                                  .withOpacity(0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ConnectionLostBar(failures: failures)),
              if (_boot) const Positioned.fill(child: BootOverlay()),
              for (final (key, at) in _ripples)
                Positioned.fill(
                  child: AtFieldRipple(
                    key: key,
                    at: at,
                    onDone: () => setState(
                        () => _ripples.removeWhere((r) => r.$1 == key)),
                  ),
                ),
              for (final (key, at) in _refused) RefusedHex(key: key, at: at),
              if (_overlay != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _overlay is EvaTerminal ? null : _hide,
                    // 覆蓋畫面在 Scaffold 之外；TextField（終端機）需要 Material。
                    child: Material(
                        type: MaterialType.transparency, child: _overlay),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
