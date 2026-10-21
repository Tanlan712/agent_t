import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../logic/eva_progress.dart';
import '../../../models/app_settings.dart';
import '../../../providers/match_history_provider.dart';
import '../../../providers/riot_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../theme/app_fonts.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/theme_ids.dart';
import 'eva_mincho.dart';
import 'eva_overlays.dart';

/// App 版本（與 pubspec.yaml 一致）；報告書的「第 N 次中間報告書」。
const appVersion = '1.0.0';

const _privacy = '本文件所載他人資料，請勿公開或分享。';
const _noData = '資料未取得';

/// 文件裡的一段文字；[DocRedacted] 預設塗黑。
sealed class DocSpan {
  const DocSpan();
}

class DocText extends DocSpan {
  final String text;
  const DocText(this.text);
}

class DocRedacted extends DocSpan {
  final String text;
  const DocRedacted(this.text);
}

class EvaDocument {
  final String id;
  final String title;
  final String subtitle;
  final List<List<DocSpan>> lines;
  final int number;

  const EvaDocument({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lines,
    required this.number,
  });

  String get footer => 'VAL-SYS ARCHIVE · DOC-$number';

  /// 純文字（含塗黑內容），給測試與搜尋用。
  String get plainText => [
        title,
        subtitle,
        for (final l in lines)
          l
              .map((s) => switch (s) {
                    DocText(:final text) => text,
                    DocRedacted(:final text) => text,
                  })
              .join(),
      ].join('\n');
}

/// 文件中會填入的已載入資料（不觸發載入；沒有時為 null）。
class EvaDocData {
  final int shopCount;
  final int matched;
  final double? sync;
  final String refresh;
  final double? completion;
  final int matchesLoaded;
  final double? winRate;
  final double? avgAcs;
  final int openDays;
  final int angelCount;

  const EvaDocData({
    required this.shopCount,
    required this.matched,
    required this.sync,
    required this.refresh,
    required this.completion,
    required this.matchesLoaded,
    required this.winRate,
    required this.avgAcs,
    required this.openDays,
    required this.angelCount,
  });

  /// 從目前的 provider 狀態讀取（listen: false）。
  factory EvaDocData.of(BuildContext context) {
    final s = context.read<SettingsProvider>().settings;
    final shop = context.read<ShopProvider>().shop;
    final wish = context.read<WishlistProvider>().uuids;
    final riot = context.read<RiotProvider>();
    final entries = context.read<MatchHistoryProvider>().entries;
    final summaries =
        entries.map((e) => e.detail?.summary).whereType<Object>().toList();
    final wins = entries.map((e) => e.detail?.summary.won).toList();
    final acs =
        entries.map((e) => e.detail?.summary.acs).whereType<int>().toList();
    String two(int n) => n.toString().padLeft(2, '0');
    return EvaDocData(
      shopCount: shop.daily.length,
      matched: shop.daily.where((e) => wish.contains(e.skinUuid)).length,
      sync: syncRatioOf(wins),
      refresh: '${two(s.resetHour)}:${two(s.resetMinute)}',
      completion: riot.isLoggedIn && wish.isNotEmpty
          ? wish.where(riot.isOwned).length / wish.length
          : null,
      matchesLoaded: summaries.length,
      winRate: syncRatioOf(wins),
      avgAcs: acs.isEmpty ? null : acs.reduce((a, b) => a + b) / acs.length,
      openDays: s.evaEpisodeDays,
      angelCount: s.evaAngelCount,
    );
  }
}

String _pct(double? v) =>
    v == null ? _noData : '${(v * 100).toStringAsFixed(1)}%';

/// 附錄 C 的彩蛋說明（只列出已發現的）。
const _eggHints = {
  'E1': 'Konami 碼 → 圖形判定',
  'E2': '品牌字連點 5 下 → MAGI 表決',
  'E3': '今日商店出現究極／限定 → 使徒接近',
  'E4': '閒置 60 秒 → 假人系統',
  'E5': '鍵入 sync → 同步率',
  'E6': '深夜開啟 → 夜間警戒態勢',
  'E7': '連點兩下空白處 → REFUSED',
  'E8': '刷新前 60 秒 → 大倒數',
  'E9': '設定頁連點 EVA 縮圖 7 下 → 暴走',
  'E10': '每天第一次開啟 → 開機自檢',
  'E11': '按 ` 鍵 → 終端機',
  'E12': '品牌字按右鍵 → 本文件庫',
  'E13': '連勝或連敗 3 場 → 印章',
  'E14': '今日商店全部命中 → 補完達成',
  'E15': '夜市開放 → 非常事態',
  'E16': '連續失敗 3 次 → CONNECTION LOST',
  'E17': '捲到最底 → 液面',
  'E18': '機密文件雙擊標題 → 德文副標',
  'E19': '10 月 4 日 → 放送紀念日',
  'E20': 'Konami 碼後再按 B A → 第拾捌話',
};

