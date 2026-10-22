import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../logic/eva_progress.dart';
import '../../../logic/shop_time.dart';
import '../../../models/tier.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/match_history_provider.dart';
import '../../../providers/riot_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../shell/nav_items.dart' show wishlistEnabled;
import '../../../theme/app_fonts.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/eva_names.dart';
import 'eva_mincho.dart';

// ── 純函式（規格 §4.4 的判斷規則）──────────────────────────────

/// E6／E19：特殊日期時段的代碼行；10 月 4 日（電視版首播日）優先於夜間 0:00–4:59。
String? codeLineOverride(DateTime now) {
  if (now.month == 10 && now.day == 4) return 'ANNIVERSARY / 放送紀念日';
  if (now.hour < 5) return '夜間警戒態勢 / NIGHT WATCH';
  return null;
}

enum StampKind { win, loss }

/// E13：已載入的前 3 場都勝或都敗；不足 3 場或有平手時不蓋章。
StampKind? stampFor(Iterable<bool?> recent) {
  final first = recent.take(3).toList();
  if (first.length < 3 || first.any((r) => r == null)) return null;
  if (first.every((r) => r == true)) return StampKind.win;
  if (first.every((r) => r == false)) return StampKind.loss;
  return null;
}

/// E14：今日商店（4 件）全部在願望清單。
bool allWishlisted(List<String> daily, Set<String> wishlist) =>
    daily.length >= 4 && daily.every(wishlist.contains);

/// E3：今日商店最高的 Ultra 或 Exclusive；都沒有時為 null。
Tier? angelTier(Iterable<Tier?> tiers) {
  if (tiers.contains(Tier.ultra)) return Tier.ultra;
  if (tiers.contains(Tier.exclusive)) return Tier.exclusive;
  return null;
}

enum CountdownPhase { normal, last60, reboot }

/// E8：剩 ≤ 60 秒放大倒數；刷新後 60 秒內（下次刷新還有 ≥ 23:59:00）顯示 REBOOT。
CountdownPhase countdownPhase(Duration left) {
  if (left <= const Duration(seconds: 60)) return CountdownPhase.last60;
  if (left >= const Duration(hours: 23, minutes: 59)) {
    return CountdownPhase.reboot;
  }
  return CountdownPhase.normal;
}

/// E16：同一個 provider 連續失敗的次數；成功（不在載入且沒有錯誤）一次就歸零。
class FailureCounter {
  int count = 0;
  String? _last;
  bool _wasLoading = false;

  void update({required bool loading, required String? error}) {
    if (error != null && (error != _last || _wasLoading)) count++;
    if (!loading && error == null) count = 0;
    _last = error;
    _wasLoading = loading;
  }
}

/// 第一次建構後記錄一次彩蛋。
void recordEggOnce(BuildContext context, String id) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final settings = context.read<SettingsProvider>();
    if (!settings.settings.evaEnabled) return;
    if (settings.settings.evaFoundEggs.contains(id)) return;
    settings.updateEva((s) => recordEgg(s, id));
  });
}

TextStyle _mono(double size, Color color) =>
    AppFonts.mono(TextStyle(fontSize: size, letterSpacing: 1, color: color));

// ── 元件 ──────────────────────────────────────────────────────

/// E10：每天第一次開啟的開機自檢（角落小面板，不攔截點擊）。
class BootOverlay extends StatelessWidget {
  const BootOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final catalog = context.read<CatalogProvider>();
    final riot = context.read<RiotProvider>();
    final wish = context.read<WishlistProvider>().items.length;
    final lines = [
      '> MAGI BOOT SEQUENCE',
      '> CATALOG … ${catalog.catalog == null ? 'LOADING' : catalog.usingStaleCache ? 'STALE' : 'OK'}',
      '> SESSION … ${riot.isLoggedIn ? 'OK' : 'CABLE OFF'}',
      '> WISHLIST … $wish',
    ];
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: p.background.withOpacity(0.95),
              border: Border.all(color: p.frame ?? p.primary)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final l in lines) Text(l, style: _mono(12, p.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// E3：「第 N 使徒 接近」標題卡。
class AngelOverlay extends StatelessWidget {
  final int number;
  final Tier tier;

  const AngelOverlay({super.key, required this.number, required this.tier});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: p.background.withOpacity(0.95),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          EvaTitleCard(
              episode: 'PATTERN ANALYSIS',
              big: '第 ${kanjiNumber(number.clamp(1, 99))} 使徒',
              small: '接近'),
          const SizedBox(height: 12),
          Text('PATTERN: ${tier.devName.toUpperCase()} · IDENTIFIED',
              style: _mono(14, p.warn)),
        ]),
      ),
    );
  }
}

/// E13：對戰紀錄頁首的印章（作戰成功／撤退勸告）。
class EvaStamp extends StatelessWidget {
  /// 測試用；null 時讀已載入的對戰紀錄（不觸發載入）。
  final List<bool?>? results;

  const EvaStamp({super.key, this.results});

