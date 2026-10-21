import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../nav_items.dart';

/// A 編輯海報的全螢幕選單：依分組列出所有頁面；Esc 或右上角關閉。
Future<void> showFullscreenMenu(
  BuildContext context, {
  required String currentRoute,
  required ValueChanged<NavItem> onSelect,
  List<NavItem> items = navItems,
}) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '關閉選單',
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      pageBuilder: (dialog, _, __) => _FullscreenMenu(
        currentRoute: canonicalRoute(currentRoute),
        items: items,
        onSelect: (item) {
          Navigator.pop(dialog);
          onSelect(item);
        },
      ),
    );

class _FullscreenMenu extends StatelessWidget {
  final String currentRoute;
  final List<NavItem> items;
  final ValueChanged<NavItem> onSelect;

  const _FullscreenMenu(
      {required this.currentRoute,
      required this.items,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      key: const ValueKey('fullscreen-menu'),
      color: p.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: '關閉',
                icon: Icon(Icons.close, color: p.text),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                children: [
                  for (final g in NavGroup.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(navGroupLabels[g]!,
                          style: TextStyle(
                              fontSize: 12, letterSpacing: 2, color: p.muted)),
                    ),
                    for (final n in items.where((n) => n.group == g))
                      InkWell(
                        onTap: () => onSelect(n),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(n.label,
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: n.route == currentRoute
                                      ? p.primary
                                      : p.text)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
