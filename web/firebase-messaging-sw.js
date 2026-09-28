// web/firebase-messaging-sw.js
//
// Shows Kilimo Mkononi pushes while the web app's tab is closed or in the
// background (foreground pushes are handled in-app by NotificationService).
// Config mirrors DefaultFirebaseOptions.web in lib/firebase_options.dart —
// regenerate if that changes. (Firebase web config values are public.)
// Keep the SDK version in step with firebase_core_web's supported JS SDK.

importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAKBGxVcKrjjC-ZpmgzLltUOlpe8cUciC8',
  appId: '1:865770087354:web:fe0785f373c312f0167383',
  messagingSenderId: '865770087354',
  projectId: 'kilimomkononi-e1031',
  authDomain: 'kilimomkononi-e1031.firebaseapp.com',
  storageBucket: 'kilimomkononi-e1031.firebasestorage.app',
});

const messaging = firebase.messaging();

// Every Kilimo Mkononi push carries a `notification` payload, which the
// Firebase SDK displays by itself (and opens webpush.fcmOptions.link —
// /?km_route=… — when clicked). Showing it here too would duplicate it, so
// only data-only messages are shown manually.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const d = payload.data || {};
  if (!d.title) return;
  self.registration.showNotification(d.title, {
    body: d.body || '',
    icon: '/icons/Icon-192.png',
    tag: d.tag || undefined,
    data: d,
  });
});

// Clicks on the data-only notifications shown above: open the app on the
// right screen (same /?km_route=… link the SDK uses), focusing an open tab.
self.addEventListener('notificationclick', (event) => {
  const d = event.notification.data || {};
  if (d.FCM_MSG) return; // shown by the Firebase SDK, which handles the click
  event.notification.close();
  const qs = new URLSearchParams();
  if (d.route) qs.set('km_route', d.route);
  for (const [k, v] of Object.entries(d)) {
    if (!['route', 'title', 'body', 'tag', 'channel', 'type'].includes(k)) qs.set(k, v);
  }
  const url = '/' + (qs.toString() ? '?' + qs.toString() : '');
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const c of list) {
      if ('navigate' in c) return c.navigate(url).then((w) => (w || c).focus());
    }
    return clients.openWindow(url);
  }));
});
