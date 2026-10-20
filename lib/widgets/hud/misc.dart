import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 區塊標題（Chakra Petch）＋右側動作。
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(width: 3, height: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
                child:
                    Text(title, style: Theme.of(context).textTheme.titleLarge)),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// 空狀態：圖示＋說明＋一個動作。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

/// 載入骨架，避免版面跳動。
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonBox({super.key, this.width, this.height = 16});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

/// 依序淡入（間隔 40ms、位移 8px）；減少動態效果時直接顯示。
class FadeInList extends StatefulWidget {
  final List<Widget> children;

  const FadeInList({super.key, required this.children});

  @override
  State<FadeInList> createState() => _FadeInListState();
}

class _FadeInListState extends State<FadeInList>
    with SingleTickerProviderStateMixin {
  static const _each = Duration(milliseconds: 200);
  static const _gap = 40;

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // 在 initState 建立：減少動態效果時 build 不會用到它，dispose 仍要安全。
    _c = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: _each.inMilliseconds +
              _gap * (widget.children.length - 1).clamp(0, 5)),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.children);
    }
    final total = _c.duration!.inMilliseconds;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            Builder(builder: (_) {
              // 超過 5 項後同時進場，總長不超過 400ms。
              final start = _gap * i.clamp(0, 5) / total;
              final end =
                  (start + _each.inMilliseconds / total).clamp(0.0, 1.0);
              final t = Curves.easeOut.transform(
                  ((_c.value - start) / (end - start)).clamp(0.0, 1.0));
              return Opacity(
                opacity: t,
                child: Transform.translate(
                    offset: Offset(0, 8 * (1 - t)), child: widget.children[i]),
              );
            }),
        ],
      ),
    );
  }
}
