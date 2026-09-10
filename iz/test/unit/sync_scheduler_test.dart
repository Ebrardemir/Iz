/// Motorun NE ZAMAN çalıştığı.
///
/// Zamanlayıcıyı sahte bir motorla sınıyoruz: burada test edilen şey
/// eşitlemenin kendisi değil, tetikleme kuralları. Gerçek motor kurmak
/// sahte sunucu ve veritabanı gerektirir ve bu testleri okunmaz yapardı.
///
/// SÜRELER KÜÇÜLTÜLÜYOR (30 sn yerine milisaniye). Sahte bir saat kurmak
/// yerine gerçek zamanlayıcıyı kısa sürelerle koşturmak, aynı kod yolunu
/// sınıyor ve bir bağımlılık daha eklemiyor.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/database/owner_scope.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/sync/data/repositories/sync_scheduler.dart';
import 'package:iz/features/sync/domain/entities/sync_outcome.dart';
import 'package:iz/features/sync/domain/repositories/sync_repository.dart';

final class _FakeSync implements SyncRepository {
  _FakeSync({this.hata, this.gecikme = Duration.zero});

  Failure? hata;
  Duration gecikme;

  int cagriSayisi = 0;

  /// Aynı anda kaç tur koştuğunu ölçüyor — paralel tur OLMAMALI.
  int esZamanli = 0;
  int enYuksekEsZamanli = 0;

  final _turBasladi = StreamController<void>.broadcast();
  Stream<void> get turBasladi => _turBasladi.stream;

  @override
  Future<Result<SyncOutcome>> syncNow() async {
    cagriSayisi++;
    esZamanli++;
    enYuksekEsZamanli = esZamanli > enYuksekEsZamanli
        ? esZamanli
        : enYuksekEsZamanli;
    _turBasladi.add(null);

    if (gecikme > Duration.zero) await Future<void>.delayed(gecikme);

    esZamanli--;
    return hata == null ? const Ok(SyncOutcome(pushed: 1)) : Err(hata!);
  }
}

/// Kısa süreli zamanlayıcı kurar.
SyncScheduler _kur(
  _FakeSync motor,
  Stream<int> kuyruk, {
  Stream<String>? hesapDegisimleri,
  Duration bekleme = const Duration(milliseconds: 40),
  Duration enAzYeniden = const Duration(milliseconds: 20),
  Duration enCokYeniden = const Duration(milliseconds: 80),
}) => SyncScheduler(
  sync: motor,
  pendingCount: kuyruk,
  ownerChanges: hesapDegisimleri,
  writeDebounce: bekleme,
  minRetryDelay: enAzYeniden,
  maxRetryDelay: enCokYeniden,
);

