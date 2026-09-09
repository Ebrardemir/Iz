/// Motoru NE ZAMAN çalıştıracağımıza karar veren katman.
///
/// Motor (`SyncEngine`) "nasıl"ı biliyor, bu sınıf "ne zaman"ı. Ayrı
/// durmalarının sebebi test edilebilirlik: motoru sınarken zamanlayıcı
/// kurmak, zamanlayıcıyı sınarken sahte sunucu kurmak gerekirdi.
///
/// ÜÇ TETİKLEYİCİ (BACKEND_YOL_HARITASI, Faz 3 istemci):
///   • uygulama öne geldiğinde
///   • yazma sonrası bekleme (varsayılan 30 sn)
///   • kullanıcının "şimdi eşitle" demesi
///
/// AYNI ANDA TEK TUR. Bir tur sürerken gelen tetikleyici yeni bir tur
/// başlatmıyor, "bittiğinde bir daha koş" diye işaretliyor. Paralel iki tur,
/// aynı kuyruk satırını iki kez göndermek ve aynı sayfayı iki kez uygulamak
/// demekti.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/sync/domain/entities/sync_outcome.dart';
import 'package:iz/features/sync/domain/repositories/sync_repository.dart';

final class SyncScheduler {
  SyncScheduler({
    required SyncRepository sync,
    required Stream<int> pendingCount,
    Duration writeDebounce = const Duration(seconds: 30),
    Duration minRetryDelay = const Duration(seconds: 5),
    Duration maxRetryDelay = const Duration(minutes: 10),
    Random? random,
  }) : _sync = sync,
       _pendingCount = pendingCount,
       _writeDebounce = writeDebounce,
       _minRetryDelay = minRetryDelay,
       _maxRetryDelay = maxRetryDelay,
       _random = random ?? Random();

  final SyncRepository _sync;
  final Stream<int> _pendingCount;
  final Duration _writeDebounce;
  final Duration _minRetryDelay;
  final Duration _maxRetryDelay;
  final Random _random;

  static final _log = appLogger('sync.scheduler');

  StreamSubscription<int>? _kuyrukAbonesi;
  Timer? _bekleme;
  Timer? _yenidenDeneme;

  /// Süren tur. `null` değilse yeni tur başlatılmıyor.
  Future<void>? _suren;

  /// Tur sürerken gelen tetikleyici burada birikiyor.
  bool _tekrarGerekli = false;

  /// Üst üste başarısız tur sayısı — geri çekilme buna dayanıyor.
  int _basarisiz = 0;

  bool _kapandi = false;

  /// Uygulama açılışında bir kez çağrılır.
  void start() {
    if (_kapandi) return;

    // KUYRUK DEĞİŞİMİNİ DİNLİYORUZ, yazma çağrılarını değil. Repository'lere
    // "yazdıktan sonra zamanlayıcıya haber ver" satırı eklemek, on beş yere
    // dağılmış ve biri bir gün unutulacak bir kural olurdu.
    _kuyrukAbonesi = _pendingCount.listen(_kuyrukDegisti);

    // Açılışta hemen bir tur: uygulama kapalıyken başka cihazda yapılan
    // değişiklikler ekrana ilk açılışta gelsin.
    unawaited(_calistir(reason: 'startup'));
  }

  /// Uygulama arka plandan öne geldiğinde.
  ///
  /// Beklemeye takılmıyor: kullanıcı ekrana baktığı an en taze hâli görmeli.
  void onResumed() {
    if (_kapandi) return;
    unawaited(_calistir(reason: 'resumed'));
  }

  /// Kullanıcının "şimdi eşitle" demesi.
  ///
  /// Öteki tetikleyicilerden farkı SONUCU DÖNDÜRMESİ: kullanıcı düğmeye
  /// bastıysa ne olduğunu görmeyi hak ediyor. Bir tur zaten sürüyorsa onun
  /// bitmesi bekleniyor — ikinci bir tur başlatmak yerine.
  Future<Result<SyncOutcome>?> syncNow() async {
    if (_kapandi) return null;

    _bekleme?.cancel();
    _yenidenDeneme?.cancel();

    return _calistir(reason: 'manual', sonucIsteniyor: true);
  }

