import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';

/// 在新分頁開啟（造型影片）。
Future<bool> openInNewTab(Uri uri) =>
    launchUrl(uri, webOnlyWindowName: '_blank');

/// 資料庫詳細頁的共用外框：標題列＋置中、最大寬度 1080 的捲動內容。
class DetailScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const DetailScaffold(
      {super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      );
}

/// 一格數據：標籤在上、數值在下。
class StatTile extends StatelessWidget {
  final String label;
  final String value;

  const StatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value,
                style: AppText.tabular(const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
