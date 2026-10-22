# App 圖示

每個資料夾是一款圖示，名稱就是 key（和 `lib/services/app_icon_service.dart` 的 `AppIconId.key` 相同）：
`default`（預設、網頁版也用它）、`editorial`、`airy`、`terminal`、`eva_alert`、`eva_monitor`。
規格見 `docs/superpowers/specs/2026-10-22-switchable-app-icons-design.md`。

每款有 `background.svg`、`foreground.svg`，使用 Android 自適應圖示的 108×108 格線：

- 啟動器只顯示中間 72×72，前景內容要放在中心半徑 33 的安全區內。
- Android 13 主題圖示用前景的透明度當剪影；前景有挖空效果（例如 `eva_alert` 的黑 V）時另外放 `monochrome.svg`。
- PWA 的 `any` 圖示是圓角方形，`maskable` 是整張；iOS 與 `apple-touch-icon` 不透明（系統自己加圓角）。

改完 SVG 後重新產生全部 PNG（Android、iOS、網頁、設定頁預覽）：

```sh
npm i -g playwright
node tool/app_icon/generate.mjs
```

已有 Chromium 時可設 `CHROMIUM_PATH`，playwright 不在全域時可設 `PLAYWRIGHT_PATH`。

新增一款時：加資料夾、把 key 加進 `generate.mjs`、`AppIconId`、`MainActivity.kt`、`AppDelegate.swift`、
`AndroidManifest.xml` 的 activity-alias 與 `project.pbxproj` 的 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`；
`test/build/app_icons_test.dart` 會檢查這些地方一致。
