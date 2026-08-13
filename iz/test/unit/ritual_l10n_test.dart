/// Ritüel tekrar açıklamaları.
///
/// NEDEN AYRI TEST?
/// Türkçede bulunma hâli eki aya göre değişiyor (Mart'TA, Nisan'DA,
/// Eylül'DE) ve bu 12 dallı bir ICU `select` olarak çeviri dosyasında
/// duruyor. Bir dalı yanlış yazmak ya da atlamak sessizce `other` dalına
/// düşer — ekranda yalnızca "Her yıl" görünür ve kimse fark etmez.
/// Bu test 12 ayı tek tek doğruluyor.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/presentation/ritual_l10n.dart';

Ritual _yearly(int month, int day) => Ritual(
  id: 'r',
  title: 'Test',
  recurrenceType: RecurrenceType.yearly,
  anchorMonth: month,
  anchorDay: day,
);

Ritual _seasonal(int? month) => Ritual(
  id: 'r',
  title: 'Test',
  recurrenceType: RecurrenceType.seasonal,
  anchorMonth: month,
);

Ritual _simple(RecurrenceType type) =>
    Ritual(id: 'r', title: 'Test', recurrenceType: type);

void main() {
  late AppL10n tr;
  late AppL10n en;

  setUpAll(() async {
    // Üretilen sınıfı doğrudan `new`lemek yerine delegate'ten yüklüyoruz —
    // `l10n_test.dart` de böyle yapıyor; sınıf adı değişse test kırılmaz.
    tr = await AppL10n.delegate.load(const Locale('tr'));
    en = await AppL10n.delegate.load(const Locale('en'));
  });

  group('yıllık ritüel — Türkçe ekler', () {
    // Ünlü/ünsüz uyumu: -ta / -da / -de / -te.
    const expected = {
      1: 'Her yıl 3 Ocak\'ta',
      2: 'Her yıl 3 Şubat\'ta',
      3: 'Her yıl 3 Mart\'ta',
      4: 'Her yıl 3 Nisan\'da',
      5: 'Her yıl 3 Mayıs\'ta',
      6: 'Her yıl 3 Haziran\'da',
      7: 'Her yıl 3 Temmuz\'da',
      8: 'Her yıl 3 Ağustos\'ta',
      9: 'Her yıl 3 Eylül\'de',
      10: 'Her yıl 3 Ekim\'de',
      11: 'Her yıl 3 Kasım\'da',
      12: 'Her yıl 3 Aralık\'ta',
    };

    for (final entry in expected.entries) {
      test('${entry.key}. ay', () {
        expect(_yearly(entry.key, 3).recurrenceLabel(tr), entry.value);
      });
    }
  });

  group('yıllık ritüel — İngilizce', () {
    test('ay adı önce gelir', () {
      expect(_yearly(3, 3).recurrenceLabel(en), 'Every year on March 3');
      expect(_yearly(5, 15).recurrenceLabel(en), 'Every year on May 15');
    });
  });

  group('mevsimlik ritüel', () {
    test('ay mevsime çevriliyor', () {
      // Tasarımdaki örnek: "Yaz Tatillerimiz".
      expect(_seasonal(7).recurrenceLabel(tr), 'Her yıl yaz aylarında');

      expect(_seasonal(4).recurrenceLabel(tr), 'Her yıl ilkbaharda');
      expect(_seasonal(10).recurrenceLabel(tr), 'Her yıl sonbaharda');
      expect(_seasonal(1).recurrenceLabel(tr), 'Her yıl kış aylarında');
    });

    test('mevsim sınırları doğru', () {
      // İlkbahar 3-5, yaz 6-8, sonbahar 9-11, kış 12-2.
      expect(_seasonal(3).recurrenceLabel(tr), 'Her yıl ilkbaharda');
      expect(_seasonal(5).recurrenceLabel(tr), 'Her yıl ilkbaharda');
      expect(_seasonal(6).recurrenceLabel(tr), 'Her yıl yaz aylarında');
      expect(_seasonal(8).recurrenceLabel(tr), 'Her yıl yaz aylarında');
      expect(_seasonal(9).recurrenceLabel(tr), 'Her yıl sonbaharda');
      expect(_seasonal(11).recurrenceLabel(tr), 'Her yıl sonbaharda');
      expect(_seasonal(12).recurrenceLabel(tr), 'Her yıl kış aylarında');
      expect(_seasonal(2).recurrenceLabel(tr), 'Her yıl kış aylarında');
    });
  });

  group('eksik veri', () {
    test('mevsimlik ama ay yoksa genel metne düşer', () {
      // Domain'de anchorMonth nullable; boş satır bırakmıyoruz.
      expect(_seasonal(null).recurrenceLabel(tr), 'Her yıl');
    });

    test('yıllık ama tarih yoksa KISA metne düşer', () {
      // Ritüel formunda tarih ALINMIYOR (tarih anılardan geliyor), yani
      // tarihsiz yıllık ritüel en sık durum. "Her yıl aynı tarihte" hangi
      // tarih olduğunu sormaya yol açıyordu.
      const ritual = Ritual(
        id: 'r',
        title: 'Test',
        recurrenceType: RecurrenceType.yearly,
      );

      expect(ritual.recurrenceLabel(tr), 'Her yıl');
      expect(ritual.recurrenceLabel(en), 'Every year');
    });

    test('custom tekrar tipi', () {
      const ritual = Ritual(
        id: 'r',
        title: 'Test',
        recurrenceType: RecurrenceType.custom,
      );

      expect(ritual.recurrenceLabel(tr), 'Belirli bir tarihi yok');
    });
  });

  group('aylık ve haftalık', () {
    // Bu iki tür kullanıcının isteğiyle eklendi (ritüel formunda "yıl / ay /
    // hafta"). Tarih ÇAPASI YOK: kullanıcı ritüeli tarihle değil alışkanlıkla
    // tanımlıyor.
    test('her ay', () {
      expect(_simple(RecurrenceType.monthly).recurrenceLabel(tr), 'Her ay');
      expect(
        _simple(RecurrenceType.monthly).recurrenceLabel(en),
        'Every month',
      );
    });

    test('her hafta', () {
      expect(_simple(RecurrenceType.weekly).recurrenceLabel(tr), 'Her hafta');
      expect(_simple(RecurrenceType.weekly).recurrenceLabel(en), 'Every week');
    });

    test('gün-ay çapası verilse bile metin değişmiyor', () {
      // Aylık bir ritüelde `anchorDay` anlamsız; sızsa "Her ayın 3'ü" gibi bir
      // metin çıkardı ve o Türkçede ek sorunuyla birlikte gelirdi.
      const withAnchor = Ritual(
        id: 'r',
        title: 'Test',
        recurrenceType: RecurrenceType.monthly,
        anchorMonth: 3,
        anchorDay: 3,
      );

      expect(withAnchor.recurrenceLabel(tr), 'Her ay');
    });

    test('nextOccurrence null: aylık ritüelde çapa yok', () {
      expect(
        _simple(RecurrenceType.monthly).nextOccurrence(DateTime(2026, 8, 12)),
        isNull,
      );
    });
  });
}
