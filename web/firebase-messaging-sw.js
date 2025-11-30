importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// Senin Proje Ayarların (Kral burayı senin için doldurdum)
firebase.initializeApp({
  apiKey: "AIzaSyDjOpCdSVJ4WNwiDaMiQtrPYfbiWCCS1aw",
  authDomain: "on-numara-app.firebaseapp.com",
  projectId: "on-numara-app",
  storageBucket: "on-numara-app.firebasestorage.app",
  messagingSenderId: "971910590414",
  appId: "1:971910590414:web:4a197be0c7bb88e6c3459f"
});

const messaging = firebase.messaging();

// Arka planda mesaj gelirse ne olsun?
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Arka plan mesajı alındı ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // Senin ikonun
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});