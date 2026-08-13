/// Tarih yardımcıları.
///
/// İZ'in çekirdeğinde tarih var: timeline, ritüeller (FR-075), Bugünün İzi
/// (FR-080), O Zaman/Şimdi (FR-082). Bu hesapları tek yerde toplamak,
/// unit test yazmayı da kolaylaştırır (rapor 18.1: "tarih/ritüel hesapları").
library;

import 'package:intl/intl.dart';

extension DateTimeX on DateTime {
  /// Saat bileşenini atar — gün bazlı karşılaştırmalar için.
  DateTime get dateOnly => DateTime(year, month, day);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// FR-080 "Bugünün İzi": yıl fark eder, gün/ay aynı olmalı.
  bool isSameDayOfYear(DateTime other) =>
      month == other.month && day == other.day;

  bool get isToday => isSameDay(DateTime.now());

  bool get isThisYear => year == DateTime.now().year;

  /// Kaç yıl önceydi? "8 yıl önce bugün" kartları için.
  int yearsAgo([DateTime? from]) {
    final reference = from ?? DateTime.now();
    var years = reference.year - year;
    // Yıl dönümü henüz gelmediyse bir eksilt.
    if (reference.month < month ||
        (reference.month == month && reference.day < day)) {
      years--;
    }
    return years;
  }

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
  DateTime get startOfMonth => DateTime(year, month);
  DateTime get startOfYear => DateTime(year);

  /// Drift'e/JSON'a yazarken hep UTC ISO-8601 kullan — cihaz saat dilimi
  /// değişse bile kayıt bozulmasın.
  String toIsoUtc() => toUtc().toIso8601String();
}

/// Biçimleyiciler tek yerde: aynı tarih iki ekranda farklı görünmesin.
///
/// `locale` parametresi verilmezse cihazın aktif dili kullanılır.
abstract final class AppDateFormats {
  /// 12 Mart 2026
  static String long(DateTime date, {String? locale}) =>
      DateFormat.yMMMMd(locale).format(date);

  /// 12 Mar 2026
  static String medium(DateTime date, {String? locale}) =>
      DateFormat.yMMMd(locale).format(date);

  /// 12.03.2026
  static String short(DateTime date, {String? locale}) =>
      DateFormat.yMd(locale).format(date);

  /// Mart 2026 — timeline bölüm başlıkları
  static String monthYear(DateTime date, {String? locale}) =>
      DateFormat.yMMMM(locale).format(date);

  /// 2026 — ritüel yıl karşılaştırması (FR-076)
  static String year(DateTime date) => date.year.toString();

  /// Tarih ARALIĞI — koleksiyonların "10-14 Mayıs 2026" satırı için.
  ///
  /// TEKRAR EDEN PARÇAYI YAZMIYORUZ. "10 Mayıs 2026 — 14 Mayıs 2026" hem
  /// uzun hem de okuyanı yorar; aynı ay içindeyse ay ve yıl bir kez geçer.
  /// Dört durum var ve hepsi ayrı ayrı test ediliyor
  /// (bkz. test/unit/date_formats_test.dart):
  ///
  ///   tek gün       → 10 Mayıs 2026
  ///   aynı ay + yıl → 10-14 Mayıs 2026
  ///   aynı yıl      → 28 Nisan — 3 Mayıs 2026
  ///   farklı yıl    → 20 Eyl 2021 — 14 Haz 2025      ← AY ADI KISALTILIR
  ///
  /// SON DURUMDA NEDEN KISALTMA VAR?
  /// "20 Eylül 2021 — 14 Haziran 2025" 12 punto Poppins'te ~250 px; koleksiyon
  /// kartının özet satırına sığmıyor ve "14 Haziran 20…" diye ortasından
  /// kesiliyordu — yılı görmeden kalan bir tarih hiçbir işe yaramaz.
  /// Kısaltma yalnızca GEREKTİĞİNDE devreye giriyor: aynı yıl içindeki
  /// aralıklar (asıl kullanım, çoğu koleksiyon bir seyahat) tam ay adıyla
  /// kalıyor.
  ///
  /// [end] yoksa ya da aynı güne denk geliyorsa tek tarih döner: bir günlük
  /// koleksiyonda "10-10 Mayıs" yazmak hatalı görünür.
  ///
  /// AY ADI HANGİ TARİHTEN ALINIYOR? Aynı ay durumunda ikisi de aynı ayda
  /// olduğu için fark etmez; [end]'i kullanıyoruz ki yıl da ondan gelsin.
  static String range(DateTime start, DateTime? end, {String? locale}) {
    if (end == null || start.isSameDay(end)) {
      return long(start, locale: locale);
    }

    if (start.year == end.year && start.month == end.month) {
      return '${start.day}-${end.day} '
          '${DateFormat.yMMMM(locale).format(end)}';
    }

    if (start.year == end.year) {
      return '${DateFormat.MMMMd(locale).format(start)} — '
          '${long(end, locale: locale)}';
    }

    return '${medium(start, locale: locale)} — ${medium(end, locale: locale)}';
  }

  /// 14:30
  static String time(DateTime date, {String? locale}) =>
      DateFormat.Hm(locale).format(date);

  /// Günlük takvim görünümü için gün adı: "Pazartesi"
  static String weekday(DateTime date, {String? locale}) =>
      DateFormat.EEEE(locale).format(date);
}
