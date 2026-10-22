# 計畫：全物品實際定價、目前裝備、排隊懲罰

規格：[2026-10-22-offers-loadout-penalties-design.md](../specs/2026-10-22-offers-loadout-penalties-design.md)

1. 模型與解析（先寫測試）：`OfferPrices`、`PlayerLoadout`、`PenaltyStatus`，格式不符時略過。
2. `RiotClient.fetchLoadout（v3）／fetchPenalties`（offers 實測 404，已移除）：全部走 `getPd`（GET、全域限流）。
3. Provider：
   - `OfferPriceProvider`：localStorage 快取 `offer_prices_v1`；（實測後）由 `RiotProvider.onStorefront` 在每次同步商店時記錄看到的價格。
   - `RiotResource<T>` 共用的「登入期間快取、換帳號清空、授權失敗登出」，衍生 `LoadoutProvider`、`PenaltyProvider`。
4. 畫面：
   - 手動編輯商店的預設價格、選造型頁、願望清單（價格與未擁有總計）。
   - 收藏頁「目前裝備」分頁（`equippedWeapons` 依武器分類；`RefChroma.iconUrl` 用炫彩全圖）。
   - 通行證頁最上方 `PenaltyCard`。
5. AGENTS.md 第 3 節加三列，`docs/api-fields.md` 記錄欄位（📄 未實測）。
6. `flutter analyze` 無新 warning、`flutter test`、`flutter build web`。
