/// Senkronizasyon motoru — kuyruğu boşaltır, yenileri indirir.
///
/// SIRA DEĞİŞMEZ: ÖNCE PUSH, SONRA PULL.
/// Tersi olsaydı, bu cihazda bekleyen bir değişiklik varken inen sunucu
/// sürümü onu ezerdi ve kullanıcı henüz göndermediği yazısını kaybederdi.
///
/// BİR TUR YARIDA KESİLEBİLİR ve bu normaldir. Her adım kendi başına
/// kalıcı: gönderilen satır kuyruktan düşüyor, inen sayfa yazıldıktan sonra
/// cursor kaydediliyor. Yarıda kalan tur, bir sonraki turda kaldığı yerden
/// devam ediyor.
///
/// SORUMLULUĞU DEĞİL: ne zaman çalışacağı. Tetikleyiciler (uygulama öne
/// geldiğinde, yazma sonrası bekleme, "şimdi eşitle") ayrı bir adımda.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz, bu yüzden private
// alanlara `this._x` biçiminde initializing formal kullanamıyoruz.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/storage/secure_store.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/sources/sync_api.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';
import 'package:iz/features/sync/domain/entities/sync_outcome.dart';
import 'package:iz/features/sync/domain/repositories/sync_identity.dart';
import 'package:iz/features/sync/domain/repositories/sync_repository.dart';

final class SyncEngine implements SyncRepository {
  SyncEngine({
    required AppDatabase database,
    required SyncApi api,
    required SyncIdentity identity,
    required SecureStore secureStore,
    required Clock clock,
    required IdGenerator idGenerator,
    required String platform,
    int? schemaVersion,
  }) : _db = database,
       _api = api,
       _identity = identity,
       _store = secureStore,
       _clock = clock,
       _ids = idGenerator,
       _platform = platform,
       _schemaVersion = schemaVersion ?? database.schemaVersion;

  final AppDatabase _db;

  /// `OutboxDao` veritabanına `daos:` listesiyle kayıtlı DEĞİL — çağrı
  /// yerleri onu elle kuruyor (`memory_dao.dart` da öyle yapıyor). Burada da
  /// bir kez kurup saklıyoruz.
  late final OutboxDao _outbox = OutboxDao(_db);
  final SyncApi _api;
  final SyncIdentity _identity;
  final SecureStore _store;
  final Clock _clock;
  final IdGenerator _ids;
  final String _platform;
  final int _schemaVersion;

  static final _log = appLogger('sync.engine');

  /// Sunucunun batch üst sınırı (BACKEND_YOL_HARITASI §4.1).
  static const int maxChangesPerBatch = 200;

  /// Gövde bayt sınırı — sunucunun 1 MB'ının YARISI.
  ///
  /// Sunucu sınırı aşan isteği 413 ile reddediyor. Ölçüyü İSTEMCİ tarafında
  /// yapabiliyoruz: `payloadJson` elimizde. 413'e düşüp batch küçültmek
  /// yerine hiç aşmamak, hem bir gidiş-dönüş hem de "ne kadar küçültmeliyim"
  /// tahmini kurtarıyor. Yarısı seçildi çünkü zarf ve JSON kaçışları gövdeyi
  /// büyütüyor.
  static const int maxBatchBytes = 512 * 1024;

  /// Bir turda çekilecek en fazla sayfa.
  ///
  /// Bootstrap binlerce kaydı sayfa sayfa indiriyor; sınırsız bırakmak,
  /// uygulamanın açılışta dakikalarca kilitlenmesi demek olurdu. Kalanı bir
  /// sonraki tur alıyor — cursor kaydedildiği için hiçbir şey tekrarlanmıyor.
  static const int maxPagesPerRun = 50;

