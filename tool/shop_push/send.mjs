// 對 PUSH_SUBSCRIPTIONS 裡的每個訂閱送一則「每日商店已刷新」通知（.github/workflows/shop-push.yml）。
// repo 是公開的：不可印出私鑰、訂閱網址或金鑰，log 只寫第幾筆與 HTTP 狀態碼。
import webpush from 'web-push';

const { VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, PUSH_SUBSCRIPTIONS, VAPID_SUBJECT } = process.env;

if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY || !PUSH_SUBSCRIPTIONS) {
  console.log('尚未設定 VAPID_PUBLIC_KEY／VAPID_PRIVATE_KEY／PUSH_SUBSCRIPTIONS，略過（見 docs/push.md）。');
  process.exit(0);
}

let subscriptions;
try {
  subscriptions = JSON.parse(PUSH_SUBSCRIPTIONS);
} catch (_) {
  // 不印出解析錯誤的內容（可能含訂閱資料）。
  console.log('PUSH_SUBSCRIPTIONS 不是合法的 JSON。');
  process.exit(1);
}
if (!Array.isArray(subscriptions)) subscriptions = [subscriptions];

webpush.setVapidDetails(VAPID_SUBJECT || 'https://github.com', VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

const payload = JSON.stringify({
  title: 'Agent T',
  body: '每日商店已刷新，來看看今天有什麼。',
  tag: 'shop-refresh',
  url: './#/',
});

let failed = 0;
for (const [i, subscription] of subscriptions.entries()) {
  try {
    const result = await webpush.sendNotification(subscription, payload, { TTL: 6 * 60 * 60 });
    console.log(`第 ${i + 1} 筆：已送出（${result.statusCode}）`);
  } catch (error) {
    failed++;
    const status = error && error.statusCode;
    const hint = status === 404 || status === 410 ? '，訂閱已失效，請在 App 重新訂閱並更新 secret' : '';
    console.log(`第 ${i + 1} 筆：失敗（${status || '無狀態碼'}${hint}）`);
  }
}
if (failed === subscriptions.length) process.exit(1);
