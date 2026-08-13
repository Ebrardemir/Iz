/// "Tüm Günlükler" ekranının süzgeci ve gruplaması — FR-033.
///
/// NEDEN AYRI TEST?
/// "Bu hafta" ve "bu ay" bir TAKVİM kararı: haftanın pazartesi başlaması, ay
/// sınırında kesilmesi ve gün içindeki saatlerin gruplamayı bozmaması. Üçü de
/// ekranda sessizce yanlış çalışabilir — liste yine dolu görünür.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/features/journal/domain/journal_filter.dart';

/// 13 Ağustos 2026 bir PERŞEMBE — haftanın ortası, sınır testleri için ideal.
final _today = DateTime(2026, 8, 13, 21, 30);

typedef _Entry = ({DateTime date, bool isFavorite});

_Entry _entry(DateTime date, {bool favorite = false}) =>
    (date: date, isFavorite: favorite);

/// Alan okuyucuları her çağrıda tekrar yazmamak için.
List<_Entry> _filter(
  List<_Entry> entries,
  JournalFilter filter, {
  required DateTime today,
}) => filterJournalEntries(
  entries,
  filter,
  today: today,
  dateOf: (entry) => entry.date,
  isFavoriteOf: (entry) => entry.isFavorite,
);

List<({DateTime day, List<_Entry> entries})> _group(List<_Entry> entries) =>
    groupJournalEntriesByDay(entries, dateOf: (entry) => entry.date);

void main() {
  group('süzme', () {
    test('tümü hiçbir şeyi elemiyor', () {
      final entries = [
        _entry(DateTime(2020, 5, 3)),
        _entry(DateTime(2026, 8, 13)),
      ];

      expect(_filter(entries, JournalFilter.all, today: _today), hasLength(2));
    });

    test('favoriler yalnızca yıldızlıları veriyor', () {
      final entries = [
        _entry(DateTime(2026, 8, 13), favorite: true),
        _entry(DateTime(2026, 8, 12)),
      ];

      final result = _filter(entries, JournalFilter.favorites, today: _today);

      expect(result, hasLength(1));
      expect(result.single.isFavorite, isTrue);
    });

    group('bu hafta', () {
      test('haftanın PAZARTESİSİ dahil', () {
        // 13 Ağustos perşembe → haftanın başı 10 Ağustos pazartesi.
        final result = _filter(
          [_entry(DateTime(2026, 8, 10))],
          JournalFilter.thisWeek,
          today: _today,
        );

        expect(result, hasLength(1));
      });

      test('bir önceki PAZAR hariç', () {
        // "Son 7 gün" deseydik bu kayıt içeri girerdi; kullanıcının "bu
        // hafta"dan anladığı şey takvim haftası.
        final result = _filter(
          [_entry(DateTime(2026, 8, 9))],
          JournalFilter.thisWeek,
          today: _today,
        );

        expect(result, isEmpty);
      });

      test('haftanın PAZARI, gece yarısına kadar dahil', () {
        final result = _filter(
          [_entry(DateTime(2026, 8, 16, 23, 59))],
          JournalFilter.thisWeek,
          today: _today,
        );

        expect(result, hasLength(1));
      });

      test('gelecek pazartesi hariç', () {
        final result = _filter(
          [_entry(DateTime(2026, 8, 17))],
          JournalFilter.thisWeek,
          today: _today,
        );

        expect(result, isEmpty);
      });

      test('AY SINIRINI aşan hafta bölünmüyor', () {
        // 1 Eylül 2026 salı; haftası 31 Ağustos pazartesi başlıyor.
        final result = _filter(
          [_entry(DateTime(2026, 8, 31)), _entry(DateTime(2026, 9))],
          JournalFilter.thisWeek,
          today: DateTime(2026, 9, 1, 10),
        );

        expect(result, hasLength(2));
      });
    });

    group('bu ay', () {
      test('ayın ilk ve son günü dahil', () {
        final result = _filter(
          [_entry(DateTime(2026, 8)), _entry(DateTime(2026, 8, 31, 23, 59))],
          JournalFilter.thisMonth,
          today: _today,
        );

        expect(result, hasLength(2));
      });

      test('önceki ve sonraki ay hariç', () {
        final result = _filter(
          [_entry(DateTime(2026, 7, 31)), _entry(DateTime(2026, 9))],
          JournalFilter.thisMonth,
          today: _today,
        );

        expect(result, isEmpty);
      });

      test('AYNI AY, BAŞKA YIL hariç', () {
        // Yıl kontrolü unutulursa geçen yılın ağustosu da listeye girer.
        final result = _filter(
          [_entry(DateTime(2025, 8, 13))],
          JournalFilter.thisMonth,
          today: _today,
        );

        expect(result, isEmpty);
      });
    });
  });

  group('gruplama', () {
    test('aynı günün kayıtları tek başlık altında', () {
      // Saatler farklı ama gün aynı: saat bileşeni gruplamayı bozmamalı.
      final groups = _group([
        _entry(DateTime(2026, 8, 13, 9)),
        _entry(DateTime(2026, 8, 13, 21, 30)),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.entries, hasLength(2));
      expect(groups.single.day, DateTime(2026, 8, 13));
    });

    test('günler YENİDEN ESKİYE sıralı', () {
      final groups = _group([
        _entry(DateTime(2026, 8, 11)),
        _entry(DateTime(2026, 8, 13)),
        _entry(DateTime(2026, 8, 12)),
      ]);

      expect([for (final group in groups) group.day.day], [13, 12, 11]);
    });

    test('gün içindeki sıra KORUNUYOR', () {
      // Liste zaten yeniden eskiye geliyor; grup içinde yeniden sıralamak
      // depo sırasını bozardı.
      final first = _entry(DateTime(2026, 8, 13, 21));
      final second = _entry(DateTime(2026, 8, 13, 9));

      final groups = _group([first, second]);

      expect(groups.single.entries, [first, second]);
    });

    test('boş liste boş grup veriyor', () {
      expect(_group(const []), isEmpty);
    });
  });
}
