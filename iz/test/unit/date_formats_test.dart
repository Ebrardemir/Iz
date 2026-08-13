/// Tarih biçimleyicileri — özellikle ARALIK kuralları.
///
/// Aralık üç ayrı duruma göre farklı yazılıyor ve hepsi sessizce bozulabilir
/// bir metin birleştirmesi. Saf Dart testi: widget yok, veritabanı yok.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:iz/core/extensions/date_x.dart';

void main() {
  // `intl` yerelleştirme verisini yüklemeden `DateFormat('tr')` çalışmaz.
  setUpAll(initializeDateFormatting);

  group('AppDateFormats.range — aynı ay ve yıl', () {
    test('ay ve yıl BİR KEZ yazılır', () {
      expect(
        AppDateFormats.range(
          DateTime(2026, 5, 10),
          DateTime(2026, 5, 14),
          locale: 'tr',
        ),
        '10-14 Mayıs 2026',
      );
    });

    test('İngilizcede de aynı kural', () {
      expect(
        AppDateFormats.range(
          DateTime(2026, 5, 10),
          DateTime(2026, 5, 14),
          locale: 'en',
        ),
        '10-14 May 2026',
      );
    });
  });

  group('AppDateFormats.range — aynı yıl, farklı ay', () {
    test('yıl yalnızca sonda yazılır', () {
      expect(
        AppDateFormats.range(
          DateTime(2026, 4, 28),
          DateTime(2026, 5, 3),
          locale: 'tr',
        ),
        '28 Nisan — 3 Mayıs 2026',
      );
    });
  });

  group('AppDateFormats.range — farklı yıl', () {
    test('ay adı KISALTILIR — uzun aralık satıra sığmalı', () {
      // "20 Eylül 2021 — 14 Haziran 2025" koleksiyon kartının özet satırında
      // ortasından kesiliyordu. Kısaltma yalnızca burada devreye giriyor.
      expect(
        AppDateFormats.range(
          DateTime(2021, 9, 20),
          DateTime(2025, 6, 14),
          locale: 'tr',
        ),
        '20 Eyl 2021 — 14 Haz 2025',
      );
    });

    test('yıl atlayan kısa aralıkta da iki yıl da görünür', () {
      expect(
        AppDateFormats.range(
          DateTime(2025, 12, 28),
          DateTime(2026, 1, 3),
          locale: 'tr',
        ),
        '28 Ara 2025 — 3 Oca 2026',
      );
    });
  });

  group('AppDateFormats.range — tek gün', () {
    test('bitiş yoksa tek tarih döner', () {
      expect(
        AppDateFormats.range(DateTime(2026, 5, 10), null, locale: 'tr'),
        '10 Mayıs 2026',
      );
    });

    test('başlangıç ve bitiş aynı günse "10-10" yazmaz', () {
      expect(
        AppDateFormats.range(
          DateTime(2026, 5, 10, 9),
          DateTime(2026, 5, 10, 23),
          locale: 'tr',
        ),
        '10 Mayıs 2026',
      );
    });
  });
}
