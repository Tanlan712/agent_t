// Android「分享」登入（manifest 的 share_target）。
// 只處理 POST 到 share-login 的請求：把分享的文字暫存在這支手機的 Cache Storage，再轉到登入頁。
// 其他請求一律不攔截、不快取；不對外送出任何資料（docs/superpowers/specs/2026-10-22-share-login-design.md）。
const SHARE_PATH = 'share-login';
const SHARE_CACHE = 'share-login';

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Flutter 舊的 service worker 會快取整個網站，換掉後把它留下的快取刪掉。
    for (const name of await caches.keys()) {
      if (name.startsWith('flutter-')) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'POST') return;
  if (new URL(request.url).pathname !== new URL(SHARE_PATH, self.registration.scope).pathname) return;
  event.respondWith((async () => {
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
  })());
});
