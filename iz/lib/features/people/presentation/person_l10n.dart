/// [RelationType] → ekranda görünecek ad köprüsü, ve kişi arama.
///
/// NEDEN AYRI DOSYA?
/// `category_l10n.dart` ile aynı gerekçe: enum domain katmanında yaşar ve dili
/// bilmez. İlişki adı ise dile göre değişir. İkisini burada, presentation
/// katmanında birleştiriyoruz.
///
/// KULLANIM:
/// ```dart
/// Text(person.relationType.displayName(context.l10n))
/// ```
library;

import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/text/search_key.dart';
import 'package:iz/features/people/domain/entities/person.dart';

extension RelationTypeL10nX on RelationType {
  /// İlişki türünün çevrilmiş adı.
  ///
  /// `switch` üzerinde bir harita KULLANMIYORUZ: üretilen `AppL10n` sınıfına
  /// anahtarla (string) erişilemez, her alan ayrı bir getter'dır. Bu switch,
  /// enum'a yeni bir tür eklendiğinde çevirisini yazmayı unutursan
  /// derleyicinin seni uyarmasını sağlıyor.
  String displayName(AppL10n l10n) => switch (this) {
    RelationType.self => l10n.relationTypeSelf,
    RelationType.partner => l10n.relationTypePartner,
    RelationType.parent => l10n.relationTypeParent,
    RelationType.child => l10n.relationTypeChild,
    RelationType.sibling => l10n.relationTypeSibling,
    RelationType.grandparent => l10n.relationTypeGrandparent,
    RelationType.grandchild => l10n.relationTypeGrandchild,
    RelationType.relative => l10n.relationTypeRelative,
    RelationType.friend => l10n.relationTypeFriend,
    RelationType.colleague => l10n.relationTypeColleague,
    RelationType.pet => l10n.relationTypePet,
    RelationType.other => l10n.relationTypeOther,
  };
}

/// Kişileri [query] ile süzer.
///
/// SAF FONKSİYON: widget ağacına, `BuildContext`e ihtiyaç duymaz —
/// dolayısıyla doğrudan birim testiyle sınanabiliyor. Arama mantığını
/// ekranın içine gömseydik ancak metin yazıp piksel sayarak test
/// edebilirdik.
///
/// HEM ADDA HEM İLİŞKİDE arıyor: kullanıcı "anne" yazdığında hem "Annem"i
/// hem ilişki türü "Anne / Baba" olan herkesi bulmalı. İlişki adı DIŞARIDAN
/// geliyor ([relationNameOf]) çünkü bu fonksiyon dili bilmiyor.
List<Person> filterPeople(
  List<Person> people, {
  required String query,
  required String Function(Person) relationNameOf,
}) {
  final needle = localeSearchKey(query);
  if (needle.isEmpty) return people;

  return [
    for (final person in people)
      if (localeSearchKey(person.name).contains(needle) ||
          localeSearchKey(relationNameOf(person)).contains(needle))
        person,
  ];
}

/// Kişinin ekranda görünecek ilişki metni.
///
/// Kullanıcının yazdığı varsa O kazanıyor ("Annem"); yoksa türün çevrilmiş
/// adına düşüyor ("Anne / Baba"). İki kaynağın hangisinin önce geldiği tek
/// yerde duruyor ki liste, detay ve arama aynı şeyi göstersin.
String relationDisplay(Person person, AppL10n l10n) {
  final label = person.relationLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  return person.relationType.displayName(l10n);
}
