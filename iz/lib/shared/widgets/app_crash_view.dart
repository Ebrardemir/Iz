/// Bir widget **build sırasında** patladığında kullanıcının göreceği son çare
/// ekranı. `ErrorWidget.builder` bunu döndürür.
///
/// [AppErrorView] İLE KARIŞTIRMA — ikisi farklı iş yapar:
///   • `AppErrorView`  → uygulama içinde beklenen bir hata durumu
///     (veri çekilemedi, yeniden dene). Temalı, çevrilmiş, eylemli.
///   • `AppCrashView`  → beklenmeyen bir çökme. Tema ve çeviri MEVCUT
///     OLMAYABİLİR, çünkü hata `MaterialApp`in kendi ağacında oluşmuş olabilir.
///
/// NEDEN VARSAYILAN YETMİYOR?
/// Flutter'ın varsayılanı hata mesajını ve yığın izini gösteren kırmızı bir
/// ekrandır. Geliştirirken gerekli, kullanıcıda iki sebeple kabul edilemez:
/// korkutucu, ve hata metni bir anının başlığını taşıyabilir
/// (NFR-014 — kişisel içerik hata çıktısına sızmamalı).
///
/// Anahtarlama `installGlobalErrorHandlers` içinde: debug'da kırmızı ekran
/// KALIR, aksi hâlde bu ekran devreye girer.
///
/// KURAL: Bu widget hiçbir koşulda hata fırlatmamalı. Bu yüzden burada
/// `Localizations`, `Theme` veya `AppColors` ARANMAZ — hiçbiri mevcut
/// olmayabilir. Metin gömülü, renkler sabit. Sadeliği bilinçli:
/// doğru çalışması güzel görünmesinden önemli.
library;

import 'package:flutter/material.dart';

class AppCrashView extends StatelessWidget {
  const AppCrashView({super.key});

  // Açık ve koyu zeminde de okunur kalan nötr değerler.
  static const Color _bg = Color(0xFFFAF8F3);
  static const Color _ink = Color(0xFF24241F);
  static const Color _inkSoft = Color(0xFF6F6C65);

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: _bg,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: _inkSoft),
                SizedBox(height: 16),
                Text(
                  'Bir şeyler ters gitti',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Bu ekran açılamadı. Anıların yerinde duruyor.\n'
                  'Geri dönüp tekrar deneyebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5, color: _inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
