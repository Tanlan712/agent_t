// 從每個圖示資料夾的 background.svg / foreground.svg（Android 自適應圖示的 108×108 格線）
// 產生 Android、iOS、PWA 與設定頁預覽的全部圖示。
//
//   npm i -g playwright && node tool/app_icon/generate.mjs
//
// 前景內容須在中心半徑 33 的安全區內；啟動器只顯示中間 72×72，其餘給遮罩與視差動畫用。
// 資料夾名稱就是圖示的 key（和 lib/services/app_icon_service.dart 的 AppIconId.key 相同）；
// default 是預設圖示，網頁版（PWA、favicon）只用它。
import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH ?? 'playwright');

const keys = ['default', 'editorial', 'airy', 'terminal', 'eva_alert', 'eva_monitor'];

const inner = (key, file) => readFileSync(join(here, key, file), 'utf8')
  .replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');

// view：顯示範圍；radius：圓角半徑（以 108 格線計）；mono：轉成白色剪影。
const svg = ({ layers, view = [0, 0, 108, 108], radius = 0, mono = false }) => {
  const [x, y, w, h] = view;
  const clip = radius ? `<clipPath id="clip"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}"/></clipPath>` : '';
  const filter = mono ? '<filter id="mono"><feFlood flood-color="#fff"/><feComposite in2="SourceAlpha" operator="in"/></filter>' : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${view.join(' ')}" width="100%" height="100%">`
    + `<defs>${clip}${filter}</defs><g${radius ? ' clip-path="url(#clip)"' : ''}${mono ? ' filter="url(#mono)"' : ''}>${layers.join('')}</g></svg>`;
};

const visible = [18, 18, 72, 72];
const res = 'android/app/src/main/res';
const xcassets = 'ios/Runner/Assets.xcassets';
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

const jobs = [];
for (const key of keys) {
  const bg = inner(key, 'background.svg');
  const fg = inner(key, 'foreground.svg');
  // 單色層只看透明度；前景有挖空效果時另外提供 monochrome.svg。
  const mono = existsSync(join(here, key, 'monochrome.svg')) ? inner(key, 'monochrome.svg') : fg;
  const full = (o = {}) => svg({ layers: [bg, fg], view: visible, ...o });
  const name = key === 'default' ? 'ic_launcher' : `ic_launcher_${key}`;

  for (const [d, k] of Object.entries(densities)) {
    // Android 8 以下的舊式圖示（48dp，圓角方形）。
    jobs.push([`${res}/mipmap-${d}/${name}.png`, 48 * k, full({ radius: 12 })]);
    // 自適應圖示的三層（108dp）。
    jobs.push([`${res}/mipmap-${d}/${name}_background.png`, 108 * k, svg({ layers: [bg] })]);
    jobs.push([`${res}/mipmap-${d}/${name}_foreground.png`, 108 * k, svg({ layers: [fg] })]);
    jobs.push([`${res}/mipmap-${d}/${name}_monochrome.png`, 108 * k, svg({ layers: [mono], mono: true })]);
  }
  writeAdaptiveXml(name);
  // 設定頁的預覽（圓角方形）。
  jobs.push([`assets/app_icons/${key}.png`, 144, full({ radius: 16 })]);

  if (key === 'default') {
    // iOS 主圖示沿用 Flutter 範本的各尺寸；系統自己加圓角，且不可有透明。
    const set = `${xcassets}/AppIcon.appiconset`;
    const images = JSON.parse(readFileSync(join(root, set, 'Contents.json'), 'utf8')).images;
    for (const { filename, size, scale } of images) {
      jobs.push([`${set}/${filename}`, Math.round(parseFloat(size) * parseInt(scale)), full()]);
    }
    // PWA：any 用圓角方形；maskable 用整張（瀏覽器自己裁切，安全區 80% 圓）。
    jobs.push(['web/favicon.png', 32, full({ radius: 14 })]);
    jobs.push(['web/icons/Icon-192.png', 192, full({ radius: 14 })]);
    jobs.push(['web/icons/Icon-512.png', 512, full({ radius: 14 })]);
    jobs.push(['web/icons/Icon-maskable-192.png', 192, svg({ layers: [bg, fg], view: [9, 9, 90, 90] })]);
    jobs.push(['web/icons/Icon-maskable-512.png', 512, svg({ layers: [bg, fg], view: [9, 9, 90, 90] })]);
    jobs.push(['web/icons/apple-touch-icon.png', 180, full()]);
  } else {
    // iOS 替代圖示：單一 1024 尺寸的圖示集（Xcode 14 起由系統縮放）。
    const set = `${xcassets}/AppIcon-${key}.appiconset`;
    rmSync(join(root, set), { recursive: true, force: true });
    mkdirSync(join(root, set), { recursive: true });
    writeFileSync(join(root, set, 'Contents.json'), JSON.stringify({
      images: [{ filename: 'icon.png', idiom: 'universal', platform: 'ios', size: '1024x1024' }],
      info: { author: 'xcode', version: 1 },
    }, null, 2) + '\n');
    jobs.push([`${set}/icon.png`, 1024, full()]);
  }
}

function writeAdaptiveXml(name) {
  const dir = join(root, res, 'mipmap-anydpi-v26');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `${name}.xml`), `<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tool/app_icon/generate.mjs 產生，請改 SVG 後重新產生。 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/${name}_background"/>
    <foreground android:drawable="@mipmap/${name}_foreground"/>
    <monochrome android:drawable="@mipmap/${name}_monochrome"/>
</adaptive-icon>
`);
}

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH });
const page = await browser.newPage();
for (const [out, px, markup] of jobs) {
  await page.setViewportSize({ width: px, height: px });
  await page.setContent(`<body style="margin:0">${markup}</body>`);
  const opaque = out.startsWith('ios/') || out.endsWith('apple-touch-icon.png');
  const png = await page.screenshot({ omitBackground: !opaque });
  mkdirSync(join(root, dirname(out)), { recursive: true });
  writeFileSync(join(root, out), png);
}
await browser.close();
console.log(`${jobs.length} icons written`);
