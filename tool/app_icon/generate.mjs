// 從 background.svg / foreground.svg（Android 自適應圖示的 108×108 格線）
// 產生 Android、PWA、iOS 全部圖示。
//
//   npm i -g playwright && node tool/app_icon/generate.mjs
//
// 前景內容須在中心半徑 33 的安全區內；啟動器只顯示中間 72×72，其餘給遮罩與視差動畫用。
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH ?? 'playwright');

const inner = (file) => readFileSync(join(here, file), 'utf8')
  .replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
const bg = inner('background.svg');
const fg = inner('foreground.svg');

// view：顯示範圍；clip：圓角半徑（以 108 格線計）；mono：轉成白色剪影。
const svg = ({ layers, view = [0, 0, 108, 108], radius = 0, mono = false }) => {
  const [x, y, w, h] = view;
  const body = layers.join('');
  const clip = radius ? `<clipPath id="clip"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}"/></clipPath>` : '';
  const filter = mono ? '<filter id="mono"><feFlood flood-color="#fff"/><feComposite in2="SourceAlpha" operator="in"/></filter>' : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${view.join(' ')}" width="100%" height="100%">`
    + `<defs>${clip}${filter}</defs><g${radius ? ' clip-path="url(#clip)"' : ''}${mono ? ' filter="url(#mono)"' : ''}>${body}</g></svg>`;
};

const visible = [18, 18, 72, 72];
const full = (o = {}) => svg({ layers: [bg, fg], view: visible, ...o });

const res = 'android/app/src/main/res';
const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

const jobs = [];
for (const [d, k] of Object.entries(densities)) {
  // Android 8 以下的舊式圖示（48dp，圓角方形）。
  jobs.push([`${res}/mipmap-${d}/ic_launcher.png`, 48 * k, full({ radius: 12 })]);
  // 自適應圖示的三層（108dp）。
  jobs.push([`${res}/mipmap-${d}/ic_launcher_background.png`, 108 * k, svg({ layers: [bg] })]);
  jobs.push([`${res}/mipmap-${d}/ic_launcher_foreground.png`, 108 * k, svg({ layers: [fg] })]);
  jobs.push([`${res}/mipmap-${d}/ic_launcher_monochrome.png`, 108 * k, svg({ layers: [fg], mono: true })]);
}
// PWA：any 用圓角方形；maskable 用整張（瀏覽器自己裁切，安全區 80% 圓）。
jobs.push(['web/favicon.png', 32, full({ radius: 14 })]);
jobs.push(['web/icons/Icon-192.png', 192, full({ radius: 14 })]);
jobs.push(['web/icons/Icon-512.png', 512, full({ radius: 14 })]);
jobs.push(['web/icons/Icon-maskable-192.png', 192, svg({ layers: [bg, fg], view: [9, 9, 90, 90] })]);
jobs.push(['web/icons/Icon-maskable-512.png', 512, svg({ layers: [bg, fg], view: [9, 9, 90, 90] })]);
// iOS 自己會加圓角，且不可有透明。
jobs.push(['web/icons/apple-touch-icon.png', 180, full()]);
const iosIcons = JSON.parse(readFileSync(join(root, ios, 'Contents.json'), 'utf8')).images;
for (const { filename, size, scale } of iosIcons) {
  jobs.push([`${ios}/${filename}`, Math.round(parseFloat(size) * parseInt(scale)), full()]);
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
