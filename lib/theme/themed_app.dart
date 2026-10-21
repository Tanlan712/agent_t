import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'app_theme.dart';
import 'theme_ids.dart';

/// 依設定建主題，交給 [builder] 組成 MaterialApp。
/// 主題改變時讓整棵子樹重建（`AppColors.*` 不是 InheritedWidget，不會自動通知），
/// 但保留元件狀態與頁面堆疊。
class ThemedApp extends StatefulWidget {
  final bool useGoogleFonts;
  final Widget Function(ThemeData theme, TransitionBuilder builder) builder;

  const ThemedApp(
      {super.key, this.useGoogleFonts = true, required this.builder});

  @override
  State<ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<ThemedApp> {
  String? _key;
  ThemeData? _theme;

  @override
  Widget build(BuildContext context) {
    final choice =
        ThemeChoice.fromSettings(context.watch<SettingsProvider>().settings);
    // 主題沒變（例如只記錄了一個彩蛋）時沿用同一個 ThemeData，避免整個 App 重建。
    final key = '${choice.key}-${widget.useGoogleFonts}';
    if (key != _key || _theme == null) {
      _key = key;
      _theme =
          buildAppTheme(choice: choice, useGoogleFonts: widget.useGoogleFonts);
    }
    return widget.builder(
        _theme!,
        (context, child) => RebuildOnChange(
            token: choice.key, child: child ?? const SizedBox()));
  }
}

/// [token] 改變時，在下一幀把所有子孫標記為需要重建。
class RebuildOnChange extends StatefulWidget {
  final Object token;
  final Widget child;

  const RebuildOnChange({super.key, required this.token, required this.child});

  @override
  State<RebuildOnChange> createState() => _RebuildOnChangeState();
}

class _RebuildOnChangeState extends State<RebuildOnChange> {
  @override
  void didUpdateWidget(RebuildOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token == widget.token) return;
    // 建構期間不能走訪子元件；等這一幀結束再標記（多一幀舊色）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      context.visitChildElements(mark);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
