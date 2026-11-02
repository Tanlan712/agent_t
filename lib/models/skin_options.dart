/// 造型等級／炫彩的顯示資料與「選哪個要顯示什麼」的規則（純邏輯，可單元測試）。
library;

/// 造型的一個等級（顯示用）。
class SkinLevelOption {
  final String? image;
  final String? videoUrl;

  /// 是否擁有；null 代表不知道（資料庫、商店頁），一律當作可看。
  final bool? owned;

  const SkinLevelOption({this.image, this.videoUrl, this.owned});
}

/// 造型的一個炫彩（顯示用）；第 0 個是基本款。
class SkinChromaOption {
  final String name;
  final String? image;
  final String? swatch;
  final String? videoUrl;
  final bool? owned;

  const SkinChromaOption(
      {this.name = '', this.image, this.swatch, this.videoUrl, this.owned});
}

/// 選了第 [level] 等級、第 [chroma] 個炫彩時顯示的圖：
/// 炫彩（非基本款）有圖用炫彩圖，否則用等級圖，再退回基本款圖與 [fallback]。
String? skinImageFor(List<SkinLevelOption> levels,
    List<SkinChromaOption> chromas, int level, int chroma,
    {String? fallback}) {
  if (chroma > 0 && chroma < chromas.length) {
    if (chromas[chroma].image case final img?) return img;
  }
  if (level >= 0 && level < levels.length) {
    if (levels[level].image case final img?) return img;
  }
  if (chromas.isNotEmpty) {
    if (chromas.first.image case final img?) return img;
  }
  return fallback;
}

/// 選了第 [level] 等級、第 [chroma] 個炫彩時的預覽影片：
/// 炫彩（非基本款）的影片優先，否則用該等級的影片；都沒有回傳 null。
String? skinVideoFor(List<SkinLevelOption> levels,
    List<SkinChromaOption> chromas, int level, int chroma) {
  if (chroma > 0 && chroma < chromas.length) {
    if (chromas[chroma].videoUrl case final v?) return v;
  }
  if (level >= 0 && level < levels.length) return levels[level].videoUrl;
  return null;
}
