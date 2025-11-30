import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Web kontrolü için
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:on_numara/screens/home_screen.dart';
import 'package:on_numara/screens/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String? email;
  String? password;
  String? isim;
  String sehir = "Kayseri";
  String? secilenMevki;
  XFile? _secilenResim;
  String formaNo = "10";
  bool _yukleniyor = false;

  final TextEditingController _boyController = TextEditingController();
  final TextEditingController _kiloController = TextEditingController();
  final TextEditingController _formaNoController = TextEditingController(
    text: "10",
  );

  final List<String> sehirler = ["Kayseri", "Diğer"];

  final List<String> mevkiler = ["KALECİ", "DEFANS", "ORTA SAHA", "FORVET"];

  Future<void> _resimSec() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 60,
    );
    if (image != null) setState(() => _secilenResim = image);
  }

  Future<void> _kayitOl() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (secilenMevki == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bir mevki seç kral.")),
      );
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      String? resimVerisi;
      if (_secilenResim != null) {
        final bytes = await _secilenResim!.readAsBytes();
        resimVerisi = base64Encode(bytes);
      }

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email!.trim(),
            password: password!.trim(),
          );

      String uid = userCredential.user!.uid;

      Map<String, dynamic> userMap = {
        'uid': uid,
        'email': email,
        'isim': isim,
        'sehir': sehir,
        'boy': _boyController.text,
        'kilo': _kiloController.text,
        'formaNo': formaNo,
        'mevki': secilenMevki,
        'mevkiler': [secilenMevki], // Eski uyumluluk için
        'resimData': resimVerisi,
        'kayitTarihi': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userMap);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userData: userMap),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      String hata = "Hata oluştu: $e";
      if (e.toString().contains("email-already-in-use"))
        hata = "Bu e-posta zaten kullanımda.";
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(hata)));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Profil Oluştur"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a1a), Color(0xFF000000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _resimSec,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF222222),
                        backgroundImage: _secilenResim != null
                            ? (kIsWeb
                                  ? NetworkImage(_secilenResim!.path)
                                  : FileImage(File(_secilenResim!.path))
                                        as ImageProvider)
                            : null,
                        child: _secilenResim == null
                            ? const Icon(
                                Icons.add_a_photo,
                                color: Colors.white54,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec("E-posta"),
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (v) => email = v,
                    validator: (v) => v!.contains("@") ? null : "Geçersiz",
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec("Şifre (En az 6 hane)"),
                    obscureText: true,
                    onSaved: (v) => password = v,
                    validator: (v) => v!.length > 5 ? null : "Kısa",
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 20),
                  _buildTF("İsim Soyisim", (v) => isim = v),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _formaNoController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec("No"),
                          keyboardType: TextInputType.number,
                          onSaved: (v) => formaNo = v!.isEmpty ? "10" : v,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF222222),
                          value: sehirler.contains(sehir) ? sehir : null,
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
                          // DÜZELTİLEN YER: "as String" kaldırıldı
                          onChanged: (v) => setState(() => sehir = v!),
                          decoration: _inputDec("Şehir"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _boyController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec("Boy"),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? "Gir" : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _kiloController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec("Kilo"),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? "Gir" : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF222222),
                    value: secilenMevki,
                    decoration: _inputDec("Ana Mevkin Ne?"),
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
                      onPressed: _yukleniyor ? null : _kayitOl,
                      child: _yukleniyor
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              "HESABI OLUŞTUR",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    ),
                    child: const Text(
                      "Zaten hesabın var mı? Giriş Yap",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextFormField _buildTF(String label, Function(String?) s) => TextFormField(
    style: const TextStyle(color: Colors.white),
    decoration: _inputDec(label),
    onSaved: s,
    validator: (v) => v!.isEmpty ? "Gerekli" : null,
  );

  InputDecoration _inputDec(String l) => InputDecoration(
    labelText: l,
    labelStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFF2A2A2A),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );
}
