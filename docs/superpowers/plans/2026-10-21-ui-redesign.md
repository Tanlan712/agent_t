# 整站改版：戰術 HUD 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal：** 依 `design-system/valorant-tracker/MASTER.md` 把整站改成「戰術 HUD」風格（Data-Dense Dashboard＋VALORANT 品牌），只改外觀與互動，功能與 API 呼叫完全不變。

**Architecture：**
- 先把主題 tokens、字體和一組共用 HUD 元件（`lib/widgets/hud/`）做好。
- 再改殼層，改成三種導覽：側邊欄、窄導覽列、底部導覽。
- 最後逐頁套用。
- 每頁的 KPI 只用 provider 已經有的資料計算。

**Tech Stack：** Flutter 3.24.5／Dart 3.5.4、provider、**google_fonts**（使用者已同意安裝）

**Spec：** `docs/superpowers/specs/2026-10-21-ui-redesign-design.md`，以及 `design-system/valorant-tracker/MASTER.md`

## Global Constraints

- 分支 `feature/ui-redesign`，不推送；合併前要先問使用者。
- **不新增、不修改任何 API 呼叫**（AGENTS.md 全部規則照舊）。如果 diff 出現 `services/` 或 `providers/` 的請求邏輯變動，就是錯誤。
- 顏色只能來自 `AppColors`／`ThemeData`（`no_hardcoded_colors_test` 會檢查）；圖示只用 Material Icons，不用 emoji。
- 對比度依 MASTER.md 第 1 節：`primary` 不可以用在 surfaceHigh 上 14px 以下的文字。
- 動態：hover／按下 150–200ms；進場淡入每項間隔 40ms、位移 8px，總長不超過 400ms；`MediaQuery.disableAnimations` 為 true 時不播放動畫。
- 既有測試的**行為斷言不可以刪除**。只有文字或結構因改版而改變時，才可以改查找方式，並在 ledger 記錄 Ruling。
- 每個 Task 結束時，`flutter analyze` 不可以有新的 warning，`flutter test` 全部通過，`flutter build web` 成功，然後 commit。
- 斷點：寬度 ≥ 1024 用展開側邊欄，600–1023 用窄導覽列，< 600 用底部導覽（5 項，其中一項是「更多」）。

## Review Focus

1. **字體下載失敗（離線、被擋）** → 畫面退回系統字體，不丟例外，文字照常顯示。（U1）
2. **中文字** → Chakra Petch 沒有中文字形，中文標題要自動退回 Noto Sans TC，不可以出現方框（豆腐字）。（U1）
3. **375 寬** → 所有頂層頁面都沒有 RenderFlex overflow，也沒有水平捲動；寬表格只在表格內捲動。（U7 全頁掃描）
4. **減少動態效果** → FadeInList、hover 動畫都直接顯示最終狀態。（U2）
5. **跨斷點切換**（1400 → 800 → 400） → 頁面狀態與捲動位置保留，到期提醒列（ExpiryBanner）在三種模式下都還在。（U3）

---

### Task U1：主題 tokens、字體、文字樣式

**Files：**
- Modify：`pubspec.yaml`（`flutter pub add google_fonts`）、`lib/theme/app_theme.dart`、`lib/main.dart`
- Test：`test/theme/app_theme_test.dart`、`test/flutter_test_config.dart`（新增）

**Interfaces：**
- Produces：
  - `AppColors`：新增 `info = #38BDF8`，以及別名 `win`（等於 owned）、`loss`（等於 error）、`warn`（等於 wishlistGold）。舊名稱保留。
  - `ThemeData buildAppTheme({bool useGoogleFonts = true})`
    - `useGoogleFonts` 為 false 時用系統字體，給測試和離線退回使用。
    - 為 true 時，`textTheme` 以 `GoogleFonts.notoSansTcTextTheme()` 為基底；`display*`、`headline*`、`titleLarge` 改用 `GoogleFonts.chakraPetch`，並設定 `fontFamilyFallback: ['Noto Sans TC']`。
    - 元件主題：Card 加邊框、圓角 4；FilledButton、OutlinedButton、Chip、DataTable（`headingRowHeight` 36、`dataRowMinHeight` 36）、Tooltip、`focusColor = info`。
  - `abstract final class AppText`：
    - `kpi(BuildContext)`：Chakra Petch，28／700，等寬數字。
    - `tabular(TextStyle?)`：加上 `FontFeature.tabularFigures()`。
    - `label`：muted、12、字距 0.4。
- `test/flutter_test_config.dart`：設定 `GoogleFonts.config.allowRuntimeFetching = false`，讓測試不連網。harness 與所有測試都用 `buildAppTheme(useGoogleFonts: false)`（修改 `test/app_harness.dart`）。

