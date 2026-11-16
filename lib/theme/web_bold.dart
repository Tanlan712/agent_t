import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 網頁版（CanvasKit）的中文回退字型只有一般字重，粗體是 Skia 把細字「描粗」出來的；
/// 筆畫重疊的字（紀、開、店…）描粗後會破洞或多出色塊。
/// 網頁上把 600 以上的字重改成 500，再用 8 個方向、同色、不模糊的陰影補回粗細，
/// 看起來一樣粗但不會破圖。App 用系統字型有真正的粗體，維持原樣。
/// 沒有字色（交給 DefaultTextStyle）或用 foreground 畫字時無法配色，也維持原樣。
TextStyle webSafeBold(TextStyle style, {bool? web}) {
  final weight = style.fontWeight;
  final color = style.color;
  if (!(web ?? kIsWeb) ||
      weight == null ||
      weight.value < 600 ||
      color == null ||
      style.foreground != null) {
    return style;
  }
  final size = style.fontSize ?? 14;
  // 字重越重、陰影位移越大；係數依 40px 標題目測對齊原本的粗細。
  final k = switch (weight.value) {
    600 => 0.01,
    700 => 0.014,
    800 => 0.018,
    _ => 0.022,
  };
  final d = size * k;
  return style.copyWith(
    fontWeight: FontWeight.w500,
    shadows: [
      ...?style.shadows,
      for (final (dx, dy) in const [
        (1.0, 0.0),
        (-1.0, 0.0),
        (0.0, 1.0),
        (0.0, -1.0),
        (0.7071, 0.7071),
        (-0.7071, 0.7071),
        (0.7071, -0.7071),
        (-0.7071, -0.7071),
      ])
        Shadow(color: color, offset: Offset(dx * d, dy * d)),
    ],
  );
}
