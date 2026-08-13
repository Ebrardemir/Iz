/// Ritüel — tekrarlanan olayın **üst yapısı** (doğum günü, yıldönümü,
/// yaz tatili).
///
/// BR-012: "Ritüel tekrarlanan olayın üst yapısıdır; her yılın içeriği
/// ayrı Anı olarak kalır." Yani ritüel anı İÇERMEZ, anıları gruplar.
/// Bu ayrım FR-076'daki yıl yan yana karşılaştırmayı mümkün kılar.
library;

import 'package:equatable/equatable.dart';

enum RecurrenceType {
  /// Her yıl aynı tarihte (doğum günü, yıldönümü).
  yearly,

  /// Her ay (aylık aile yemeği).
  monthly,

  /// Her hafta (pazar kahvaltısı).
  weekly,

  /// Her yıl ama tarihi kayan (yaz tatili, kamp).
  seasonal,

  /// Belirli aralık yok, kullanıcı elle bağlar.
  custom,
}

final class Ritual extends Equatable {
  const Ritual({
    required this.id,
    required this.title,
    required this.recurrenceType,
    this.relatedPersonId,
    this.anchorMonth,
    this.anchorDay,
    this.iconKey = 'ritual',
  });

  final String id;
  final String title;
  final RecurrenceType recurrenceType;

  /// FR-064 — kişiye özel ritüeller (annemin doğum günü).
  final String? relatedPersonId;

  /// yearly ritüellerde hatırlatma tarihi (FR-152).
  final int? anchorMonth;
  final int? anchorDay;

  final String iconKey;

  /// Bu yılki tekrar tarihi. FR-152: "Ritüel tarihi yaklaşınca
  /// 'Bu yılın anısını eklemek ister misin?' hatırlatması".
  ///
  /// YALNIZCA [RecurrenceType.yearly] ve [RecurrenceType.seasonal] için
  /// anlamlı: aylık/haftalık ritüellerde gün-ay çapası yok, o yüzden zaten
  /// null dönüyor (hesap `anchorMonth`/`anchorDay`ye bakıyor).
  DateTime? nextOccurrence(DateTime from) {
    final month = anchorMonth;
    final day = anchorDay;
    if (month == null || day == null) return null;

    final thisYear = DateTime(from.year, month, day);
    return thisYear.isBefore(from.dateOnlyLocal)
        ? DateTime(from.year + 1, month, day)
        : thisYear;
  }

  Ritual copyWith({
    String? title,
    RecurrenceType? recurrenceType,
    String? relatedPersonId,
    int? anchorMonth,
    int? anchorDay,
    String? iconKey,
  }) => Ritual(
    id: id,
    title: title ?? this.title,
    recurrenceType: recurrenceType ?? this.recurrenceType,
    relatedPersonId: relatedPersonId ?? this.relatedPersonId,
    anchorMonth: anchorMonth ?? this.anchorMonth,
    anchorDay: anchorDay ?? this.anchorDay,
    iconKey: iconKey ?? this.iconKey,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    recurrenceType,
    relatedPersonId,
    anchorMonth,
    anchorDay,
    iconKey,
  ];
}

extension on DateTime {
  DateTime get dateOnlyLocal => DateTime(year, month, day);
}
