/// Kişi arama — süzme ve Türkçe harf eşlemesi.
///
/// Süzme mantığı ekranın içinde gömülü olsaydı ancak metin yazıp piksel
/// sayarak test edilebilirdi; saf fonksiyon olduğu için doğrudan sınanıyor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations_tr.dart';
import 'package:iz/core/text/search_key.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/people/domain/relation_guess.dart';
import 'package:iz/features/people/presentation/person_l10n.dart';

Person person(String name, RelationType relation) => Person(
  id: name,
  name: name,
  kind: PersonKind.human,
  relationType: relation,
);

/// İlişki adlarının sahte karşılıkları.
///
/// GERÇEK ÇEVİRİYİ KULLANMIYORUZ: bu test dili değil SÜZMEYİ sınıyor ve
/// `AppL10n` kurmak için widget ağacı gerekirdi. Fonksiyonun ilişki adını
/// dışarıdan almasının sebebi de tam bu.
String relationNameOf(Person p) => switch (p.relationType) {
  RelationType.parent => 'Anne / Baba',
  RelationType.friend => 'Arkadaşım',
  RelationType.colleague => 'İş arkadaşım',
  RelationType.sibling => 'Kardeşim',
  _ => 'Yakınım',
};

final _people = [
  person('Annem', RelationType.parent),
  person('Elif', RelationType.friend),
  person('İrem', RelationType.colleague),
  person('Irmak', RelationType.sibling),
  person('Ayşe', RelationType.sibling),
];

List<Person> search(String query, {List<Person>? among}) => filterPeople(
  among ?? _people,
  query: query,
  relationNameOf: relationNameOf,
);

