import 'dart:convert';
import 'dart:io';
// --- AŞAĞIDAKİ SATIR HATAYI ÇÖZER ---
import 'package:flutter/foundation.dart';
// ------------------------------------
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:on_numara/screens/home_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _isimController,
      _boyController,
      _kiloController,
      _formaNoController;
  String? sehir, secilenMevki;
  bool _yukleniyor = false;

  // --- RESİM DEĞİŞKENLERİ ---
  XFile? _yeniResimDosyasi;
  bool _resimSilinsinMi = false;
  final ImagePicker _picker = ImagePicker();
  // --------------------------

  final List<String> mevkiler = ["KALECİ", "DEFANS", "ORTA SAHA", "FORVET"];
  final List<String> sehirler = [
    "Adana",
    "Ankara",
    "Antalya",
    "Bursa",
    "Diyarbakır",
    "Eskişehir",
    "Gaziantep",
    "Hatay",
    "İstanbul",
    "İzmir",
    "Kayseri",
    "Konya",
    "Malatya",
    "Mersin",
    "Samsun",
    "Sivas",
    "Trabzon",
    "Şanlıurfa",
    "Van",
    "Diğer",
  ];

  @override
  void initState() {
    super.initState();
    _isimController = TextEditingController(text: widget.userData['isim']);
    _boyController = TextEditingController(text: widget.userData['boy']);
    _kiloController = TextEditingController(text: widget.userData['kilo']);
    _formaNoController = TextEditingController(
      text: widget.userData['formaNo'],
    );
    sehir = widget.userData['sehir'];

    var m = widget.userData['mevki'] ?? widget.userData['mevkiler'];
    if (m is List) {
      secilenMevki = m.isNotEmpty ? m[0] : null;
    } else {
      secilenMevki = m;
    }
  }

  // --- FOTOĞRAF SEÇME ---
  Future<void> _fotoSec() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        imageQuality: 60,
      );
      if (image != null) {
        setState(() {
          _yeniResimDosyasi = image;
          _resimSilinsinMi = false;
        });
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
    }
  }

  // --- FOTOĞRAF KALDIRMA ---
  void _fotoKaldir() {
    setState(() {
      _yeniResimDosyasi = null;
      _resimSilinsinMi = true;
    });
  }

  Future<void> _guncelle() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _yukleniyor = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      Map<String, dynamic> yeniVeriler = {
        'isim': _isimController.text,
        'boy': _boyController.text,
        'kilo': _kiloController.text,
        'formaNo': _formaNoController.text,
        'sehir': sehir,
        'mevki': secilenMevki,
      };

      String? sonResimData = widget.userData['resimData'];

      if (_resimSilinsinMi) {
        yeniVeriler['resimData'] = null;
        sonResimData = null;
      } else if (_yeniResimDosyasi != null) {
        final bytes = await _yeniResimDosyasi!.readAsBytes();
        String base64Image = base64Encode(bytes);
        yeniVeriler['resimData'] = base64Image;
        sonResimData = base64Image;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(yeniVeriler);

      yeniVeriler['resimData'] = sonResimData;
      yeniVeriler['uid'] = uid;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil güncellendi kral! ✅")),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userData: yeniVeriler),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool resimVarMi =
        (_yeniResimDosyasi != null) ||
        (!_resimSilinsinMi && widget.userData['resimData'] != null);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Profili Düzenle"),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFF222222),
                        backgroundImage: _getProfileImage(),
                        child: !resimVarMi
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white24,
                              )
                            : null,
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.black),
                        onPressed: _fotoSec,
                        tooltip: "Fotoğraf Değiştir",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              if (resimVarMi)
                TextButton.icon(
                  onPressed: _fotoKaldir,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    "Fotoğrafı Kaldır",
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _isimController,
                style: const TextStyle(color: Colors.white),
                decoration: _dec("İsim"),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _boyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec("Boy"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _kiloController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec("Kilo"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _formaNoController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec("No"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF222222),
                      value: sehirler.contains(sehir) ? sehir : null,
                      hint: const Text(
                        "Şehir Seç",
                        style: TextStyle(color: Colors.grey),
                      ),
                      decoration: _dec("Şehir"),
                      items: sehirler
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
                      onChanged: (v) => setState(() => sehir = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF222222),
                value: mevkiler.contains(secilenMevki) ? secilenMevki : null,
                decoration: _dec("Mevki"),
                items: mevkiler
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
                onChanged: (v) => setState(() => secilenMevki = v),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                  ),
                  onPressed: _yukleniyor ? null : _guncelle,
                  child: _yukleniyor
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "GÜNCELLE",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_resimSilinsinMi) return null;

    if (_yeniResimDosyasi != null) {
      // HATA BURADAYDI, ŞİMDİ FOUNDATION SAYESİNDE ÇALIŞACAK
      if (kIsWeb) {
        return NetworkImage(_yeniResimDosyasi!.path);
      } else {
        return FileImage(File(_yeniResimDosyasi!.path));
      }
    }

    if (widget.userData['resimData'] != null &&
        widget.userData['resimData'].toString().isNotEmpty) {
      try {
        return MemoryImage(base64Decode(widget.userData['resimData']));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  InputDecoration _dec(String l) => InputDecoration(
    labelText: l,
    labelStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFF222222),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );
}
