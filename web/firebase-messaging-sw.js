
importScripts('https://www.gstatic.com/firebasejs/11.5.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.5.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCf1ntCvH-H7LCNoPBtoOZKuxdJ_PD0Btk",
  authDomain: "resq-mob.firebaseapp.com",
  projectId: "resq-mob",
  storageBucket: "resq-mob.firebasestorage.app",
  messagingSenderId: "235986066777",
  appId: "1:235986066777:web:89c09526b475da60240048",
  measurementId: "G-YS7SM1QPJF"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/icon-192.png' // Optional
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
