# 網頁 UI 優化 設計規格

- 日期：2026-10-20
- 狀態：待使用者審閱
- 前置規格：`2026-10-19-manual-shop-wishlist-design.md`（第 3 版）。功能不變，本規格只改介面。

## 1. 目標與範圍

### 使用者明確提出
- 讓介面更符合網頁使用習慣。優化重點三項：**側邊導覽列**、**響應式多欄版面**、**VALORANT 風格深色主題**。
- 範圍包含所有頁面，也包括 6 個資料瀏覽頁（角色、武器、地圖、組合包、遊戲模式、玩家卡片）。原本「不可修改這 6 頁」的限制，這次由使用者解除。
- 導覽殼層採用做法 A：沿用現有的命名路由，加一個共用殼層 `AppShell`。不改用 go_router。
- 首頁 `/` 直接顯示「我的商店」，拿掉原本的大卡片首頁。

### 不做（YAGNI）
- 滑鼠 hover 效果、鍵盤快捷鍵、瀏覽器分頁標題同步（使用者沒有選）。
- 修正「直接重新整理子頁網址會回到首頁」的問題（屬於做法 B 的範圍，之後再處理）。
- 新增字型套件、改變任何功能或資料流程。

## 2. 導覽殼層

### 2.1 斷點
| 寬度 | 導覽型態 |
|---|---|
| `< 600` | 頂部 AppBar 加漢堡選單，點開是 `Drawer` |
| `600 – 1199` | 左側 `NavigationRail`，圖示下面加短標籤 |
| `≥ 1200` | 左側展開式導覽列（寬約 240），圖示加完整名稱 |

斷點判斷用 `LayoutBuilder` 依可用寬度決定，寫成純函式 `NavMode navModeFor(double width)`，方便測試。

### 2.2 導覽項目（`lib/shell/nav_items.dart`）
| 分組 | 項目 | 路由 |
|---|---|---|
| 商店 | 我的商店 | `/`（`/my-shop` 也指向同一頁） |
| 商店 | 願望清單 | `/wishlist` |
| 資料庫 | 角色、武器、地圖、組合包、遊戲模式、玩家卡片 | `/agents` `/weapons` `/maps` `/bundles` `/gamemodes` `/playercards` |
| 底部 | 設定 | `/settings` |

- 最上方顯示 App 名稱「VALORANT 商店追蹤」。
- 導覽列底部顯示 Riot 登入狀態：已登入時顯示 `displayName`，未登入時顯示「登入 Riot」，點擊後 push `/riot-login`。
- 目前所在的項目要反白。

### 2.3 頁面行為
- **頂層頁面**（2.2 表格裡的路由）：都包在 `AppShell` 裡。從導覽切換時用 `pushReplacementNamed`，路由不播轉場動畫，所以沒有返回鍵。
- **子頁面**（`/my-shop/edit`、`/skin-picker`、`/riot-login`）：維持一般 push，保留自己的 AppBar 和返回鍵，不包在 `AppShell` 裡。
- 內容區最大寬度 1280，水平置中。左右內距在 `≥ 600` 時為 32，`< 600` 時為 16。
- 頁面標題和頁面動作（例如願望清單的「＋」）放在內容區頂端，由 `AppShell(title:, actions:)` 統一呈現。
- `MaterialApp.debugShowCheckedModeBanner = false`。

### 2.4 介面
```
AppShell({required String currentRoute, required String title, List<Widget> actions = const [], required Widget child})
enum NavMode { drawer, rail, extended }
NavMode navModeFor(double width)
```

### 2.5 `main.dart` 的異動
- 頂層路由改由 `onGenerateRoute` 產生沒有轉場動畫的 `PageRouteBuilder`；`/` 對應 `MyShopPage`。
- 刪除 `HomePage`（`lib/screens/home_page.dart`）。
- **注意**：另一個 session 可能同時在改 `main.dart`（「當前對局查看」功能）。實作前先用 `git status`／`git log` 確認，有衝突就先問使用者。

## 3. 響應式版面

### 3.1 共用工具（`lib/shell/responsive_grid.dart`）
- `int columnsFor(double width, double minTileWidth)`：`max(1, floor((width + spacing) / (minTileWidth + spacing)))`，`spacing = 16`。
- `ResponsiveGrid({required double minTileWidth, required double childAspectRatio, required List<Widget> children})`：用 `columnsFor` 排版，可以放在可捲動的頁面裡（shrinkWrap，不自己捲動）。