  @override
  Widget build(BuildContext context) {
    final r = results ??
        context
            .watch<MatchHistoryProvider>()
            .entries
            .map((e) => e.detail?.summary.won)
            .toList();
    final kind = stampFor(r);
    if (kind == null) return const SizedBox.shrink();
    recordEggOnce(context, 'E13');
    final p = context.palette;
    final win = kind == StampKind.win;
    final color = win ? p.win : p.loss;
    return Transform.rotate(
      angle: -0.08,
      child: Container(
        key: ValueKey(win ? 'stamp-win' : 'stamp-loss'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
        child: EvaMincho(win ? '作戰成功' : '撤退勸告',
            size: 18, squeeze: 0.9, color: color),
      ),
    );
  }
}

/// 頁首下方的 EVA 橫幅：E14 補完達成、E15 夜市；E13 印章在對戰紀錄頁。
class EvaBanners extends StatelessWidget {
  final String? route;

  const EvaBanners({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    if (!context.select<SettingsProvider, bool>((s) => s.settings.evaEnabled)) {
      return const SizedBox.shrink();
    }
    final children = <Widget>[];
    if (route == '/') {
      final shop = context.watch<ShopProvider>().shop;
      final wish = context.watch<WishlistProvider>().uuids;
      if (wishlistEnabled &&
          allWishlisted([for (final e in shop.daily) e.skinUuid], wish)) {
        recordEggOnce(context, 'E14');
        children.add(const _Banner(
            key: ValueKey('banner-complete'),
            title: 'COMPLETE',
            sub: '補完達成 · 今日商店全部命中願望清單',
            gold: true));
      }
      if (isNightMarketActive(shop, DateTime.now())) {
        recordEggOnce(context, 'E15');
        children.add(const _Banner(
            key: ValueKey('banner-night'),
            title: '非常事態',
            sub: 'NIGHT MARKET · 夜市開放中'));
      }
    }
    if (route == '/matches') children.add(const EvaStamp());
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 8, runSpacing: 6, children: children),
    );
  }
}

class _Banner extends StatelessWidget {
  final String title;
  final String sub;
  final bool gold;

  const _Banner(
      {super.key, required this.title, required this.sub, this.gold = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = gold ? p.warn : p.loss;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        color: p.background,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        EvaMincho(title, size: 18, squeeze: 0.9, color: color),
        const SizedBox(width: 10),
        Flexible(child: Text(sub, style: _mono(12, p.text))),
      ]),
    );
  }
}

/// E16：連續失敗 3 次的 CONNECTION LOST 條。
class ConnectionLostBar extends StatelessWidget {
  final int failures;

  const ConnectionLostBar({super.key, required this.failures});

  @override
  Widget build(BuildContext context) {
    if (failures < 3) return const SizedBox.shrink();
    final p = context.palette;
    return IgnorePointer(
      child: Container(
        key: const ValueKey('banner-lost'),
        color: p.loss,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(children: [
          Text('CONNECTION LOST',
              style: AppFonts.condensed(TextStyle(
                  fontSize: 16, letterSpacing: 2, color: p.onButton))),
          const SizedBox(width: 12),
          Expanded(
              child: Text('連續 $failures 次讀取失敗，成功一次後自動消失',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.onButton))),
        ]),
      ),
    );
  }
}

/// R4：心理圖表波形（已載入場次的 ACS，舊 → 新）；沒有資料是平線＋NO SIGNAL。
class Psychograph extends StatelessWidget {
  /// 測試用；null 時讀已載入的對戰紀錄。
  final List<int>? values;

  const Psychograph({super.key, this.values});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final v = values ??
        context
            .watch<MatchHistoryProvider>()
            .entries
            .map((e) => e.detail?.summary.acs)
            .whereType<int>()
            .take(20)
            .toList()
            .reversed
            .toList();
    final frame = p.frame ?? p.primary;
    return Container(
      width: 120,
      height: 44,
      decoration: BoxDecoration(border: Border.all(color: frame)),
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            key: v.isEmpty ? null : const ValueKey('psychograph-line'),
            painter: _GraphPainter(v, frame, p.win),
          ),
        ),
        Positioned(
            left: 4,
            top: 2,
            child: Text('PSYCHOGRAPH', style: _mono(8, frame))),
        if (v.isEmpty)
          Center(child: Text('NO SIGNAL', style: _mono(11, p.muted))),
      ]),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<int> values;
  final Color grid;
  final Color line;

  _GraphPainter(this.values, this.grid, this.line);

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height * 0.6;
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (values.isEmpty) {
      canvas.drawLine(Offset(0, mid), Offset(size.width, mid),
          paint..color = grid.withOpacity(0.6));
      return;
    }
    final lo = values.reduce((a, b) => a < b ? a : b).toDouble();
    final hi = values.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i * size.width / (values.length - 1);
      final y = size.height - 6 - (values[i] - lo) / span * (size.height - 16);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.values != values || old.grid != grid || old.line != line;
}
