{{flutter_js}}
{{flutter_build_config}}

// 不用 Flutter 預設的 service worker（會快取整個網站），
// 改註冊只處理 Android「分享」登入的 share_login_sw.js。
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('share_login_sw.js').catch(() => {});
}

// 取出 share_login_sw.js 暫存的分享內容，取出後立即刪除；超過 10 分鐘的直接丟棄。
window.valorantTakeSharedLogin = async () => {
  if (!('caches' in window)) return null;
  const cache = await caches.open('share-login');
  const response = await cache.match('pending');
  await caches.delete('share-login');
  if (!response) return null;
  const sharedAt = Number(response.headers.get('x-shared-at')) || 0;
  if (Date.now() - sharedAt > 10 * 60 * 1000) return null;
  return await response.text();
};

_flutter.loader.load();
