import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/account_progress.dart';

import '../account_fixtures.dart';

void main() {
  test('AccountXp 解析等級與經驗', () {
    final xp = AccountXp.fromJson(accountXpJson(level: 12, xp: 3400));
    expect(xp.level, 12);
    expect(xp.xp, 3400);
  });

  test('AccountXp 缺欄位時為 0', () {
    final xp = AccountXp.fromJson(const {});
    expect(xp.level, 0);
    expect(xp.xp, 0);
  });

  test('ContractsSnapshot 解析合約、任務與每週刷新', () {
    final s = ContractsSnapshot.fromJson(contractsJson());
    expect(s.contracts, hasLength(2));
    final bp = s.contracts.first;
    expect(bp.definitionId, 'bp-now');
    expect(bp.levelReached, 2);
    expect(bp.towardsNext, 500);
    expect(bp.totalEarned, 4500);
    expect(s.missions, hasLength(2));
    expect(s.missions.first.id, 'm-daily');
    expect(s.missions.first.progress, 2);
    expect(s.missions.first.complete, isFalse);
    expect(s.missions.first.expiresAt, DateTime.utc(2026, 10, 22));
    // 多個 objective 的進度相加。
    expect(s.missions.last.progress, 15);
    expect(s.missions.last.complete, isTrue);
    expect(s.weeklyRefill, DateTime.utc(2026, 10, 26, 21, 15));
  });

  test('ContractsSnapshot 缺欄位時為空', () {
    final s = ContractsSnapshot.fromJson(const {});
    expect(s.contracts, isEmpty);
    expect(s.missions, isEmpty);
    expect(s.weeklyRefill, isNull);
  });
}