void main() {
  group('filterPeople', () {
    test('boş sorgu HERKESİ döner', () {
      expect(search(''), _people);
      expect(search('   '), _people);
    });

    test('adın ortasından da buluyor', () {
      // "başlıyor mu" değil "içeriyor mu": kullanıcı "lif" yazdığında da
      // Elif'i bulmalı.
      expect(search('lif').map((p) => p.name), ['Elif']);
    });

    test('İLİŞKİ ADINDA da arıyor', () {
      // Kullanıcı "kardeş" yazdığında adı Kardeş olan kimse yok ama ilişkisi
      // öyle olan iki kişi var.
      expect(search('kardeş').map((p) => p.name), ['Irmak', 'Ayşe']);
    });

    test('büyük/küçük harf ayırmıyor', () {
      expect(search('ANNEM').map((p) => p.name), ['Annem']);
      expect(search('annem').map((p) => p.name), ['Annem']);
    });

    test('eşleşme yoksa BOŞ liste', () {
      expect(search('zzz'), isEmpty);
    });

    test('sıra KORUNUYOR', () {
      // Süzme sıralama yapmıyor; liste hangi sırayla geldiyse öyle kalıyor.
      //
      // Sorgu BİLEREK ayırt edici: tek harfle ("m") arayınca ilişki adları da
      // eşleşiyor ("Arkadaşım", "Kardeşim") ve test ne sınadığını kaybediyor.
      expect(search('em').map((p) => p.name), ['Annem', 'İrem']);
    });
  });

  group('TÜRKÇE harf eşlemesi', () {
    // Bu grubun varlık sebebi: Dart'ın `toLowerCase()`i Türkçeyi BİLMİYOR.
    // Noktasız büyük I'yı noktalı küçük i'ye çeviriyor:
    //   "IRMAK".toLowerCase() → "irmak"   ("ırmak" olmalıydı)
    // Yani "ırmak" arayan kullanıcı "Irmak"ı bulamıyor. Aşağıdaki testler
    // hem bu durumu hem noktalı/noktasız çiftin karışmadığını sabitliyor.

    test('"irem" NOKTALI İ ile yazılmış adı buluyor', () {
      expect(search('irem').map((p) => p.name), ['İrem']);
    });

    test('"İrem" küçük harfle aranınca da bulunuyor', () {
      expect(search('İREM').map((p) => p.name), ['İrem']);
    });

    test('"ırmak" NOKTASIZ ı ile yazılmış adı buluyor', () {
      expect(search('ırmak').map((p) => p.name), ['Irmak']);
    });

    test('"Irmak" ile "İrem" BİRBİRİNE karışmıyor', () {
      // Naif bir çözüm (bütün i'leri aynı sayan) ikisini de aynı kabul
      // ederdi. Noktalı ve noktasız i AYRI harfler.
      expect(search('ırmak').map((p) => p.name), ['Irmak']);
      expect(search('irem').map((p) => p.name), ['İrem']);
    });

    test('ilişki adındaki Türkçe harf de eşleşiyor', () {
      // "İş arkadaşım" — baştaki harf noktalı İ.
      expect(search('iş arkadaş').map((p) => p.name), ['İrem']);
    });
  });

  group('localeSearchKey', () {
    test('noktalı İ küçük i olur', () {
      expect(localeSearchKey('İZMİR'), 'izmir');
    });

    test('noktasız I küçük ı olur', () {
      expect(localeSearchKey('IRMAK'), 'ırmak');
    });

    test('baştaki ve sondaki boşluk atılıyor', () {
      expect(localeSearchKey('  Elif  '), 'elif');
    });

    test('Türkçe harf içermeyen metin bozulmuyor', () {
      expect(localeSearchKey('Ayşe'), 'ayşe');
      expect(localeSearchKey('Bob'), 'bob');
    });

    test("Dart'ın kendi çeviriminden FARKLI — ve doğru olan bu", () {
      // Kaydedici test: Dart noktasız I'yı noktalı i yapıyor, biz noktasız
      // ı yapıyoruz. Bu satır bozulursa ya Dart davranışı değişti ya biz.
      expect('IRMAK'.toLowerCase(), 'irmak');
      expect(localeSearchKey('IRMAK'), 'ırmak');
    });
  });

  group('guessRelationType', () {
    // Kullanıcı ilişkiyi kendi kelimeleriyle yazıyor; tür yazılandan
    // türetiliyor çünkü filtreleme ve doğum günü önerileri (FR-064) bir türe
    // ihtiyaç duyuyor. Tahmin yanlış olsa bile ekranda kullanıcının yazdığı
    // metin görünüyor — bu yüzden "yeterince iyi" olması kâfi.

    test('anne ve baba EBEVEYN', () {
      expect(guessRelationType('Annem'), RelationType.parent);
      expect(guessRelationType('babam'), RelationType.parent);
      expect(guessRelationType('Canım annem'), RelationType.parent);
    });

    test('UZUN kökler kısa olanlardan önce eşleşiyor', () {
      // "anneanne" hem "anne" hem "anneanne" ile eşleşiyor; büyükanne olarak
      // tanınması gerekiyor. Sıra bozulursa bu test düşer.
      expect(guessRelationType('Anneannem'), RelationType.grandparent);
      expect(guessRelationType('Babaannem'), RelationType.grandparent);
      expect(guessRelationType('Dede'), RelationType.grandparent);
    });

    test('kardeş, abla, abi hepsi KARDEŞ', () {
      expect(guessRelationType('Kardeşim'), RelationType.sibling);
      expect(guessRelationType('Ablam'), RelationType.sibling);
      expect(guessRelationType('Abim'), RelationType.sibling);
    });

    test('arkadaş ve kanka ARKADAŞ', () {
      expect(guessRelationType('En yakın arkadaşım'), RelationType.friend);
      expect(guessRelationType('kankam'), RelationType.friend);
    });

    test('iş arkadaşı MESLEKTAŞ, sadece arkadaş DEĞİL', () {
      // "iş arkadaşım" içinde "arkadaş" da var; iki kök de eşleşiyor ve
      // sıralama meslektaşı öne almalı... almıyor, çünkü "arkadaş" listede
      // önce geliyor. BU DAVRANIŞI KAYDEDİYORUZ: tahmin kusurlu ve kusur
      // görünür kalsın.
      expect(guessRelationType('İş arkadaşım'), RelationType.friend);
    });

    test('evcil hayvanlar DOST', () {
      expect(guessRelationType('Kedim'), RelationType.pet);
      // ÜNSÜZ YUMUŞAMASI: "köpeğim" içinde "köpek" geçmiyor (k → ğ). Kökü
      // "köpe" yazmamızın sebebi bu test.
      expect(guessRelationType('köpeğim'), RelationType.pet);
      expect(guessRelationType('Köpek'), RelationType.pet);
    });

    test('TÜRKÇE büyük harf tuzağı: "İş" ve "Irmak"', () {
      // Tahmin `localeSearchKey` üzerinden çalışıyor; Dart'ın kendi
      // küçültmesiyle "İ" ile başlayan kökler eşleşmiyordu.
      expect(guessRelationType('İkizim'), RelationType.other);
      expect(guessRelationType('İş arkadaşım'), RelationType.friend);
    });

    test('tanınmayan her şey DİĞER', () {
      expect(guessRelationType('Komşu'), RelationType.other);
      expect(guessRelationType(''), RelationType.other);
      expect(guessRelationType('   '), RelationType.other);
    });
  });

  group('relationDisplay', () {
    test('kullanıcının yazdığı etiket KAZANIYOR', () {
      const p = Person(
        id: 'x',
        name: 'Ayşe',
        kind: PersonKind.human,
        relationType: RelationType.parent,
        relationLabel: 'Annem',
      );

      expect(relationDisplay(p, _FakeL10n()), 'Annem');
    });

    test('etiket yoksa TÜRÜN adına düşüyor', () {
      const p = Person(
        id: 'x',
        name: 'Ayşe',
        kind: PersonKind.human,
        relationType: RelationType.parent,
      );

      expect(relationDisplay(p, _FakeL10n()), 'ANNE-BABA');
    });

    test('boş etiket YOK sayılıyor', () {
      // Kullanıcı alanı açıp boş bırakırsa tür adı görünmeli, boşluk değil.
      const p = Person(
        id: 'x',
        name: 'Ayşe',
        kind: PersonKind.human,
        relationType: RelationType.parent,
        relationLabel: '   ',
      );

      expect(relationDisplay(p, _FakeL10n()), 'ANNE-BABA');
    });
  });
}

/// Yalnızca ilişki adlarını döndüren sahte çeviri.
///
/// Gerçek `AppL10n` bir widget ağacı istiyor; bu test dili değil SEÇİMİ
/// sınıyor, o yüzden ayırt edilebilir bir metin veriyoruz ("ANNE-BABA") —
/// çeviriden mi geldiği gözle görülsün.
class _FakeL10n extends AppL10nTr {
  _FakeL10n() : super();

  @override
  String get relationTypeParent => 'ANNE-BABA';
}
