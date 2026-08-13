/// Bir ayın takvimde gösterilecek günlerini üretir.
///
/// SAF DART — widget yok, `BuildContext` yok. Takvimin en kolay yanlış
/// yapılan kısmı burası olduğu için ayrı tutuldu: artık Flutter kurmadan,
/// saf birim testiyle sınanabiliyor (artık yıl, ayın pazar günü başlaması,
/// 6 haftaya taşan aylar...).
library;

import 'package:iz/features/my_life/presentation/my_life_layout.dart';

abstract final class CalendarMonth {
  /// [month]'un takvimde görünecek TÜM günleri — hafta başlarına
  /// tamamlanmış hâlde.
  ///
  /// Baştaki ve sondaki günler komşu aylara aittir ("outside month");
  /// takvim ızgarası onları soluk çizer. Dönen liste her zaman 7'nin katıdır.
  ///
  /// ⚠️ GÜN EKLERKEN `Duration` KULLANILMIYOR. `add(Duration(days: 1))`
  /// yaz saati geçişlerinde 23 veya 25 saat ekler; arka arkaya
  /// çağrıldığında gün atlayabilir. `DateTime(y, m, d + i)` ise takvim
  /// aritmetiği yapar ve ay/yıl taşmasını da kendisi halleder.
  static List<DateTime> daysOf(DateTime month) {
    final first = DateTime(month.year, month.month);

    // Ayın ilk gününden, haftanın ilk gününe kadar kaç gün geriye gitmeli?
    final leading = (first.weekday - MyLifeLayout.firstWeekday + 7) % 7;

    // Bir sonraki ayın "0." günü = bu ayın son günü.
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final weeks = ((leading + daysInMonth) / MyLifeLayout.weekdayCount).ceil();

    return [
      for (var i = 0; i < weeks * MyLifeLayout.weekdayCount; i++)
        DateTime(first.year, first.month, 1 - leading + i),
    ];
  }

  /// Ayın takvimde kaç hafta (satır) tuttuğu — 4, 5 veya 6.
  static int weekCountOf(DateTime month) =>
      daysOf(month).length ~/ MyLifeLayout.weekdayCount;

  /// İki tarih AYNI GÜN mü? Saat/dakika yok sayılır.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// [day], [month]'un kendi günü mü, yoksa komşu aydan mı geldi?
  static bool isInMonth(DateTime day, DateTime month) =>
      day.year == month.year && day.month == month.month;
}
