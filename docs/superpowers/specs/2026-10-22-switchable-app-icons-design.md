# 可更換的 App 圖示（2026-10-22）

## 1. 目的

使用者要求（2026-10-22）：把主題風格 A、C、D、F1、F2 的圖示做成手機 App 可以更換的桌面圖示。
預設圖示維持「雙刃 V」，另外加 5 款主題圖示，共 6 款。

| key | 名稱 | 來源 |
|---|---|---|
| `default` | 預設 | 雙刃 V＋VP 寶石，深酒紅背景 |
| `editorial` | A 編輯海報 | 米白底、黑色粗 V、特務紅斜切色帶 |
| `airy` | C 優雅留白 | 白底、黑色襯線 V、紅色短線 |
| `terminal` | D 終端機 | 深藍柔光、`>` 提示字元、紅色方塊游標、四角對位標記 |
| `eva_alert` | F1 警戒 | 六角格黑底、警戒紅六角徽章、黑 V |
| `eva_monitor` | F2 監控 | 斜菱格、琥珀色括號框、準星與刻度 |

不使用 NERV 標誌或任何官方圖形（沿用 MASTER.md 第 5 節的 EVA 規則）。

## 2. 圖檔

- 原始檔：`tool/app_icon/<key>/background.svg`、`foreground.svg`（108×108 自適應格線，前景在半徑 33 的安全區內）；
  前景有挖空時另加 `monochrome.svg`（F1）。
- `tool/app_icon/generate.mjs` 產生：
  - Android：每款 `ic_launcher[_<key>]` 的舊式 PNG、自適應 XML 與背景／前景／單色三層（Android 13 主題圖示）。
  - iOS：主圖示 `AppIcon` 各尺寸；替代圖示 `AppIcon-<key>` 為單一 1024 圖示集，
    列在 Runner 三組建置設定的 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`（Xcode 會自動寫進 Info.plist）。
  - 網頁：PWA 與 favicon 只用 `default`。
  - 設定頁預覽：`assets/app_icons/<key>.png`。

## 3. 切換方式

- Dart：`AppIconService`（`lib/services/app_icon_service.dart`）透過 `valorant_shop_tracker/app_icon` channel 呼叫
  `getIcon`（回傳 key）與 `setIcon(key)`；未知值退回 `default`。
- Android：`AndroidManifest.xml` 每款一個 `activity-alias`（`.Icon_<key>`，指向 MainActivity），只有 `default` 預設啟用；
  MainActivity 本身不再是桌面入口。切換時先啟用新的 alias，再停用其他的（`DONT_KILL_APP`）。
  桌面啟動器可能要幾秒才更新，部分啟動器會把已放在桌面上的捷徑移除，要從 App 清單重新拖出來。
- iOS：`UIApplication.setAlternateIconName`；系統會跳出「已更改圖示」提示，這是 iOS 的固定行為。
- 選擇存在系統裡（Android 的元件狀態、iOS 的 alternateIconName），不另外存進 `AppSettings`。

## 4. 設定頁

- 「外觀」下方新增「App 圖示」卡片，只在 Android／iOS App 顯示（`AppIconService.supported`）。
- 6 張預覽，目前的有主色框與勾選；點目前的不做事；失敗時顯示「無法更換圖示」並保留原選擇。
- 不跟著主題自動切換：Android 每次切換都可能讓桌面捷徑消失、iOS 每次都會跳提示，所以只在使用者點選時切換。

## 5. 網頁版限制

瀏覽器安裝的 PWA 圖示由 `manifest.json` 決定，頁面無法更換；已安裝的 PWA 只在 manifest 更新後由瀏覽器自行刷新。
網頁版不顯示「App 圖示」卡片。

## 6. 測試

- `test/services/app_icon_service_test.dart`：key 清單、channel 呼叫、未知值退回預設、支援平台。
- `test/build/app_icons_test.dart`：manifest alias 與 Dart key 一致且只啟用預設、各密度圖檔與自適應 XML、
  iOS 圖示集與建置設定、Kotlin／Swift 的 key 清單、預覽圖。
- `test/widgets/app_icon_picker_test.dart`：列出全部並標出目前的、點選切換、點目前的不做事、失敗訊息。
- APK／IPA 由 CI 建置確認。