List<DocSpan> _t(String s) => [DocText(s)];

/// 依劇集與彩蛋發現解鎖的文件（規格 §4.7）。
List<EvaDocument> availableDocuments(AppSettings s, EvaDocData d) {
  final ep = s.evaEpisodeDays;
  final found = [
    for (final id in evaEggIds)
      if (s.evaFoundEggs.contains(id)) id
  ];
  final docs = <EvaDocument>[
    EvaDocument(
      id: 'report',
      number: 27,
      title: '商店追蹤計畫　第 $appVersion 次中間報告書',
      subtitle:
          'Bericht über die Ladenbeobachtung · Zwischenbericht $appVersion',
      lines: [
        [
          const DocText('一、本期觀測對象為今日商店 '),
          DocRedacted('${d.shopCount} 件'),
          const DocText('，其中 '),
          DocRedacted('${d.matched} 件'),
          const DocText(' 命中願望清單。')
        ],
        [
          const DocText('二、適格者之同步率記錄為 '),
          DocRedacted(_pct(d.sync)),
          const DocText('。')
        ],
        [
          const DocText('三、下次補給線刷新預定於 '),
          DocRedacted(d.refresh),
          const DocText('。')
        ],
        [
          const DocText('四、補完計畫進捗 '),
          DocRedacted(_pct(d.completion)),
          const DocText('。')
        ],
        _t('五、$_privacy'),
      ],
    ),
    EvaDocument(
      id: 'B',
      number: 28,
      title: '附錄 B　更新記錄',
      subtitle: 'APPENDIX B / CHANGELOG · 閱後歸檔',
      lines: [
        _t('・可切換主題：8 種風格 × 主色 × 明暗'),
        _t('・通行證與任務頁'),
        _t('・我的收藏頁'),
        [const DocText('・'), const DocRedacted('即時對局（使用者核准）')],
        _t('・商店追蹤與願望清單'),
        _t(_privacy),
      ],
    ),
    EvaDocument(
      id: 'C',
      number: 29,
      title: '附錄 C　已知彩蛋一覽',
      subtitle: 'APPENDIX C / ACCESS LEVEL: AAA',
      lines: [
        for (final id in found) [DocText('$id　'), DocRedacted(_eggHints[id]!)],
        _t('其餘 ${evaEggIds.length - found.length} 項未解密'),
        _t(_privacy),
      ],
    ),
  ];
  if (ep >= 5) {
    docs.add(EvaDocument(
      id: 'D',
      number: 30,
      title: '附錄 D　VAL-SYS 設立經緯',
      subtitle: 'APPENDIX D / FOUNDING RECORD',
      lines: [
        _t('本系統設立之目的，是在不接觸遊戲本體的前提下，整理適格者自己的補給線資料。'),
        _t('一切觀測只經由瀏覽器進行，不讀取記憶體、不攔截通訊、不代為操作。'),
        _t('此原則高於所有功能，任何附錄皆不得例外。'),
        _t(_privacy),
      ],
    ));
  }
  if (ep >= 10) {
    docs.add(EvaDocument(
      id: 'E',
      number: 31,
      title: '附錄 E　MAGI 設計概要',
      subtitle: 'APPENDIX E / MAGI OVERVIEW',
      lines: [
        _t('MELCHIOR：判讀補給線（今日商店）是否有效。'),
        _t('BALTHASAR：判讀錢包與登入狀態。'),
        _t('CASPER：判讀格納庫（收藏）與育成計畫（通行證）是否讀取成功。'),
        _t('三者只回報「可／否／未連線」，不會自行重試或發出任何請求。'),
        _t(_privacy),
      ],
    ));
  }
  if (ep >= 15) {
    docs.add(EvaDocument(
      id: 'F',
      number: 32,
      title: '附錄 F　補給線運用規程',
      subtitle: 'APPENDIX F / SUPPLY LINE RULES',
      lines: [
        [
          const DocText('第一條　補給線每日 '),
          DocRedacted(d.refresh),
          const DocText(' 更新。')
        ],
        _t('第二條　願望清單命中時，於補給線以金框標示。'),
        _t('第三條　夜市開放期間，另以非常事態告示。'),
        _t(_privacy),
      ],
    ));
  }
  if (ep >= 20) {
    docs.add(EvaDocument(
      id: 'G',
      number: 33,
      title: '附錄 G　適格者觀測記錄',
      subtitle: 'APPENDIX G / PILOT OBSERVATION',
      lines: [
        [const DocText('已載入作戰記錄：'), DocRedacted('${d.matchesLoaded} 場')],
        [const DocText('勝率：'), DocRedacted(_pct(d.winRate))],
        [
          const DocText('平均 ACS：'),
          DocRedacted(
              d.avgAcs == null ? _noData : d.avgAcs!.toStringAsFixed(0)),
        ],
        _t('以上僅為本機已載入的自己的資料。'),
        _t(_privacy),
      ],
    ));
  }
  if (ep >= evaMaxEpisodes) {
    docs.add(EvaDocument(
      id: 'final',
      number: 34,
      title: '最終報告書',
      subtitle: 'FINAL REPORT',
      lines: [
        [const DocText('累計開啟：'), DocRedacted('${d.openDays} 日')],
        [const DocText('使徒接近：'), DocRedacted('${d.angelCount} 次')],
        [const DocText('補完計畫進捗：'), DocRedacted(_pct(d.completion))],
        _t('觀測至此告一段落。補給線仍會在每日的同一時刻更新。'),
        _t(_privacy),
      ],
    ));
  }
  if (allEggsFound(s)) {
    docs.add(EvaDocument(
      id: 'Z',
      number: 35,
      title: '附錄 Z　補完完了',
      subtitle: 'APPENDIX Z / END OF FILE',
      lines: [
        _t('二十項彩蛋全部解密。感謝你一路的觀測。'),
        _t('本系統的所有文案皆為原創，僅向作品的世界觀致敬。'),
        _t(_privacy),
      ],
    ));
  }
  return docs;
}

