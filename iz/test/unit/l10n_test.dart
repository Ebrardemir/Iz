/// Çok dillilik KORUMA testleri.
///
/// NEDEN BU TEST VAR?
/// Çeviri disiplini kendiliğinden bozulur: acele bir düzeltme sırasında
/// widget'a doğrudan 'Kaydet' yazmak `flutter analyze`ı geçer, testleri
/// geçer, gözden de kaçar. Sonuç, aylar sonra fark edilen yarı Türkçe bir
/// İngilizce arayüzdür.
///
/// Bu iki test o hatayı **yazıldığı gün** yakalar:
///   1. Her dilde aynı anahtarlar var mı?
///   2. Arayüz kodunda çeviriden geçmeyen metin kaldı mı?
///
/// Bunlar birer "lint" görevi görür. `flutter analyze` yerine test olarak
/// yazıldılar çünkü projede özel lint paketi (custom_lint) yok — bkz.
/// pubspec.yaml'daki riverpod_lint notu.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/l10n/app_languages.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';

/// Yalnızca Türkçede bulunan harfler. `i`/`I` iki dilde de olduğu için
/// listede yok — yanlış alarm vermesin.
final _turkishChars = RegExp('[çğıöşüÇĞİÖŞÜ]');

/// Dart string literalleri (tek ve çift tırnak).
final _stringLiteral = RegExp(
  "'[^'\\n]*'"
  r'|"[^"\n]*"',
);

/// Doğrudan kullanıcıya metin basan yerler.
///
/// NEDEN İKİNCİ BİR KURAL?
/// [_turkishChars] yalnızca Türkçeye özgü harf İÇEREN metinleri yakalar;
/// `Text('Save')` veya `Text('Not')` gözden kaçardı. Bu desen ise metnin
/// dilinden bağımsız olarak "buraya sabit metin yazılmış" durumunu yakalar.
///
/// Sondaki `(?=['"])` bir *ileri bakış*tır: eşleşme tırnağın hemen ÖNÜNDE
/// biter, böylece literalin kendisini ayrıca okuyabiliriz.
final _uiTextPrefix = RegExp(
  r'''(?:Text|SelectableText)\(\s*(?:const\s+)?(?=['"])'''
  r'''|(?:labelText|hintText|helperText|tooltip|semanticLabel|label|title'''
  r'''|message|actionLabel|confirmLabel|cancelLabel)\s*:\s*(?:const\s+)?(?=['"])''',
);

/// `$değişken` ve `${ifade}` — bunlar metin değil, veridir.
final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');

/// Herhangi bir dilde harf.
final _anyLetter = RegExp('[A-Za-zçğıöşüÇĞİÖŞÜ]');

/// Literalin içinde gerçekten *insan metni* var mı?
///
/// `'${l10n.commonSearch}…'` veya `'${memory.mediaCount}'` çeviriden geçmiş
/// ya da salt veridir — interpolasyonları atınca harf kalmaz, suçlu değildir.
bool _hasHumanText(String literal) =>
    _anyLetter.hasMatch(literal.replaceAll(_interpolation, ''));

/// Tırnakla başlayan literali okur; kapanmıyorsa null.
String? _readLiteral(String code, int quoteIndex) {
  final quote = code[quoteIndex];
  final end = code.indexOf(quote, quoteIndex + 1);
  return end < 0 ? null : code.substring(quoteIndex + 1, end);
}

/// Arayüz metinlerinin yaşadığı klasörler. Buralarda sabit metin OLMAMALI.
const _scannedDirs = ['lib/features', 'lib/shared', 'lib/app/router'];

