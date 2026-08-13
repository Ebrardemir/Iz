/// KİŞİ DETAYI İÇİN GEÇİCİ VERİ.
///
/// ⚠️ ÜRETİM VERİSİ DEĞİL. Kişinin koleksiyonlarını ve ritüellerini okuyacak
/// katman yok (`PersonDao`, `CollectionDao`, `RitualDao` yazılmadı); ekranın
/// dolu hâlini görebilmek için elle yazıyoruz.
///
/// ⚠️ KOLEKSİYON KİMLİKLERİ "HAYATIM" EKRANINDAKİLERLE AYNI OLMAK ZORUNDA.
/// Bir koleksiyon satırına dokunmak Hayatım'ın koleksiyonlar sekmesini o kişiye
/// süzülmüş hâlde açıyor; süzme kimlik üzerinden çalışıyor. Ad, görsel ve anı
/// sayısı burada TEKRAR EDİYOR çünkü iki ekran ayrı feature'larda ve biri
/// ötekinin önizleme verisini import edemez (bkz. ARCHITECTURE.md).
///
/// Veri bağlandığında ikisi de repository'den gelecek ve bu tekrar kalkacak;
/// o güne kadar kimlikler bağı kuruyor.
///
/// İçindeki "Kapadokya 2026", "Doğum Günleri" gibi metinler KULLANICI VERİSİ
/// taklidi — çeviriden geçmezler, geçmemeleri de gerekir
/// (bkz. `test/unit/l10n_test.dart` istisna listesi).
library;

/// Kişi detayındaki bir koleksiyon satırı.
typedef PersonCollection = ({
  /// "Hayatım" ekranındaki koleksiyonla AYNI kimlik — süzme buna dayanıyor.
  String id,
  String coverAsset,
  String title,
  int memoryCount,
});

/// Kişi detayındaki bir ritüel satırı.
///
/// [iconKey] taşınıyor, `IconData` DEĞİL: ikon seti değişse bile kullanıcının
/// verisi bozulmamalı (aynı kural ritüel ve kategori tablolarında da var).
typedef PersonRitual = ({String iconKey, String title, int years});

abstract final class PersonDetailPreviewData {
  /// Kişi kimliği → o kişiyle paylaşılan koleksiyonlar.
  ///
  /// Kimlikler `my_life_preview_data.dart`taki koleksiyonlarla eşleşiyor:
  /// 'col-kapadokya', 'col-universite', 'col-kahvaltilar'.
  static const Map<String, List<PersonCollection>> _collections = {
    'person-annem': [
      (
        id: 'col-kapadokya',
        coverAsset: 'assets/images/home/hero_today.jpg',
        title: 'Kapadokya 2026',
        memoryCount: 8,
      ),
      (
        id: 'col-kahvaltilar',
        coverAsset: 'assets/images/home/memory_coffee.jpg',
        title: 'Pazar Kahvaltıları',
        memoryCount: 12,
      ),
    ],
    'person-babam': [
      (
        id: 'col-kapadokya',
        coverAsset: 'assets/images/home/hero_today.jpg',
        title: 'Kapadokya 2026',
        memoryCount: 8,
      ),
    ],
    'person-elif': [
      (
        id: 'col-universite',
        coverAsset: 'assets/images/auth/hero_light.jpg',
        title: 'Üniversite Yıllarım',
        memoryCount: 24,
      ),
    ],
    // Kalan kişilerde koleksiyon YOK — bölümün boş hâli de tasarımın parçası.
  };

  /// Kişi kimliği → o kişinin dahil olduğu ritüeller.
  static const Map<String, List<PersonRitual>> _rituals = {
    'person-annem': [
      (iconKey: 'birthday', title: 'Doğum Günleri', years: 5),
      (iconKey: 'anniversary', title: 'Anneler Günü', years: 4),
      (iconKey: 'summer', title: 'Aile Tatilleri', years: 3),
    ],
    'person-babam': [
      (iconKey: 'birthday', title: 'Doğum Günleri', years: 5),
      (iconKey: 'summer', title: 'Aile Tatilleri', years: 3),
    ],
    'person-ayse': [(iconKey: 'birthday', title: 'Doğum Günleri', years: 2)],
  };

  /// Verilen kişinin koleksiyonları; yoksa boş liste.
  static List<PersonCollection> collectionsOf(String personId) =>
      _collections[personId] ?? const [];

  /// Verilen kişinin ritüelleri; yoksa boş liste.
  static List<PersonRitual> ritualsOf(String personId) =>
      _rituals[personId] ?? const [];

  /// Bir koleksiyonda BU KİŞİ var mı?
  ///
  /// "Hayatım" ekranı koleksiyonları kişiye göre süzerken buna bakıyor.
  /// Süzme mantığı kişi tarafında duruyor çünkü ilişkiyi tanımlayan taraf
  /// burası — koleksiyonun kendisi kimlerle paylaşıldığını bilmiyor.
  static bool collectionHasPerson(String collectionId, String personId) =>
      collectionsOf(personId).any((c) => c.id == collectionId);
}
