/// Ana sayfanın ORTAK ölçüleri.
///
/// Sayfadaki üç blok (fotoğraf üzerindeki metin, sayaç ızgarası, son anılar)
/// aynı Figma çerçevesinden geliyor ve aynı hizada duruyor. Bu sayı üç ayrı
/// dosyada ayrı ayrı yazılıydı; biri değişince ötekiler sessizce kayıyordu.
/// Tek kaynak olarak buraya taşındı.
library;

abstract final class HomeLayout {
  /// Figma: her blok `left: 20, width: 350` — yani ekranın iki yanından
  /// 20 px içeride.
  ///
  /// Bu bir MARJDIR, ölçeklenmez: geniş ekranda bloklar genişler, kenar
  /// boşluğu sabit kalır.
  static const double pageInset = 20;
}