/// 塗黑文字：預設黑條，滑鼠移過、長按或鍵盤聚焦時顯示內容。
class Redacted extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const Redacted({super.key, required this.text, this.style});

  @override
  State<Redacted> createState() => _RedactedState();
}

class _RedactedState extends State<Redacted> {
  bool _hover = false, _press = false, _focus = false;

  @override
  Widget build(BuildContext context) {
    final shown = _hover || _press || _focus;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final ink = style.color ?? context.palette.text;
    return Semantics(
      label: shown ? widget.text : '已塗黑，聚焦以顯示',
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (v) => setState(() => _focus = v),
        child: MouseRegion(
          cursor: SystemMouseCursors.help,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onLongPressStart: (_) => setState(() => _press = true),
            onLongPressEnd: (_) => setState(() => _press = false),
            child: shown
                ? Text(widget.text, style: style)
                // 原文不放進畫面樹（螢幕閱讀器也讀不到），只顯示等長的黑塊。
                : Text('█' * widget.text.characters.length,
                    style: style.copyWith(color: ink)),
          ),
        ),
      ),
    );
  }
}

/// 文件庫覆蓋畫面（F2 淺色紙張）；點頁碼翻頁、✕ 或 Esc 關閉。
class EvaArchive extends StatefulWidget {
  final VoidCallback onClose;

  const EvaArchive({super.key, required this.onClose});

  @override
  State<EvaArchive> createState() => _EvaArchiveState();
}

class _EvaArchiveState extends State<EvaArchive> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final docs = availableDocuments(
        context.watch<SettingsProvider>().settings, EvaDocData.of(context));
    final doc = docs[_page.clamp(0, docs.length - 1)];
    // 機密文件一律用紙色（F2 淺色）。
    final paper = AppPalette.resolve(const ThemeChoice(
        style: ThemeStyleId.evaMonitor, mode: BrightnessMode.light));
    final body = TextStyle(fontSize: 14, height: 1.9, color: paper.text);
    return ColoredBox(
      color: context.palette.background.withOpacity(0.85),
      child: Center(
        child: GestureDetector(
          onTap: () {},
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            decoration: BoxDecoration(
                color: paper.surface, border: Border.all(color: paper.outline)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: paper.text, width: 2),
                        borderRadius: BorderRadius.circular(3)),
                    child: EvaMincho('超機密',
                        size: 14, squeeze: 1, color: paper.text),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                    child: EvaMincho(doc.title,
                        size: 24, squeeze: 0.9, color: paper.text)),
                Text(doc.subtitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.serif(
                        TextStyle(fontSize: 13, color: paper.muted))),
                Divider(color: paper.outline),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in doc.lines)
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final span in line)
                                switch (span) {
                                  DocText(:final text) =>
                                    Text(text, style: body),
                                  DocRedacted(:final text) =>
                                    Redacted(text: text, style: body),
                                },
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                Divider(color: paper.outline),
                Row(children: [
                  Expanded(
                    child: Text(doc.footer,
                        style: AppFonts.mono(
                            TextStyle(fontSize: 11, color: paper.muted))),
                  ),
                  for (var i = 0; i < docs.length; i++)
                    InkWell(
                      key: ValueKey('doc-page-${docs[i].id}'),
                      onTap: () => setState(() => _page = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Text('${i + 1}',
                            style: AppFonts.mono(TextStyle(
                                fontSize: 12,
                                color: i == _page ? paper.loss : paper.text,
                                decoration: i == _page
                                    ? TextDecoration.underline
                                    : null))),
                      ),
                    ),
                  IconButton(
                    tooltip: '關閉',
                    icon: Icon(Icons.close, size: 18, color: paper.text),
                    onPressed: widget.onClose,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
