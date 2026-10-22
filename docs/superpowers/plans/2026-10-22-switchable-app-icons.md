# 計畫：可更換的 App 圖示

規格：`docs/superpowers/specs/2026-10-22-switchable-app-icons-design.md`

1. SVG 原始檔分成 `tool/app_icon/<key>/`，`generate.mjs` 改成產生 6 款（Android、iOS 替代圖示、預覽）。
2. 先寫測試：`app_icon_service_test`、`app_icons_test`、`app_icon_picker_test`。
3. `AppIconService`＋`AppIconPicker`，設定頁在 Android／iOS 顯示。
4. Android：manifest 的 activity-alias、MainActivity 的 channel。
5. iOS：建置設定 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`、AppDelegate 的 channel。
6. `flutter analyze` 沒有新 warning、`flutter test` 全過、`flutter build web` 成功；APK／IPA 看 CI。
