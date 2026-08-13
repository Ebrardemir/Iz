/// Halka menünün YUVA GEOMETRİSİ.
///
/// Açılar eylem sayısından türetiliyor. Elle yazılmış beş koordinat olsaydı
/// altıncı seçenek eklendiğinde halka sessizce bozulurdu — üst üste binen
/// daireler ya da boş bir yuva. Bu test hem referans tasarımın yerleşimini
/// hem de kuralın her sayıda çalıştığını doğruluyor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/shared/widgets/iz_radial_menu.dart';

const _r = 128.0;

/// İki noktanın yakınlığı — trigonometri sonuçları tam sayı çıkmıyor.
Matcher _near(Offset expected) => predicate<Offset>(
  (actual) => (actual - expected).distance < 1.0,
  'yaklaşık $expected',
);

void main() {
  group('referans tasarım — beş eylem', () {
    late List<Offset> slots;

    setUp(() {
      slots = resolveRadialSlots(actionCount: 5, radius: _r);
    });

    test('beş yuva üretiliyor', () {
      expect(slots, hasLength(5));
    });

    test('ORTADAKİ eylem tam TEPEDE', () {
      // Asıl eylem (Anı) en görünür yuvada olsun diye.
      expect(slots[2], _near(const Offset(0, -_r)));
    });

    test('yerleşim referanstaki gibi: 210 · 150 · 90 · 30 · 330 derece', () {
      // cos/sin(60°) = 0.5 / 0.866 → (±110.85, ±64)
      expect(slots[0], _near(const Offset(-110.85, 64))); // Koleksiyon
      expect(slots[1], _near(const Offset(-110.85, -64))); // Ritüel
      expect(slots[2], _near(const Offset(0, -_r))); // Anı
      expect(slots[3], _near(const Offset(110.85, -64))); // Günlük
      expect(slots[4], _near(const Offset(110.85, 64))); // Kişi
    });

    test('sıra SOLDAN SAĞA', () {
      // Kullanıcı listeyi soldan sağa okuyor; bildirim sırası da öyle olmalı.
      for (var i = 1; i < slots.length; i++) {
        expect(
          slots[i].dx,
          greaterThan(slots[i - 1].dx - 1),
          reason: '$i. yuva bir öncekinin solunda kalmış',
        );
      }
    });

    test('hepsi AYNI yarıçapta — halka gerçekten dairesel', () {
      for (final slot in slots) {
        expect(slot.distance, closeTo(_r, 0.01));
      }
    });

    test('hiçbir daire kapatma düğmesiyle çakışmıyor', () {
      // Alt yuva kapatma düğmesinin. Eylem daireleri 64, kapatma 56 —
      // merkezler arası mesafe ikisinin yarıçapları toplamından büyük olmalı,
      // yoksa daireler üst üste biner.
      const minSeparation = (64 + 56) / 2;
      final close = resolveRadialCloseSlot(radius: _r);

      for (final slot in slots) {
        expect((slot - close).distance, greaterThan(minSeparation));
      }
    });
  });

  group('kapatma düğmesi', () {
    test('her zaman EN ALTTA', () {
      // Alt çubuktaki "+" düğmesinin hemen üstüne düşüyor.
      expect(resolveRadialCloseSlot(radius: _r), _near(const Offset(0, _r)));
    });
  });

  group('kural her sayıda çalışıyor', () {
    for (final count in [1, 2, 3, 4, 5, 6, 8]) {
      test('$count eylem: eşit aralıklı ve alt yuva boş', () {
        final slots = resolveRadialSlots(actionCount: count, radius: _r);
        final close = resolveRadialCloseSlot(radius: _r);

        expect(slots, hasLength(count));

        // Yarıçap sabit.
        for (final slot in slots) {
          expect(slot.distance, closeTo(_r, 0.01));
        }

        // Komşu yuvalar arasındaki mesafe eşit → açılar eşit aralıklı.
        if (count >= 2) {
          final first = (slots[1] - slots[0]).distance;
          for (var i = 2; i < slots.length; i++) {
            expect((slots[i] - slots[i - 1]).distance, closeTo(first, 0.01));
          }
        }

        // Komşu daireler de, kapatma düğmesi de üst üste binmemeli.
        // Eylem dairesi 64, kapatma 56.
        for (final slot in slots) {
          expect(
            (slot - close).distance,
            greaterThan((64 + 56) / 2),
            reason: '$count eylemde bir daire kapatma düğmesine biniyor',
          );
        }
        if (count >= 2) {
          expect(
            (slots[1] - slots[0]).distance,
            greaterThan(64),
            reason: '$count eylemde komşu daireler üst üste biniyor',
          );
        }
      });
    }

    test('tek eylemde de tepede duruyor', () {
      final slots = resolveRadialSlots(actionCount: 1, radius: _r);
      expect(slots.single, _near(const Offset(0, -_r)));
    });

    test('eylem yoksa boş liste — çökmez', () {
      expect(resolveRadialSlots(actionCount: 0, radius: _r), isEmpty);
    });
  });
}
