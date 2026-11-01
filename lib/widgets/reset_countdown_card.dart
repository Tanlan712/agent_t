import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/shop_time.dart';
import '../models/current_shop.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';

/// 倒數文字：一天以上「2 天 03:04:05」，否則「03:04:05」；過了為 null。
String? countdownLabel(DateTime? target, DateTime now) {
  if (target == null) return null;
  final d = target.difference(now);
  if (d.isNegative) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  final hms =
      '${two(d.inHours % 24)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  return d.inDays > 0 ? '${d.inDays} 天 $hms' : hms;
}

/// 一列倒數。
class ResetRow {
  final String label;
  final IconData icon;
  final DateTime? target;

  /// 沒有時間時顯示的文字。
  final String fallback;

  /// 時間是依設定的刷新時間推算（還沒同步到 Riot 的實際時間）。
  final bool estimated;

  const ResetRow(this.label, this.icon, this.target,
      {this.fallback = '—', this.estimated = false});
}

/// 商店各區的重置倒數（規格 2026-11-01-five-features-design.md §2）：
/// 每日商店、夜市、配件商店、精選組合包。只用已同步的商店資料，不另外送請求。
List<ResetRow> resetRows(
    CurrentShop shop, DateTime now, int resetHour, int resetMinute) {
  final dailyLive = isDailyActive(shop, now);
  final bundleEnds = [
    for (final b in shop.bundles)
      if (b.endsAt case final e? when e.isAfter(now)) e,
  ]..sort();
  final accessory = shop.accessoryEndsAt;
  return [
    dailyLive
        ? ResetRow('每日商店刷新', Icons.storefront, shop.dailyExpiresAt)
        : ResetRow('每日商店刷新', Icons.storefront,
            nextResetAfter(now, resetHour, resetMinute),
            estimated: true),
    ResetRow('夜市結束', Icons.nightlight_outlined,
        isNightMarketActive(shop, now) ? shop.nightMarketEndsAt : null,
        fallback: '未開放'),
    ResetRow('配件商店刷新', Icons.style_outlined,
        accessory != null && accessory.isAfter(now) ? accessory : null,
        fallback: '同步後顯示'),
    ResetRow('組合包下架', Icons.card_giftcard,
        bundleEnds.isEmpty ? null : bundleEnds.first,
        fallback: '同步後顯示'),
  ];
}

/// 首頁的重置倒數卡，每秒更新。
class ResetCountdownCard extends StatefulWidget {
  final CurrentShop shop;
  final int resetHour;
  final int resetMinute;
  final DateTime Function() now;
  final VoidCallback? onOpenHistory;

  const ResetCountdownCard({
    super.key,
    required this.shop,
    required this.resetHour,
    required this.resetMinute,
    this.now = DateTime.now,
    this.onOpenHistory,
  });

  @override
  State<ResetCountdownCard> createState() => _ResetCountdownCardState();
}

class _ResetCountdownCardState extends State<ResetCountdownCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now();
    final rows =
        resetRows(widget.shop, now, widget.resetHour, widget.resetMinute);
    return PanelCard(
      key: const ValueKey('reset-countdown'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: '重置倒數',
            trailing: widget.onOpenHistory == null
                ? null
                : TextButton.icon(
                    key: const ValueKey('open-shop-history'),
                    onPressed: widget.onOpenHistory,
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('商店歷史'),
                  ),
          ),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(r.icon, size: 18, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(r.label, overflow: TextOverflow.ellipsis)),
                _value(r, now),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _value(ResetRow r, DateTime now) {
    final text = Text(
      countdownLabel(r.target, now) ?? r.fallback,
      key: ValueKey('reset-${r.label}'),
      style: AppText.tabular(TextStyle(
        fontWeight: r.target == null ? FontWeight.normal : FontWeight.w600,
        color: r.target == null || r.estimated ? AppColors.muted : null,
      )),
    );
    return r.estimated ? Tooltip(message: '依設定的刷新時間推算', child: text) : text;
  }
}
