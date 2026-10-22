# Handoff：商店與特務頁介面調整（WIP）

分支：`claude/project-thread-y9r4z1`（從 master 6acf82f 開出）。**尚未合併、不要直接推 master**，測試還沒修完。

## 使用者要求（2026-10-22）
1. 移除「我的收藏 › 特務」分頁的合約按鈕
2. 點擊我的收藏裡的特務可以查看特務等級（新功能 → 依規則要另開 PR）
3. 我的商店：移除每日商店下方的「商店刷新」KPI 卡（每日商店標題已有剩餘時間）
4. 我的商店底部「已擁有造型」卡移到我的收藏
5. 暫時關閉願望清單（隱藏入口，保留程式與已存資料，之後可恢復）

規則：純版面調整（1、3、4、5）跑 analyze + test + web build 後直接推 master，不開 PR；新功能（2）開 PR 等使用者同意。

## 已完成（本分支，未驗證完）
- `lib/shell/nav_items.dart`：新增 `const wishlistEnabled = false;`，`navItems` 用 `if (wishlistEnabled)` 隱藏願望清單；`bottomNavRoutes` 第 4 格在關閉時改成 `/collection`。`/wishlist` 路由、WishlistProvider、儲存資料都保留。
- `lib/screens/my_shop_page.dart`：`_ShopKpi` 只剩 VP／輻能點數／王國幣（未登入時整個不顯示）；移除「商店刷新」與「已擁有造型」tile 與 `_clock`；願望清單關閉時不顯示 `_WishlistHits`、不標金框；右欄空時每日商店／夜市改成全寬 span 12。
- `lib/widgets/my_shop_settings_card.dart`：關閉時隱藏「標示願望清單」開關。
- `lib/widgets/theme/eva/eva_data_eggs.dart`：E14（今日商店全在願望清單）在關閉時不觸發。
- `lib/screens/collection_page.dart`：移除特務合約按鈕（`_contract`、`contractIds`、`activeContract` 參數；`RemoteClient.activateContract` 本身保留）；造型分頁最上方加 `KpiTile('已擁有造型', skinCount)`（key `collection-owned-skins`）。
- `flutter analyze` 已無新增 warning（只剩原本的 info）。

## 待辦
1. **修測試**（Flutter 3.24.5，`flutter test` 目前 -30 左右失敗）。失敗清單：
   - `test/screens/my_shop_page_test.dart`：KPI 相關（商店刷新／已擁有造型／右欄版面）、願望清單上架與金框測試
   - `test/screens/settings_page_test.dart`：標示願望清單開關
   - `test/widgets/theme/eva/eva_data_eggs_test.dart`：E14
   - `test/widgets/theme/eva/eva_layer_test.dart`、`eva_story_test.dart`、`test/widgets/style_variants_test.dart`：導覽編號／話數因願望清單從 navItems 移除而位移
   - `test/shell/*`（routing、app_shell 底部導覽有「願望清單」、nav_order）、`test/remote/remote_ui_test.dart`（`activate-a-paid` 合約按鈕測試應刪除）
   - `test/screens/shop_details_test.dart`「目錄裡找不到這款造型時說明」— 先在 master 上確認是否本來就會失敗
   - 做法建議：願望清單功能測試加 `skip: !wishlistEnabled`（關閉中的功能，恢復時自動再跑），並新增「關閉時看不到入口／卡片」的測試；KPI 與合約測試改成新行為；新增我的收藏「已擁有造型」測試。
2. 測試全綠 + `flutter build web` 後，把 1、3、4、5 推到 master（先 `git pull` master，其他執行緒也在改）。
3. **功能 2（特務等級）另開分支＋PR**：特務卡片已顯示「等級 X / Y」與進度條；點擊時開一頁顯示該特務合約的章節與每階獎勵。資料已有（`ProgressProvider.contracts` + `ref.contracts` 中 `relationType == 'Agent'` 的合約，不需新 API）。可把 `progress_page.dart` 的 `_PassCard`／`_ChapterSection`／`_RewardTile` 改成公開元件重用，並在 `progress_logic.dart` 仿 `currentBattlePass` 寫 `agentContract(snapshot, ref, agentUuid)` 回傳 `BattlePass`（未開始時 reached = 0）。
