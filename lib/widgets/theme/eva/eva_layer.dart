import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../logic/eva_progress.dart';
import '../../../providers/match_history_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../shell/nav_items.dart';
import '../../../theme/eva_names.dart';
import '../../../theme/nav_labels_en.dart';
import 'egg_detector.dart';
import 'eva_overlays.dart';

/// 讓子元件（EVA 側欄的品牌字）回報點擊。
class EvaEggScope extends InheritedWidget {
  final VoidCallback onBrandTap;

  const EvaEggScope(
      {super.key, required this.onBrandTap, required super.child});

  static EvaEggScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EvaEggScope>();

  @override
  bool updateShouldNotify(EvaEggScope oldWidget) => false;
}

/// EVA 系列的彩蛋與常駐互動層（規格 §4.4）：包住殼層，負責鍵盤序列、連點、閒置、
/// 點擊波紋與各覆蓋畫面。只讀已經在記憶體裡的資料，不觸發任何載入。
class EvaLayer extends StatefulWidget {
  final String currentRoute;
  final Widget child;

  const EvaLayer({super.key, required this.currentRoute, required this.child});

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

  bool get _eggsOn => context.read<SettingsProvider>().settings.evaEnabled;
  bool get _still => MediaQuery.disableAnimationsOf(context);
  bool get _isCurrent => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  void initState() {
    super.initState();
    // 立刻建立：閒置計時從頁面出現就開始。
    _detector = EggDetector(onEgg: _onEgg);
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTitleCard());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _detector.dispose();
    _close?.cancel();
    super.dispose();
  }

  void _maybeTitleCard() {
    final pending = EvaLayer._pendingTitleCard;
    final route = canonicalRoute(widget.currentRoute);
    if (!mounted || pending != route) return;
    EvaLayer._pendingTitleCard = null;
    if (!context.read<SettingsProvider>().settings.evaTitleCards) return;
    final number = navNumberOf(route);
    if (number == null) return;
    final label = navItems.firstWhere((n) => n.route == route).label;
    _show(
        TitleCardOverlay(
            number: number, title: label, story: evaStoryNames[route]?.$1),
        const Duration(milliseconds: 600));
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
    if (e is! KeyDownEvent || !mounted || !_isCurrent) return false;
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
        break;
    }
  }

  void _activity() {
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
      Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _refused.removeWhere((r) => r.$1 == key));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 讀設定讓開關改變時重建。
    context.select<SettingsProvider, bool>((s) => s.settings.evaEnabled);
    return EvaEggScope(
      onBrandTap: () {
        if (_eggsOn) _detector.tapBrand();
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _activity(),
        onPointerMove: (_) => _activity(),
        onPointerHover: (_) => _activity(),
        onPointerSignal: (_) => _activity(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: _onTapUp,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
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
                    onTap: _hide,
                    child: _overlay,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