/// Bilinçli istisnalar. Yeni bir satır eklerken NEDENİNİ de yaz.
const _allowedFiles = <String>{
  // Tasarım önizlemesi için yazılmış SAHTE KULLANICI VERİSİ ("Kahve
  // Molası", "3 gün önce"...). Bunlar arayüz metni değil, kullanıcının
  // gireceği içeriğin taklidi — çeviriden geçmemeleri gerekiyor.
  // Veri bağlandığında dosya silinecek, istisna da kalkacak.
  'lib/features/home/presentation/views/home_preview_data.dart',

  // Aynı gerekçe, "Hayatım" ekranı için: takvimin altındaki panelin dolu
  // hâlini görebilmek için yazılmış sahte anı başlıkları ve kategori adları
  // ("Kahve Molası", "Seyahat"). Kategori adı özellikle dikkat isteyen bir
  // durum: SİSTEM kategorilerinin adı çeviriden gelir
  // (bkz. category_l10n.dart), ama burada taklit ettiğimiz şey veritabanından
  // okunmuş hâlidir — yani veri.
  'lib/features/my_life/presentation/views/my_life_preview_data.dart',

  // Aynı gerekçe, RİTÜEL formundaki seçim listeleri ve anı seçme sayfası için:
  // kişi ve anı kayıtlarını okuyacak katman yok, listelerin dolu hâlini
  // görebilmek için sahte adlar ("Annem", "Kahve Molası") yazdık. Kategori bu
  // dosyada YOK — o gerçekten çeviriden geliyor (bkz. category_l10n.dart).
  'lib/shared/preview/form_preview_data.dart',

  // Aynı gerekçe, seri detay ekranı için: seriye bağlı anıları okuyacak sorgu
  // yok, ekranın dolu hâlini görebilmek için sahte anı başlıkları ve kategori
  // adları yazdık ("Kaş'ta gün batımı", "Seyahat").
  'lib/features/rituals/presentation/views/ritual_detail_preview_data.dart',

  // Aynı gerekçe, anı formundaki seçim listeleri için: kişi/koleksiyon/seri
  // kayıtlarını okuyacak katman yok, listelerin dolu hâlini görebilmek için
  // sahte adlar ("Annem", "Kapadokya 2026") yazdık. Kategori bu dosyada
  // YOK — o gerçekten çeviriden geliyor (bkz. category_l10n.dart).
  'lib/features/memories/presentation/views/memory_form_preview_data.dart',

  // Aynı gerekçe, kişi listesi için: sahte kişi adları ("Annem", "Elif").
  // İLİŞKİ TÜRLERİ bu dosyada metin OLARAK GEÇMİYOR — enum kullanılıyor ve
  // adları çeviriden geliyor (bkz. person_l10n.dart).
  'lib/features/people/presentation/views/people_preview_data.dart',

  // BAMBAŞKA BİR GEREKÇE: burada Türkçe kelimeler var ama hiçbiri kullanıcıya
  // GÖSTERİLMİYOR. Dosyanın tek işi kullanıcının yazdığı ilişki metnini
  // ("Annem", "kankam") tanınabilir köklerle eşleştirmek; kökler çevrilecek
  // metin değil, tanıma kuralının kendisi.
  //
  // Muafiyet DAR: dosya yalnızca bu tabloyu ve tek bir fonksiyonu taşıyor.
  // Uygulama başka bir dile açıldığında tablo dile göre bölünecek ve o gün
  // burası yeniden değerlendirilecek.
  'lib/features/people/domain/relation_guess.dart',

  // Kişi detayındaki koleksiyon ve ritüel adları ("Kapadokya 2026", "Doğum
  // Günleri") — kullanıcı verisi taklidi, arayüz metni değil.
  'lib/features/people/presentation/views/person_detail_preview_data.dart',
};

