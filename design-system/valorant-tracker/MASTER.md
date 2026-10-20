# 設計系統主檔：VALORANT Tracker

> **邏輯：** 製作某一頁時，先看 `design-system/valorant-tracker/pages/<頁面>.md`；
> 有這個檔案就以它為準，沒有就完全依照本檔。

- 來源：UI UX Pro Max（Data-Dense Dashboard 風格，Variance 6／Motion 3／Density 8），
  依 VALORANT 品牌改寫配色與字體（使用者 2026-10-21 選定方向 A「戰術 HUD」）。
- 技術：Flutter Web。所有顏色只能來自 `AppColors`／`ThemeData`（`test/theme/no_hardcoded_colors_test.dart` 會檢查）。
- 對比度都已實際計算（WCAG 公式）。

## 1. 配色

### 表面（由深到淺）

| Token | Hex | 用途 |
|---|---|---|
| `background` | `#0F1923` | 頁面底色 |
| `surface` | `#1A2530` | 卡片、表格 |
| `surfaceHigh` | `#243240` | 浮起的卡片、hover 列、自己那一列 |
| `outline` | `#2F3D4B` | 分隔線、卡片邊框 |

### 文字與品牌

| Token | Hex | 在 background／surface／surfaceHigh 的對比 | 規則 |
|---|---|---|---|
| `text` | `#ECE8E1` | 14.5／12.7／10.7 | 主要文字 |
| `muted` | `#9AA6B2` | 7.2／6.3／5.3 | 次要文字、標籤 |
| `primary` | `#FF4655` | 5.3／4.6／**3.9** | 品牌紅：圖示、指示條、粗體大字；**surfaceHigh 上不可用於 14px 以下文字** |
| `buttonRed` | `#D7263D` | 白字 4.96 | 主要按鈕的底色（白字） |

### 語意色

| Token | Hex | 對 surface 對比 | 用途 |
|---|---|---|---|
| `win`（現 `owned`） | `#4ADE80` | 8.9 | 勝利、已擁有、已鎖定 |
| `loss`（現 `error`） | `#FF6B6B` | 5.6 | 落敗、錯誤 |
| `warn`（現 `wishlistGold`） | `#FFC107` | 9.5 | 警示、MVP、疑似小號、願望清單 |
| `info`（新增） | `#38BDF8` | 7.3 | 資訊、連結、進行中 |

- 勝負、狀態**不能只靠顏色**：一律搭配文字或圖示（勝／敗、✓、⚠ 用 Material Icons，不用 emoji）。
- 稀有度色沿用 `Tier.color`。

## 2. 字體（google_fonts 套件，使用者已同意安裝）

| 用途 | 字體 | 字級／字重 |
|---|---|---|
| 頁面標題、區塊標題、KPI 數字 | **Chakra Petch** | 標題 20–28／600；KPI 24–32／700 |
| 內文、表格、按鈕 | **系統字體**（使用者 2026-10-21 決定：Noto Sans TC 約 14MB，不下載） | 內文 14–16／400；表格 13–14；最小 12（只限標籤） |
| 數字（ACS、K/D、比分、價格） | 加上 `FontFeature.tabularFigures()` | 讓欄位對齊 |

- 行高：內文 1.5、表格 1.3。
- Chakra Petch 沒有中文字形，中文會自動退回系統中文字體。

## 3. 間距與形狀

| Token | 值 | 用途 |
|---|---|---|
| `space-xs` | 2 | 緊密間隔 |
| `space-sm` | 4 | 圖示與文字 |
| `space-md` | 8 | 元件內距、格線間距 |
| `space-lg` | 12 | 卡片內距 |
| `space-xl` | 16 | 區塊間距 |
| `space-2xl` | 24 | 頁面內距（桌機） |

- 圓角：卡片 4、按鈕 4、標籤 2。**切角**：重點卡片（KPI、商店造型）右上角 8px 斜切，呼應 VALORANT 的 UI。
- 陰影：只用在浮起的元素（選單、對話框），卡片用邊框區分層次。
- 格線：12 欄；寬度 ≥1024 時側邊導覽，600–1023 窄導覽，<600 底部導覽（最多 5 項）加「更多」。

## 4. 元件

- **KPI 摘要列**：每頁頂端 2–5 張卡；標籤（muted 12）＋大數字（Chakra Petch）＋變化（win／loss 加箭頭圖示）。
- **資料表**：表頭固定、斑馬紋（surface／surfaceHigh 交替）、hover 整列高亮、數字靠右、可排序欄位有排序圖示。
- **狀態標籤（Chip）**：邊框＋文字同色、底色 15% 透明度；文字不換行。
- **按鈕**：主要（buttonRed 底、白字）、次要（outline 邊框）、文字按鈕；可點區域至少 44×44。
- **空狀態／錯誤**：圖示＋一句說明＋一個動作（例如「重試」「登入 Riot」）。
- **載入**：骨架（skeleton）優先，避免版面跳動；長列表依序淡入。

## 5. 動態（Motion 3／10）

- hover／按下：150–200ms，`Curves.easeOut`；不改變尺寸，避免版面位移。
- 列表與卡片進場：淡入＋位移 8px，每項間隔 40ms，總長不超過 400ms。
- 頁面切換：維持現有無轉場（頂層頁面）。
- 尊重「減少動態效果」：`MediaQuery.disableAnimations` 為 true 時直接顯示最終狀態。

## 6. 無障礙

- 對比至少 4.5:1（大字 3:1），依第 1 節的數字。
- 鍵盤：可以 Tab 到所有互動元件，焦點框使用 `info` 2px。
- 只有圖示的按鈕一律有 tooltip 與 semantics label。
- 不只靠顏色傳達狀態。
- 寬度 375／768／1024／1440 都不可以出現水平捲動（寬表格只在表格內捲動）。

## 7. 禁止

- ❌ 用 emoji 當圖示（統一用 Material Icons）
- ❌ 元件裡寫死色碼
- ❌ 會造成版面位移的 hover（放大、改變邊框寬度）
- ❌ 沒有過渡的狀態變化、看不見的焦點
- ❌ 3D、視差、大量裝飾（Data-Dense 風格的反模式：Ornate design）
- ❌ 違反 AGENTS.md 的任何功能（改版只改外觀，不新增 API 呼叫）

## 8. 交付前檢查

- [ ] 沒有 emoji 圖示，圖示來源一致
- [ ] 所有可點元素有 hover／按下回饋（150–300ms）與滑鼠游標
- [ ] 文字對比 ≥ 4.5:1
- [ ] 鍵盤焦點看得見
- [ ] 尊重減少動態效果
- [ ] 375／768／1024／1440 沒有水平捲動
- [ ] `flutter analyze` 無新 warning、`flutter test` 全過、`flutter build web` 成功