- [ ] **Step 1：寫失敗的測試**（`app_theme_test.dart`）
  - `AppColors.info == Color(0xFF38BDF8)`。
  - `win`、`loss`、`warn` 分別等於 owned、error、wishlistGold。
  - info、win、loss、warn 對 surface 的對比都 ≥ 4.5。
  - `AppText.tabular(null).fontFeatures` 包含 tabularFigures。
  - `buildAppTheme(useGoogleFonts: false).textTheme.titleLarge!.fontFamily` 不是 Chakra Petch。
  - `buildAppTheme(useGoogleFonts: false).focusColor == AppColors.info`。
- [ ] **Step 2：執行** `flutter test test/theme`
  預期 FAIL（info／AppText 不存在）。
- [ ] **Step 3：安裝套件並實作**
  - 執行 `flutter pub add google_fonts`，鎖定實際安裝的版本。
  - `main.dart` 用 `buildAppTheme()`；載入字體失敗時，`GoogleFonts` 會自己退回系統字體，不需要另外處理。
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: HUD theme tokens, Chakra Petch/Noto Sans TC, AppText`。

---

### Task U2：共用 HUD 元件

**Files：**
- Create：`lib/widgets/hud/hud_card.dart`、`kpi_strip.dart`、`status_chip.dart`、`section_header.dart`、`empty_state.dart`、`skeleton_box.dart`、`fade_in_list.dart`，以及 `hud.dart`（統一匯出）
- Test：`test/widgets/hud_test.dart`

**Interfaces：**
- `HudCard({required Widget child, bool notched = false, EdgeInsets padding = const EdgeInsets.all(12), VoidCallback? onTap, Color? accent})`
  - `notched` 時用 `CustomClipper`，在右上角切出 8px 斜角。
  - `accent` 是左側 3px 色條。
  - `onTap` 時加上 hover 底色（surfaceHigh，150ms）和滑鼠游標。
- `KpiTile({required String label, required String value, String? delta, bool? up, Widget? leading})`；`KpiStrip({required List<KpiTile> tiles})`
  - 用 Wrap 排列：寬度 ≥ 600 時同一列，窄螢幕每列 2 個。
  - `delta` 的顏色：up 為 true 時用 win 加 `Icons.arrow_upward`，false 時用 loss 加 `Icons.arrow_downward`，null 時用 muted。
- `StatusChip({required String label, required Color color, IconData? icon, String? tooltip})`
  - 邊框與文字使用 color，底色是 color 的 15% 透明度，`softWrap: false`。
- `SectionHeader({required String title, Widget? trailing})`：titleLarge。
- `EmptyState({required IconData icon, required String message, String? actionLabel, VoidCallback? onAction})`
- `SkeletonBox({double? width, double height = 16})`：surfaceHigh 底色、圓角 4。
- `FadeInList({required List<Widget> children})`
  - 每個子元件淡入並位移 8px，間隔 40ms。
  - `MediaQuery.disableAnimationsOf(context)` 為 true 時直接顯示。

- [ ] **Step 1：寫失敗的測試**
  - KpiTile：up 為 true 時顯示 `Icons.arrow_upward`，delta 文字顏色是 win；up 為 null 時沒有箭頭。
  - KpiStrip：在 375 寬放 4 個 tile 不會 overflow，而且排成 2 列（第 3 個 tile 的 dy 大於第 1 個）。
  - StatusChip：label 不換行（`softWrap == false`），有 tooltip 時找得到 Tooltip。
  - HudCard：`notched: true` 時有 `ClipPath`；有 onTap 時點擊會觸發。
  - EmptyState：按下動作按鈕會呼叫 onAction。
  - FadeInList：
    - 一般情況下，第一個 frame 第一個子元件的 opacity < 1，pumpAndSettle 後變成 1。
    - 用 `MediaQuery(data: MediaQueryData(disableAnimations: true))` 包住時，第一個 frame 的 opacity 就是 1。
- [ ] **Step 2：執行** `flutter test test/widgets/hud_test.dart`
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: HUD shared widgets`。

---

### Task U3：殼層，改成三種導覽

**Files：**
- Modify：`lib/shell/layout.dart`、`lib/shell/app_shell.dart`、`lib/shell/nav_items.dart`
- Test：`test/shell/app_shell_test.dart`、`layout_test.dart`、`routing_test.dart`、`short_window_test.dart`

