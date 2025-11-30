import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // YENİ PAKET
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:on_numara/screens/splash_screen.dart';

// --- BİLDİRİM KANALI AYARLARI ---
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id (Manifest ile aynı olmalı)
  'Yüksek Önemli Bildirimler', // Başlık
  description: 'Bu kanal maç bildirimleri içindir.', // Açıklama
  importance: Importance.max, // POP-UP İÇİN KRİTİK AYAR
  playSound: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Arka planda bildirim gelirse çalışacak fonksiyon
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Arka plan mesajı: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDjOpCdSVJ4WNwiDaMiQtrPYfbiWCCS1aw",
      appId: "1:971910590414:web:4a197be0c7bb88e6c3459f",
      messagingSenderId: "971910590414",
      projectId: "on-numara-app",
      storageBucket: "on-numara-app.firebasestorage.app",
      authDomain: "on-numara-app.firebaseapp.com",
    ),
  );

  // Arka plan işleyicisini ata
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Kanalı oluştur (Android için)
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // iOS için ön planda bildirim izni
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const OnNumaraApp());
}

class OnNumaraApp extends StatefulWidget {
  const OnNumaraApp({super.key});

  @override
  State<OnNumaraApp> createState() => _OnNumaraAppState();
}

class _OnNumaraAppState extends State<OnNumaraApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  void _initNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // İzin iste
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true, // Kritik uyarı
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Kullanıcı izin verdi');

      // Kanal aboneliği
      await messaging.subscribeToTopic('genel');

      // Token (Web için gerekebilir ama mobilde topic yetiyor)
      messaging.getToken(
        vapidKey:
            "BLF2ZfELmvdn6X6cfvGUVI1mhbVhOj941i1_Rdo5bewToLVxwK0iuCHQI6zxmkyPahCPVITcyGnTUNG9898eh_s",
      );

      // --- UYGULAMA AÇIKKEN BİLDİRİM GELİRSE ---
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        // Eğer bildirim verisi varsa, yerel bildirim (Local Notification) oluştur
        // Bu sayede uygulama açıkken bile yukardan DİNG diye düşer.
        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher', // Manifestte tanımladığımız ikon
                importance: Importance.max,
                priority: Priority.high,
                color: const Color(0xFFD4AF37), // Altın rengi
              ),
            ),
          );
        }
      });
    } else {
      debugPrint('Bildirim izni verilmedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '10 Numara',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFD4AF37),
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],

      home: const SplashScreen(), // Direkt Splash'e gidiyoruz, o yönetiyor
    );
  }
}
