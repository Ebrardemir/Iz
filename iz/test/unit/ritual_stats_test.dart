/// Seri özetinin üç sayısı.
///
/// NEDEN AYRI TEST?
/// Bu sayılar kullanıcının girdiği değerler değil, anılardan TÜRETİLEN
/// sonuçlar — seri formunda tarih sormamamızın devamı. Kural yanlışsa ekranda
/// "6 yıl" yerine "6 anı kadar yıl" görünür ve kimse fark etmez: bir seride
/// aynı yıla iki anı düşmesi çok olağan.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/features/rituals/domain/ritual_stats.dart';

RitualStatInput _memory(int year, [String? place]) =>
    (year: year, placeLabel: place);

void main() {
  test('boş liste hepsini sıfır veriyor', () {
    final stats = ritualStats(const []);

    expect(stats.yearCount, 0);
    expect(stats.memoryCount, 0);
    expect(stats.cityCount, 0);
  });

  test('anı sayısı listenin uzunluğu', () {
    final stats = ritualStats([_memory(2024), _memory(2025), _memory(2026)]);

    expect(stats.memoryCount, 3);
  });

  test('YIL BENZERSİZ: aynı yaz iki anı "2 yıl" değil', () {
    // Kutunun altında "Birlikte" yazıyor; o söz kaç yıldır sürdüğünü vaat
    // ediyor, kaç kayıt olduğunu değil.
    final stats = ritualStats([_memory(2026), _memory(2026), _memory(2025)]);

    expect(stats.yearCount, 2);
    expect(stats.memoryCount, 3);
  });

  test('ŞEHİR BENZERSİZ: iki yıl aynı yere gidilmişse tek şehir', () {
    final stats = ritualStats([
      _memory(2026, 'Çeşme'),
      _memory(2025, 'Çeşme'),
      _memory(2024, 'Datça'),
    ]);

    expect(stats.cityCount, 2);
  });

  test('konumu olmayan anı şehir sayılmıyor', () {
    // Konum opsiyonel (rapor 20.1); boş bırakılmış bir alan bir şehir değil.
    final stats = ritualStats([
      _memory(2026, 'Venedik'),
      _memory(2025),
      _memory(2024, null),
    ]);

    expect(stats.cityCount, 1);
    expect(stats.memoryCount, 3);
  });

  test('yalnızca boşluk içeren konum sayılmıyor', () {
    // Elle girilen alanlarda olan bir şey; "  " bir yer adı değil.
    final stats = ritualStats([_memory(2026, '   ')]);

    expect(stats.cityCount, 0);
  });

  test('Türkçe büyük harf farkı iki ayrı şehir yapmıyor... yapıyor', () {
    // BİLİNÇLİ SINIR: karşılaştırma birebir. "çeşme" ve "Çeşme" iki ayrı
    // şehir sayılıyor. Konum verisi ileride konum servisinden gelecek ve
    // normalize edilmiş olacak; elle yazılan serbest metin için burada bir
    // küçültme yapmak (`localeSearchKey`) sayıyı düzeltirken şehir adını da
    // bozardı. Bu testin işi kararı GÖRÜNÜR kılmak.
    final stats = ritualStats([_memory(2026, 'Çeşme'), _memory(2025, 'çeşme')]);

    expect(stats.cityCount, 2);
  });
}