  @override
  Future<Result<SyncOutcome>> syncNow() async {
    final baslangic = _clock.now();

    try {
      final ownerId = await _identity.ownerId();
      if (ownerId == null) {
        return const Err(
          AuthFailure(message: 'sync requires a signed-in account'),
        );
      }

      final deviceId = await _deviceId();
      if (deviceId == null) {
        return const Err(NetworkFailure(message: 'device registration failed'));
      }

      var sonuc = const SyncOutcome();

      final push = await _push(deviceId: deviceId, outcome: sonuc);
      if (push case Err(:final failure)) return await _fail(failure, baslangic);
      sonuc = push.valueOrNull!;

      final pull = await _pull(
        ownerId: ownerId,
        deviceId: deviceId,
        outcome: sonuc,
      );
      if (pull case Err(:final failure)) return await _fail(failure, baslangic);
      sonuc = pull.valueOrNull!;

      final bekleyen = (await _outbox.pending()).length;
      sonuc = sonuc.copyWith(pendingAfter: bekleyen);

      await _db.syncStateDao.finish(at: _clock.now(), pendingCount: bekleyen);

      _log.info('sync finished: $sonuc');
      return Ok(sonuc);
    } on Object catch (error, stackTrace) {
      // Motorun kendisi ÇÖKMEMELİ. Buraya düşen şey bir programlama hatası
      // ya da beklenmeyen bir veritabanı arızası; kullanıcının uygulaması
      // kapanmasın diye yakalanıyor ama deftere yazılıyor.
      return await _fail(
        UnexpectedFailure(
          message: 'sync stopped unexpectedly',
          cause: error,
          stackTrace: stackTrace,
        ),
        baslangic,
      );
    }
  }

  // --- Kimlik ------------------------------------------------------------

  /// Bu kurulumun cihaz kimliği; yoksa sunucuya kaydettirilip saklanıyor.
  ///
  /// KİMLİĞİ SUNUCU ÜRETİYOR (Faz 1 kararı). İstemci üretseydi başka bir
  /// cihazın kimliğini iddia edip echo kuralını, kurbanın değişikliklerini
  /// gizlemek için kullanabilirdi.
  Future<String?> _deviceId() async {
    final onbellek = await _store.read(SecureKey.izDeviceId);

    // Kayıtlı kimlik OLSA BİLE çağırıyoruz: sunucudaki "son görülme" ve şema
    // sürümü tazeleniyor. Sunucu aynı kimliği geri veriyor.
    final kayit = await _api.registerDevice(
      id: onbellek,
      platform: _platform,
      schemaVersion: _schemaVersion,
    );

    if (kayit case Ok(:final value)) {
      if (value.id != onbellek) {
        await _store.write(SecureKey.izDeviceId, value.id);
      }
      return value.id;
    }

    // Ağ yoksa ELDEKİ kimlikle devam ediliyor: cihaz zaten kayıtlı olabilir
    // ve push'un tek ihtiyacı o kimlik. İlk kurulumda `null` döner ve tur
    // burada biter — doğrusu da bu, cihazsız push reddedilir.
    return onbellek;
  }

  // --- Push --------------------------------------------------------------

  Future<Result<SyncOutcome>> _push({
    required String deviceId,
    required SyncOutcome outcome,
  }) async {
    var sonuc = outcome;

    for (var tur = 0; tur < maxPagesPerRun; tur++) {
      final bekleyen = await _outbox.pending(limit: maxChangesPerBatch);
      if (bekleyen.isEmpty) return Ok(sonuc);

      final grup = _batch(bekleyen);

      final yanit = await _api.push(
        deviceId: deviceId,
        idempotencyKey: _idempotencyKey(grup),
        changes: [for (final satir in grup) _toChange(satir)],
      );

      if (yanit case Err(:final failure)) return Err(failure);

      final islenen = await _applyPushResults(grup, yanit.valueOrNull!);
      sonuc = sonuc.copyWith(
        pushed: sonuc.pushed + islenen.applied,
        conflicted: sonuc.conflicted + islenen.conflicted,
        rejected: sonuc.rejected + islenen.rejected,
      );

      // İLERLEME YOKSA DUR. Hiçbir satır kuyruktan düşmediyse bir sonraki
      // tur aynı satırları çeker ve sonsuza kadar döneriz. Bu, sunucunun
      // tanımadığımız bir durum döndürmesi gibi hâllerde olabiliyor.
      if (islenen.removed == 0) {
        _log.warning(
          'push made no progress: ${grup.length} rows sent, none removed '
          'from the queue; queue left untouched',
        );
        return Ok(sonuc);
      }
    }

    return Ok(sonuc);
  }

  /// Sayı VE bayt sınırına göre bir grup ayırır.
  ///
  /// Tek bir satır bayt sınırını tek başına aşıyorsa YALNIZ ONU gönderiyoruz:
  /// atlarsak o satır kuyruğu sonsuza kadar tıkardı. Sunucu 413 döndürürse
  /// hata görünür olur — sessiz bir tıkanmadan iyidir.
  List<OutboxEntryRow> _batch(List<OutboxEntryRow> bekleyen) {
    final grup = <OutboxEntryRow>[];
    var bayt = 0;

    for (final satir in bekleyen) {
      final boyut = satir.payloadJson.length;
      if (grup.isNotEmpty && bayt + boyut > maxBatchBytes) break;

      grup.add(satir);
      bayt += boyut;
    }

    return grup;
  }