**Interfaces：**
- `enum NavMode { bottom, rail, extended }`（取代 `drawer`）
- `navModeFor(width)`：< 600 為 bottom，< 1024 為 rail，其餘為 extended。
- `const bottomNavRoutes = ['/', '/matches', '/live', '/wishlist']`；第 5 項是「更多」，點了會打開 `showModalBottomSheet`，列出其餘的 `navItems`（依分組）。
- 側邊欄：目前頁面左側 3px primary 指示條（`Container`）；寬螢幕標題用 `AppText`／`headlineSmall`（Chakra Petch）。
- `ExpiryBanner` 三種模式都在，位置在標題列下面、內容上面。

- [ ] **Step 1：修改並新增測試**（記錄 Ruling：漢堡選單換成底部導覽，是規格第 4 節的要求）
  - `app_shell_test`：
    - 400 寬：有 `NavigationBar`，有 5 個 destination（標籤為我的商店、對戰紀錄、即時對局、願望清單、更多），沒有 `Icons.menu`，也沒有 NavigationRail。
    - 900 寬：有 NavigationRail，而且沒有展開。
    - 1100 寬：有展開的 NavigationRail，看得到完整名稱。
    - 1400 縮到 800 再縮到 400：不丟例外，`內容` 的捲動位置保留（沿用既有測試的寫法，改成三段寬度）。
    - 400 寬：點「更多」會出現「角色」「設定」，點「角色」會換頁。
    - 400 寬與 1400 寬：快到期時都找得到 `expiry-banner`（用 `Harness.create(now:)`）。
  - `layout_test`：斷點 599 為 bottom、600 為 rail、1023 為 rail、1024 為 extended。
  - `routing_test` 的「手機寬度：抽屜點角色」改成「手機寬度：更多 → 角色」。
- [ ] **Step 2：執行** `flutter test test/shell`
  預期 FAIL。
- [ ] **Step 3：實作**
  保留現有「三種模式共用同一個樹結構」的作法，讓捲動位置能保留：底部導覽放在 `Scaffold.bottomNavigationBar`，主體結構不變。
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: HUD shell with bottom nav, rail and sidebar`。

---

### Task U4：我的商店、願望清單

**Files：**
- Modify：`lib/screens/my_shop_page.dart`、`lib/screens/wishlist_page.dart`、`lib/widgets/skin_card.dart`、`lib/widgets/skin_tile.dart`
- Test：`test/screens/my_shop_page_test.dart`、`test/screens/wishlist_page_test.dart`

**Interfaces：**
- 我的商店：
  - 頂端 `KpiStrip`（key `shop-kpi`）。已登入時顯示 VP、輻能點數、王國幣；每日商店的倒數一直顯示。資料來自 `RiotProvider.wallet` 與現有的倒數計算。
  - 造型卡片改用 `HudCard(notched: true, accent: tier.color)`。
  - 夜市折扣用 `StatusChip`（warn）。
- 願望清單：
  - 在售的造型排在最前面，卡片上加 `StatusChip('在售', warn)`。
  - 清單是空的時候顯示 `EmptyState(Icons.star_border, ...)`，動作按鈕是「加入造型」。

- [ ] **Step 1：寫失敗的測試**
  - 登入後 `shop-kpi` 內有 `1500`（VP，fixture 的值）和倒數文字；未登入時 KPI 只有倒數。
  - 願望清單在售的項目排第一，而且有「在售」chip。
  - 空清單時找得到 EmptyState 的訊息與按鈕。
  - 既有測試全部保留。
- [ ] **Step 2：執行**相關測試
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: HUD my shop and wishlist`。

---

### Task U5：對戰紀錄、詳情、玩家頁、遇過的玩家

**Files：**
- Modify：`lib/screens/match_history_page.dart`、`match_detail_page.dart`、`player_page.dart`、`seen_players_page.dart`
- Test：`test/screens/match_pages_test.dart`、`player_page_test.dart`、`seen_players_page_test.dart`

**Interfaces：**
- `match_history_page`：
  - 頂端 `KpiStrip`（key `history-kpi`），四個值：
    - 牌位＋RR：`rank`。
    - 近 5 場 RR 合計：`recentRr` 加總，正數前面加 +。
    - 勝率：已載入場次中 `won == true` 的比例，取整數百分比。
    - 平均 ACS：已載入場次 `summary.acs` 的平均。
  - 列表改成緊湊列，可以沿用 `MatchCard` 再改樣式：左側勝敗色條，依序是地圖、特務、比分、K/D/A、RR。
- `match_detail_page`：
  - DataTable 表頭固定（用 `SliverPersistentHeader` 或把表頭與內容分開放的 `Column`），奇數列底色用 surfaceHigh。
  - 數字欄套用 `AppText.tabular`，靠右對齊。
  - MVP 改用 `StatusChip`。
