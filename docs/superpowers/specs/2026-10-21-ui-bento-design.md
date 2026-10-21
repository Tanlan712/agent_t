# UI 改版 B：儀表板 Bento 風（設計規格）

> **已被 `2026-10-21-ui-themes-design.md` 取代**（可切換主題；Bento 風格已移除）。本文件保留作為歷史紀錄。

- 日期：2026-10-21
- 狀態：使用者已同意設計方向（從 A／B／C 預覽中選 B），待審閱本規格
- 前一版：`2026-10-21-ui-redesign-design.md`（戰術 HUD），本規格取代其中的視覺語言與排版，元件與資料流不變

## 0. 目的與成功條件

使用者認為改版後仍「不夠現代、排版要再調整」。具體問題（1440 寬實測）：

1. 側欄 13 項擠在一起、字小、沒有分組。
2. 內容沒有層次：標題是普通文字、內容貼左、右側大片空白、空狀態只有一行字。
3. 我的商店未登入時只有幾條區塊標題，看起來像沒做完。
4. 整體仍是 Material 預設感；8px 斜切太細，看不出來。

成功條件：

- 1440 寬時內容填滿到最大寬度 1280，主要頁面用 Bento 卡片格呈現。
- 側欄分組、選中狀態清楚。
- 每頁都有大標題頁首；空狀態有圖示、標題、說明、動作。
- 375／768／1024／1440 都沒有 overflow；`flutter analyze` 無新 warning、`flutter test` 全過、`flutter build web` 成功。

## 1. 不變的限制

- 只改外觀與排版：**不新增任何 API 呼叫**，不改 provider、service、logic 的行為。
- AGENTS.md 全部適用：即時對局、小號推測、隱私提示（「請勿公開或分享他人資訊」）、他人資料顯示範圍都維持現狀。
- 顏色只能來自 `AppColors`；`lib/` 不用 `dart:io`；不用 emoji 當圖示（Material Icons）。
- 手機（< 600）維持底部導覽加「更多」。
- 字體維持：標題 Chakra Petch（google_fonts），內文系統字體。

## 2. 視覺語言

| 項目 | 值 |
|---|---|
| 卡片 | 圓角 12、1px `outline` 邊框、`surface` 底色；可點擊時 hover 邊框變 `muted`、底色 `surfaceHigh` |
| 強調條 | 可選左側 3px 色條（勝負、警示），此時該卡左側圓角為 0 |
| 斜切 | 全部移除（`NotchClipper`、`notched` 參數、CardTheme 的 BeveledRectangleBorder） |
| CardTheme | `RoundedRectangleBorder(12)`＋outline 邊框 |
| 間距 | 卡片間距 16；頁面區塊間距 24；卡片內距 16 |
| 頁首標題 | 28px、w600（Chakra Petch）；副標 14px `muted` |
| KPI | 標籤 12px `muted`；數值 24px w700、等寬數字 |
| 空狀態 | 卡片內：48px 圓形 `surfaceHigh` 底＋圖示、16px 標題、14px muted 說明、一個按鈕 |
| 減少動態 | hover 動畫在 `MediaQuery.disableAnimations` 時為 0ms |

## 3. 外殼（AppShell）

- **≥ 1024（extended）**：自製側欄（不再用 `NavigationRail`），寬 248、`surface` 底、右側 1px 分隔。
  - 頂部：品牌名稱（`primary`、18px）。
  - 依 `NavGroup` 分三組，組標題文字：「主要」「資料庫」「其他」，11px `muted`、上方間距 16。
  - 項目：高 40、圓角 8、圖示 20＋文字 14；選中時底色 `surfaceHigh`、左側 3px `primary` 條、文字 `text`；未選中文字 `muted`；hover 底色 `surfaceHigh`（半透明）。
  - 底部：Riot 狀態卡（沿用 `_RiotStatus` 的行為）。
  - 側欄內容超過視窗高度時可捲動。
- **600–1023（rail）**：寬 72，只有圖示，每個圖示有 `Tooltip(label)`；選中樣式同上；組之間用 1px 分隔線。
- **< 600（bottom）**：不變。
- **頁首**（非手機）：`PageHeader(title, subtitle?, actions)`，上距 24、下距 16；標題 28px；actions 靠右。手機沿用 AppBar。
- 內容最大寬度 1280，置中；左右內距沿用 `horizontalPadding`。
- 跨斷點維持同一棵樹（保留捲動位置）的既有行為與測試。
- `ExpiryBanner` 保留在頁首下方。

## 4. 共用元件（沿用 `lib/widgets/hud/` 目錄，不搬移、不刪除檔案）

