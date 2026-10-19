import '../models/tier.dart';

/// 一般武器在每日商店的常見定價（推估值，使用者可修改）。
int defaultPrice(Tier tier) {
  switch (tier) {
    case Tier.select:
      return 875;
    case Tier.deluxe:
      return 1275;
    case Tier.premium:
      return 1775;
    case Tier.exclusive:
      return 2175;
    case Tier.ultra:
      return 2475;
  }
}