  /// Grubun DEĞİŞMEZ kimliği — yeniden denemede aynı kalmalı.
  ///
  /// NEDEN HASH DEĞİL?
  /// Kuyruk `createdAt` sırasında okunuyor ve grup her zaman baştan alınan
  /// bir dilim. Dolayısıyla ilk kimlik + son kimlik + adet, o dilimi tek
  /// anlamlı biçimde belirliyor. Bir hash aynı işi yapardı ama Dart'ın
  /// tamsayıları web'de 53 bitle sınırlı ve taşan bir çarpım sessizce farklı
  /// sonuç verirdi.
  ///
  /// Grup değişirse (bir satır düştü, yenisi eklendi) anahtar da değişiyor —
  /// doğrusu bu: artık FARKLI bir istek.
  String _idempotencyKey(List<OutboxEntryRow> grup) =>
      '${grup.first.id}:${grup.last.id}:${grup.length}';

  SyncPushChange _toChange(OutboxEntryRow satir) => SyncPushChange(
    entityType: satir.entityType,
    entityId: satir.entityId,
    // Sunucu `create`/`update` de kabul ediyor ama kablodaki sözleşme
    // `upsert`/`delete`: sunucunun işlemi zaten bu ikisine indirgiyor.
    op: satir.op == OutboxOperation.delete ? 'delete' : 'upsert',
    baseVersion: satir.baseVersion,
    payload: jsonDecode(satir.payloadJson),
  );

  Future<({int applied, int conflicted, int rejected, int removed})>
  _applyPushResults(List<OutboxEntryRow> grup, SyncPushResponse yanit) async {
    // Sunucu sonuçları `entityId` ile eşleştiriyor; bir satırın hangi outbox
    // kaydına ait olduğunu buradan buluyoruz.
    final kuyruk = {for (final satir in grup) satir.entityId: satir};

    var applied = 0;
    var conflicted = 0;
    var rejected = 0;
    var removed = 0;

    for (final sonuc in yanit.results) {
      final satir = kuyruk[sonuc.entityId];
      if (satir == null) continue;

      switch (sonuc.status) {
        case SyncPushStatus.applied:
          applied++;
          if (sonuc.version case final surum?) {
            // ⚠️ SUNUCU SÜRÜMÜNÜ YAZMAZSAK bir sonraki push eski bir
            // `baseVersion` gönderir ve kullanıcı KENDİ değişikliğini
            // "başka bir sürüm" olarak görür.
            await _db.syncDao.setServerVersion(
              entityType: satir.entityType,
              entityId: satir.entityId,
              version: surum,
            );
          }
          await _outbox.remove(satir.id);
          removed++;

        case SyncPushStatus.conflict:
          conflicted++;
          await _recordConflict(satir, sonuc.server);
          // SATIR KUYRUKTAN DÜŞÜYOR: aynı gövdeyi yeniden göndermek yine
          // çakışırdı. Sunucudaki sürüm hemen ardından gelen pull ile
          // inecek; kullanıcının kaybolan metni `SyncConflicts`te duruyor.
          await _outbox.remove(satir.id);
          removed++;

        case SyncPushStatus.rejected:
          rejected++;
          if (_kalicRed(sonuc.reason)) {
            // Tekrar denemek düzeltmez; satır kalırsa kuyruk sonsuza kadar
            // tıkanır. Sebebi deftere yazılıyor ki sessizce kaybolmasın.
            _log.warning(
              'permanent rejection: ${satir.entityType} — ${sonuc.reason}',
            );
            await _outbox.remove(satir.id);
            removed++;
          } else {
            // Örn. `entitlement_required`: abonelik alınınca düzelir.
            await _outbox.recordFailure(satir.id, sonuc.reason ?? 'rejected');
          }

        case SyncPushStatus.unknown:
          // Sunucudan yeni bir istemciyiz. Satırı DÜŞÜRMÜYORUZ: anlamadığımız
          // bir cevabı "başarılı" saymak veriyi kaybetmek olurdu.
          await _outbox.recordFailure(satir.id, 'unknown status');
      }
    }

    return (
      applied: applied,
      conflicted: conflicted,
      rejected: rejected,
      removed: removed,
    );
  }