  /// Kuyruk sayacı değişti.
  ///
  /// SIFIRA DÜŞTÜĞÜNDE BEKLEME İPTAL EDİLİYOR — ve bu bir döngüyü kapatıyor:
  /// turun kendisi kuyruğu boşaltıyor, bu da sayacı değiştirip yeni bir tur
  /// planlıyor olurdu. Boş kuyruk için tur planlamak hem gereksiz hem
  /// sonsuz.
  void _kuyrukDegisti(int adet) {
    if (_kapandi) return;

    if (adet == 0) {
      _bekleme?.cancel();
      _bekleme = null;
      return;
    }

    // HER YAZMADA SAYAÇ SIFIRLANIYOR. Kullanıcı arka arkaya beş anı
    // düzenlediğinde beş ayrı istek değil, sonuncudan 30 sn sonra tek istek
    // gidiyor.
    _bekleme?.cancel();
    _bekleme = Timer(
      _writeDebounce,
      () => unawaited(_calistir(reason: 'write debounce')),
    );
  }

  Future<Result<SyncOutcome>?> _calistir({
    required String reason,
    bool sonucIsteniyor = false,
  }) async {
    if (_suren case final suren?) {
      // ⚠️ ELLE TETİKLEMEDE "BİRİKTİR" İŞARETİ KONMUYOR — ve bu, bir
      // kilitlenmenin çaresi. İkisini birden yapınca şu oluyordu: süren tur
      // bitince işaret yüzünden yeni bir tur başlıyor, biz de sonucu almak
      // için onu bekliyoruz; o tur biterken işaret yine konmuş oluyor ve
      // döngü hiç kapanmıyordu. Test 30 saniyede zaman aşımına düştü.
      //
      // Doğrusu: elle çağıran ZATEN kendisi bir tur koşacak, ayrıca
      // biriktirmeye gerek yok.
      if (!sonucIsteniyor) {
        _tekrarGerekli = true;
        return null;
      }

      // Kullanıcı sonucu bekliyor: süren turu bekleyip ARDINDAN kendi
      // turumuzu koşuyoruz — bastığı andan sonraki durumu görmesi için.
      await suren;
      return _calistir(reason: reason, sonucIsteniyor: true);
    }

    final tamamlandi = Completer<void>();
    _suren = tamamlandi.future;

    Result<SyncOutcome>? sonuc;
    try {
      _log.info('sync run started ($reason)');
      sonuc = await _sync.syncNow();

      if (sonuc.isOk) {
        _basarisiz = 0;
        _yenidenDeneme?.cancel();
        _yenidenDeneme = null;
      } else {
        _geriCekil();
      }
    } finally {
      _suren = null;
      tamamlandi.complete();
    }

    if (_tekrarGerekli && !_kapandi) {
      _tekrarGerekli = false;
      unawaited(_calistir(reason: 'queued trigger'));
    }

    return sonuc;
  }

  /// Başarısız turdan sonra ÜSTEL geri çekilme + jitter.
  ///
  /// NEDEN JITTER? Sunucu bir dakika düşüp kalktığında sabit bir gecikme tüm
  /// cihazları AYNI anda geri getirir ve sunucuyu yeniden düşürürdü. Aynı
  /// gerekçe `IzRetryInterceptor`da da yazılı.
  ///
  /// Üst sınır var çünkü kullanıcı çevrimdışıyken denemeler seyrekleşmeli
  /// ama TAMAMEN durmamalı: ağ geri geldiğinde kimse "şimdi eşitle"ye
  /// basmak zorunda kalmasın.
  void _geriCekil() {
    _basarisiz++;

    final us = _minRetryDelay.inMilliseconds * pow(2, _basarisiz - 1).toInt();
    final taban = min(us, _maxRetryDelay.inMilliseconds);
    final sapma = _random.nextInt((taban ~/ 2) + 1);
    final gecikme = Duration(milliseconds: taban + sapma);

    _log.info('retry scheduled in ${gecikme.inSeconds}s (attempt $_basarisiz)');

    _yenidenDeneme?.cancel();
    _yenidenDeneme = Timer(
      gecikme,
      () => unawaited(_calistir(reason: 'retry')),
    );
  }

  /// Zamanlayıcıları ve aboneliği kapatır.
  ///
  /// ÇAĞRILMAZSA sızıntı olur: uygulama kapanırken tetiklenen bir tur,
  /// kapatılmış bir veritabanına yazmaya çalışır.
  Future<void> dispose() async {
    _kapandi = true;
    _bekleme?.cancel();
    _yenidenDeneme?.cancel();
    await _kuyrukAbonesi?.cancel();
    await _suren;
  }
}
