import 'theme_ids.dart';

/// EVA 系列的故事語彙（規格 2026-10-21-ui-themes-design.md §4.5）。
/// 全部是原創文案，只取世界觀用語，不使用原作台詞或集數標題。

/// 路由 → （故事名, 英文名）；主標題仍是原本的中文頁名，這裡只用在代碼行與英文標。
const Map<String, (String, String)> evaStoryNames = {
  '/': ('補給線', 'SUPPLY LINE'),
  '/wishlist': ('補完目標', 'TARGET LIST'),
  '/matches': ('作戰記錄', 'OPERATION LOG'),
  '/live': ('迎擊態勢', 'INTERCEPT'),
  '/players': ('接觸記錄', 'CONTACT LOG'),
  '/collection': ('格納庫', 'HANGAR'),
  '/progress': ('育成計畫', 'TRAINING PLAN'),
  '/agents': ('適格者資料', 'PILOT FILE'),
  '/weapons': ('兵裝', 'ARMAMENT'),
  '/maps': ('作戰區域', 'SECTOR'),
  '/bundles': ('補給包', 'SUPPLY PACK'),
  '/gamemodes': ('作戰形態', 'OPERATION TYPE'),
  '/playercards': ('識別證', 'ID CARD'),
  '/settings': ('MAGI 設定', 'MAGI CONFIG'),
};

/// EVA 系列的主色名稱（規格 §3.2 的 EVA 對應色）。
const Map<AccentId, String> evaAccentNames = {
  AccentId.red: '警戒紅',
  AccentId.blue: '琥珀',
  AccentId.green: '訊號綠',
  AccentId.violet: '初號機紫',
  AccentId.berserk: '暴走',
};

/// F2 機密文件的德文副標（E18）。
const Map<String, String> navLabelsDe = {
  '/': 'Versorgungslinie',
  '/wishlist': 'Zielliste',
  '/matches': 'Einsatzprotokoll',
  '/live': 'Abfangbereitschaft',
  '/players': 'Kontaktprotokoll',
  '/collection': 'Hangar',
  '/progress': 'Ausbildungsplan',
  '/agents': 'Pilotenakte',
  '/weapons': 'Bewaffnung',
  '/maps': 'Einsatzgebiet',
  '/bundles': 'Versorgungspaket',
  '/gamemodes': 'Einsatzart',
  '/playercards': 'Ausweis',
  '/settings': 'MAGI-Konfiguration',
};

/// 每一頁專屬的標題卡標題：（大詞, 小詞），對應頁面內容（使用者決定 2026-10-21）。
const Map<String, (String, String)> evaPageTitles = {
  '/': ('補給線', '開通'),
  '/wishlist': ('願望', '之清單'),
  '/matches': ('交戰', '記錄'),
  '/live': ('迎擊', '態勢'),
  '/players': ('接觸', '者名冊'),
  '/collection': ('格納庫', '深處'),
  '/progress': ('育成', '計畫'),
  '/agents': ('適格者', '檔案'),
  '/weapons': ('兵裝', '點檢'),
  '/maps': ('作戰', '區域'),
  '/bundles': ('補給包', '到著'),
  '/gamemodes': ('作戰', '形態'),
  '/playercards': ('識別證', '發行'),
  '/settings': ('MAGI', '設定'),
};

/// 26 話的原創標題：（大詞, 小詞），用於 L 形混排的標題卡。
const List<(String, String)> evaEpisodeTitles = [
  ('起動', '之日'),
  ('補給線', '確保'),
  ('交戰', '記錄'),
  ('夜市', '開放'),
  ('格納庫', '深處'),
  ('決戰', '第三區'),
  ('願望', '之清單'),
  ('同步率', '測定'),
  ('刷新', '倒數'),
  ('適格者', '登錄'),
  ('迎擊', '態勢'),
  ('接觸', '記錄'),
  ('補給包', '到著'),
  ('兵裝', '點檢'),
  ('作戰區域', '偵察'),
  ('識別證', '發行'),
  ('育成計畫', '進捗'),
  ('使徒', '接近'),
  ('MAGI', '審議'),
  ('觀測', '記錄'),
  ('收藏', '整理'),
  ('夜間', '警戒'),
  ('連勝', '之後'),
  ('撤退', '勸告'),
  ('補完', '前夜'),
  ('終劇', '之日'),
];

const _digits = ['', '壱', '弐', '参', '肆', '伍', '陸', '漆', '捌', '玖'];

/// 1～99 的漢字數字（大寫字），例如 14 → 拾肆、26 → 弐拾陸。
String kanjiNumber(int n) {
  assert(n > 0 && n < 100);
  final tens = n ~/ 10, ones = n % 10;
  final t = switch (tens) {
    0 => '',
    1 => '拾',
    _ => '${_digits[tens]}拾',
  };
  return '$t${_digits[ones]}';
}
