import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:on_numara/screens/card_screen.dart';
import 'package:on_numara/screens/match_lobby_screen.dart';

class ChatScreen extends StatefulWidget {
  final String userName;

  const ChatScreen({super.key, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _mesajController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Temizlik fonksiyonunu hafiflettik, ekran açılışını engellemesin diye arkada çalışsın
    Future.delayed(Duration.zero, () => _eskiMaclariTemizle());
  }

  // --- HAFİFLETİLMİŞ TEMİZLİKÇİ ---
  Future<void> _eskiMaclariTemizle() async {
    try {
      var chatSnapshot = await FirebaseFirestore.instance
          .collection('chat_room')
          .where('isMatch', isEqualTo: true)
          .get();

      for (var doc in chatSnapshot.docs) {
        Map<String, dynamic> chatData = doc.data();
        String? matchId = chatData['matchId'];

        // Eğer maç ID'si yoksa veya hatalıysa bu mesajı silme, dursun.
        if (matchId == null) continue;

        var matchDoc = await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .get();

        // TEK KURAL: Maç veritabanından tamamen silinmişse (Son kişi çıkınca siliniyor), ilanı da sil.
        // Onun haricinde tarih geçse de, dolsa da silme.
        if (!matchDoc.exists) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      debugPrint("Temizlik hatası (Önemli değil): $e");
    }
  }

  void _mesajGonder() async {
    if (_mesajController.text.trim().isEmpty) return;
    String mesaj = _mesajController.text;
    _mesajController.clear();

    await FirebaseFirestore.instance.collection('chat_room').add({
      'text': mesaj,
      'sender': widget.userName,
      'uid': _auth.currentUser!.uid,
      'time': FieldValue.serverTimestamp(),
      'isMatch': false,
    });
  }

  void _kullaniciKartiniAc(String uid) async {
    if (uid == 'system_bot') return;
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        var data = doc.data()!;
        List<String> guvenliMevkiler = [];
        if (data['mevki'] != null) {
          guvenliMevkiler = [data['mevki'].toString()];
        } else if (data['mevkiler'] != null) {
          guvenliMevkiler = List<String>.from(data['mevkiler']);
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                title: Text(data['isim']),
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
                        isim: data['isim'],
                        mevkiler: guvenliMevkiler,
                        sehir: data['sehir'],
                        boy: data['boy'],
                        kilo: data['kilo'],
                        formaNo: data['formaNo'],
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
      }
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  void _macaGit(Map<String, dynamic> veri) {
    if (veri['matchId'] == null) return;

    String macId = veri['matchId'];
    bool kilitli = veri['isLocked'] ?? false;
    // matchData eski kalmış olabilir, sadece ID ile gidelim, Lobi veriyi taze çeksin.
    Map<String, dynamic> matchData = veri['matchData'] ?? {};

    if (kilitli) {
      _sifreSor(context, veri['password'], macId, matchData);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MatchLobbyScreen(matchId: macId, matchData: matchData),
        ),
      );
    }
  }

  void _sifreSor(
    BuildContext context,
    String? gercekSifre,
    String macId,
    Map<String, dynamic> data,
  ) {
    TextEditingController sifreController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("Şifreli Maç", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: sifreController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Şifreyi gir",
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onSubmitted: (girilen) {
            if (girilen == gercekSifre) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MatchLobbyScreen(matchId: macId, matchData: data),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Yanlış şifre kral.")),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (sifreController.text == gercekSifre) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MatchLobbyScreen(matchId: macId, matchData: data),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Yanlış şifre kral.")),
                );
              }
            },
            child: const Text(
              "Gir",
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('chat_room')
                .orderBy('time', descending: true)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (!snapshot.hasData)
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                );

              var mesajlar = snapshot.data!.docs;

              return ListView.builder(
                reverse: true,
                itemCount: mesajlar.length,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 20,
                ),
                itemBuilder: (context, index) {
                  var veri = mesajlar[index].data() as Map<String, dynamic>;
                  bool benAttim = veri['uid'] == _auth.currentUser?.uid;
                  bool isSystem = veri['uid'] == 'system_bot';

                  if (isSystem) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.all(15),
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.redAccent),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.sports_soccer,
                              color: Colors.white,
                              size: 30,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              veri['text'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red.shade900,
                              ),
                              onPressed: () => _macaGit(veri),
                              child: const Text(
                                "MAÇA GİT >",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Align(
                    alignment: benAttim
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: benAttim
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!benAttim)
                          GestureDetector(
                            onTap: () => _kullaniciKartiniAc(veri['uid']),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 10,
                                bottom: 2,
                              ),
                              child: Text(
                                veri['sender'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: benAttim
                                ? const Color(0xFFD4AF37)
                                : const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            veri['text'],
                            style: TextStyle(
                              color: benAttim ? Colors.black : Colors.white,
                              fontWeight: benAttim
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mesajController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Yaz bakalım...",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF222222),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _mesajGonder(),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: const Color(0xFFD4AF37),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.black),
                  onPressed: _mesajGonder,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
