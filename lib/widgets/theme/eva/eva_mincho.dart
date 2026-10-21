import 'package:flutter/material.dart';

import '../../../theme/app_fonts.dart';
import '../../../theme/app_palette.dart';

/// EVA 明朝體（規格 §4.6）：Noto Serif TC Black、只在 x 方向壓縮；
/// 空間不夠時整體縮小，不會溢出。只用在標題、導覽與標籤，不用在內文。
class EvaMincho extends StatelessWidget {
  final String text;
  final double size;
  final double squeeze;
  final Color? color;

  const EvaMincho(this.text,
      {super.key, required this.size, this.squeeze = 0.8, this.color});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: Matrix4.diagonal3Values(squeeze, 1, 1),
        child: Text(text,
            maxLines: 1,
            softWrap: false,
            style: AppFonts.mincho(TextStyle(
                fontSize: size,
                height: 1.05,
                color: color ?? context.palette.text))),
      ),
    );
  }
}

/// L 形大小混排的標題卡：左上「第 N 話」、一個大詞（72）＋一個小詞（26），基線對齊。
class EvaTitleCard extends StatelessWidget {
  final String episode;
  final String big;
  final String small;
  final Color? color;

  const EvaTitleCard(
      {super.key,
      required this.episode,
      required this.big,
      required this.small,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EvaMincho(episode, size: 18, squeeze: 0.9, color: c),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              EvaMincho(big, size: 72, squeeze: 0.72, color: c),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EvaMincho(small, size: 26, color: c),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
