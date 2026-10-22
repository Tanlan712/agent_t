# App 圖示

`background.svg`、`foreground.svg` 是所有平台圖示的唯一來源，使用 Android 自適應圖示的 108×108 格線：

- 啟動器只顯示中間 72×72，前景內容要放在中心半徑 33 的安全區內。
- Android 8 以上用 `mipmap-anydpi-v26/ic_launcher.xml` 的前景／背景／單色（Android 13 主題圖示）三層，較舊版本用 `ic_launcher.png`。
- PWA 的 `any` 圖示是圓角方形，`maskable` 是整張；iOS 與 `apple-touch-icon` 不透明（系統自己加圓角）。

改完 SVG 後重新產生全部 PNG：

```sh
npm i -g playwright
node tool/app_icon/generate.mjs
```

已有 Chromium 時可設 `CHROMIUM_PATH`，playwright 不在全域時可設 `PLAYWRIGHT_PATH`。
