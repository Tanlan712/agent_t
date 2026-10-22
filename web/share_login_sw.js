// Agent T 的 service worker（檔名沿用 share_login_sw.js，已安裝的 App 才不會留下舊的註冊）。
// 1. Android「分享」登入（manifest 的 share_target）：POST 到 share-login 的文字只暫存在這支手機的 Cache Storage，
//    再轉到登入頁；分享內容不對外送出（docs/superpowers/specs/2026-10-22-share-login-design.md）。
// 2. 離線開啟（docs/superpowers/specs/2026-10-22-pwa-offline-push-design.md）：只快取本站檔案與允許清單上的公開 CDN，
//    Riot 的主機一律不攔截、不快取（請求帶有 token）。
// 3. 商店刷新通知：收到推播就顯示通知，點通知打開商店頁。
const SHARE_PATH = 'share-login';
const SHARE_CACHE = 'share-login';

// 本站檔案：有網路時一律向伺服器確認（拿到最新版），沒網路才用快取。
const SHELL_CACHE = 'agent-t-shell-v1';
// 公開 CDN（CanvasKit、字型、造型圖片）：網址內容不會變，有快取就直接用。
const CDN_CACHE = 'agent-t-cdn-v1';
const MEDIA_CACHE = 'agent-t-media-v1';
const MEDIA_LIMIT = 600;
const KEEP_CACHES = [SHARE_CACHE, SHELL_CACHE, CDN_CACHE, MEDIA_CACHE];

// 只有這些主機的 GET 會被快取；其他主機（含 Riot 的 auth／pd／glz）完全不經過快取。
const CDN_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com'];
const MEDIA_HOSTS = ['media.valorant-api.com'];
// 版本檔每次都要問伺服器，不能被快取（更新提示靠它）。
const NO_CACHE_FILES = ['app_build.json'];

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Flutter 舊 service worker 留下的快取，以及舊版本的快取，一併刪掉。
    for (const name of await caches.keys()) {
      if (!KEEP_CACHES.includes(name)) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method === 'POST') {
    if (url.pathname === new URL(SHARE_PATH, self.registration.scope).pathname) {
      event.respondWith(saveShared(request));
    }
    return;
  }
  if (request.method !== 'GET') return;
  if (url.origin === self.location.origin) {
    if (!url.href.startsWith(self.registration.scope)) return;
    if (NO_CACHE_FILES.some((f) => url.pathname.endsWith('/' + f))) return;
    event.respondWith(networkFirst(request));
  } else if (CDN_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(request, CDN_CACHE, 0));
  } else if (MEDIA_HOSTS.includes(url.hostname)) {
    event.respondWith(cacheFirst(request, MEDIA_CACHE, MEDIA_LIMIT));
  }
});

async function saveShared(request) {
  const parts = [];
  try {
    const form = await request.formData();
    for (const key of ['url', 'text', 'title']) {
      const value = form.get(key);
      if (typeof value === 'string' && value) parts.push(value);
    }
  } catch (_) {
    // 表單讀不到時當作沒有內容，登入頁會顯示提示。
  }
  const cache = await caches.open(SHARE_CACHE);
  await cache.put('pending', new Response(parts.join('\n'), {
    headers: { 'x-shared-at': String(Date.now()) },
  }));
  return Response.redirect(new URL('./#/riot-login', self.registration.scope).href, 303);
}

async function networkFirst(request) {
  const cache = await caches.open(SHELL_CACHE);
  // 網址的 ?v= 等查詢字串不影響內容，離線時用路徑找回快取。
  const key = request.url.split('#')[0];
  try {
    // 頁面請求原樣送出（轉址要交給瀏覽器處理）；其他檔案用 no-cache 向伺服器確認
    // （沒變只回 304），避免瀏覽器快取給舊版。
    const response = request.mode === 'navigate'
      ? await fetch(request)
      : await fetch(key, { cache: 'no-cache', credentials: 'same-origin' });
    if (response.ok && !response.redirected) await cache.put(key, response.clone());
    return response;
  } catch (error) {
    const cached = await cache.match(key, { ignoreSearch: true });
    if (cached) return cached;
    // 沒有這個檔案的快取時，頁面請求改給首頁（hash 路由都在首頁裡）。
    if (request.mode === 'navigate') {
      const home = await cache.match(self.registration.scope);
      if (home) return home;
    }
    throw error;
  }
}

async function cacheFirst(request, cacheName, limit) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  // 只存成功、可讀的回應（opaque 回應的大小未知，會佔用大量配額）。
  if (response.ok && response.type !== 'opaque') {
    await cache.put(request, response.clone());
    if (limit > 0) await trim(cache, limit);
  }
  return response;
}

// 超過上限時從最早存入的開始刪。
async function trim(cache, limit) {
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - limit; i++) await cache.delete(keys[i]);
}

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }
  event.waitUntil(self.registration.showNotification(data.title || 'Agent T', {
    body: data.body || '每日商店已刷新，來看看今天有什麼。',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: data.tag || 'shop-refresh',
    data: { url: data.url || './#/' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || './#/', self.registration.scope).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (client.url.startsWith(self.registration.scope)) {
        await client.focus();
        if ('navigate' in client) await client.navigate(target);
        return;
      }
    }
    await self.clients.openWindow(target);
  })());
});
