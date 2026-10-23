{{flutter_js}}
{{flutter_build_config}}

// 不用 Flutter 預設的 service worker，改註冊自己的 share_login_sw.js
// （分享登入、離線開啟、商店刷新通知；Riot 的請求不經過快取）。
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('share_login_sw.js').catch(() => {});
}

// PWA 功能給 Dart（lib/services/pwa/web.dart）呼叫。
// beforeinstallprompt 可能在 Flutter 載入前就觸發，所以在這裡先攔下來。
let deferredInstall = null;
const installListeners = [];
const installChanged = () => installListeners.forEach((callback) => callback());
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  deferredInstall = event;
  installChanged();
});
window.addEventListener('appinstalled', () => {
  deferredInstall = null;
  installChanged();
});

const urlBase64ToBytes = (base64) => {
  const padded = (base64 + '='.repeat((4 - base64.length % 4) % 4))
    .replace(/-/g, '+').replace(/_/g, '/');
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
};

window.agentTPwa = {
  canInstall: () => deferredInstall !== null,
  // 回傳 'accepted'、'dismissed' 或 'unavailable'。
  install: async () => {
    if (!deferredInstall) return 'unavailable';
    const event = deferredInstall;
    deferredInstall = null;
    await event.prompt();
    const choice = await event.userChoice;
    installChanged();
    return choice.outcome;
  },
  // 可以安裝的狀態改變時呼叫 callback()。
  onInstallChange: (callback) => { installListeners.push(callback); },
  isStandalone: () => window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true,
  isIos: () => /iphone|ipad|ipod/i.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1),
  isOnline: () => navigator.onLine,
  // 連線狀態改變時呼叫 callback(true/false)。
  onOnlineChange: (callback) => {
    window.addEventListener('online', () => callback(true));
    window.addEventListener('offline', () => callback(false));
  },
  // 伺服器上最新版本的 build（deploy.yml 寫入 app_build.json）；離線或讀不到時回傳 null。
  latestBuild: async () => {
    try {
      const response = await fetch('app_build.json?t=' + Date.now(), { cache: 'no-store' });
      if (!response.ok) return null;
      const data = await response.json();
      return typeof data.build === 'string' ? data.build : null;
    } catch (_) {
      return null;
    }
  },
  reload: () => window.location.reload(),
  // 推播：'unsupported'、'default'、'granted' 或 'denied'。
  notificationPermission: () => {
    if (!('Notification' in window) || !('serviceWorker' in navigator) ||
        !('PushManager' in window)) return 'unsupported';
    return Notification.permission;
  },
  // 回傳訂閱的 JSON 字串（要貼到 GitHub 的 PUSH_SUBSCRIPTIONS），沒有訂閱時回傳 null。
  pushSubscription: async () => {
    if (!('serviceWorker' in navigator)) return null;
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    return subscription ? JSON.stringify(subscription) : null;
  },
  subscribePush: async (vapidPublicKey) => {
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return null;
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToBytes(vapidPublicKey),
    });
    return JSON.stringify(subscription);
  },
  unsubscribePush: async () => {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    if (subscription) await subscription.unsubscribe();
  },
  // 在這台裝置上立即顯示一則測試通知（不經過伺服器）。
  testNotification: async () => {
    const registration = await navigator.serviceWorker.ready;
    await registration.showNotification('Agent T', {
      body: '通知測試成功：每日商店刷新時會收到這樣的通知。',
      icon: 'icons/Icon-192.png',
      tag: 'shop-refresh-test',
      data: { url: './#/' },
    });
  },
};

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
