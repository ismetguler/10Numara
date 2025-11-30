import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchLobbyScreen extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> matchData;

  const MatchLobbyScreen({
    super.key,
    required this.matchId,
    required this.matchData,
  });

  @override
  State<MatchLobbyScreen> createState() => _MatchLobbyScreenState();
}

class _MatchLobbyScreenState extends State<MatchLobbyScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _yukleniyor = false;
  bool _cikisYapiliyor = false;

  Future<void> _aramaYap(String numara) async {
    final Uri launchUri = Uri(scheme: 'tel', path: numara);
    try {
      if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  // 1. Yedeklere Otomatik Katıl
  Future<void> _yedeklereKatil() async {
    String uid = _auth.currentUser!.uid;
    if (_yukleniyor || _cikisYapiliyor) return;

    setState(() => _yukleniyor = true);
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      var userData = userDoc.data()!;
      Map<String, dynamic> oyuncu = {
        'uid': uid,
        'isim': userData['isim'],
        'mevki': userData['mevki'] ?? "OS",
        'bolge': 'YEDEK',
        'slotIndex': -1,
        'formaNo': userData['formaNo'],
        'resimData': userData['resimData'],
      };

      // GÜVENLİ EKLEME
      var doc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .get();
      if (!doc.exists) return;
      List y = List.from(doc.data()!['yedekler'] ?? []);
      // Zaten varsa ekleme
      if (!y.any((p) => p['uid'] == uid)) {
        y.add(oyuncu);
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .update({'yedekler': y});
      }
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // 2. MAÇTAN AYRIL
  Future<void> _mactanAyril(
    List kadroA,
    List kadroB,
    List yedekler,
    String kurucuId,
  ) async {
    String myUid = _auth.currentUser!.uid;
    bool benKurucuyum = (myUid == kurucuId);
    List tumOyuncular = [...kadroA, ...kadroB, ...yedekler];
    tumOyuncular.removeWhere((p) => p['uid'] == myUid);

    if (tumOyuncular.isEmpty) {
      bool sil =
          await showDialog(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: Colors.black,
              title: const Text(
                "Maç Silinsin mi?",
                style: TextStyle(color: Colors.red),
              ),
              content: const Text(
                "Senden başka kimse kalmadı. Çıkarsan maç tamamen silinecek.",
                style: TextStyle(color: Colors.grey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text("İptal"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text(
                    "SİL VE ÇIK",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (sil) _maciSilVeCik();
      return;
    }

    if (benKurucuyum && tumOyuncular.isNotEmpty) {
      _liderDevretVeCik(tumOyuncular);
    } else {
      await _normalCikis(
        myUid,
      ); // Parametreleri azalttım, içeride taze veri çekecek
    }
  }

  Future<void> _maciSilVeCik() async {
    setState(() {
      _yukleniyor = true;
      _cikisYapiliyor = true;
    });
    try {
      Navigator.of(context).pop();
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .delete();
      var chats = await FirebaseFirestore.instance
          .collection('chat_room')
          .where('matchId', isEqualTo: widget.matchId)
          .get();
      for (var doc in chats.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Silme hatası: $e");
    }
  }

  void _liderDevretVeCik(List adaylar) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text(
          "Kaptanlığı Devret",
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: adaylar.length,
            itemBuilder: (context, index) {
              var p = adaylar[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.black,
                  backgroundImage: (p['resimData'] != null)
                      ? MemoryImage(base64Decode(p['resimData']))
                      : null,
                ),
                title: Text(
                  p['isim'],
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => _lideriGuncelleVeCik(p),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _lideriGuncelleVeCik(Map<String, dynamic> yeniLider) async {
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .update({
          'kurucuId': yeniLider['uid'],
          'kurucuIsim': yeniLider['isim'],
        });
    Navigator.pop(context); // Dialogu kapat
    await _normalCikis(_auth.currentUser!.uid);
  }

  // --- KRİTİK DÜZELTME: KESİN ÇIKIŞ FONKSİYONU ---
  Future<void> _normalCikis(String uid) async {
    setState(() => _yukleniyor = true);
    try {
      // 1. Verinin en güncel halini çek
      var doc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .get();
      if (!doc.exists) return;
      var data = doc.data()!;

      List a = List.from(data['kadro_A'] ?? []);
      List b = List.from(data['kadro_B'] ?? []);
      List y = List.from(data['yedekler'] ?? []);

      // 2. Listelerden UID'ye göre temizle (En garanti yöntem)
      a.removeWhere((p) => p['uid'] == uid);
      b.removeWhere((p) => p['uid'] == uid);
      y.removeWhere((p) => p['uid'] == uid);

      // 3. Temiz listeleri geri yükle
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({'kadro_A': a, 'kadro_B': b, 'yedekler': y});

      if (mounted) Navigator.pop(context); // Lobiden at
      _snack("Maçtan tamamen ayrıldın.");
    } catch (e) {
      _snack("Çıkış hatası: $e");
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // 3. Mevki Değiştir
  Future<void> _oyuncuTasi(
    Map<String, dynamic> oyuncu,
    String hedefTakim,
    String hedefBolge,
    int hedefSlotIndex,
  ) async {
    String myUid = _auth.currentUser!.uid;
    var doc = await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .get();
    if (doc.data()!['kurucuId'] != myUid) {
      _snack("Sadece kaptan oyuncu taşıyabilir!");
      return;
    }

    setState(() => _yukleniyor = true);
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List a = List.from(data['kadro_A'] ?? []);
      List b = List.from(data['kadro_B'] ?? []);
      List y = List.from(data['yedekler'] ?? []);

      a.removeWhere((p) => p['uid'] == oyuncu['uid']);
      b.removeWhere((p) => p['uid'] == oyuncu['uid']);
      y.removeWhere((p) => p['uid'] == oyuncu['uid']);

      oyuncu['bolge'] = hedefBolge;
      oyuncu['slotIndex'] = hedefSlotIndex;

      if (hedefTakim == "A")
        a.add(oyuncu);
      else if (hedefTakim == "B")
        b.add(oyuncu);
      else
        y.add(oyuncu);

      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({'kadro_A': a, 'kadro_B': b, 'yedekler': y});
    } catch (e) {
      _snack("Hata: $e");
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  // 4. Sahaya Gir
  Future<void> _sahayaGir(
    String hedefTakim,
    String hedefBolge,
    int hedefSlotIndex,
  ) async {
    String uid = _auth.currentUser!.uid;
    setState(() => _yukleniyor = true);
    try {
      var doc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .get();
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List a = List.from(data['kadro_A'] ?? []);
      List b = List.from(data['kadro_B'] ?? []);
      List y = List.from(data['yedekler'] ?? []);
      var ben =
          y.firstWhere((p) => p['uid'] == uid, orElse: () => null) ??
          a.firstWhere((p) => p['uid'] == uid, orElse: () => null) ??
          b.firstWhere((p) => p['uid'] == uid, orElse: () => null);

      if (ben == null) {
        var u = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        ben = {
          'uid': uid,
          'isim': u['isim'],
          'mevki': u['mevki'],
          'bolge': hedefBolge,
          'slotIndex': hedefSlotIndex,
          'formaNo': u['formaNo'],
          'resimData': u['resimData'],
        };
      } else {
        a.removeWhere((p) => p['uid'] == uid);
        b.removeWhere((p) => p['uid'] == uid);
        y.removeWhere((p) => p['uid'] == uid);
        ben['bolge'] = hedefBolge;
        ben['slotIndex'] = hedefSlotIndex;
      }
      if (hedefTakim == "A")
        a.add(ben);
      else if (hedefTakim == "B")
        b.add(ben);
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({'kadro_A': a, 'kadro_B': b, 'yedekler': y});
    } catch (e) {
      _snack("Hata: $e");
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  // 5. Yedeğe Geç
  Future<void> _yedegeGec() async {
    String uid = _auth.currentUser!.uid;
    setState(() => _yukleniyor = true);
    try {
      var doc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .get();
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List a = List.from(data['kadro_A'] ?? []);
      List b = List.from(data['kadro_B'] ?? []);
      List y = List.from(data['yedekler'] ?? []);
      var ben =
          a.firstWhere((p) => p['uid'] == uid, orElse: () => null) ??
          b.firstWhere((p) => p['uid'] == uid, orElse: () => null);
      if (ben == null) {
        setState(() => _yukleniyor = false);
        return;
      }

      a.removeWhere((p) => p['uid'] == uid);
      b.removeWhere((p) => p['uid'] == uid);
      ben['bolge'] = "YEDEK";
      y.add(ben);
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({'kadro_A': a, 'kadro_B': b, 'yedekler': y});
    } catch (e) {
      _snack("Hata: $e");
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _duyuruYap(int toplamOyuncu) async {
    int kapasite = widget.matchData['kapasite'] ?? 14;
    int eksik = kapasite - toplamOyuncu;
    String msg = eksik > 0
        ? "📢 $eksik KİŞİ LAZIM! Koşun!"
        : "📢 KADRO TAM! Yedekler hazır olsun!";
    await _otomatikMesajAt(msg);
    _snack("Duyuru yapıldı!");
  }

  Future<void> _otomatikMesajAt(String mesaj) async {
    var macKontrol = await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .get();
    if (!macKontrol.exists) return;
    await FirebaseFirestore.instance.collection('chat_room').add({
      'text': mesaj,
      'sender': "MAÇ BOTU",
      'uid': "system_bot",
      'time': FieldValue.serverTimestamp(),
      'isMatch': true,
      'matchId': widget.matchId,
      'isLocked': widget.matchData['sifreli'] ?? false,
      'password': widget.matchData['sifre'],
      'matchData': widget.matchData,
    });
  }

  // 6. Karıştır
  Future<void> _karistir(List a, List b) async {
    setState(() => _yukleniyor = true);
    List havuz = [...a, ...b];

    List kaleciler = havuz.where((p) => p['mevki'] == "KALECİ").toList()
      ..shuffle();
    List defanslar = havuz.where((p) => p['mevki'] == "DEFANS").toList()
      ..shuffle();
    List ortalar = havuz.where((p) => p['mevki'] == "ORTA SAHA").toList()
      ..shuffle();
    List forvetler = havuz.where((p) => p['mevki'] == "FORVET").toList()
      ..shuffle();
    List belirsizler =
        havuz
            .where(
              (p) => ![
                "KALECİ",
                "DEFANS",
                "ORTA SAHA",
                "FORVET",
              ].contains(p['mevki']),
            )
            .toList()
          ..shuffle();

    List yeniA = [];
    List yeniB = [];

    void dagit(List liste, String bolgeAdi) {
      for (int i = 0; i < liste.length; i++) {
        var oyuncu = liste[i];
        oyuncu['bolge'] = bolgeAdi;
        oyuncu['slotIndex'] = -1;
        (yeniA.length <= yeniB.length) ? yeniA.add(oyuncu) : yeniB.add(oyuncu);
      }
    }

    dagit(kaleciler, "KALECİ");
    dagit(defanslar, "DEFANS");
    dagit(ortalar, "FORVET");
    dagit(forvetler, "FORVET");
    dagit(belirsizler, "DEFANS");

    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .update({'kadro_A': yeniA, 'kadro_B': yeniB});
    setState(() => _yukleniyor = false);
  }

  void _snack(String m) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: const Color(0xFFD4AF37),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    String myUid = _auth.currentUser!.uid;
    if (_cikisYapiliyor)
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            ),
          );
        if (!snapshot.data!.exists) {
          if (!_cikisYapiliyor)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          return const SizedBox();
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String kurucuId = data['kurucuId'];
        bool kurucu = kurucuId == myUid;
        List kadroA = List.from(data['kadro_A'] ?? []);
        List kadroB = List.from(data['kadro_B'] ?? []);
        List yedekler = List.from(data['yedekler'] ?? []);

        bool listedeVarim =
            yedekler.any((p) => p['uid'] == myUid) ||
            kadroA.any((p) => p['uid'] == myUid) ||
            kadroB.any((p) => p['uid'] == myUid);
        if (!listedeVarim && !_yukleniyor) {
          Future.microtask(() => _yedeklereKatil());
        }

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['halisaha'], style: const TextStyle(fontSize: 16)),
                Row(
                  children: [
                    if (data['fiyat'] != null &&
                        data['fiyat'].toString().isNotEmpty)
                      Text(
                        "💰 ${data['fiyat']} ",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.greenAccent,
                        ),
                      ),
                    const SizedBox(width: 10),
                    if (data['telefon'] != null &&
                        data['telefon'].toString().isNotEmpty)
                      GestureDetector(
                        onTap: () => _aramaYap(data['telefon']),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${data['telefon']}",
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(
              color: Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                tooltip: "Maçtan Ayrıl",
                onPressed: () =>
                    _mactanAyril(kadroA, kadroB, yedekler, kurucuId),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                color: const Color(0xFF1A1A1A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFD4AF37),
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          data['kurucuIsim'] ?? "Kaptan",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (kurucu)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                        ),
                        icon: const Icon(
                          Icons.campaign,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Duyuru",
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        onPressed: () =>
                            _duyuruYap(kadroA.length + kadroB.length),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      color: const Color(0xFF0F0F0F),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            "YEDEKLER",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(color: Colors.white12),
                          Expanded(
                            child: DragTarget<Map<String, dynamic>>(
                              onAccept: (oyuncu) =>
                                  _oyuncuTasi(oyuncu, "YEDEK", "YEDEK", -1),
                              builder: (context, candidates, rejects) {
                                return ListView.builder(
                                  itemCount: yedekler.length,
                                  itemBuilder: (context, index) => _miniKart(
                                    yedekler[index],
                                    myUid,
                                    kurucu,
                                    true,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.green.shade900,
                              Colors.green.shade800,
                              Colors.green.shade900,
                            ],
                          ),
                          border: const Border(
                            left: BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double w = constraints.maxWidth;
                            double h = constraints.maxHeight;
                            double kartW = 60;
                            double centerX = (w / 2) - (kartW / 2);
                            double gap = 90;

                            return Stack(
                              children: [
                                Center(
                                  child: Container(
                                    height: 2,
                                    width: double.infinity,
                                    color: Colors.white24,
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white24,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),

                                Positioned(
                                  top: h * 0.02,
                                  left: 5,
                                  child: _pozisyonEtiketi("KL"),
                                ),
                                Positioned(
                                  top: h * 0.13,
                                  left: 5,
                                  child: _pozisyonEtiketi("DEFANS"),
                                ),
                                Positioned(
                                  top: h * 0.25,
                                  left: 5,
                                  child: _pozisyonEtiketi("ORTA SAHA"),
                                ),
                                Positioned(
                                  top: h * 0.38,
                                  left: 5,
                                  child: _pozisyonEtiketi("FORVET"),
                                ),

                                Positioned(
                                  bottom: h * 0.38,
                                  right: 5,
                                  child: _pozisyonEtiketi("FORVET"),
                                ),
                                Positioned(
                                  bottom: h * 0.25,
                                  right: 5,
                                  child: _pozisyonEtiketi("ORTA SAHA"),
                                ),
                                Positioned(
                                  bottom: h * 0.13,
                                  right: 5,
                                  child: _pozisyonEtiketi("DEFANS"),
                                ),
                                Positioned(
                                  bottom: h * 0.03,
                                  right: 5,
                                  child: _pozisyonEtiketi("KL"),
                                ),

                                // A TAKIMI
                                _yerlestir(
                                  h * 0.01,
                                  centerX,
                                  "KALECİ",
                                  "A",
                                  kadroA,
                                  myUid,
                                  kurucu,
                                  0,
                                ),
                                _yerlestir(
                                  h * 0.13,
                                  centerX - gap,
                                  "DEFANS",
                                  "A",
                                  kadroA,
                                  myUid,
                                  kurucu,
                                  0,
                                ),
                                _yerlestir(
                                  h * 0.13,
                                  centerX,
                                  "DEFANS",
                                  "A",
                                  kadroA,
                                  myUid,
                                  kurucu,
                                  1,
                                ),
                                _yerlestir(
                                  h * 0.13,
                                  centerX + gap,
                                  "DEFANS",
                                  "A",
                                  kadroA,
                                  myUid,
                                  kurucu,
                                  2,
                                ),
                                _yerlestir(
                                  h * 0.28,
                                  centerX - gap,
                                  "FORVET",
                                  "A",
                                  kadroA,
                                  myUid,
                                  kurucu,
                                  0,
                                ),
                                _yerlestir(
                                  h * 0.28,
                                  centerX,
                                  "FORVET",
                                  "A",
                                  kadroA,
                                  myUid,
                                  kurucu,
                                  1,
                                ),
                                _yerlestir(
                                  h * 0.28,
                                  centerX + gap,
                                  "FORVET",
                                  "A",
                                  kadroA,
                                  myUid,
                                  kurucu,
                                  2,
                                ),

                                // B TAKIMI
                                _yerlestir(
                                  h * 0.62,
                                  centerX - gap,
                                  "FORVET",
                                  "B",
                                  kadroB,
                                  myUid,
                                  kurucu,
                                  0,
                                ),
                                _yerlestir(
                                  h * 0.62,
                                  centerX,
                                  "FORVET",
                                  "B",
                                  kadroB,
                                  myUid,
                                  kurucu,
                                  1,
                                ),
                                _yerlestir(
                                  h * 0.62,
                                  centerX + gap,
                                  "FORVET",
                                  "B",
                                  kadroB,
                                  myUid,
                                  kurucu,
                                  2,
                                ),
                                _yerlestir(
                                  h * 0.77,
                                  centerX - gap,
                                  "DEFANS",
                                  "B",
                                  kadroB,
                                  myUid,
                                  kurucu,
                                  0,
                                ),
                                _yerlestir(
                                  h * 0.77,
                                  centerX,
                                  "DEFANS",
                                  "B",
                                  kadroB,
                                  myUid,
                                  kurucu,
                                  1,
                                ),
                                _yerlestir(
                                  h * 0.77,
                                  centerX + gap,
                                  "DEFANS",
                                  "B",
                                  kadroB,
                                  myUid,
                                  kurucu,
                                  2,
                                ),
                                _yerlestir(
                                  h * 0.89,
                                  centerX,
                                  "KALECİ",
                                  "B",
                                  kadroB,
                                  myUid,
                                  kurucu,
                                  0,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const Text(
                      "⚠️ Takımları karıştırma ve dizme yetkisi sadece KURUCUYA aittir.",
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    if (kurucu)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _karistir(kadroA, kadroB),
                        icon: const Icon(Icons.shuffle),
                        label: const Text("TAKIMLARI KARIŞTIR"),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pozisyonEtiketi(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _yerlestir(
    double top,
    double left,
    String bolge,
    String takim,
    List kadro,
    String myUid,
    bool kurucu,
    int slotIndex,
  ) {
    var oturan = kadro.firstWhere(
      (p) => p['bolge'] == bolge && p['slotIndex'] == slotIndex,
      orElse: () => null,
    );
    if (oturan == null) {
      var adaylar = kadro
          .where(
            (p) =>
                p['bolge'] == bolge &&
                (p['slotIndex'] == -1 || p['slotIndex'] == null),
          )
          .toList();
      if (adaylar.isNotEmpty && slotIndex < adaylar.length) {
        oturan = adaylar[slotIndex];
      }
    }

    return Positioned(
      top: top,
      left: left,
      child: DragTarget<Map<String, dynamic>>(
        onAccept: (p) => _oyuncuTasi(p, takim, bolge, slotIndex),
        builder: (context, candidates, rejects) {
          return GestureDetector(
            onTap: () => _sahayaGir(takim, bolge, slotIndex),
            child: oturan != null
                ? _miniKart(oturan, myUid, kurucu, false)
                : Container(
                    width: 60,
                    height: 90,
                    decoration: BoxDecoration(
                      color: candidates.isNotEmpty
                          ? Colors.white24
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Center(
                      child: Icon(Icons.add, color: Colors.white30),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _miniKart(
    Map<String, dynamic> p,
    String myUid,
    bool kurucu,
    bool yedekteMi,
  ) {
    bool benim = p['uid'] == myUid;
    Widget kart = GestureDetector(
      onTap: () {
        if (benim && !yedekteMi) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: Colors.black,
              title: const Text(
                "Yedeğe Geç?",
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                "As kadrodan çıkıp yedeğe geçmek ister misin?",
                style: TextStyle(color: Colors.grey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text(
                    "Hayır",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    _yedegeGec();
                  },
                  child: const Text(
                    "Evet",
                    style: TextStyle(color: Color(0xFFD4AF37)),
                  ),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
        width: 60,
        height: 90,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: benim ? Colors.white : const Color(0xFFFFD700),
            width: benim ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 2,
              left: 2,
              child: Text(
                p['formaNo'] ?? "10",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                    image: DecorationImage(
                      image: (p['resimData'] != null)
                          ? MemoryImage(base64Decode(p['resimData']))
                          : const NetworkImage(
                                  "https://cdn-icons-png.flaticon.com/512/3048/3048122.png",
                                )
                                as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                child: Text(
                  p['isim'].toString().split(' ')[0].toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (kurucu) {
      return Draggable<Map<String, dynamic>>(
        data: p,
        feedback: Transform.scale(
          scale: 1.1,
          child: Container(color: Colors.transparent, child: kart),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: kart),
        child: kart,
      );
    }
    return kart;
  }
}
