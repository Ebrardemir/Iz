/// Kimlik ekranlarının ortak iskeleti: üstte görsel, üzerine binen kavisli kart.
///
/// NEDEN AYRI BİLEŞEN?
/// Giriş ve kayıt ekranları aynı düzeni paylaşıyor. Kopyalasaydık iki dosya
/// zamanla birbirinden ayrışırdı: birinde düzeltilen bir kenar boşluğu
/// ötekinde eski kalırdı. Buradaki hesap (görselin yüksekliği, kartın binmesi,
/// klavye payı) tek yerde duruyor.
///
/// KULLANIM:
/// ```dart
/// AuthScaffold(
///   formHeight: 552,   // kart içeriğinin ÖLÇÜLMÜŞ yüksekliği
///   child: Column(...),
/// )
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/auth/presentation/widgets/auth_hero.dart';

/// Formun okunabilir kalacağı azami genişlik. Bunun üstünde metin satırları
/// gözün takip edemeyeceği kadar uzar.
const double _kFormMaxWidth = 460;

/// Kartın görselin üzerine bindiği miktar — tasarımdaki yumuşak geçiş.
/// Köşe yarıçapıyla (40) uyumlu: daha az binerse kavis yarım görünür.
const double _kCardOverlap = 42;

/// Görsel en az bu kadar yer kaplar; altında tanınmaz bir şeride döner.
const double _kHeroMinHeight = 150;

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.formHeight,
    required this.child,
    super.key,
  });

  /// Kart içeriğinin (kendi kenar boşlukları dahil) kapladığı yükseklik.
  ///
  /// ⚠️ ÖLÇÜLMÜŞ DEĞER, tahmin değil. Görsel bu alandan ARTAKALANI alır;
  /// yanlış verilirse içerik ekrandan taşar. Forma yeni bir alan eklersen
  /// büyütmen gerekir — ilgili ekranın testi bunu yakalar.
  final double formHeight;

  /// Kartın içine çizilecek form.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Kartın kendi rengi var; scaffold zemini görselin arkasında kalıyor.
      backgroundColor: context.colors.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Jest çubuğu / sistem gezinme çubuğunun kapladığı şerit.
          // Kartın içindeki `SafeArea` bu kadar dolgu ekliyor, yani form
          // GERÇEKTE `formHeight + safeBottom` kadar yer kaplıyor. Hesaba
          // katmazsak görsele fazla yer ayırıp formu ekrandan taşırıyoruz;
          // sayfa o kadar kayıyor ve kart ekranın dibine oturmuyor.
          final safeBottom = context.media.padding.bottom;
          final heroHeight = _heroHeightFor(constraints, safeBottom);

          return SingleChildScrollView(
            // Klavye açıldığında son alan görünür kalsın.
            padding: EdgeInsets.only(bottom: context.media.viewInsets.bottom),
            child: ConstrainedBox(
              // Kısa içerikte kart ekranın altına kadar uzasın.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Stack(
                children: [
                  SizedBox(
                    height: heroHeight,
                    width: double.infinity,
                    child: const AuthHero(),
                  ),

                  // Kart görselin üzerine biner: Stack yüksekliğini bu dal
                  // belirlediği için altta boşluk kalmaz.
                  Padding(
                    padding: EdgeInsets.only(top: heroHeight - _kCardOverlap),
                    // Kart SAYFANIN SONUNA KADAR uzasın: içerik kısa kalırsa
                    // kartın zemini erken biter ve altında scaffold rengi
                    // görünürdü. Asgari yükseklik vererek kartı ekranın
                    // dibine yapıştırıyoruz.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight - heroHeight + _kCardOverlap,
                      ),
                      child: _AuthCard(child: child),
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

  /// Görselin yüksekliği.
  ///
  /// KURAL: **önce form, artan yer görsele.**
  ///
  /// Sadece orana (%36) bakmak yetmiyordu: aynı oran uzun telefonda güzel
  /// dururken kısa telefonda formu ekran dışına itiyor ve alttaki metni
  /// kesiyordu. Burada görsel, formun ihtiyacı karşılandıktan SONRA kalan
  /// alanı alıyor — yani dekor, içeriğin yerini asla çalmıyor.
  ///
  /// Üç sınır birlikte çalışır:
  ///   • Tercih edilen: ekranın %36'sı (yatayda %38).
  ///   • Tavan: [formHeight] kadar yer forma ayrıldıktan sonra kalan.
  ///   • Taban: [_kHeroMinHeight] — görsel tanınmaz hâle gelmesin.
  double _heroHeightFor(BoxConstraints constraints, double safeBottom) {
    final height = constraints.maxHeight;
    final isLandscape = constraints.maxWidth > height;
    final ratio = isLandscape ? 0.38 : 0.36;

    final preferred = (height * ratio).clamp(_kHeroMinHeight, 300.0);

    // `+ _kCardOverlap` UNUTULMAMALI: kart görselin üzerine [_kCardOverlap]
    // kadar biniyor, yani toplam yükseklik `görsel + form - binme`. Payı
    // eklemezsek görsele tam bu kadar (42px) haksız yere az yer veririz;
    // ekranda kart olması gerekenden yukarıda başlar ve altta boşluk kalır.
    //
    // `- safeBottom`: form o şeridin ÜSTÜNDE bitmeli. Simülatörde jest
    // çubuğu yok, gerçek telefonda var — bu yüzden hata yalnızca cihazda
    // görünüyordu.
    final leftAfterForm = height - formHeight - safeBottom + _kCardOverlap;

    return math.max(_kHeroMinHeight, math.min(preferred, leftAfterForm));
  }
}

/// Görselin üzerine binen, üstten kavisli panel.
class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Figma'daki "Background/App" (açık FAF8F3 / koyu 141914).
        color: context.colors.surface,
        borderRadius: AppRadius.topPanel,
        // Kartın üst kenarı fotoğrafın üzerine biniyor. Gölge olmadan iki
        // yüzey aynı düzlemde duruyor ve kavis "kesilmiş" gibi okunuyordu;
        // yukarı doğru yumuşak bir gölge köşeleri belirginleştirip kartı
        // fotoğrafın ÜSTÜNE oturtuyor.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // Yatay kenar boşluğu `lg`: referanstaki gibi alanlar ekran
          // kenarından belirgin şekilde içeride dursun.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          // RESPONSIVE: geniş ekranda form ortalanır ve okunur genişlikte kalır.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