  /// Tekrar denemekle DÜZELMEYECEK redler.
  ///
  /// Ayrım önemli: kalıcı bir redde satırı tutmak kuyruğu kilitler, geçici
  /// bir redde düşürmek veriyi kaybettirir.
  bool _kalicRed(String? reason) => const {
    'unknown_entity_type',
    'entity_id_invalid',
    'operation_invalid',
    'payload_invalid',
    'payload_version_unsupported',
    'payload_entity_missing',
    'payload_encoding_invalid',
  }.contains(reason);

  /// Çakışmada KAYBOLACAK metni kurtarır (TR-M13-10).
  ///
  /// Yalnız UZUN METİN alanları kaydediliyor. Skaler alanlar (favori,
  /// arşiv, sıra) yol haritası §4.4'te "son yazma kazanır" sınıfında:
  /// kullanıcıya "favori mi değil mi" diye sormak, çözmesi gereken bir soru
  /// değil gürültü olurdu.
  Future<void> _recordConflict(
    OutboxEntryRow satir,
    SyncServerVersion? sunucu,
  ) async {
    if (sunucu == null) return;

    final alanlar = _uzunMetinAlanlari[satir.entityType];
    if (alanlar == null) return;

    Map<String, Object?>? yerel;
    try {
      final zarf = jsonDecode(satir.payloadJson);
      if (zarf is Map<String, Object?>) {
        yerel = zarf['entity'] as Map<String, Object?>?;
      }
    } on FormatException {
      // Gövde okunamıyorsa çakışmayı kaydedemeyiz ama tur durmamalı.
      _log.warning('conflict payload unreadable: ${satir.entityType}');
      return;
    }

    if (yerel == null) return;

    for (final alan in alanlar) {
      final bizim = yerel[alan] as String?;
      final onunki = sunucu.payload[alan] as String?;

      // Aynıysa çakışma YOK: kullanıcıya gösterecek bir fark yok.
      if (bizim == onunki) continue;

      await _db.syncStateDao.recordConflict(
        id: _ids.newId(),
        entityType: satir.entityType,
        entityId: satir.entityId,
        field: alan,
        localValue: bizim,
        serverValue: onunki,
        detectedAt: _clock.now(),
      );
    }
  }

  static const Map<String, List<String>> _uzunMetinAlanlari = {
    'memory': ['title', 'note'],
    'journal_entry': ['title', 'content'],
    'person': ['name', 'note'],
    'collection': ['title', 'description'],
    'ritual': ['title'],
    'location': ['label'],
    'category': ['name'],
  };

  // --- Pull --------------------------------------------------------------

  Future<Result<SyncOutcome>> _pull({
    required String ownerId,
    required String deviceId,
    required SyncOutcome outcome,
  }) async {
    var sonuc = outcome;
    final defter = await _db.syncStateDao.current();
    var cursor = int.tryParse(defter.cursor ?? '') ?? 0;

    for (var sayfa = 0; sayfa < maxPagesPerRun; sayfa++) {
      final yanit = await _api.pull(cursor: cursor, limit: maxChangesPerBatch);
      if (yanit case Err(:final failure)) return Err(failure);

      final icerik = yanit.valueOrNull!;
      final uygulanan = await _applyPage(
        icerik.changes,
        ownerId: ownerId,
        deviceId: deviceId,
      );

      cursor = icerik.nextCursor;

      // ⚠️ CURSOR YAZMADAN ÖNCE SAYFA UYGULANDI. Tersi olsaydı ve araya bir
      // çökme girseydi, o sayfa bir daha gelmezdi.
      await _db.syncStateDao.saveCursor(cursor);

      sonuc = sonuc.copyWith(
        pulled: sonuc.pulled + uygulanan.applied,
        skipped: sonuc.skipped + uygulanan.skipped,
        cursor: cursor,
      );

      if (!icerik.hasMore) break;
    }

    return Ok(sonuc);
  }

