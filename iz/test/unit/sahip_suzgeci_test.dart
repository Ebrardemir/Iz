/// SAHİP SÜZGECİ — statik koruma.
///
/// NEDEN BİR DAVRANIŞ TESTİ DEĞİL DE KAYNAK TARAMASI?
/// Bu sorunun şekli "şu sorgu yanlış" değil, "GELECEKTE yazılacak sorgulardan
/// biri süzgeci unutacak". Davranış testi yalnız BUGÜN var olan sorguları
/// kapsar; yarın eklenen bir `select(memories)` hiçbir testi kırmadan
/// sızıntıyı geri getirir ve bunu kimse fark etmez.
///
/// GERÇEK OLAY: aynı cihazda ikinci bir hesapla giriş yapan kullanıcı,
/// birinci hesabın anılarını, kişilerini ve günlüklerini ekranda gördü.
/// Sebep, `ownerId` sütununun her sahipli tabloda DURMASI ama hiçbir okuma
/// sorgusunun ona BAKMAMASIYDI. Görmek tek başına yeterince kötüydü; asıl
/// tehlike gördüğü bir kaydı düzenlemesi hâlinde o kaydın kuyruğa girip
/// KENDİ hesabına yüklenmesiydi.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `OwnedTable` karıştıran tabloların Drift'teki alan adları.
///
/// Bu liste `lib/core/database/table_mixins.dart`taki `OwnedTable` mixin'ini
/// kullanan tablolarla AYNI olmak zorunda; aşağıdaki ilk test bunu denetliyor,
/// çünkü listeye eklenmeyen yeni bir sahipli tablo sessizce süzgeçsiz kalırdı.
const _sahipliTablolar = {
  'memories',
  'journalEntries',
  'people',
  'categories',
  'collections',
  'rituals',
};

/// Süzgeç kuralının DIŞINDA kalan dosyalar.
///
/// Senkronizasyon DAO'ları bilinçli olarak hesap kapsamının dışında çalışıyor:
/// biri sahipliği DÜZELTEN doldurma, öteki sunucudan inen satırları yazan
/// uygulayıcı. İkisi de sahip kimliğini parametre olarak alıyor, aktif
/// kapsamdan okumuyor.
const _kapsamDisi = {'sync_backfill_dao.dart', 'sync_dao.dart'};

void main() {
  final daoKlasoru = Directory('lib/features');

  List<File> daoDosyalari() => daoKlasoru
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.replaceAll(r'\', '/').contains('/data/daos/'))
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .where((f) => !_kapsamDisi.any(f.path.endsWith))
      .toList();

  test('sahipli tablo listesi GÜNCEL', () {
    // Listeye eklenmeyen yeni bir sahipli tablo, aşağıdaki taramanın gözünden
    // kaçar ve süzgeçsiz kalır.
    final mixinKullananlar = <String>{};
    for (final dosya
        in daoKlasoru.listSync(recursive: true).whereType<File>()) {
      if (!dosya.path.contains('tables')) continue;
      if (!dosya.path.endsWith('.dart') || dosya.path.endsWith('.g.dart')) {
        continue;
      }
      final kaynak = dosya.readAsStringSync();
      for (final eslesme in RegExp(
        r'class\s+(\w+)\s+extends\s+Table\s+with\s+([\w\s,]+?)\s*\{',
      ).allMatches(kaynak)) {
        if (!eslesme.group(2)!.contains('OwnedTable')) continue;
        final sinif = eslesme.group(1)!;
        // Drift alanı sınıf adının başı küçük hâli: Memories → memories.
        mixinKullananlar.add(sinif[0].toLowerCase() + sinif.substring(1));
      }
    }

    expect(
      mixinKullananlar,
      isNotEmpty,
      reason: 'tablo tarama deseni tutmuyor — test kendini kandırıyor olabilir',
    );
    expect(
      mixinKullananlar,
      _sahipliTablolar,
      reason:
          'OwnedTable kullanan tablolar değişmiş. Yeni tabloyu bu testteki '
          'listeye ekle VE onu okuyan sorgulara sahip süzgecini koy.',
    );
  });

  test('DAO taraması gerçekten dosya buluyor', () {
    // Yol deseni bozulursa tarama sessizce boş kümede gezer ve bu dosyadaki
    // her test yeşil kalırdı — testin en tehlikeli başarısızlık biçimi.
    final dosyalar = daoDosyalari();
    expect(dosyalar.length, greaterThanOrEqualTo(6));
    expect(
      dosyalar.map((f) => f.uri.pathSegments.last),
      contains('memory_dao.dart'),
    );
  });

  test('sahipli tablodan ÇIPLAK okuma yok', () {
    final ihlaller = <String>[];

    for (final dosya in daoDosyalari()) {
      final kaynak = dosya.readAsStringSync();
      final ad = dosya.uri.pathSegments.last;

      for (final tablo in _sahipliTablolar) {
        // Üç biçim: `select(memories)`, satır sonuna sarkmış
        // `select(\n  memories,\n)` ve sayma sorgularının kullandığı
        // `selectOnly(memories)`.
        //
        // Sonuncusu ilk turda gözden kaçtı ve `countAll()` süzgeçsiz kaldı:
        // kullanıcıya BAŞKA hesabın anı sayısını gösteren bir sorgu. Koruma
        // testinin kendisi de gözden geçirilmeyi hak ediyor.
        final desen = RegExp(
          r'(?<!Owned)\bselect(Only)?\(\s*' + tablo + r'\s*,?\s*\)',
        );

        for (final eslesme in desen.allMatches(kaynak)) {
          // Kural: çıplak `select` serbest DEĞİL — ama aynı DEYİMİN içinde
          // `ownedBy(` varsa süzgeç elle eklenmiş demektir (join kuran ya da
          // `|` ile genişletilen sorgular `selectOwned`ı kullanamıyor).
          final deyimSonu = kaynak.indexOf(';', eslesme.start);
          final deyim = kaynak.substring(
            eslesme.start,
            deyimSonu == -1 ? kaynak.length : deyimSonu,
          );
          if (deyim.contains('ownedBy(')) continue;

          final satir =
              '\n'.allMatches(kaynak.substring(0, eslesme.start)).length + 1;
          ihlaller.add('$ad:$satir → ${eslesme.group(0)}');
        }
      }
    }

    expect(
      ihlaller,
      isEmpty,
      reason:
          'Sahipli tablodan süzgeçsiz okuma. `selectOwned(tablo, tablo.ownerId)` '
          'kullan; join kuran sorguda `query.where(ownedBy(tablo.ownerId))` ekle.\n'
          '${ihlaller.join('\n')}',
    );
  });

  test('koruma testi GERÇEKTEN yakalıyor', () {
    // Bir koruma testinin en kötü hâli, hiçbir şeyi yakalamayan ama yeşil
    // duran hâlidir. Deseni bilerek ihlal eden bir örnek üzerinde deniyoruz.
    final desen = RegExp(r'(?<!Owned)\bselect(Only)?\(\s*memories\s*,?\s*\)');

    expect(desen.hasMatch('final x = select(memories)..where(...);'), isTrue);
    expect(desen.hasMatch('await (select(\n  memories,\n)).get();'), isTrue);
    expect(desen.hasMatch('selectOnly(memories)..addColumns([]);'), isTrue);

    // `selectOwned` tetiklememeli.
    expect(desen.hasMatch('selectOwned(memories, memories.ownerId)'), isFalse);
  });
}
