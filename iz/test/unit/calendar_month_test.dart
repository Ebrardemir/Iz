/// Takvim günlerini üreten SAF mantık.
///
/// Takvimin en kolay yanlış yapılan yeri burası: artık yıl, ayın hangi güne
/// denk geldiği, 6 haftaya taşan aylar. Widget kurmadan sınandığı için
/// hızlı ve kesin.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/features/my_life/presentation/calendar_month.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';

void main() {
  group('daysOf', () {
    test('her zaman tam haftalar döner', () {
      for (var month = 1; month <= 12; month++) {
        final days = CalendarMonth.daysOf(DateTime(2026, month));
        expect(
          days.length % MyLifeLayout.weekdayCount,
          0,
          reason: '$month. ay tam hafta değil',
        );
      }
    });

    test('ilk gün HER ZAMAN pazartesi', () {
      for (var month = 1; month <= 12; month++) {
        final days = CalendarMonth.daysOf(DateTime(2026, month));
        expect(days.first.weekday, DateTime.monday);
        expect(days.last.weekday, DateTime.sunday);
      }
    });

    test('ağustos 2026 tasarımdaki gibi diziliyor', () {
      // 1 Ağustos 2026 CUMARTESİ. Pazartesiyle başlayan hafta bu yüzden
      // 27 Temmuz'dan başlıyor — referans tasarımda da öyle.
      final days = CalendarMonth.daysOf(DateTime(2026, 8));

      expect(days.first, DateTime(2026, 7, 27));
      expect(days[5], DateTime(2026, 8, 1));
      expect(CalendarMonth.weekCountOf(DateTime(2026, 8)), 6);
      expect(days.last, DateTime(2026, 9, 6));
    });

    test('şubat 2026 tam dört haftaya sığmaz', () {
      // 1 Şubat 2026 pazar; 28 gün. Pazartesi başlangıcıyla 5 hafta eder.
      expect(CalendarMonth.weekCountOf(DateTime(2026, 2)), 5);
    });

    test('ARTIK YIL: şubat 2024 29 gün', () {
      final days = CalendarMonth.daysOf(DateTime(2024, 2));
      final inMonth = days
          .where((d) => CalendarMonth.isInMonth(d, DateTime(2024, 2)))
          .toList();

      expect(inMonth, hasLength(29));
      expect(inMonth.last.day, 29);
    });

    test('günler kesintisiz ve sıralı', () {
      // REGRESYON: `add(Duration(days: 1))` yaz saati geçişinde gün
      // atlayabilir. Takvim aritmetiği kullandığımız için atlamamalı.
      final days = CalendarMonth.daysOf(DateTime(2026, 3));

      for (var i = 1; i < days.length; i++) {
        final expected = DateTime(
          days[i - 1].year,
          days[i - 1].month,
          days[i - 1].day + 1,
        );
        expect(days[i], expected, reason: '$i. günde kopukluk');
      }
    });

    test('yıl sınırını doğru geçer', () {
      final days = CalendarMonth.daysOf(DateTime(2026, 12));

      expect(days.any((d) => d.year == 2027), isTrue);
      expect(
        days.where((d) => CalendarMonth.isInMonth(d, DateTime(2026, 12))),
        hasLength(31),
      );
    });
  });

  group('yardımcılar', () {
    test('isSameDay saati yok sayar', () {
      expect(
        CalendarMonth.isSameDay(
          DateTime(2026, 8, 12, 23, 59),
          DateTime(2026, 8, 12),
        ),
        isTrue,
      );
      expect(
        CalendarMonth.isSameDay(DateTime(2026, 8, 12), DateTime(2026, 8, 13)),
        isFalse,
      );
    });

    test('isInMonth komşu ayın gününü ayırt eder', () {
      final august = DateTime(2026, 8);

      expect(CalendarMonth.isInMonth(DateTime(2026, 8, 31), august), isTrue);
      expect(CalendarMonth.isInMonth(DateTime(2026, 7, 31), august), isFalse);
      // Aynı ay ama BAŞKA YIL — sadece aya bakmak yanlış olurdu.
      expect(CalendarMonth.isInMonth(DateTime(2025, 8, 12), august), isFalse);
    });
  });
}
