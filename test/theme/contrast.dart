import 'dart:math';

import 'package:flutter/material.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.red / 255) +
    0.7152 * _channel(c.green / 255) +
    0.0722 * _channel(c.blue / 255);

/// WCAG 2.1 對比度。
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}