- `PanelCard`：取代 `HudCard`。參數 `child`、`padding`（預設 16）、`onTap`、`accent`；可點擊時用 `InkWell`（可鍵盤聚焦、有 semantics button）。
- `BentoGrid` / `BentoTile`：
  - 欄數：寬度 ≥ 1024 → 12 欄；600–1023 → 6 欄；< 600 → 1 欄。這裡的寬度是 **BentoGrid 自己的可用寬度**。
  - `BentoTile(span: n)`，n 以 12 欄為準；6 欄時用 `ceil(n / 2)`；1 欄時一律佔滿。span 超過欄數時截成欄數。
  - 由左到右依序排，放不下就換列；列內頂端對齊；間距 16。
- `KpiTile`：改成 `PanelCard` 樣式；`KpiStrip` 保留（每個 tile 至少 160px 的規則不變）。
- `StatusChip`：文字包 `Flexible`，窄寬度不 overflow。
- `SectionHeader`：移除紅色豎條，改成 18px 標題＋右側動作。
- `EmptyState`：依第 2 節樣式，參數加上 `title`（原 `message` 變說明）。
- `PageHeader`：見第 3 節。

## 5. 各頁排版（以 1440 寬描述；6 欄／1 欄依第 4 節規則自動換列）

### 我的商店
| 列 | 內容 |
|---|---|
| 1 | 未登入：「登入 Riot 自動同步」大卡（span 12，含說明與按鈕「登入 Riot」、次要動作「手動輸入」）。已登入：帳號列（span 12，現有 `_RiotBar` 內容） |
| 2 | 每日商店（span 8，造型 2×2；未輸入時空狀態＋「編輯」）｜右欄（span 4）：直向堆疊 KPI：商店刷新、VP、輻能點數、王國幣、已擁有造型（沒有錢包時只有商店刷新） |
| 3 | 夜市（span 8）｜願望清單上架（span 4：上架數與名稱列表；沒有時顯示「今天沒有願望清單造型」） |
| 4 | 組合包（span 12） |

頁首副標：每日商店刷新倒數（沒有資料時不顯示）。

### 對戰紀錄
| 列 | 內容 |
|---|---|
| 1 | 牌位卡（span 4，現有 `_RankHeader`）｜近 N 場 RR（span 3，勝負色＋箭頭）｜勝率（span 2）｜平均 ACS（span 3） |
| 2 | 對戰列表（span 12）：每場一列，細邊框、左側 3px 勝負色條，欄位：地圖、模式、特務、比分、K/D/A、ACS、RR；點擊進詳情（行為不變） |

未登入：空狀態卡（標題「登入 Riot 以查看對戰紀錄」＋按鈕）。

### 對戰詳情、玩家頁、遇過的玩家
- 頁首＋`PanelCard` 包住既有內容；玩家頁 KPI 只有平均 ACS（AGENTS.md §7）。
- 遇過的玩家：搜尋列＋等寬卡片網格（每卡至少 280px）。

### 即時對局
- 第 1 列：地圖、模式、狀態三張 KPI（各 span 4）。
- 第 2 列：我方、敵方兩張隊伍卡（各 span 6；6 欄以下上下排），左側勝負色條。
- 選角、隊伍畫面同樣用 PanelCard 與 Bento；所有既有提示、tooltip、key 保留。

### 願望清單、資料庫各頁（角色、武器、地圖、組合包、遊戲模式、玩家卡片）
- 頁首（標題＋項目數副標）、篩選列（有的頁面）、等大圓角卡片網格（沿用 `ResponsiveGrid`，卡片改 PanelCard 樣式）。

### 設定、Riot 登入
- 單欄最寬 760、置中；區塊用 `PanelCard`＋`SectionHeader`。

## 6. 測試

- `BentoGrid`：12／6／1 欄的 tile 寬度與換列（例：span 8＋4 在 1200 寬同列；在 800 寬變 4＋2 同列；在 400 寬各自一列）。
- 外殼：三種寬度的導覽型態、分組標題、選中項目、tooltip（rail）、跨斷點保留狀態（既有測試改用新 finder）。
- `PanelCard`：可點擊時可以用鍵盤聚焦並觸發；減少動態時無動畫。
- 我的商店：未登入顯示登入大卡；已登入顯示右欄 KPI；願望清單上架卡。
- 既有測試只更新 finder 與排版相關斷言，行為斷言不刪除；更新的理由記在 ledger。
- responsive sweep：12 個路由 × 4 種寬度不 overflow（保留）。

## 7. 不做的事

- 不改資料、API、輪詢、快取與任何 AGENTS.md 相關行為。
- 不新增頁面或功能（造型庫、特務庫仍暫停）。
- 不做淺色模式。
