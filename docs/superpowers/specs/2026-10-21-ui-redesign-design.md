# 整站改版：戰術 HUD（方向 A） 設計規格

- 日期：2026-10-21
- 狀態：待使用者審閱
- 設計依據：`design-system/valorant-tracker/MASTER.md`（UI UX Pro Max，Data-Dense Dashboard，依 VALORANT 品牌改寫）
- 分支：`feature/ui-redesign`（從 master 開出；造型庫與特務庫暫停在 `feature/collection`）

## 1. 目標與範圍

- **只改外觀與互動，不改功能，也不新增任何 API 呼叫**（AGENTS.md 全部規則照舊）。
- 範圍：主題、殼層（導覽）、共用元件，以及所有頁面：我的商店、願望清單、對戰紀錄與詳情、即時對局（隊伍／選角／對局）、遇過的玩家、玩家頁、資料庫各頁、設定、Riot 登入。
- 使用者已同意：安裝 `google_fonts` 套件（Chakra Petch＋Noto Sans TC）。
- 不做：亮色主題、3D 或視差效果、新功能。

## 2. 主題（`lib/theme/app_theme.dart`）

- `AppColors` 補齊第 1 節的語意色：新增 `info`，加上 `win`、`loss`、`warn` 別名。舊名稱保留，避免一次改動太多檔案。
- `buildAppTheme()`：
  - 字體：`GoogleFonts.notoSansTcTextTheme()` 作為基底；`displayX`／`headlineX`／`titleLarge` 改用 Chakra Petch。
  - 新增 `AppText.kpi`、`AppText.tabular`（等寬數字），供數字欄位使用。
  - 元件主題：Card（邊框、圓角 4）、FilledButton（buttonRed）、OutlinedButton、Chip、DataTable（表頭色、列高）、Tooltip、焦點顏色（info）。
- 字體載入失敗（離線）時退回系統字體，畫面不可以壞掉。

## 3. 共用元件（`lib/widgets/hud/`）

| 元件 | 說明 |
|---|---|
| `HudCard` | 卡片；可選右上角 8px 切角（`CustomClipper`） |
| `KpiStrip`／`KpiTile` | 頁首 KPI 摘要列：標籤、大數字、變化（箭頭圖示＋勝負色） |
| `StatusChip` | 邊框＋文字同色、15% 底色、不換行 |
| `SectionHeader` | 區塊標題（Chakra Petch）＋右側動作 |
| `EmptyState` | 圖示＋說明＋一個動作按鈕 |
| `SkeletonBox` | 載入骨架 |
| `FadeInList` | 依序淡入（40ms 間隔、8px 位移）；`MediaQuery.disableAnimations` 時不播放 |

## 4. 殼層（`lib/shell/`）

- 寬度 ≥ 1024：側邊導覽列，分組標題，目前頁面左側顯示 3px 品牌紅指示條。
- 600～1023：窄導覽列（只有圖示加 tooltip）。
- < 600：**底部導覽**，固定 5 項：我的商店、對戰紀錄、即時對局、願望清單、更多；「更多」打開其餘頁面的清單。這一點取代現在的漢堡選單。
- 頂部列：頁面標題用 Chakra Petch；右側顯示 Riot 登入狀態。

## 5. 各頁

| 頁面 | 改版重點 |
|---|---|
| 我的商店 | KPI（VP、輻能點數、王國幣、每日商店倒數）；造型卡片加切角與稀有度底光；夜市折扣用 StatusChip |
| 願望清單 | 在售的造型置頂，加 warn 色標籤；空狀態用 EmptyState |
| 對戰紀錄 | KPI（牌位＋RR、近 5 場 RR、勝率、平均 ACS，全部來自已讀取的資料）；列表改成緊湊列（勝敗色條、地圖、特務、比分、K/D/A、RR） |
| 對戰詳情 | 計分板表頭固定、斑馬紋、數字等寬靠右；MVP 用 StatusChip |
| 即時對局 | 對局時寬螢幕雙方左右對照，窄螢幕上下排列；狀態列改成 KPI 樣式；疑似小號、表現突變用 StatusChip（warn） |
| 遇過的玩家／玩家頁 | 搜尋框加上 EmptyState；玩家頁 KPI（平均 ACS、勝率） |
| 資料庫各頁 | 統一卡片網格與篩選列 |
| 設定、Riot 登入 | 表單元件套用新主題；風險提示用 warn 樣式的提示框 |

所有 KPI 數字都只用現有 provider 已經讀到的資料計算，不新增請求。

## 6. 驗收

- 既有測試全部通過。只有文字或結構改變時，才可以調整測試的查找方式，且必須說明原因；行為斷言不可以刪除。
- 新增測試：
  - 主題：語意色、等寬數字。
  - KpiStrip、StatusChip、FadeInList：減少動態效果時不播放動畫。
  - 殼層三種寬度：底部導覽 5 項，「更多」可以打開其餘頁面。
  - `no_hardcoded_colors_test` 繼續通過。
- 375、768、1024、1440 四種寬度的 widget 測試都不可以 overflow。
- `flutter analyze` 沒有新的 warning，`flutter build web` 成功。
- 實測：使用者登入後逐頁確認，我截圖回報。

## 7. 分段實作（每段結束都要測試、建置並 commit）

1. 主題、字體、共用元件
2. 殼層（三種導覽）
3. 我的商店、願望清單
4. 對戰紀錄、詳情、玩家頁、遇過的玩家
5. 即時對局
6. 資料庫各頁、設定、登入，加上整體檢查（MASTER.md 第 8 節的檢查清單）
