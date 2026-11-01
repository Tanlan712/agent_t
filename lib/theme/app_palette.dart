import 'package:flutter/material.dart';

import 'theme_ids.dart';

/// 目前主題的顏色（規格 2026-10-21-ui-themes-design.md §3）。
/// 這個檔案是唯一可以寫死色碼的主題定義檔。
class AppPalette extends ThemeExtension<AppPalette> {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;
  final Color text;
  final Color muted;
  final Color primary;
  final Color buttonFill;
  final Color onButton;
  final Color win;
  final Color loss;
  final Color warn;
  final Color info;

  /// 依 Tier.values 的順序。
  final List<Color> tier;
  final List<Color> party;

  /// F2／F3 的結構色（括號框、分隔直線）。
  final Color? frame;

  /// E 的裝飾漸層、H 的背景山景色（只用在背景，不承載文字）。
  final List<Color>? decor;

  /// H 的主色漸層（選中導覽、主要按鈕）；上面放白字，兩端對白色對比都 ≥ 4.5。
  final List<Color>? accentGradient;

  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.text,
    required this.muted,
    required this.primary,
    required this.buttonFill,
    required this.onButton,
    required this.win,
    required this.loss,
    required this.warn,
    required this.info,
    required this.tier,
    required this.party,
    this.frame,
    this.decor,
    this.accentGradient,
  });

  /// `AppColors.*` 讀這裡；由 `buildAppTheme` 設定。
  static AppPalette current = resolve(const ThemeChoice());

  @visibleForTesting
  static void reset() => current = resolve(const ThemeChoice());

  static AppPalette resolve(ThemeChoice c) {
    final dark = c.brightness == Brightness.dark;
    if (c.style == ThemeStyleId.material) return _material(c);
    if (c.style == ThemeStyleId.glass) return _glass(c);
    final n = (dark ? _neutralDark : _neutralLight)[c.style]!;
    // 暴走只在 EVA 系列有效，其他風格當成紅。
    final accent = !c.style.isEva && c.accent == AccentId.berserk
        ? AccentId.red
        : c.accent;
    final (primary, fill, on) = c.style.isEva
        ? (dark ? _evaAccentDark : _evaAccentLight)[accent]!
        : (dark ? _accentDark : _accentLight)[accent]!;
    final usesFrame =
        c.style == ThemeStyleId.evaMonitor || c.style == ThemeStyleId.evaFusion;
    // I 極簡儀表板：主要按鈕與選中標示用墨色（淺色黑底白字、深色白底黑字），主色只做點綴。
    // J 控制台的主要按鈕用主色，反黑重點卡另外用墨色（hud_card.dart）。
    final ink = c.style == ThemeStyleId.dashboard;
    return AppPalette(
      brightness: c.brightness,
      background: n[0],
      surface: n[1],
      surfaceHigh: n[2],
      outline: n[3],
      text: n[4],
      muted: n[5],
      primary: primary,
      buttonFill: ink ? n[4] : fill,
      onButton: ink ? n[1] : on,
      win: dark ? const Color(0xFF4ADE80) : const Color(0xFF166534),
      loss: dark ? const Color(0xFFFF6B6B) : const Color(0xFFB42318),
      warn: dark ? const Color(0xFFFFC107) : const Color(0xFF8A5A00),
      info: dark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
      tier: dark ? _tierDark : _tierLight,
      party: dark ? _partyDark : _partyLight,
      frame: usesFrame
          ? (dark ? const Color(0xFFFF9A1F) : const Color(0xFF5E5A3A))
          : null,
      decor: c.style == ThemeStyleId.dreamy
          ? _dreamyDecor
          : c.style.isEva && accent == AccentId.berserk
              ? _berserkDecor
              : null,
    );
  }

  /// G：中性色與主色都取自 MD3 色彩系統（[materialScheme]），語意色沿用共用值。
  static AppPalette _material(ThemeChoice c) {
    final dark = c.brightness == Brightness.dark;
    final s = materialScheme(c);
    return AppPalette(
      brightness: c.brightness,
      background: s.surface,
      surface: s.surfaceContainer,
      surfaceHigh: s.surfaceContainerHigh,
      outline: s.outlineVariant,
      text: s.onSurface,
      muted: s.onSurfaceVariant,
      primary: s.primary,
      buttonFill: s.primary,
      onButton: s.onPrimary,
      win: dark ? const Color(0xFF4ADE80) : const Color(0xFF166534),
      loss: s.error,
      warn: dark ? const Color(0xFFFFC107) : const Color(0xFF8A5A00),
      info: dark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
      tier: dark ? _tierDark : _tierLight,
      party: dark ? _partyDark : _partyLight,
    );
  }

  /// H 玻璃黏土：白天淡藍灰（淺）／暮色煙燻灰（深）中性色，主色沿用共用主色，
  /// 另外帶一組主色漸層與背景山景色。暴走不適用，當成紅。
  static AppPalette _glass(ThemeChoice c) {
    final dark = c.brightness == Brightness.dark;
    final n = dark ? _glassNeutralDark : _glassNeutralLight;
    final accent = c.accent == AccentId.berserk ? AccentId.red : c.accent;
    final (primary, _, on) = (dark ? _accentDark : _accentLight)[accent]!;
    final gradient = _glassGradients[accent]!;
    return AppPalette(
      brightness: c.brightness,
      background: n[0],
      surface: n[1],
      surfaceHigh: n[2],
      outline: n[3],
      text: n[4],
      muted: n[5],
      primary: primary,
      buttonFill: gradient.first,
      onButton: on,
      win: dark ? const Color(0xFF4ADE80) : const Color(0xFF166534),
      loss: dark ? const Color(0xFFFF6B6B) : const Color(0xFFB42318),
      warn: dark ? const Color(0xFFFFC107) : const Color(0xFF8A5A00),
      info: dark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
      tier: dark ? _tierDark : _tierLight,
      party: dark ? _partyDark : _partyLight,
      decor: dark ? _glassSceneDark : _glassSceneLight,
      accentGradient: gradient,
    );
  }

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.current;
}

