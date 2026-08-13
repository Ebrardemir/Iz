/// "Tüm Günlükler" ekranının süzgeci ve gruplaması — FR-033.
///
/// NEDEN `domain/` VE SAF?
/// "Bu hafta" ile "bu ay"ın ne demek olduğu bir TAKVİM kararı, bir ekran
/// kararı değil: haftanın pazartesi mi pazar mı başladığı, ayın kalan
/// günlerinin sayılıp sayılmadığı burada yazıyor. Widget'ın içinde kalsaydı
/// sınamak için ekran kurmak gerekirdi; burada üç satırlık bir listeyle
/// sınanıyor.
library;

/// Ekrandaki dört çip.
enum JournalFilter {
  all,
  thisWeek,
  thisMonth,
  favorites;

  /// URL ve test için sabit anahtar. Enum adını doğrudan kullanmak da
  /// olurdu; ayrı bir alan, ileride ad değiştirmenin bağlantıları kırmasını
  /// engelliyor.
  String get key => name;
}

/// [entries] listesini [filter]e göre süzer.
///
/// NEDEN ALAN OKUYUCULAR ([dateOf], [isFavoriteOf]) PARAMETRE?
/// Önce `({DateTime date, bool isFavorite})` biçiminde bir kayıt tipi
/// bekleniyordu; Dart'ta kayıtlar YAPISAL ama fazladan alanı olan bir kayıt
/// ötekinin alt tipi DEĞİL — çağıran taraf yanına bir alan daha koyunca
/// derlenmiyordu. Okuyucu geçmek fonksiyonu çağıranın veri tipinden tamamen
/// bağımsız kılıyor.
///
/// [today] DIŞARIDAN geliyor: `DateTime.now()` çağıran bir fonksiyon test
/// edilemez ve gece yarısı davranışı da sınanamaz (bkz. `clockProvider`).
List<T> filterJournalEntries<T>(
  List<T> entries,
  JournalFilter filter, {
  required DateTime today,
  required DateTime Function(T entry) dateOf,
  required bool Function(T entry) isFavoriteOf,
}) => switch (filter) {
  JournalFilter.all => entries,
  JournalFilter.favorites => [
    for (final entry in entries)
      if (isFavoriteOf(entry)) entry,
  ],
  JournalFilter.thisWeek => [
    for (final entry in entries)
      if (_isInThisWeek(dateOf(entry), today)) entry,
  ],
  JournalFilter.thisMonth => [
    for (final entry in entries)
      if (dateOf(entry).year == today.year &&
          dateOf(entry).month == today.month)
        entry,
  ],
};

/// [date] içinde bulunulan haftanın içinde mi?
///
/// HAFTA PAZARTESİ BAŞLIYOR: Türkiye'de (ve `intl`in tr yerelinde) haftanın
/// ilk günü pazartesi. "Son 7 gün" demek daha kolaydı ama kullanıcının
/// "bu hafta" derken kastettiği şey takvim haftası — salı günü açtığında
/// geçen cumartesiyi görmek istemiyor.
bool _isInThisWeek(DateTime date, DateTime today) {
  final startOfWeek = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - DateTime.monday));
  // Pazar gecesi 23:59'u da kapsasın diye bir sonraki pazartesiyi sınır
  // alıyoruz ve `isBefore` ile karşılaştırıyoruz.
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  return !date.isBefore(startOfWeek) && date.isBefore(endOfWeek);
}

/// Güne göre gruplanmış liste — her grup bir tarih başlığı ve o günün
/// kayıtları.
///
/// SIRA: günler YENİDEN ESKİYE, gün içindeki kayıtlar geldikleri sırada.
/// Günlük tersten okunur; kullanıcı önce dünü görmek ister.
///
/// SAAT BİLEŞENİ ATILIYOR: aynı günün iki kaydı aynı başlığın altında
/// toplanmalı, saatleri farklı olsa bile.
List<({DateTime day, List<T> entries})> groupJournalEntriesByDay<T>(
  List<T> entries, {
  required DateTime Function(T entry) dateOf,
}) {
  final byDay = <DateTime, List<T>>{};

  for (final entry in entries) {
    final date = dateOf(entry);
    final day = DateTime(date.year, date.month, date.day);
    (byDay[day] ??= []).add(entry);
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

  return [for (final day in days) (day: day, entries: byDay[day]!)];
}
