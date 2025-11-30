import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Web kontrolü için
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:on_numara/screens/register_screen.dart';
import 'package:on_numara/screens/home_screen.dart';
import 'package:url_launcher/url_launcher.dart'; // İndirme linki için

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  String? password;
  bool _yukleniyor = false;

  // --- APK İNDİRME FONKSİYONU ---
  Future<void> _apkIndir() async {
    const url =
        'https://www.mediafire.com/file/mkaq8a27tjq44vq/app-release.apk/file';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Link açılamadı kral.")));
      }
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  // --- IPHONE KURULUM REHBERİ ---
  void _iphoneBilgiGoster() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "iPhone'a Nasıl Yüklenir?",
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _adimSatiri(
                "1",
                "Safari tarayıcısından bu siteye girin.",
                Icons.public,
              ),
              _adimSatiri(
                "2",
                "Alt orta kısımdaki 'Paylaş' simgesine dokunun.",
                Icons.ios_share, // Paylaş simgesi
              ),
              _adimSatiri(
                "3",
                "Menüde aşağı inip 'Ana Ekrana Ekle' seçeneğine basın.",
                Icons.add_box_outlined, // Artı kutu simgesi
              ),
              _adimSatiri(
                "4",
                "Sağ üst köşedeki 'Ekle' butonuna basın.",
                Icons.check_circle_outline,
              ),

              const SizedBox(height: 20),
              const Text(
                "Artık ana ekrandaki 10 Numara logosuna basarak uygulama gibi kullanabilirsiniz!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _adimSatiri(String no, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFFD4AF37),
            child: Text(
              no,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Icon(icon, color: Colors.white54, size: 20),
        ],
      ),
    );
  }

  Future<void> _girisYap() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _yukleniyor = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: password!.trim(),
          );

      String uid = userCredential.user!.uid;
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        Map<String, dynamic> userData = docSnapshot.data()!;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userData: userData),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kullanıcı verisi bulunamadı.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String hata = "Giriş yapılamadı.";
      if (e.toString().contains("user-not-found") ||
          e.toString().contains("invalid-credential"))
        hata = "Kullanıcı bulunamadı veya şifre yanlış.";
      if (e.toString().contains("wrong-password")) hata = "Şifre yanlış.";

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata)));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _sifremiUnuttum() {
    TextEditingController resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text(
          "Şifre Sıfırla",
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "E-posta adresini gir, sana sıfırlama bağlantısı gönderelim.",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: resetEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("E-posta", Icons.email),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (resetEmailController.text.isEmpty) return;
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: resetEmailController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "✅ Bağlantı gönderildi! Spam kutusunu kontrol et.",
                      ),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Hata: Bu mail kayıtlı değil.")),
                );
              }
            },
            child: const Text(
              "GÖNDER",
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF000000), Color(0xFF111111)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_soccer,
                      size: 80,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "10 NUMARA",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("E-posta", Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => v!.isEmpty ? "Gir" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Şifre", Icons.lock),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _girisYap(),
                    validator: (v) => v!.isEmpty ? "Gir" : null,
                    onSaved: (v) => password = v,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _sifremiUnuttum,
                      child: const Text(
                        "Şifremi Unuttum?",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _yukleniyor ? null : _girisYap,
                      child: _yukleniyor
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              "GİRİŞ YAP",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    ),
                    child: const Text(
                      "Hesabın yok mu? Kayıt Ol",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),

                  // --- İNDİRME VE REHBER BUTONLARI (SADECE WEB İÇİN) ---
                  if (kIsWeb) ...[
                    const SizedBox(height: 30),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 10),

                    // ANDROID İNDİR
                    ElevatedButton.icon(
                      onPressed: _apkIndir,
                      icon: const Icon(Icons.android, color: Colors.white),
                      label: const Text("ANDROID UYGULAMASI İNDİR"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // IPHONE REHBERİ
                    ElevatedButton.icon(
                      onPressed: _iphoneBilgiGoster,
                      icon: const Icon(Icons.apple, color: Colors.black),
                      label: const Text("IPHONE'A NASIL YÜKLENİR?"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Text(
                      "Android için APK indirebilir, iPhone için ana ekrana ekleyebilirsiniz.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF222222),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
    );
  }
}