/// G Material 3 的完整 ColorScheme：以主色為種子色、tonal spot 變體產生
/// （與 Android 12+ 動態色相同的演算法）。暴走不適用，當成紅。
ColorScheme materialScheme(ThemeChoice c) => ColorScheme.fromSeed(
      seedColor: _materialSeeds[c.accent] ?? _materialSeeds[AccentId.red]!,
      brightness: c.brightness,
    );

const _materialSeeds = <AccentId, Color>{
  AccentId.red: Color(0xFFFF4655),
  AccentId.blue: Color(0xFF0B6FB8),
  AccentId.green: Color(0xFF0E7A5A),
  AccentId.violet: Color(0xFF7C3AED),
};

// 中性色：bg、surface、surfaceHigh、outline、text、muted（規格 §3.1）。
List<Color> _n(List<int> v) => [for (final x in v) Color(x)];

final _neutralDark = <ThemeStyleId, List<Color>>{
  ThemeStyleId.editorial: _n(
      [0xFF111111, 0xFF1A1A1A, 0xFF242424, 0xFF333333, 0xFFF2F2F2, 0xFFA3A3A3]),
  ThemeStyleId.neon: _n(
      [0xFF0E0A1A, 0xFF1C1530, 0xFF271E40, 0xFF3A2F58, 0xFFF1EEF8, 0xFFABA3C4]),
  ThemeStyleId.airy: _n(
      [0xFF161513, 0xFF201E1B, 0xFF2A2824, 0xFF3A3732, 0xFFF2EFE9, 0xFFA8A296]),
  ThemeStyleId.terminal: _n(
      [0xFF05070C, 0xFF0D111A, 0xFF151B27, 0xFF232C3D, 0xFFE6EAF2, 0xFF9AA3B5]),
  ThemeStyleId.dreamy: _n(
      [0xFF1A1230, 0xFF251A40, 0xFF30234F, 0xFF453568, 0xFFF6F0FF, 0xFFB8ACD6]),
  ThemeStyleId.evaAlert: _n(
      [0xFF0A0000, 0xFF140505, 0xFF1F0A08, 0xFF4A1410, 0xFFFFE3DA, 0xFFC49A90]),
  ThemeStyleId.evaMonitor: _n(
      [0xFF070302, 0xFF120A05, 0xFF1C1209, 0xFF5C3A12, 0xFFF2E6D0, 0xFFBFA888]),
  ThemeStyleId.evaFusion: _n(
      [0xFF070302, 0xFF120A05, 0xFF1C1209, 0xFF5C3A12, 0xFFF2E6D0, 0xFFBFA888]),
  ThemeStyleId.dashboard: _n(
      [0xFF0B0B0D, 0xFF17181B, 0xFF1F2023, 0xFF2C2D32, 0xFFF3F3F5, 0xFFA2A4AC]),
  // J 控制台：近黑畫布、深灰工作台、再亮一階的面板。
  ThemeStyleId.console: _n(
      [0xFF0C0C0D, 0xFF161618, 0xFF1F1F22, 0xFF2D2D31, 0xFFF2F2F0, 0xFFA4A4A9]),
};

