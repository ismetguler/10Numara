import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:on_numara/screens/card_screen.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text(
          "TRANSFER PİYASASI",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Color(0xFFD4AF37), fontSize: 20),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('kayitTarihi', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            );
          }

          var players = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75, // Biraz daha kareye yakın, derli toplu
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: players.length,
            itemBuilder: (context, index) {
              var data = players[index].data() as Map<String, dynamic>;

              // Güvenli Mevki
              List<String> guvenliMevkiler = [];
              String anaMevki = "OS"; // Varsayılan kısaltma
              if (data['mevki'] != null) {
                guvenliMevkiler = [data['mevki'].toString()];
                anaMevki = data['mevki'].toString().substring(0, 2);
              } else if (data['mevkiler'] != null && data['mevkiler'] is List) {
                guvenliMevkiler = List<String>.from(data['mevkiler']);
                if (guvenliMevkiler.isNotEmpty) {
                  anaMevki = guvenliMevkiler[0].substring(0, 2);
                }
              }

              return GestureDetector(
                onTap: () {
                  // Tıklayınca Orijinal Büyük Kartı Aç
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          title: Text(data['isim'] ?? "Oyuncu"),
                          backgroundColor: Colors.transparent,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Center(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              height: 500,
                              child: Transform.scale(
                                scale: 0.9,
                                child: CardScreen(
                                  isim: data['isim'] ?? "İsimsiz",
                                  mevkiler: guvenliMevkiler,
                                  sehir: data['sehir'] ?? "Belirsiz",
                                  boy: data['boy'] ?? "-",
                                  kilo: data['kilo'] ?? "-",
                                  formaNo: data['formaNo'] ?? "10",
                                  resimBase64: data['resimData'],
                                  backButtonVarMi: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E2E2E), Color(0xFF111111)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Arka Plan Deseni (Opsiyonel)
                      Positioned.fill(
                        child: Icon(
                          Icons.shield,
                          size: 100,
                          color: Colors.white.withOpacity(0.03),
                        ),
                      ),

                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Reyting ve Mevki (Sol Üst Köşe Havası)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data['formaNo'] ?? "10",
                                style: const TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  anaMevki,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Profil Resmi (Yuvarlak ve Altın Çerçeveli)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.black,
                              backgroundImage: _getProfileImage(
                                data['resimData'],
                              ),
                              child: data['resimData'] == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white54,
                                    )
                                  : null,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // İsim
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              (data['isim'] ?? "İsimsiz")
                                  .toString()
                                  .toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                          ),

                          // Şehir
                          Text(
                            data['sehir'] ?? "",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  ImageProvider? _getProfileImage(String? base64Data) {
    if (base64Data != null && base64Data.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(base64Data));
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
