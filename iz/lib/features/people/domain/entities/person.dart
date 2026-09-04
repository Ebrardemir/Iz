/// Kişi / özne profili.
///
/// FR-062: "Evcil hayvan gibi insan olmayan önemli varlıklar da
/// 'Kişi/Özne' modeliyle desteklenebilmelidir." Bu yüzden model
/// "insan" varsayımı yapmaz; [PersonKind] ayrımı taşır.
library;

import 'package:equatable/equatable.dart';

enum PersonKind { human, pet, other }

/// FR-061 — ilişki türü. Serbest metin yerine enum: filtreleme ve
/// ritüel önerileri (FR-064) bunun üstüne kurulacak.
enum RelationType {
  self,
  partner,
  parent,
  child,
  sibling,
  grandparent,
  grandchild,
  relative,
  friend,
  colleague,
  pet,
  other,
}

final class Person extends Equatable {
  const Person({
    required this.id,
    required this.name,
    required this.kind,
    required this.relationType,
    this.relationLabel,
    this.birthDate,
    this.avatarMediaId,
    this.note,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final PersonKind kind;

  /// FR-061 — ilişki türü. Filtreleme ve doğum günü ritüeli önerileri
  /// (FR-064) bunun üstüne kurulacak.
  final RelationType relationType;

  /// Kullanıcının KENDİ YAZDIĞI ilişki adı: "Annem", "Kankam", "Komşu Ayla".
  ///
  /// NEDEN İKİ ALAN?
  /// Enum makine için, bu metin insan için. Kullanıcıdan bir listeden seçim
  /// beklemek ilişkiyi yoksullaştırıyordu: "Annem" ile "Anne / Baba" aynı şey
  /// değil, ilki kullanıcının kendi sesi. Ama yalnızca serbest metin de
  /// olmuyor — ritüel önerileri ("annesinin doğum günü yaklaşıyor") ve
  /// filtreleme bir türe ihtiyaç duyuyor.
  ///
  /// Bu yüzden kullanıcı YAZIYOR, tür yazılandan TÜRETİLİYOR
  /// (bkz. `guessRelationType`). Yanlış tahmin edilse bile ekranda görünen
  /// şey kullanıcının yazdığı metin — kayıp yok.
  ///
  /// Boşsa ekranlar [relationType]'ın çevrilmiş adına düşüyor.
  final String? relationLabel;

  /// Opsiyonel — FR-061. Doğum günü ritüeli (FR-064) buradan türetilir.
  final DateTime? birthDate;
  final String? avatarMediaId;
  final String? note;

  /// Ana ekranda öne çıkarılacak kişiler.
  final bool isFavorite;

  /// Doğum tarihi varsa bugünkü yaşı.
  int? ageAt(DateTime reference) {
    final birth = birthDate;
    if (birth == null) return null;
    var age = reference.year - birth.year;
    if (reference.month < birth.month ||
        (reference.month == birth.month && reference.day < birth.day)) {
      age--;
    }
    return age;
  }

  /// ⚠️ [relationLabel] BU LİSTEDE OLMAK ZORUNDA.
  /// Eksikti: `copyWith` çağıran her yer kullanıcının yazdığı "Annem"i
  /// sessizce düşürüyordu. Yeni bir alan eklerken buraya da eklemeyi unutma —
  /// derleyici bunu yakalamaz.
  Person copyWith({
    String? name,
    PersonKind? kind,
    RelationType? relationType,
    String? relationLabel,
    DateTime? birthDate,
    String? avatarMediaId,
    String? note,
    bool? isFavorite,
  }) => Person(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    relationType: relationType ?? this.relationType,
    relationLabel: relationLabel ?? this.relationLabel,
    birthDate: birthDate ?? this.birthDate,
    avatarMediaId: avatarMediaId ?? this.avatarMediaId,
    note: note ?? this.note,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    relationType,
    relationLabel,
    birthDate,
    avatarMediaId,
    note,
    isFavorite,
  ];
}
