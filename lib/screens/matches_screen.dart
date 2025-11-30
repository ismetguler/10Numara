import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:on_numara/screens/match_lobby_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:on_numara/screens/notification_service.dart'; // BİLDİRİM İÇİN ŞART

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  String? secilenHalisaha;
  String? secilenFormat = "7v7";
  DateTime? secilenTarihHam;
  String tarih = "Tarih Seç";
  String saat = "Saat Seç";
  bool sifreliMi = false;
  String? sifre;

  final TextEditingController _fiyatController = TextEditingController();
  final TextEditingController _telController = TextEditingController();

  bool _yukleniyor = false;

  final List<String> halisahalar = [
    "Mustafa Uğur Halısaha",
    "Kartal Halısaha",
    "Bayraktar Halısaha",
    "Wembley Halısaha",
    "Nuri Has Halısaha",
    "Millet Bahçesi",
    "Erü Halısaha",
    "Ağırnas Halısaha",
    "Rüya Halısaha",
    "Diğer",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    initializeDateFormatting('tr_TR', null);
  }

  Future<void> _tarihSec() async {
    DateTime? p = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale("tr", "TR"),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF222222),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (p != null) {
      setState(() {
        secilenTarihHam = p;
        tarih = DateFormat('d MMMM EEEE', 'tr_TR').format(p);
      });
    }
  }

  Future<void> _saatSec() async {
    TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 00),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) {
      String baslangic =
          "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
      int bitisSaat = (t.hour + 1) % 24;
      String bitis =
          "${bitisSaat.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
      setState(() => saat = "$baslangic - $bitis");
    }
  }

  Future<void> _macOlustur() async {
    if (!_formKey.currentState!.validate()) return;
    if (tarih == "Tarih Seç" || saat == "Saat Seç") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tarih ve Saat seçmelisin kral.")),
      );
      return;
    }
    _formKey.currentState!.save();
    setState(() => _yukleniyor = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      String kurucuIsmi = userDoc.data()!['isim'];
      int kapasite = secilenFormat == "7v7" ? 14 : 16;

      DocumentReference macRef = await FirebaseFirestore.instance
          .collection('matches')
          .add({
            'kurucuId': uid,
            'kurucuIsim': kurucuIsmi,
            'halisaha': secilenHalisaha,
            'format': secilenFormat,
            'tarih': tarih,
            'saat': saat,
            'sifreli': sifreliMi,
            'sifre': sifre,
            'kapasite': kapasite,
            'fiyat': _fiyatController.text,
            'telefon': _telController.text,
            'kadro_A': [],
            'kadro_B': [],
            'yedekler': [],
            'siralamaTarihi': secilenTarihHam ?? DateTime.now(),
            'olusturmaZamani': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance.collection('chat_room').add({
        'text':
            "📢 YENİ MAÇ! \n🏟️ $secilenHalisaha \n📅 $tarih \n⏰ $saat \n⚽ $secilenFormat \n💰 ${_fiyatController.text.isEmpty ? 'Ücretsiz' : _fiyatController.text}",
        'sender': "MAÇ BOTU",
        'uid': "system_bot",
        'time': FieldValue.serverTimestamp(),
        'isMatch': true,
        'matchId': macRef.id,
        'isLocked': sifreliMi,
        'password': sifre,
        'matchData': {
          'halisaha': secilenHalisaha,
          'tarih': tarih,
          'saat': saat,
          'kapasite': kapasite,
          'fiyat': _fiyatController.text,
          'telefon': _telController.text,
        },
      });

      // --- BİLDİRİM GÖNDERME KISMI ---
      await NotificationService.bildirimGonder(
        baslik: "⚽ YENİ MAÇ VAR!",
        icerik: "$secilenHalisaha'da yeni bir maç kuruldu. Hemen kadroya gir!",
      );
      // ------------------------------

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Maç kuruldu ve bildirim gönderildi!")),
        );
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("MAÇ MERKEZİ"),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "MAÇ BUL"),
            Tab(text: "MAÇ KUR"),
            Tab(text: "MAÇLARIM"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _macListesi(sadeceBenimkiler: false),
          _macKurmaFormu(),
          _macListesi(sadeceBenimkiler: true),
        ],
      ),
    );
  }

  Widget _macListesi({required bool sadeceBenimkiler}) {
    String myUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .orderBy('siralamaTarihi', descending: false)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
          );

        var tumMaclar = snapshot.data!.docs;
        var gosterilecekMaclar = tumMaclar;

        if (sadeceBenimkiler) {
          gosterilecekMaclar = tumMaclar.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            List a = data['kadro_A'] ?? [];
            List b = data['kadro_B'] ?? [];
            List y = data['yedekler'] ?? [];
            String k = data['kurucuId'] ?? "";

            return (k == myUid) ||
                a.any((p) => p['uid'] == myUid) ||
                b.any((p) => p['uid'] == myUid) ||
                y.any((p) => p['uid'] == myUid);
          }).toList();
        }

        if (gosterilecekMaclar.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  sadeceBenimkiler
                      ? Icons.sports_handball
                      : Icons.sports_soccer,
                  size: 50,
                  color: Colors.grey,
                ),
                const SizedBox(height: 10),
                Text(
                  sadeceBenimkiler
                      ? "Şu an bi maçta bulunmuyorsun kral."
                      : "Aktif maç yok. Hemen bir tane kur!",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: gosterilecekMaclar.length,
          itemBuilder: (context, index) {
            var data = gosterilecekMaclar[index].data() as Map<String, dynamic>;
            String macId = gosterilecekMaclar[index].id;
            bool kilitli = data['sifreli'] ?? false;

            return GestureDetector(
              onTap: () {
                bool benimMacim = sadeceBenimkiler;
                bool kurucuBenim = data['kurucuId'] == myUid;

                if (!kilitli || benimMacim || kurucuBenim) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MatchLobbyScreen(matchId: macId, matchData: data),
                    ),
                  );
                } else {
                  _sifreSor(context, data['sifre'], macId, data);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white12),
                  boxShadow: sadeceBenimkiler
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sadeceBenimkiler
                              ? const Color(0xFFD4AF37)
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        kilitli ? Icons.lock : Icons.lock_open,
                        color: kilitli
                            ? Colors.red
                            : (sadeceBenimkiler
                                  ? const Color(0xFFD4AF37)
                                  : Colors.green),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['halisaha'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "${data['tarih']}  |  ${data['saat']}",
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (data['fiyat'] != null &&
                              data['fiyat'].toString().isNotEmpty)
                            Text(
                              "💰 ${data['fiyat']}",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data['format'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _macKurmaFormu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF222222),
              value: secilenHalisaha,
              hint: const Text(
                "Halısaha Seç",
                style: TextStyle(color: Colors.grey),
              ),
              decoration: _inputDec("Nerde Oynanacak?", Icons.stadium),
              items: halisahalar
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => secilenHalisaha = v),
              validator: (v) => v == null ? "Seçmelisin" : null,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF222222),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    icon: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFFD4AF37),
                    ),
                    label: Text(
                      tarih,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onPressed: _tarihSec,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF222222),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    icon: const Icon(
                      Icons.access_time,
                      color: Color(0xFFD4AF37),
                    ),
                    label: Text(
                      saat,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onPressed: _saatSec,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF222222),
              value: secilenFormat,
              decoration: _inputDec("Format", Icons.people),
              items: ["7v7", "8v8", "6v6"]
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => secilenFormat = v),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _fiyatController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec(
                "Fiyat (Örn: Kişi Başı 50 TL)",
                Icons.attach_money,
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _telController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec("Telefon (İsteğe Bağlı)", Icons.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),
            SwitchListTile(
              activeColor: const Color(0xFFD4AF37),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Şifreli Maç",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Sadece şifreyi bilenler girebilsin",
                style: TextStyle(color: Colors.grey),
              ),
              value: sifreliMi,
              onChanged: (v) => setState(() => sifreliMi = v),
            ),
            if (sifreliMi)
              TextFormField(
                style: const TextStyle(color: Colors.white),
                decoration: _inputDec("Şifre Belirle", Icons.lock),
                onSaved: (v) => sifre = v,
                validator: (v) => (sifreliMi && (v == null || v.isEmpty))
                    ? "Şifre girmen lazım"
                    : null,
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                onPressed: _yukleniyor ? null : _macOlustur,
                child: _yukleniyor
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        "MAÇI KUR VE YAYINLA",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, color: Colors.grey),
    labelText: label,
    labelStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFF222222),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );

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
          onSubmitted: (v) {
            if (v == gercekSifre) {
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
}