  /// Bir sayfayı TEK transaction'da uygular.
  ///
  /// İKİ SORUNU BİRDEN ÇÖZÜYOR:
  ///
  /// 1. SIRALAMA. Sunucu sayfayı `seq` sırasında veriyor ve sayfa içi
  ///    birleştirme yüzünden bir BAĞ, ebeveyninden önce gelebiliyor. İstemcide
  ///    bağ tablolarının yabancı anahtarı var (sunucuda bilinçli olarak yok),
  ///    yani ebeveynsiz bağ yazmak kısıtı patlatıyor. Önce ana kayıtlar,
  ///    sonra bağlar uygulanıyor.
  ///
  /// 2. AYNI TRANSACTION İÇİNDE de sıra bozulabilir (ana kayıt bağdan sonra
  ///    gelen bir `seq`te olabilir), o yüzden `defer_foreign_keys` açılıyor:
  ///    kısıt her satırda değil COMMIT'te denetleniyor.
  ///
  /// KISIT YİNE DE PATLARSA sayfa satır satır, tek tek uygulanıyor ve
  /// uygulanamayan atlanıyor. Alternatif, o sayfanın sonsuza kadar
  /// uygulanamaması ve kullanıcının bir daha hiç eşitlenememesiydi.
  Future<({int applied, int skipped})> _applyPage(
    List<SyncRemoteChange> changes, {
    required String ownerId,
    required String deviceId,
  }) async {
    // ECHO ÖNLEME: kendi gönderdiğimiz değişikliği geri alıp yeniden
    // uygulamak hem gereksiz iş hem de o sırada yapılan yeni bir düzenlemeyi
    // ezme riski (BACKEND_YOL_HARITASI §4.2).
    final uygulanacak = changes.where((c) => c.deviceId != deviceId).toList()
      ..sort((a, b) {
        final aBag = a.entityId.contains(':') ? 1 : 0;
        final bBag = b.entityId.contains(':') ? 1 : 0;
        if (aBag != bBag) return aBag - bBag;
        return a.seq.compareTo(b.seq);
      });

    if (uygulanacak.isEmpty) return (applied: 0, skipped: 0);

    try {
      var uygulandi = 0;
      var atlandi = 0;

      await _db.transaction(() async {
        await _db.customStatement('PRAGMA defer_foreign_keys = ON');

        for (final change in uygulanacak) {
          if (await _applyOne(change, ownerId)) {
            uygulandi++;
          } else {
            atlandi++;
          }
        }
      });

      return (applied: uygulandi, skipped: atlandi);
    } on Object catch (error) {
      _log.warning('page apply failed, retrying row by row: $error');
      return _applyOneByOne(uygulanacak, ownerId);
    }
  }

  /// Toplu uygulama başarısız olduğunda son çare.
  ///
  /// Her satır KENDİ transaction'ında; biri düşerse ötekiler yazılmış
  /// kalıyor. Atlanan satır sayısı sonuçta görünüyor — sessizce kaybolmuyor.
  Future<({int applied, int skipped})> _applyOneByOne(
    List<SyncRemoteChange> changes,
    String ownerId,
  ) async {
    var uygulandi = 0;
    var atlandi = 0;

    for (final change in changes) {
      try {
        if (await _db.transaction(() => _applyOne(change, ownerId))) {
          uygulandi++;
        } else {
          atlandi++;
        }
      } on Object catch (error) {
        atlandi++;
        _log.warning(
          'could not apply: ${change.entityType} ${change.entityId} — $error',
        );
      }
    }

    return (applied: uygulandi, skipped: atlandi);
  }

  Future<bool> _applyOne(SyncRemoteChange change, String ownerId) {
    if (change.isDelete) {
      return _db.syncDao.applyDelete(
        entityType: change.entityType,
        entityId: change.entityId,
        version: change.version,
        now: _clock.now(),
      );
    }

    final govde = change.payload;
    if (govde == null) {
      // `upsert` ama gövde yok: sunucu böyle bir şey göndermiyor. Yine de
      // varsayımı koda gömmüyoruz — atlıyoruz, çökmüyoruz.
      return Future.value(false);
    }

    return _db.syncDao.applyUpsert(
      entityType: change.entityType,
      entityId: change.entityId,
      payload: govde,
      ownerId: ownerId,
    );
  }

  // --- Hata yolu ---------------------------------------------------------

  /// Hatayı deftere yazar ve döndürür.
  ///
  /// `lastError` Yedekleme Sağlığı ekranında görünüyor (FR-164). Yazmasaydık
  /// kullanıcı "en son ne zaman eşitlendim" sorusuna cevap bulur ama "neden
  /// duruyor" sorusuna bulamazdı.
  Future<Result<SyncOutcome>> _fail(Failure failure, DateTime baslangic) async {
    _log.warning('sync halted: ${failure.runtimeType}');

    await _db.syncStateDao.finish(
      at: baslangic,
      pendingCount: (await _outbox.pending()).length,
      error: failure.runtimeType.toString(),
    );

    return Err(failure);
  }
}
