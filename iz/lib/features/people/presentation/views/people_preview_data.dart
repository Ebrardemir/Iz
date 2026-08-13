/// TASARIM ÖNİZLEMESİ İÇİN SAHTE VERİ.
///
/// ⚠️ ÜRETİM VERİSİ DEĞİL. Kişileri okuyacak katman henüz yok (`PersonDao`,
/// `PersonRepository` yazılmadı); listenin dolu hâlini ve aramanın çalıştığını
/// görebilmek için referans tasarımdaki kişileri burada elle yazıyoruz.
///
/// İçindeki "Annem", "Elif" gibi adlar KULLANICI VERİSİ taklidi — çeviriden
/// geçmezler, geçmemeleri de gerekir. Çeviri koruma testi
/// (`test/unit/l10n_test.dart`) sabit Türkçe metin arıyor; istisnayı ekranın
/// tamamına açmak yerine yalnızca bu dosyaya açtık — `home_preview_data.dart`
/// ve `my_life_preview_data.dart` ile aynı gerekçe.
///
/// FOTOĞRAF YOK ve bu bilinçli: `avatarMediaId` alanı entity'de duruyor ama
/// onu bir `MediaItem`a çevirecek hat kurulmadı. Liste bu yüzden ikonlu
/// avatarı gösteriyor — fotoğrafsız kişi gerçek uygulamada da olacak bir
/// durum, yani atılacak bir yer tutucu değil.
///
/// Veri bağlandığında bu dosya SİLİNECEK.
library;

import 'package:iz/features/people/domain/entities/person.dart';

abstract final class PeoplePreviewData {
  /// Referans tasarımdaki altı kişi.
  ///
  /// İlişki türleri BİLEREK çeşitli: arama hem adda hem ilişkide çalışıyor ve
  /// hepsi "Arkadaşım" olsaydı ikinci yolun çalıştığını göremezdik.
  /// `const` DEĞİL: `DateTime` sabit ifade olamıyor, doğum tarihleri de bu
  /// listede duruyor.
  static final List<Person> people = [
    Person(
      id: 'person-annem',
      name: 'Annem',
      note: 'En büyük destekçim, canım annem.',
      birthDate: DateTime(1968, 4, 18),
      kind: PersonKind.human,
      relationType: RelationType.parent,
    ),
    Person(
      id: 'person-babam',
      name: 'Babam',
      note: 'Bana sabrı öğreten adam.',
      birthDate: DateTime(1965, 11, 3),
      kind: PersonKind.human,
      relationType: RelationType.parent,
    ),
    Person(
      id: 'person-elif',
      name: 'Elif',
      note: 'Lisede yan yana oturduk, hâlâ yanımda.',
      birthDate: DateTime(1996, 8, 15),
      relationLabel: 'En yakın arkadaşım',
      kind: PersonKind.human,
      relationType: RelationType.friend,
    ),
    const Person(
      id: 'person-ahmet',
      name: 'Ahmet',
      kind: PersonKind.human,
      relationType: RelationType.friend,
    ),
    const Person(
      id: 'person-ayse',
      name: 'Ayşe',
      relationLabel: 'Ablam',
      kind: PersonKind.human,
      relationType: RelationType.sibling,
    ),
    const Person(
      id: 'person-dede',
      name: 'Dede',
      kind: PersonKind.human,
      relationType: RelationType.grandparent,
    ),
    // Türkçe arama tuzağını ekranda da görebilmek için: "irem" yazınca
    // bulunmalı (bkz. `localeSearchKey`).
    const Person(
      id: 'person-irem',
      name: 'İrem',
      kind: PersonKind.human,
      relationType: RelationType.colleague,
    ),
    // Uygulama evcil hayvanları da aileden sayıyor (FR-060).
    Person(
      id: 'person-tekir',
      name: 'Tekir',
      note: 'Sabahları beni o uyandırıyor.',
      birthDate: DateTime(2021, 6, 9),
      relationLabel: 'Kedim',
      kind: PersonKind.pet,
      relationType: RelationType.pet,
    ),
  ];
}
