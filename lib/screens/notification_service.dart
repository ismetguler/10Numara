import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NotificationService {
  // Proje ID'si (Firebase Console'daki ile birebir aynı olmalı)
  static const String _projectId = "on-numara-app";

  static Future<String?> _getAccessToken() async {
    try {
      // Dosyayı okumaya çalışıyoruz
      final jsonString = await rootBundle.loadString(
        'assets/service_account.json',
      );

      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(accountCredentials, scopes);

      return client.credentials.accessToken.data;
    } catch (e) {
      debugPrint("🔴 KIRMIZI ALARM - Service Account Okunamadı: $e");
      debugPrint(
        "Lütfen assets/service_account.json dosyasının var olduğundan ve pubspec.yaml'da tanımlı olduğundan emin ol.",
      );
      return null;
    }
  }

  static Future<void> bildirimGonder({
    required String baslik,
    required String icerik,
  }) async {
    try {
      debugPrint("🟡 Bildirim gönderilmeye hazırlanıyor...");
      final String? token = await _getAccessToken();

      if (token == null) {
        debugPrint("🔴 Token yok, iptal edildi.");
        return;
      }

      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "message": {
            "topic": "genel",
            "notification": {"title": baslik, "body": icerik},
            "android": {
              "priority": "high",
              "notification": {
                "sound": "default",
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "channel_id": "high_importance_channel", // Pop-up için şart
              },
            },
            "data": {
              "click_action": "FLUTTER_NOTIFICATION_CLICK",
              "status": "done",
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ BİLDİRİM BAŞARIYLA GİTTİ! (Google Kabul Etti)");
      } else {
        debugPrint(
          "🔴 Google Hatası (${response.statusCode}): ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("🔴 Genel Gönderim Hatası: $e");
    }
  }
}
