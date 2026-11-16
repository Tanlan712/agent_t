import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/theme/web_bold.dart';

void main() {
  const bold = TextStyle(
      fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF111111));

  test('網頁上粗體改成 500 字重加 8 個同色陰影', () {
    final s = webSafeBold(bold, web: true);
    expect(s.fontWeight, FontWeight.w500);
    expect(s.shadows, hasLength(8));
    expect(s.shadows!.every((x) => x.color == bold.color), isTrue);
    expect(s.shadows!.every((x) => x.blurRadius == 0), isTrue);
    expect(s.shadows!.first.offset.dx, closeTo(40 * 0.022, 1e-9));
  });

  test('App、細字、沒有字色時不變', () {
    expect(webSafeBold(bold, web: false), same(bold));
    const thin = TextStyle(fontWeight: FontWeight.w500, color: Colors.black);
    expect(webSafeBold(thin, web: true), same(thin));
    const noColor = TextStyle(fontWeight: FontWeight.w700);
    expect(webSafeBold(noColor, web: true), same(noColor));
  });
}
