/// SERİ DETAY EKRANI İÇİN GEÇİCİ VERİ.
///
/// ⚠️ ÜRETİM VERİSİ DEĞİL. `RitualDao` yazılmadı; serinin anılarını okuyacak
/// sorgu yok. Ekranın dolu hâlini görebilmek için "Hayatım"daki seri
/// kartlarıyla AYNI kimlikleri kullanan kayıtları elle yazıyoruz
/// (`rit-yaz`, `rit-dogumgunu`, `rit-yildonumu`).
///
/// ANI KİMLİKLERİ DE UYUMLU: `<seriKimliği>-<yıl>` biçiminde, yani seri
/// şeridinden ve buradan açılan anı AYNI kayda gidiyor
/// (`MyLifePreviewData.seriesYearDetail`). Kullanıcı uygulamada dolaşırken
/// aynı anıyı iki farklı yerde farklı görmemeli.
///
/// İçindeki "Kaş'ta gün batımı", "Seyahat" gibi metinler KULLANICI VERİSİ
/// taklidi — çeviriden geçmezler (`l10n_test.dart` istisnası yalnızca bu
/// dosyaya açıldı; öteki önizleme dosyalarıyla aynı gerekçe).
library;

/// Seri detayındaki tek anı satırı.
///
/// [categoryLabel] ve [placeLabel] OPSİYONEL: gerçek veride ikisi de boş
/// olabilir ve ekranın onları nasıl karşıladığını tasarım aşamasında görmek
/// istiyoruz.
typedef RitualDetailMemory = ({
  String id,
  String imageAsset,
  String title,
  String dateLabel,
  int year,
  String? categoryLabel,
  String? placeLabel,
});

abstract final class RitualDetailPreviewData {
  /// [ritualId] serisinin anıları — en yeniden eskiye.
  static List<RitualDetailMemory> memoriesOf(String ritualId) =>
      _memories[ritualId] ?? const [];

  static const Map<String, List<RitualDetailMemory>> _memories = {
    'rit-yaz': [
      (
        id: 'rit-yaz-2026',
        imageAsset: 'assets/images/home/hero_today.jpg',
        title: 'Çeşme’de gün batımı',
        dateLabel: '14 Temmuz 2026',
        year: 2026,
        categoryLabel: 'Seyahat',
        placeLabel: 'Çeşme',
      ),
      (
        id: 'rit-yaz-2025',
        imageAsset: 'assets/images/home/memory_coffee.jpg',
        title: 'Kekova tekne turu',
        dateLabel: '20 Temmuz 2025',
        year: 2025,
        categoryLabel: 'Seyahat',
        placeLabel: 'Kaş',
      ),
      (
        id: 'rit-yaz-2024',
        imageAsset: 'assets/images/auth/hero_light.jpg',
        title: 'Datça’da sabah yüzüşü',
        dateLabel: '8 Ağustos 2024',
        year: 2024,
        categoryLabel: 'Seyahat',
        placeLabel: 'Datça',
      ),
      (
        id: 'rit-yaz-2023',
        imageAsset: 'assets/images/home/hero_today.jpg',
        title: 'Çeşme’de ilk yaz',
        dateLabel: '12 Temmuz 2023',
        year: 2023,
        categoryLabel: 'Seyahat',
        placeLabel: 'Çeşme',
      ),
      // Beşinci ve altıncı kayıt BİLEREK var: liste kısaltma sınırını
      // (`kCollapsedCount`) aşıyor ve "Tümünü Gör" görünür hâle geliyor.
      (
        id: 'rit-yaz-2022',
        imageAsset: 'assets/images/home/memory_coffee.jpg',
        title: 'Ayvalık’ta bisikletli akşam',
        dateLabel: '3 Ağustos 2022',
        year: 2022,
        categoryLabel: 'Seyahat',
        placeLabel: 'Ayvalık',
      ),
      (
        id: 'rit-yaz-2021',
        imageAsset: 'assets/images/auth/hero_light.jpg',
        title: 'Ayvalık’ta ilk kamp',
        dateLabel: '29 Temmuz 2021',
        year: 2021,
        // Kategorisi YOK: satırın çipsiz hâlini de görmek istiyoruz.
        categoryLabel: null,
        placeLabel: 'Ayvalık',
      ),
    ],
    'rit-dogumgunu': [
      (
        id: 'rit-dogumgunu-2026',
        imageAsset: 'assets/images/home/memory_coffee.jpg',
        title: 'Annemin 60. yaşı',
        dateLabel: '3 Mart 2026',
        year: 2026,
        categoryLabel: 'Aile',
        placeLabel: 'Ankara',
      ),
      (
        id: 'rit-dogumgunu-2025',
        imageAsset: 'assets/images/auth/hero_light.jpg',
        title: 'Mutfakta pasta telaşı',
        dateLabel: '3 Mart 2025',
        year: 2025,
        categoryLabel: 'Aile',
        placeLabel: 'Ankara',
      ),
      (
        id: 'rit-dogumgunu-2024',
        imageAsset: 'assets/images/home/hero_today.jpg',
        title: 'İzmir’de sürpriz kutlama',
        dateLabel: '3 Mart 2024',
        year: 2024,
        categoryLabel: 'Aile',
        placeLabel: 'İzmir',
      ),
    ],
    'rit-yildonumu': [
      (
        id: 'rit-yildonumu-2026',
        imageAsset: 'assets/images/auth/hero_light.jpg',
        title: 'Evde sessiz bir akşam',
        dateLabel: '15 Mayıs 2026',
        year: 2026,
        categoryLabel: 'Anılar',
        // Konumu YOK: "şehir" kutusunun eksik veriyle nasıl davrandığını
        // görmek için.
        placeLabel: null,
      ),
      (
        id: 'rit-yildonumu-2025',
        imageAsset: 'assets/images/home/hero_today.jpg',
        title: 'Venedik’te yıldönümü',
        dateLabel: '15 Mayıs 2025',
        year: 2025,
        categoryLabel: 'Seyahat',
        placeLabel: 'Venedik',
      ),
    ],
  };
}