void main() {
  group('çeviri dosyaları', () {
    late Map<String, Map<String, dynamic>> arbs;

    setUpAll(() {
      arbs = {
        for (final language in AppLanguages.all)
          language.code:
              json.decode(
                    File(
                      'lib/core/l10n/arb/app_${language.code}.arb',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>,
      };
    });

    test('form alanı ipuçları her dilde BÜYÜK harfle başlar', () {
      // Alanların içindeki yer tutucu metinler ("E-posta", "Şifre"...)
      // cümle gibi okunur; küçük harfle başlayanlar tasarımda özensiz
      // duruyordu. Kural TÜM dillerde geçerli, o yüzden testi tek tek
      // dosyaya değil listeye bağladık.
      const hintKeys = [
        'authEmail',
        'authPassword',
        'authFullName',
        'authPasswordAgain',
      ];

      for (final entry in arbs.entries) {
        for (final key in hintKeys) {
          final value = entry.value[key] as String?;
          expect(value, isNotNull, reason: '${entry.key}: $key eksik');
          final first = value!.characters.first;
          expect(
            first,
            first.toUpperCase(),
            reason: '${entry.key}.$key büyük harfle başlamalı: "$value"',
          );
        }
      }
    });

    test('desteklenen her dil için bir .arb dosyası var', () {
      for (final language in AppLanguages.all) {
        expect(
          File('lib/core/l10n/arb/app_${language.code}.arb').existsSync(),
          isTrue,
          reason:
              '${language.nativeName} (${language.code}) AppLanguages.all '
              'içinde ama app_${language.code}.arb dosyası yok.',
        );
      }
    });

    test('tüm diller aynı anahtar kümesine sahip', () {
      // '@' ile başlayanlar meta veridir (description/placeholders),
      // çeviri değildir — karşılaştırma dışı bırakıyoruz.
      Set<String> keysOf(String code) =>
          arbs[code]!.keys.where((k) => !k.startsWith('@')).toSet();

      final reference = keysOf('tr');

      for (final language in AppLanguages.all) {
        final keys = keysOf(language.code);

        expect(
          keys.difference(reference),
          isEmpty,
          reason:
              'app_${language.code}.arb içinde app_tr.arb\'de olmayan anahtar '
              'var. Şablon dosya app_tr.arb — önce oraya ekle.',
        );
        expect(
          reference.difference(keys),
          isEmpty,
          reason:
              'app_${language.code}.arb içinde EKSİK çeviri var. Eksik '
              'anahtarlar o dilde Türkçe görünür.',
        );
      }
    });

    test('hiçbir çeviri boş değil', () {
      for (final language in AppLanguages.all) {
        arbs[language.code]!.forEach((key, value) {
          if (key.startsWith('@')) return;
          expect(
            (value as String).trim(),
            isNotEmpty,
            reason: 'app_${language.code}.arb → "$key" boş.',
          );
        });
      }
    });
  });

  /// ASIL SÖZLEŞME: iş kuralı hataları domain'de METİN değil KOD taşır,
  /// çeviri UI katmanında seçilir. Bu testler o zincirin uçtan uca
  /// çalıştığını kanıtlar.
  group('Failure çevirisi', () {
    late AppL10n tr;
    late AppL10n en;

    setUpAll(() async {
      // Widget kurmadan çeviri sınıfı yüklenebilir — saf Dart testi.
      tr = await AppL10n.delegate.load(const Locale('tr'));
      en = await AppL10n.delegate.load(const Locale('en'));
    });

    test('aynı hata, uygulamanın diline göre farklı metin verir', () {
      const failure = ValidationFailure(code: ValidationCode.emptyMemory);

      expect(
        failure.localizedMessage(tr),
        'Bir anı en az bir not veya bir fotoğraf içermeli.',
      );
      expect(
        failure.localizedMessage(en),
        'A memory needs at least a note or one photo.',
      );
    });

    test('limit çeviriye yerleşir ve dil sızmaz', () {
      const failure = ValidationFailure(
        code: ValidationCode.photoLimitExceeded,
        limit: 3,
      );

      expect(failure.localizedMessage(tr), contains('3'));
      expect(failure.localizedMessage(en), contains('3'));
      // İngilizce metinde Türkçe kelime kalmamalı — eski hatanın nöbetçisi.
      expect(failure.localizedMessage(en), isNot(contains('fotoğraf')));
    });

    test('her ValidationCode her dilde bir metne sahip', () {
      for (final code in ValidationCode.values) {
        final failure = ValidationFailure(code: code, limit: 3);

        for (final l10n in [tr, en]) {
          expect(
            failure.localizedMessage(l10n).trim(),
            isNotEmpty,
            reason: '$code için çeviri boş.',
          );
        }
      }
    });

    test('teknik message kullanıcıya sızmaz', () {
      const failure = ValidationFailure(code: ValidationCode.futureDate);

      // `message` loga gider; ekranda görünen metin ondan farklı olmalı.
      expect(failure.message, isNot(failure.localizedMessage(tr)));
    });
  });

  test('arayüz kodunda sabit Türkçe metin kalmamış', () {
    final offenders = <String>[];
    // Aynı satır iki kurala da takılabilir; raporda bir kez görünsün.
    final reportedLines = <String>{};

    for (final dir in _scannedDirs) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;

      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'));

      for (final file in files) {
        final relative = file.path.replaceAll(r'\', '/');
        if (_allowedFiles.any(relative.endsWith)) continue;

        // Ekran çizen dosyalar mı, yoksa data/domain mi?
        final isUiFile =
            relative.contains('/presentation/') ||
            relative.contains('lib/shared/') ||
            relative.contains('lib/app/router/');

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          // Yorumları at: `//` öncesini al. (String içindeki `//` — örn. bir
          // URL — kesilebilir, ama URL'lerde Türkçe harf olmaz; bu kayıp
          // yalnızca yanlış alarmı azaltır.)
          final commentIndex = lines[i].indexOf('//');
          final code = commentIndex >= 0
              ? lines[i].substring(0, commentIndex)
              : lines[i];

          // `assert(...)` mesajları GELİŞTİRİCİYE yazılır: sürüm derlemesinde
          // tamamen elenirler, kullanıcı hiçbir koşulda görmez. Çeviri
          // beklemek yanlış alarm olur — ilk yakaladığı şey ana sayfadaki
          // "tam dört sayaç bekleniyor" iddiasıydı.
          if (code.contains('assert(')) continue;

          final location = '$relative:${i + 1}';

          // 1) Türkçeye özgü harf içeren HER metin (nerede olursa olsun).
          for (final match in _stringLiteral.allMatches(code)) {
            final literal = match.group(0)!;
            if (_turkishChars.hasMatch(literal) &&
                reportedLines.add(location)) {
              offenders.add('$location  ${lines[i].trim()}');
            }
          }

          // 2) Dili ne olursa olsun, kullanıcıya metin basan yerlere
          //    doğrudan yazılmış literal (`Text('Save')`, `hintText: '...'`).
          //
          //    Bu kural yalnızca ARAYÜZ dosyalarında geçerli: `data/` ve
          //    `domain/` katmanlarındaki `message:` alanları loga gider,
          //    kullanıcıya değil (bkz. Failure.message).
          if (!isUiFile) continue;

          for (final match in _uiTextPrefix.allMatches(code)) {
            final literal = _readLiteral(code, match.end);
            if (literal == null || !_hasHumanText(literal)) continue;

            if (reportedLines.add(location)) {
              offenders.add('$location  ${lines[i].trim()}');
            }
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu metinler çeviriden geçmiyor; uygulama İngilizceye alındığında '
          'Türkçe kalırlar.\n'
          'ÇÖZÜM: metni lib/core/l10n/arb/app_tr.arb ve app_en.arb dosyalarına '
          'taşı, sonra `flutter gen-l10n` çalıştırıp context.l10n.<anahtar> '
          'ile kullan.\n'
          'Gerçekten istisna gerekiyorsa (kullanıcı verisi, log metni, dil '
          'adı) dosyayı bu testteki _allowedFiles listesine NEDENİYLE ekle.\n\n'
          '${offenders.join('\n')}',
    );
  });
}
