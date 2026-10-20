import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/layout.dart';
import 'package:valorant_shop_tracker/shell/responsive_grid.dart';

void main() {
  test('navModeFor 斷點', () {
    expect(navModeFor(599), NavMode.drawer);
    expect(navModeFor(600), NavMode.rail);
    expect(navModeFor(1199), NavMode.rail);
    expect(navModeFor(1200), NavMode.extended);
  });

  test('columnsFor', () {
    expect(columnsFor(1136, 240), 4);
    expect(columnsFor(756, 240), 3);
    expect(columnsFor(358, 240), 1);
    expect(columnsFor(100, 240), 1);
    expect(columnsFor(1136, 140), 7);
  });

  test('horizontalPadding', () {
    expect(horizontalPadding(599), 16);
    expect(horizontalPadding(600), 32);
  });
}