- `player_page`：頂端 KPI，顯示平均 ACS（已有）和勝率。
- `seen_players_page`：沒有符合的搜尋結果時改用 `EmptyState`。
- **既有的 key 不可以改**（`match-card-*`、`player-row-me`、`acs-*`、`mvp-*`、`form-*`、`rank-*`、`level-*` 等）。

- [ ] **Step 1：寫失敗的測試**
  - `history-kpi` 顯示正確的勝率與平均 ACS：fixture 的 3 場都是同一份資料，所以勝率 100%、平均 ACS 191。
  - 近 5 場 RR 合計：fixture 是 +18 和 −15，結果是 `+3`。
  - 詳情頁 ACS 欄的 Text 帶有 tabularFigures。
  - MVP 是 StatusChip。
  - 玩家頁 KPI 有勝率。
  - 遇過的玩家搜尋不到時出現 EmptyState。
- [ ] **Step 2：執行**相關測試
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: HUD match history, detail, player and seen players`。

---

### Task U6：即時對局

**Files：**
- Modify：`lib/screens/live_page.dart`
- Test：`test/screens/live_page_test.dart`

**Interfaces：**
- 對局畫面：
  - 寬度 ≥ 1024 時，我方和敵方左右並排（兩個 Expanded）；較窄時上下排列。
  - 頂端狀態改成 `KpiStrip`：地圖、模式、狀態。
- 「疑似小號」「表現突變」標籤改用 `StatusChip(color: warn, icon: Icons.warning_amber, tooltip: 原因)`，key 維持 `sus-*`。
- 選角與隊伍畫面也套用 HudCard、KpiStrip 和 EmptyState，例如「遊戲沒有開啟，或目前不在大廳」。
- 既有的 key 全部保留。

- [ ] **Step 1：寫失敗的測試**
  - 1400 寬時，`team-Blue`（我方）和敵方的 dy 相同、dx 不同；800 寬時敵方的 dy 比較大。
  - `sus-*` 是 StatusChip，tooltip 包含「推測」。
  - 404 時出現 EmptyState。
- [ ] **Step 2：執行**相關測試
  預期 FAIL。
- [ ] **Step 3：實作**
  我方和敵方的容器加上 key：`live-team-<id>`。
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: HUD live party, pregame and match views`。

---

### Task U7：資料庫各頁、設定、登入，以及整體檢查

**Files：**
- Modify：`lib/screens/agents_page.dart`、`weapons_page.dart`、`maps_page.dart`、`bundles_page.dart`、`gamemodes_page.dart`、`playercards_page.dart`、`settings_page.dart`、`riot_login_page.dart`
- Test：`test/screens/responsive_sweep_test.dart`（新增）

**Interfaces：**
- 資料庫各頁：統一用 `SectionHeader`、`HudCard` 網格；有篩選的頁面，篩選列固定在上方。
- 設定頁：區塊用 `HudCard`。
- Riot 登入頁：風險提示改成 warn 邊框的 `HudCard`，加上 `Icons.warning_amber`，取代現在的 ⚠️ emoji；步驟用編號區塊排列。
- `responsive_sweep_test`：對 12 個頂層路由，各以 375、768、1024、1440 寬度 pump，`tester.takeException()` 必須是 null（不能有 overflow）。

- [ ] **Step 1：寫測試**
  - responsive sweep：先跑一次，記錄改版前已經 overflow 的頁面，這次要修好。
  - 登入頁不再含有 emoji：找不到 `⚠️`，找得到 `Icons.warning_amber`。
- [ ] **Step 2：執行**
  預期登入頁的測試 FAIL；responsive sweep 依實際結果記錄。
- [ ] **Step 3：實作**
  逐頁套用元件，修正 overflow。
- [ ] **Step 4：MASTER.md 第 8 節的交付前檢查**
  逐項確認並記錄在 ledger：
  - 用 grep 檢查 lib/ 裡沒有 emoji 圖示。
  - 可點元素都有回饋。
  - 對比度、焦點、減少動態效果都符合規定。
  - 四種寬度都沒有 overflow。
- [ ] **Step 5：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 6：Commit**
  commit 訊息為 `feat: HUD database pages, settings, login; responsive sweep`。
- [ ] **Step 7：實測與審查**
  - 重啟 8642，請使用者登入後逐頁截圖確認。
  - 請一位全新的審查者，用最強的模型審查整個分支，重點是 Review Focus 和「沒有新增 API 呼叫」。
  - 依實際影響分級後修正，每個修正都要先寫出會失敗的測試。
  - 回報後，詢問是否合併到 master。