final _neutralLight = <ThemeStyleId, List<Color>>{
  ThemeStyleId.editorial: _n(
      [0xFFF5F5F3, 0xFFFFFFFF, 0xFFEDEDED, 0xFFD9D9D9, 0xFF111111, 0xFF595959]),
  ThemeStyleId.neon: _n(
      [0xFFF4F2FA, 0xFFFFFFFF, 0xFFECE8F6, 0xFFD4CEE6, 0xFF1A1430, 0xFF5A5470]),
  ThemeStyleId.airy: _n(
      [0xFFFBFAF8, 0xFFFFFFFF, 0xFFF1EEE8, 0xFFDDD8CE, 0xFF222222, 0xFF5E5A52]),
  ThemeStyleId.terminal: _n(
      [0xFFF2F4F7, 0xFFFFFFFF, 0xFFE8ECF2, 0xFFCBD2DE, 0xFF0D111A, 0xFF4F5A6E]),
  ThemeStyleId.dreamy: _n(
      [0xFFF7EEF8, 0xFFFFFFFF, 0xFFF2EAF7, 0xFFDCCFE6, 0xFF2A2340, 0xFF5B5470]),
  ThemeStyleId.evaAlert: _n(
      [0xFFF4F1EA, 0xFFFFFFFF, 0xFFECE6DA, 0xFFCFC4B0, 0xFF1A0A08, 0xFF5E4A42]),
  // 機密文件紙色。
  ThemeStyleId.evaMonitor: _n(
      [0xFFECE9E0, 0xFFF6F4EE, 0xFFE6E3D9, 0xFFB9B4A0, 0xFF2B2A1F, 0xFF5A5744]),
  ThemeStyleId.evaFusion: _n(
      [0xFFECE9E0, 0xFFF6F4EE, 0xFFE6E3D9, 0xFFB9B4A0, 0xFF2B2A1F, 0xFF5A5744]),
  // I 極簡儀表板：淺灰底、純白卡片、近黑文字。
  ThemeStyleId.dashboard: _n(
      [0xFFEEEEEC, 0xFFFFFFFF, 0xFFF5F5F4, 0xFFE2E2DF, 0xFF0F1012, 0xFF5B5D65]),
  // J 控制台：暖灰畫布、純白工作台、工作台上的淺灰面板。
  ThemeStyleId.console: _n(
      [0xFFE8E8E5, 0xFFFFFFFF, 0xFFF6F6F3, 0xFFE4E4DF, 0xFF111111, 0xFF5A5A55]),
};

// H 玻璃黏土中性色（順序同上）：淺色是白天的淡藍灰，深色是暮色的煙燻灰（不帶紫）。
final _glassNeutralLight = _n(
    [0xFFE6EBF2, 0xFFFBFBFD, 0xFFEFF1F5, 0xFFD5D9E1, 0xFF1C1D22, 0xFF53555E]);
final _glassNeutralDark = _n(
    [0xFF16151B, 0xFF242328, 0xFF2E2D33, 0xFF4A4850, 0xFFF4F1EC, 0xFFBDB6AE]);

/// H 背景山景的顏色：天空頂端、地平線、太陽光暈（淺色＝白天、深色＝黃昏）。
/// 只用在背景，不承載文字；頂端與底部都收回 background，手機頂列與底部導覽沒有接縫。
const _glassSceneLight = [
  Color(0xFFBCD0E6),
  Color(0xFFF1D9C4),
  Color(0xFFFFE2B8)
];
const _glassSceneDark = [
  Color(0xFF1B1D2B),
  Color(0xFF4A3530),
  Color(0xFFE08A4A)
];

