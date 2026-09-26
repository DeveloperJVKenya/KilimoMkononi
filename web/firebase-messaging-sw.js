// web/firebase-messaging-sw.js
//
// Shows Kilimo Mkononi pushes while the web app's tab is closed or in the
// background (foreground pushes are handled in-app by NotificationService).
// Config mirrors DefaultFirebaseOptions.web in lib/firebase_options.dart —
// regenerate if that changes. (Firebase web config values are public.)

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAKBGxVcKrjjC-ZpmgzLltUOlpe8cUciC8',
  appId: '1:865770087354:web:fe0785f373c312f0167383',
  messagingSenderId: '865770087354',
  projectId: 'kilimomkononi-e1031',
  authDomain: 'kilimomkononi-e1031.firebaseapp.com',
  storageBucket: 'kilimomkononi-e1031.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'Kilimo Mkononi', {
    body: n.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  });
});

// Open (or focus) the app when a notification is clicked.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const c of list) { if ('focus' in c) return c.focus(); }
    return clients.openWindow('/');
  }));
});
