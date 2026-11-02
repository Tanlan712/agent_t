import 'package:agent_t/widgets/skin_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const levels = [
    SkinLevelOption(image: 'lv1.png'),
    SkinLevelOption(videoUrl: 'lv2.mp4', owned: false),
  ];
  const chromas = [
    SkinChromaOption(name: '原色', image: 'base.png', swatch: 'b.png'),
    SkinChromaOption(
        name: '紅色', image: 'red.png', swatch: 'r.png', videoUrl: 'red.mp4'),
    SkinChromaOption(name: '藍色', swatch: 'bl.png'),
  ];

  group('skinImageFor', () {
    test('炫彩有圖用炫彩圖', () {
      expect(skinImageFor(levels, chromas, 0, 1), 'red.png');
    });
    test('基本款用等級圖；等級沒圖退回基本款圖', () {
      expect(skinImageFor(levels, chromas, 0, 0), 'lv1.png');
      expect(skinImageFor(levels, chromas, 1, 0), 'base.png');
    });
    test('炫彩沒圖退回等級圖', () {
      expect(skinImageFor(levels, chromas, 0, 2), 'lv1.png');
    });
    test('什麼都沒有用 fallback', () {
      expect(
          skinImageFor(const [], const [], 0, 0, fallback: 'f.png'), 'f.png');
    });
  });

  group('skinVideoFor', () {
    test('炫彩影片優先，否則用等級影片', () {
      expect(skinVideoFor(levels, chromas, 0, 1), 'red.mp4');
      expect(skinVideoFor(levels, chromas, 1, 2), 'lv2.mp4');
      expect(skinVideoFor(levels, chromas, 0, 0), isNull);
      expect(skinVideoFor(levels, chromas, 5, 0), isNull);
    });
  });

  testWidgets('SkinViewer：切換等級後影片按鈕跟著換', (tester) async {
    final played = <Uri>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkinViewer(
          id: 's',
          title: '造型',
          levels: levels,
          chromas: chromas,
          playVideo: (_, u, __) async => played.add(u),
        ),
      ),
    ));
    expect(find.text('這個組合沒有預覽影片'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewer-level-s-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('viewer-video-s')));
    expect(played, [Uri.parse('lv2.mp4')]);
  });

  testWidgets('預設在站內對話框播放；播放器無法載入時顯示重試', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showSkinVideo(context, Uri.parse('https://x.test/a.mp4'), '標題'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skin-video-dialog')), findsOneWidget);
    expect(find.text('標題'), findsOneWidget);
    // 測試環境沒有播放器外掛：初始化失敗，顯示重試而不是另開分頁。
    expect(find.text('影片載入失敗'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skin-video-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skin-video-dialog')), findsNothing);
  });
}
