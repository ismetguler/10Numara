import 'package:flutter/material.dart';
import 'package:on_numara/screens/card_screen.dart';
import 'package:on_numara/screens/chat_screen.dart';
import 'package:on_numara/screens/players_screen.dart';
import 'package:on_numara/screens/edit_profile_screen.dart';
import 'package:on_numara/screens/matches_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Çıkış için lazım
import 'package:on_numara/screens/login_screen.dart'; // Yönlendirme için lazım

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  // --- ÇIKIŞ YAPMA FONKSİYONU ---
  void _cikisYap(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("Çıkış Yap", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Hesabından çıkmak istediğine emin misin kral?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // İptal
            child: const Text("Hayır", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              // 1. Firebase'den çık
              await FirebaseAuth.instance.signOut();

              // 2. Login ekranına git ve geçmişi sil (Geri tuşuna basıp dönemesin)
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              "EVET, ÇIK",
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
    // --- VERİ GÜVENLİĞİ AYARI ---
    List<String> guvenliMevkiler = [];
    if (userData['mevki'] != null) {
      guvenliMevkiler = [userData['mevki'].toString()];
    } else if (userData['mevkiler'] != null) {
      guvenliMevkiler = List<String>.from(userData['mevkiler']);
    } else {
      guvenliMevkiler = ["Belirsiz"];
    }
    // ---------------------------

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.logout,
            color: Colors.red,
          ), // ÇIKIŞ BUTONU (SOLDA)
          tooltip: "Hesaptan Çık",
          onPressed: () => _cikisYap(context),
        ),
        title: const Text(
          "10 NUMARA",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Color(0xFFD4AF37),
            fontSize: 22,
            shadows: [Shadow(color: Color(0xFFD4AF37), blurRadius: 10)],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white54),
            tooltip: "Profili Düzenle",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(userData: userData),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: "Hoş geldin, ",
                      style: TextStyle(color: Colors.grey, fontSize: 18),
                    ),
                    TextSpan(
                      text: userData['isim']
                          .toString()
                          .split(' ')[0]
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: GestureDetector(
                      onTap: () => _kartiTamEkranAc(context, guvenliMevkiler),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 10),
                            const Text(
                              "PROFİLİM",
                              style: TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),

                            Expanded(
                              child: Transform.scale(
                                scale: 0.75,
                                child: Hero(
                                  tag: "kartim",
                                  child: CardScreen(
                                    isim: userData['isim'],
                                    mevkiler: guvenliMevkiler,
                                    sehir: userData['sehir'],
                                    boy: userData['boy'],
                                    kilo: userData['kilo'],
                                    formaNo: userData['formaNo'],
                                    resimBase64: userData['resimData'],
                                    backButtonVarMi: false,
                                  ),
                                ),
                              ),
                            ),
                            const Text(
                              "Detaylar için tıkla",
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: _neonMenuButonu(
                            context,
                            icon: Icons.groups_rounded,
                            baslik: "FUTBOLCULAR",
                            baslangicRenk: const Color(0xFF00C853),
                            bitisRenk: const Color(0xFF1B5E20),
                            tiklaninca: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PlayersScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        Expanded(
                          child: _neonMenuButonu(
                            context,
                            icon: Icons.forum_rounded,
                            baslik: "SOYUNMA\nODASI",
                            baslangicRenk: const Color(0xFFFFD700),
                            bitisRenk: const Color(0xFFB8860B),
                            ikonRengi: Colors.black,
                            yaziRengi: Colors.black,
                            tiklaninca: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text("Soyunma Odası"),
                                    backgroundColor: const Color(0xFF111111),
                                    iconTheme: const IconThemeData(
                                      color: Colors.white,
                                    ),
                                    titleTextStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                  body: ChatScreen(userName: userData['isim']),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        Expanded(
                          child: _neonMenuButonu(
                            context,
                            icon: Icons.sports_soccer,
                            baslik: "MAÇ\nMERKEZİ",
                            baslangicRenk: const Color(0xFFFF3D00),
                            bitisRenk: const Color(0xFFB71C1C),
                            tiklaninca: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MatchesScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _neonMenuButonu(
    BuildContext context, {
    required IconData icon,
    required String baslik,
    required Color baslangicRenk,
    required Color bitisRenk,
    required VoidCallback tiklaninca,
    Color ikonRengi = Colors.white,
    Color yaziRengi = Colors.white,
  }) {
    return GestureDetector(
      onTap: tiklaninca,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [baslangicRenk, bitisRenk],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: baslangicRenk.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: ikonRengi),
            const SizedBox(height: 5),
            Text(
              baslik,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: yaziRengi,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _kartiTamEkranAc(BuildContext context, List<String> mevkiler) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text("Kartın"),
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: SingleChildScrollView(
              child: SizedBox(
                height: 500,
                child: Hero(
                  tag: "kartim",
                  child: CardScreen(
                    isim: userData['isim'],
                    mevkiler: mevkiler,
                    sehir: userData['sehir'],
                    boy: userData['boy'],
                    kilo: userData['kilo'],
                    formaNo: userData['formaNo'],
                    resimBase64: userData['resimData'],
                    backButtonVarMi: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