/// H 的主色漸層：起點與終點對白字對比都 ≥ 4.5（有測試）。
const _glassGradients = <AccentId, List<Color>>{
  AccentId.red: [Color(0xFFD7263D), Color(0xFFC2185B)],
  AccentId.blue: [Color(0xFF3F51E0), Color(0xFF6A3FD8)],
  AccentId.green: [Color(0xFF0E7A5A), Color(0xFF0B6E80)],
  AccentId.violet: [Color(0xFF6D3CE0), Color(0xFF8E2DC2)],
};

// 主色：primary、buttonFill、onButton（規格 §3.2）。
const _white = Color(0xFFFFFFFF);

const _accentDark = <AccentId, (Color, Color, Color)>{
  AccentId.red: (Color(0xFFFF4655), Color(0xFFD7263D), _white),
  AccentId.blue: (Color(0xFF4FC3F7), Color(0xFF0B6FB8), _white),
  AccentId.green: (Color(0xFF2DD4A4), Color(0xFF0E7A5A), _white),
  AccentId.violet: (Color(0xFFB794F6), Color(0xFF7C3AED), _white),
};

const _accentLight = <AccentId, (Color, Color, Color)>{
  AccentId.red: (Color(0xFFC8102E), Color(0xFFC8102E), _white),
  AccentId.blue: (Color(0xFF0B5C99), Color(0xFF0B5C99), _white),
  AccentId.green: (Color(0xFF0B6B4F), Color(0xFF0B6B4F), _white),
  AccentId.violet: (Color(0xFF6D28D9), Color(0xFF6D28D9), _white),
};

// EVA 對應：警戒紅、琥珀、訊號綠、初號機紫。
const _evaAccentDark = <AccentId, (Color, Color, Color)>{
  AccentId.red: (Color(0xFFFF2A1A), Color(0xFFFF2A1A), Color(0xFF0A0000)),
  AccentId.blue: (Color(0xFFF5B800), Color(0xFFF5B800), Color(0xFF0B1226)),
  AccentId.green: (Color(0xFF2BFF88), Color(0xFF2BFF88), Color(0xFF02140A)),
  AccentId.violet: (Color(0xFF9D6BFF), Color(0xFF9D6BFF), Color(0xFF0E0718)),
  AccentId.berserk: (Color(0xFF9D6BFF), Color(0xFF9D6BFF), Color(0xFF0E0718)),
};

const _evaAccentLight = <AccentId, (Color, Color, Color)>{
  AccentId.red: (Color(0xFFB3261E), Color(0xFFB3261E), _white),
  AccentId.blue: (Color(0xFF8A5A00), Color(0xFF8A5A00), _white),
  AccentId.green: (Color(0xFF2F6B3A), Color(0xFF2F6B3A), _white),
  AccentId.violet: (Color(0xFF5B2DB0), Color(0xFF5B2DB0), _white),
  AccentId.berserk: (Color(0xFF5B2DB0), Color(0xFF5B2DB0), _white),
};

// 稀有度：select、deluxe、premium、exclusive、ultra（規格 §3.3）。
const _tierDark = [
  Color(0xFF94A3B8),
  Color(0xFF06B6D4),
  Color(0xFFE879F9),
  Color(0xFFA78BFA),
  Color(0xFFEAB308),
];
const _tierLight = [
  Color(0xFF475569),
  Color(0xFF0B6577),
  Color(0xFFA21CAF),
  Color(0xFF6D28D9),
  Color(0xFF765800),
];

const _partyDark = [
  Color(0xFF60A5FA),
  Color(0xFFF472B6),
  Color(0xFFFBBF24),
  Color(0xFF34D399),
  Color(0xFFA78BFA),
];
const _partyLight = [
  Color(0xFF1D4ED8),
  Color(0xFFBE185D),
  Color(0xFF9A4A07),
  Color(0xFF03664A),
  Color(0xFF6D28D9),
];

/// 暴走主色的輔助綠（初號機的綠色紋路），只用在裝飾。
const _berserkDecor = [Color(0xFF7CFF4F)];

const _dreamyDecor = [Color(0xFFF7A1C4), Color(0xFFB9A7F5), Color(0xFF8FC9F7)];
