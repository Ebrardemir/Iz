/// "Hayatım" ekranının ORTAK ölçüleri.
///
/// Ekrandaki her blok (üst şerit, sekme çubuğu, ay gezinmesi, takvim) aynı
/// Figma çerçevesinden geliyor ve aynı hizada duruyor. Ana sayfada bu sayıyı
/// üç ayrı dosyada tutmuştuk ve biri değişince ötekiler sessizce kaymıştı;
/// burada baştan tek kaynak.
library;

abstract final class MyLifeLayout {
  /// Figma: her blok `left: 20, width: 350`.
  ///
  /// Bu bir MARJDIR, ölçeklenmez: geniş ekranda bloklar genişler, kenar
  /// boşluğu sabit kalır.
  static const double pageInset = 20;

  /// Takvim haftada yedi sütun.
  static const int weekdayCount = 7;

  /// Haftanın İLK GÜNÜ pazartesi.
  ///
  /// `DateTime.monday == 1`. Türkiye ve Avrupa'nın büyük kısmı böyle;
  /// tasarım da pazartesiyle başlıyor. ABD gibi pazar günüyle başlayan
  /// yerler için ileride dile göre seçilebilir — o gün değişecek TEK yer
  /// burası, hem başlık satırı hem ızgara buradan okuyor.
  static const int firstWeekday = DateTime.monday;
}
