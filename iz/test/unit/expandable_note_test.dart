/// Notun kaç satır kapladığını ÖLÇEN saf fonksiyon.
///
/// Bu hesap widget'ın içine gömülü olsaydı ancak ekran kurup piksel ölçerek
/// test edilebilirdi; ayrı bir fonksiyon olduğu için doğrudan sınanıyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/features/memories/presentation/widgets/expandable_note.dart';

/// Ölçüm testinde GERÇEK bir yazı tipi kullanmıyoruz.
///
/// `flutter test` varsayılan olarak bütün harfleri aynı genişlikte çizen bir
/// yer tutucu fontla çalışır ("Ahem"). Bu testin işi metnin GÜZEL ölçülmesi
/// değil, ölçümün doğru KARŞILAŞTIRILMASI — sabit genişlikli font bunu daha
/// öngörülebilir yapıyor.
const _style = TextStyle(fontSize: 14, height: 1.4);

bool exceeds(String text, {double width = 200, int lines = 2}) =>
    noteExceedsLines(
      text,
      style: _style,
      maxWidth: width,
      maxLines: lines,
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
    );

void main() {
  group('noteExceedsLines', () {
    test('tek kelimelik not taşmaz', () {
      expect(exceeds('Güzeldi.'), isFalse);
    });

    test('boş metin taşmaz', () {
      expect(exceeds(''), isFalse);
    });

    test('uzun not iki satırı aşar', () {
      expect(exceeds('kelime ' * 60), isTrue);
    });

    test('AYNI metin, GENİŞ alanda taşmıyor', () {
      // Testin çekirdeği: taşma metnin uzunluğuna DEĞİL, uzunluk ile
      // genişliğin ilişkisine bağlı. Karakter sayısına bakan bir çözüm bu
      // ayrımı yapamaz — aynı 90 karakter telefonda iki, tablette tek satır.
      final text = 'kelime ' * 12;

      expect(exceeds(text, width: 120), isTrue);
      expect(exceeds(text, width: 2000), isFalse);
    });

    test('satır sınırı artınca taşma kalkıyor', () {
      final text = 'kelime ' * 12;

      expect(exceeds(text, width: 150, lines: 2), isTrue);
      expect(exceeds(text, width: 150, lines: 20), isFalse);
    });

    test('satır sonları da sayılıyor', () {
      // Üç kısa satır iki satıra sığmaz; genişlik bol olsa bile.
      expect(exceeds('bir\niki\nüç', width: 2000), isTrue);
      expect(exceeds('bir\niki', width: 2000), isFalse);
    });

    test('BÜYÜK yazı ölçeği taşmayı tetikliyor', () {
      // Erişilebilirlik ayarı açık kullanıcıda aynı metin daha fazla satır
      // kaplar; aç/kapa oku o zaman görünmeli. Ölçekleyiciyi geçirmeyi
      // unutan bir kod bu farkı kaçırırdı.
      // Normal ölçekte iki satıra TAM sığan bir uzunluk seçtik; ölçek
      // ikiye katlanınca aynı metin dört satıra çıkıyor.
      final text = 'kelime ' * 3;

      expect(
        noteExceedsLines(
          text,
          style: _style,
          maxWidth: 200,
          maxLines: 2,
          textScaler: TextScaler.noScaling,
          textDirection: TextDirection.ltr,
        ),
        isFalse,
      );
      expect(
        noteExceedsLines(
          text,
          style: _style,
          maxWidth: 200,
          maxLines: 2,
          textScaler: const TextScaler.linear(2),
          textDirection: TextDirection.ltr,
        ),
        isTrue,
      );
    });
  });
}
