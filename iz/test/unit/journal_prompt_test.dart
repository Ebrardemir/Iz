/// Günlük davet cümlesinin GÜNE göre seçilmesi — FR-032.
///
/// NEDEN AYRI TEST?
/// Kural görünmez: yanlış olsa da ekranda hep bir cümle çıkar ve kimse fark
/// etmez. Oysa iki söz veriyoruz — "aynı gün aynı cümle" ve "ertesi gün başka
/// cümle". İkisi de burada sabitleniyor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/features/journal/domain/journal_prompt.dart';

void main() {
  test('aynı gün AYNI cümle — saat fark etmiyor', () {
    // Ekranı sabah açan da akşam açan da aynı daveti görmeli; her açılışta
    // değişen bir metin ekranı huzursuz yapıyordu.
    final morning = journalPromptIndexFor(
      DateTime(2026, 8, 13, 7, 30),
      count: 5,
    );
    final night = journalPromptIndexFor(
      DateTime(2026, 8, 13, 23, 59),
      count: 5,
    );

    expect(morning, night);
  });

  test('ertesi gün BAŞKA cümle', () {
    final today = journalPromptIndexFor(DateTime(2026, 8, 13), count: 5);
    final tomorrow = journalPromptIndexFor(DateTime(2026, 8, 14), count: 5);

    expect(today, isNot(tomorrow));
  });

  test('sonuç havuzun içinde kalıyor', () {
    // Bir gün taşarsa `journalPrompts(...)[index]` çöker.
    for (var day = 1; day <= 31; day++) {
      final index = journalPromptIndexFor(DateTime(2026, 12, day), count: 5);
      expect(index, inInclusiveRange(0, 4), reason: 'gün $day');
    }
  });

  test('yıl sınırında sıçrama yok — sıra kesintisiz ilerliyor', () {
    // "Yılın kaçıncı günü" ile hesaplasaydık 31 Aralık ile 1 Ocak arasında
    // sıra atlıyordu (365 % 5 = 0 değil).
    final lastDay = journalPromptIndexFor(DateTime(2026, 12, 31), count: 5);
    final firstDay = journalPromptIndexFor(DateTime(2027), count: 5);

    expect(firstDay, (lastDay + 1) % 5);
  });

  test('2000 öncesi tarihlerde de geçerli sıra', () {
    // İçe aktarılan eski kayıtlar bu tarihleri taşıyabiliyor.
    final index = journalPromptIndexFor(DateTime(1994, 3, 2), count: 5);

    expect(index, inInclusiveRange(0, 4));
  });

  test('havuz boşsa çökmüyor', () {
    expect(journalPromptIndexFor(DateTime(2026, 8, 13), count: 0), 0);
  });
}