### 3.2 `SkinCard`（`lib/widgets/skin_card.dart`）
直式造型卡片：大圖在上，下面依序是名稱、武器、稀有度、價格（有原價時加刪除線）。參數和 `SkinTile` 相同：`skin`、`price`、`originalPrice`、`highlighted`、`owned`、`onTap`、`trailing`。顯示文字也相同：「★ 願望清單」、「已擁有」、「未知造型」。`SkinTile` 保留給編輯頁使用。

### 3.3 各頁面
| 頁面 | 版面 | `minTileWidth` | 約略欄數（1440／900／390） |
|---|---|---|---|
| 我的商店：每日、夜市 | `SkinCard` 網格 | 240 | 4／3／1 |
| 我的商店：精選組合包 | 橫幅大圖，價格疊在圖上 | — | — |
| 我的商店：帳號列 | 頁首一列：帳號、錢包、已擁有數量、同步按鈕；窄螢幕自動換行 | — | — |
| 願望清單 | `SkinCard` 網格；左滑刪除保留，卡片右上另加刪除鈕 | 200 | 5／3／1 |
| 造型搜尋器 | 寬度 `≥ 600` 時搜尋框和武器篩選並排；結果用網格 | 200 | 5／3／1 |
| 商店編輯 | 表單最大寬度 760；`≥ 700` 時格子排兩欄 | — | 2／2／1 |
| Riot 登入、設定 | 單欄，最大寬度 760，置中 | — | 1 |
| 角色 | 網格，比例 0.75 | 140 | 7／4／2 |
| 玩家卡片 | 網格 | 200 | 5／3／1 |
| 地圖 | 網格，橫式 | 260 | 4／2／1 |
| 組合包 | 網格，橫式大圖 | 340 | 3／2／1 |
| 武器 | 網格，橫式武器圖加名稱 | 200 | 5／3／1 |
| 遊戲模式 | 網格卡片 | 260 | 4／2／1 |

欄數是依可用寬度估算的：導覽列加左右內距之後，1440 寬約 1136、900 寬約 756、390 寬約 358。

瀏覽頁的資料來源、載入和錯誤處理都不變。

## 4. 深色主題（`lib/theme/app_theme.dart`）

### 4.1 色彩 tokens
| token | 值 | 用途 |
|---|---|---|
| `background` | `#0F1923` | 頁面背景 |
| `surface` | `#1A2530` | 卡片、導覽列底色 |
| `surfaceHigh` | `#243240` | 輸入框、選中的導覽項目 |
| `outline` | `#2F3D4B` | 邊框 |
| `primary` | `#FF4655` | 按鈕、選中導覽、重點色 |
| `onPrimary` | `#FFFFFF` | 主色上的文字 |
| `text` | `#ECE8E1` | 主要文字 |
| `muted` | `#9AA6B2` | 次要文字 |
| `error` | `#FF6B6B` | 錯誤 |
| `wishlistGold` | `#FFC107` | 願望清單金框（不變） |
| `owned` | `#4ADE80` | 已擁有 |

### 4.2 規則
- `ThemeData(useMaterial3: true, brightness: dark)`，`ColorScheme` 用上表的值明確指定。
- 卡片和按鈕用 4 px 圓角；卡片加 1 px `outline` 邊框。
- 稀有度 5 色沿用。每個顏色當作文字放在 `surface` 上時，對比度要 ≥ 4.5:1，不足就調亮並記錄在實作計畫。
- 各頁面寫死的顏色一律改用主題色，例如設定頁的 `Colors.indigo`、首頁卡片顏色、`Colors.green`。

## 5. 測試與驗證
- **單元測試**：
  - `navModeFor`：599／600／1199／1200 的邊界。
  - `columnsFor`：剛好整除、比最小卡片寬還窄（回傳 1）、很寬。
- **Widget 測試**（用 `tester.view.physicalSize` 設定寬度，`devicePixelRatio = 1`）：
  - 400 寬：有漢堡圖示，沒有 `NavigationRail`。
  - 900 寬：有 `NavigationRail`，沒有展開的名稱。
  - 1400 寬：導覽項目的完整名稱可見。
  - 點擊「願望清單」導覽：換頁、項目反白、沒有返回鍵。
  - 子頁面（造型搜尋器）有返回鍵。
- **現有測試**：同步更新後必須全部通過。例如首頁測試改成驗證「`/` 顯示我的商店」、搜尋器測試改找 `SkinCard`。
- `flutter analyze` 不能有新的 warning；`flutter build web` 要成功。
- **實際檢查**：在內建瀏覽器用 1440、900、390 三種寬度截圖確認，深色主題下的文字要清楚可讀。

## 6. 風險
- 改動範圍涵蓋所有頁面，現有 widget test 依賴的頁面結構（AppBar、文字）會變動，測試要一起改。
- 和「當前對局查看」功能可能同時修改 `main.dart` 與導覽項目，需要協調。