Future<void> _bekle([int ms = 120]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late StreamController<int> kuyruk;
  late OwnerScope kapsam;

  setUp(() {
    kuyruk = StreamController<int>.broadcast();
    kapsam = OwnerScope();
  });

  tearDown(() async {
    await kuyruk.close();
    await kapsam.dispose();
  });

  group('giriş', () {
    test('GİRİŞ YAPILINCA hemen tur başlıyor', () async {
      // GERÇEK OLAY: ikinci bir cihazda hesabına giren kullanıcının verisi
      // gelmiyordu. Açılış turu, kullanıcı henüz giriş yapmadığı için boş
      // dönüyordu; kuyruk beklemesi yalnız YAZMA olduğunda çalışır ve taze
      // cihazda kuyruk boştur. Geriye tek yol kalıyordu: uygulamayı arka
      // plana atıp geri açmak. Veri "gecikmeli" geliyordu.
      final motor = _FakeSync();
      _kur(motor, kuyruk.stream, hesapDegisimleri: kapsam.changes).start();
      await _bekle();

      final acilistakiTur = motor.cagriSayisi;

      kapsam.enter('kullanici-1');
      await _bekle();

      expect(motor.cagriSayisi, acilistakiTur + 1);
    });

    test('BEKLEMEYE takılmıyor', () async {
      // Otuz saniye bekletseydik kullanıcı çalışan bir eşitlemeyi bozuk
      // sanardı.
      final motor = _FakeSync();
      _kur(
        motor,
        kuyruk.stream,
        hesapDegisimleri: kapsam.changes,
        bekleme: const Duration(seconds: 30),
      ).start();
      await _bekle();

      final once = motor.cagriSayisi;
      kapsam.enter('kullanici-1');
      await _bekle(60);

      expect(motor.cagriSayisi, once + 1);
    });

    test('AYNI hesap tekrar girilince tur AÇILMIYOR', () async {
      // Her açılışta önbellekten okunan kimlik gereksiz bir tur tetiklerdi.
      final motor = _FakeSync();
      kapsam.enter('kullanici-1');
      _kur(motor, kuyruk.stream, hesapDegisimleri: kapsam.changes).start();
      await _bekle();

      final once = motor.cagriSayisi;
      kapsam.enter('kullanici-1');
      await _bekle();

      expect(motor.cagriSayisi, once);
    });

    test('ÇIKIŞ tur başlatmıyor', () async {
      // Gönderilecek oturum yok; motor zaten hemen dönerdi.
      final motor = _FakeSync();
      kapsam.enter('kullanici-1');
      _kur(motor, kuyruk.stream, hesapDegisimleri: kapsam.changes).start();
      await _bekle();

      final once = motor.cagriSayisi;
      kapsam.leave();
      await _bekle();

      expect(motor.cagriSayisi, once);
    });
  });

  group('açılış', () {
    test('start() bir tur başlatıyor', () async {
      // Uygulama kapalıyken başka cihazda yapılan değişiklikler ilk açılışta
      // gelsin diye.
      final motor = _FakeSync();
      final zamanlayici = _kur(motor, kuyruk.stream)..start();

      await _bekle(30);
      expect(motor.cagriSayisi, 1);

      await zamanlayici.dispose();
    });
  });

  group('öne gelme', () {
    test('onResumed() beklemeye takılmadan tur başlatıyor', () async {
      // Kullanıcı ekrana baktığı an en taze hâli görmeli.
      final motor = _FakeSync();
      final zamanlayici = _kur(motor, kuyruk.stream)..start();
      await _bekle(30);

      zamanlayici.onResumed();
      await _bekle(30);

      expect(motor.cagriSayisi, 2);
      await zamanlayici.dispose();
    });
  });

  group('yazma sonrası bekleme', () {
    test('kuyruk dolunca BEKLEYİP tur başlatıyor', () async {
      final motor = _FakeSync();
      final zamanlayici = _kur(motor, kuyruk.stream)..start();
      await _bekle(30);
      final acilis = motor.cagriSayisi;

      kuyruk.add(1);

      // Bekleme dolmadan tur BAŞLAMAMALI.
      await _bekle(15);
      expect(motor.cagriSayisi, acilis);

      await _bekle(60);
      expect(motor.cagriSayisi, acilis + 1);

      await zamanlayici.dispose();
    });

    test('arka arkaya yazmalar TEK tura düşüyor', () async {
      // Kullanıcı beş anı düzenlediğinde beş istek değil, sonuncudan sonra
      // tek istek gitmeli.
      final motor = _FakeSync();
      final zamanlayici = _kur(motor, kuyruk.stream)..start();
      await _bekle(30);
      final acilis = motor.cagriSayisi;

      for (var i = 1; i <= 5; i++) {
        kuyruk.add(i);
        await _bekle(10);
      }

      await _bekle(80);
      expect(motor.cagriSayisi, acilis + 1);

      await zamanlayici.dispose();
    });

    test('kuyruk BOŞALINCA planlanmış tur iptal ediliyor', () async {
      // BU TESTİN KAPATTIĞI DÖNGÜ: turun kendisi kuyruğu boşaltıyor, bu da
      // sayacı değiştirip yeni bir tur planlıyor olurdu. Boş kuyruk için tur
      // planlamak hem gereksiz hem sonsuz.
      final motor = _FakeSync();
      final zamanlayici = _kur(motor, kuyruk.stream)..start();
      await _bekle(30);
      final acilis = motor.cagriSayisi;

      kuyruk.add(3);
      await _bekle(10);
      kuyruk.add(0); // tur bitti, kuyruk boşaldı

      await _bekle(80);
      expect(motor.cagriSayisi, acilis);

      await zamanlayici.dispose();
    });
  });

  group('aynı anda tek tur', () {
    test('süren tur varken ikinci tur BAŞLAMIYOR', () async {
      // Paralel iki tur, aynı kuyruk satırını iki kez göndermek ve aynı
      // sayfayı iki kez uygulamak demekti.
      final motor = _FakeSync(gecikme: const Duration(milliseconds: 60));
      final zamanlayici = _kur(motor, kuyruk.stream)..start();

      await _bekle(10);
      zamanlayici.onResumed();
      zamanlayici.onResumed();

      await _bekle(200);
      expect(motor.enYuksekEsZamanli, 1);

      await zamanlayici.dispose();
    });

    test('biriken tetikleyici tur bitince BİR KEZ koşuyor', () async {
      final motor = _FakeSync(gecikme: const Duration(milliseconds: 60));
      final zamanlayici = _kur(motor, kuyruk.stream)..start();

      await _bekle(10);
      zamanlayici.onResumed();
      zamanlayici.onResumed();
      zamanlayici.onResumed();

      await _bekle(250);

      // Açılış turu + biriken tetikleyiciler için TEK tur.
      expect(motor.cagriSayisi, 2);
      await zamanlayici.dispose();
    });
  });

  group('geri çekilme', () {
    test('başarısız tur YENİDEN DENENİYOR', () async {
      final motor = _FakeSync(hata: const NetworkFailure(message: 'koptu'));
      final zamanlayici = _kur(motor, kuyruk.stream)..start();

      await _bekle(200);

      // Açılış + en az bir yeniden deneme.
      expect(motor.cagriSayisi, greaterThan(1));
      await zamanlayici.dispose();
    });

    test('denemeler SEYRELİYOR — üstel geri çekilme', () async {
      final motor = _FakeSync(hata: const NetworkFailure(message: 'koptu'));
      final zamanlayici = _kur(
        motor,
        kuyruk.stream,
        enAzYeniden: const Duration(milliseconds: 20),
        enCokYeniden: const Duration(seconds: 10),
      )..start();

      await _bekle(150);
      final ilkPencere = motor.cagriSayisi;

      await _bekle(150);
      final ikinciPencere = motor.cagriSayisi - ilkPencere;

      // Aynı uzunlukta ikinci pencerede DAHA AZ deneme olmalı: gecikme
      // katlanarak büyüyor.
      expect(ikinciPencere, lessThanOrEqualTo(ilkPencere));
      await zamanlayici.dispose();
    });

    test('başarılı tur geri çekilmeyi SIFIRLIYOR', () async {
      final motor = _FakeSync(hata: const NetworkFailure(message: 'koptu'));
      final zamanlayici = _kur(motor, kuyruk.stream)..start();

      await _bekle(150);
      motor.hata = null;
      await _bekle(150);
      final basariliSonrasi = motor.cagriSayisi;

      // Başarıdan sonra yeni tur PLANLANMIYOR: tetikleyici yok.
      await _bekle(150);
      expect(motor.cagriSayisi, basariliSonrasi);

      await zamanlayici.dispose();
    });
  });

  group('elle eşitleme', () {
    test('syncNow() SONUCU döndürüyor', () async {
      // Kullanıcı düğmeye bastıysa ne olduğunu görmeyi hak ediyor.
      final motor = _FakeSync();
      final zamanlayici = _kur(motor, kuyruk.stream);

      final sonuc = await zamanlayici.syncNow();

      expect(sonuc, isNotNull);
      expect(sonuc!.isOk, isTrue);
      expect(sonuc.valueOrNull!.pushed, 1);

      await zamanlayici.dispose();
    });

    test('süren tur varken BEKLİYOR, ikinci tur açmıyor', () async {
      final motor = _FakeSync(gecikme: const Duration(milliseconds: 50));
      final zamanlayici = _kur(motor, kuyruk.stream)..start();

      await _bekle(10);
      final sonuc = await zamanlayici.syncNow();

      expect(sonuc, isNotNull);
      expect(motor.enYuksekEsZamanli, 1);

      await zamanlayici.dispose();
    });
  });

  group('kapatma', () {
    test('dispose sonrası tetikleyici tur başlatmıyor', () async {
      // Çağrılmazsa sızıntı olur: kapanan uygulamada tetiklenen bir tur,
      // kapatılmış bir veritabanına yazmaya çalışır.
      final motor = _FakeSync();
      final zamanlayici = _kur(motor, kuyruk.stream)..start();
      await _bekle(30);

      await zamanlayici.dispose();
      final kapanistaki = motor.cagriSayisi;

      zamanlayici.onResumed();
      kuyruk.add(5);
      expect(await zamanlayici.syncNow(), isNull);

      await _bekle(120);
      expect(motor.cagriSayisi, kapanistaki);
    });
  });
}
