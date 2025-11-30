import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class CardScreen extends StatelessWidget {
  final String isim;
  final dynamic mevkiler;
  final String sehir;
  final String boy;
  final String kilo;
  final XFile? resimDosyasi;
  final String? resimBase64;
  final String formaNo;
  final bool backButtonVarMi;

  const CardScreen({
    super.key,
    required this.isim,
    required this.mevkiler,
    required this.sehir,
    required this.boy,
    required this.kilo,
    this.resimDosyasi,
    this.resimBase64,
    required this.formaNo,
    this.backButtonVarMi = true,
  });

  @override
  Widget build(BuildContext context) {
    String mevkiYazisi = "";
    if (mevkiler is List) {
      mevkiYazisi = (mevkiler as List).join(" - ");
    } else {
      mevkiYazisi = mevkiler.toString();
    }

    // Ekran boyutuna göre ölçekleme yapısı
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Eğer ekran çok küçükse kartı küçült
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              width: 320,
              height: 500,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD4AF37), Color(0xFFAA8822), Colors.black],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: const Color(0xFFFFD700), width: 2),
              ),
              child: Stack(
                children: [
                  // Forma No
                  Positioned(
                    top: 25,
                    left: 25,
                    child: Text(
                      formaNo,
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(2, 2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Logo
                  const Positioned(
                    top: 25,
                    right: 25,
                    child: Icon(
                      Icons.sports_soccer,
                      color: Colors.white24,
                      size: 45,
                    ),
                  ),
                  // Resim
                  Positioned(
                    top: 110,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.black45,
                              blurRadius: 10,
                            ),
                          ],
                          color: Colors.black26,
                          image: DecorationImage(
                            image: _resimSaglayici(),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bilgiler
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Text(
                          isim.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            mevkiYazisi,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white38, thickness: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoBox("BOY", boy.isEmpty ? "-" : boy),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.white24,
                            ),
                            _infoBox("ŞEHİR", sehir),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.white24,
                            ),
                            _infoBox("KİLO", kilo.isEmpty ? "-" : kilo),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (backButtonVarMi)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white54,
                            size: 20,
                          ),
                          label: const Text(
                            "Geri Dön",
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  ImageProvider _resimSaglayici() {
    if (resimDosyasi != null) {
      return kIsWeb
          ? NetworkImage(resimDosyasi!.path)
          : FileImage(File(resimDosyasi!.path)) as ImageProvider;
    }
    if (resimBase64 != null && resimBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(resimBase64!));
      } catch (e) {
        return const NetworkImage(
          "https://cdn-icons-png.flaticon.com/512/3048/3048122.png",
        );
      }
    }
    return const NetworkImage(
      "https://cdn-icons-png.flaticon.com/512/3048/3048122.png",
    );
  }

  Widget _infoBox(String label, String val) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      Text(
        val,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ],
  );
}
