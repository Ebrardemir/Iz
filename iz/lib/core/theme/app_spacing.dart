/// Tasarım tokenları: boşluk, köşe yarıçapı, animasyon süreleri.
///
/// NEDEN?
/// Widget içinde `EdgeInsets.all(16)` yazmak kısa vadede hızlıdır ama
/// 40 ekrandan sonra 12/14/16/18 karışımı bir kaos olur. Token kullanınca
/// tüm uygulamanın ritmi tek dosyadan ayarlanır.
///
/// KULLANIM: `padding: EdgeInsets.all(AppSpacing.md)`
library;

import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  /// 4 — ikon ile metin arası gibi çok küçük ayrımlar
  static const double xs = 4;

  /// 8 — ilişkili öğeler arası
  static const double sm = 8;

  /// 16 — varsayılan ekran kenar boşluğu
  static const double md = 16;

  /// 24 — bölümler arası
  static const double lg = 24;

  /// 32 — büyük ayrımlar
  static const double xl = 32;

  /// 48 — boş durum ekranlarındaki nefes alanı
  static const double xxl = 48;

  /// Ekranların standart yatay kenar boşluğu.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: md);

  /// NFR-033: "Dokunma hedefleri platform erişilebilirlik önerilerine uygun
  /// boyutta olmalıdır." Material ve iOS için asgari 48dp/44pt → 48 alıyoruz.
  static const double minTapTarget = 48;
}

/// İkon boyutları.
///
/// Tasarımın standart ikon ölçüsü **28**. Widget'ta `size: 28` YAZMA —
/// zaten temada varsayılan olarak ayarlı (bkz. `app_theme.dart` → `iconTheme`),
/// yani çoğu yerde boyut vermene hiç gerek yok. Farklı bir ölçü gerekiyorsa
/// buradaki token'lardan birini kullan.
abstract final class AppIconSize {
  /// 16 — metin içine gömülü küçük rozetler (kart üzerindeki sayaçlar).
  static const double sm = 16;

  /// 20 — çip ve liste satırı ikonları.
  static const double md = 20;

  /// 28 — TASARIM VARSAYILANI. Sekme çubuğu, AppBar, buton ikonları.
  static const double lg = 28;

  /// 48 — boş durum ve hata ekranlarındaki büyük görsel.
  static const double xl = 48;

  /// 72 — onboarding sayfalarının ana görseli.
  static const double xxl = 72;
}

abstract final class AppRadius {
  static const Radius xs = Radius.circular(4);
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(16);
  static const Radius xl = Radius.circular(24);

  /// 40 — görselin üzerine binen büyük yüzeyler (giriş ekranı kartı).
  /// Küçük yarıçap bu ölçekte "kavis" değil "köşe kırpma" gibi durur.
  static const Radius xxl = Radius.circular(40);

  static const BorderRadius card = BorderRadius.all(lg);
  static const BorderRadius sheet = BorderRadius.vertical(top: xl);

  /// İÇİNDE KENDİ SATIRLARI OLAN geniş kartlar (seri kartı) — 20.
  ///
  /// Ölçekte [lg] (16) ile [xl] (24) arasında bilinçli bir ara basamak.
  /// Bu ölçekte 16 "köşe kırpma" gibi duruyor, 24 ise kartı balona
  /// çeviriyor. Ham bir `Radius` yerine anlamsal bir ad veriyoruz ki
  /// aynı rolü paylaşan kartlar tek yerden değişsin — `card`, `sheet` ve
  /// `topPanel` de aynı mantıkla adlandırıldı.
  static const BorderRadius contentCard = BorderRadius.all(Radius.circular(20));

  /// Tam genişlikte, üstten kavisli panel (giriş / kayıt ekranı).
  static const BorderRadius topPanel = BorderRadius.vertical(top: xxl);

  /// Küçük etiket çipleri — pill'e dönmesin diye küçük kalır.
  static const BorderRadius chip = BorderRadius.all(sm);

  /// Form alanları ve butonlar AYNI yarıçapı paylaşır: alt alta dizildiklerinde
  /// köşeleri birbirini tutmazsa liste kırık görünür.
  static const BorderRadius input = BorderRadius.all(lg);
  static const BorderRadius button = BorderRadius.all(lg);

  /// Tasarımdaki `border-radius: 999` — yani "yüksekliğin yarısı kadar",
  /// hap biçimi. Yüksekliğin yarısını elle yazmak yerine büyük sabit bir
  /// yarıçap kullanıyoruz: kutu boyu değişse de sonuç hep tam hap olur.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Arama kutusu gibi girdilerde gereksiz sorguyu engeller (NFR-002).
  static const Duration debounce = Duration(milliseconds: 300);
}
