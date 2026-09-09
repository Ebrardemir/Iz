/// Senkronizasyon uçlarının istemci karşılığı — `/v1/sync/*` ve `/v1/devices`.
///
/// BU DOSYA SÖZLEŞMENİN İSTEMCİ UCU. Karşı ucu
/// `api/src/Iz.Api/Endpoints/SyncEndpoints.cs`. İkisi ayrıştığı gün
/// senkronizasyon sessizce durur: istemci yanıtı çözemez, kuyruk boşalmaz ve
/// kullanıcı hiçbir hata görmez. Bu yüzden alanlar birebir ve testli.
///
/// SORUMLULUĞU DEĞİL: ne zaman çağrılacağı, kuyruğun nasıl boşaltılacağı,
/// yanıtın yerele nasıl uygulanacağı. Hepsi motorun işi (`SyncEngine`).
/// Buradaki sınıflar yalnız HTTP ile Dart tipleri arasında çeviri yapıyor.
///
/// ⚠️ YANIT ALANLARI camelCase, GÖVDE İÇİNDEKİ `payload` snake_case.
/// Çelişki gibi görünüyor ama doğru: zarf sunucunun kendi sözleşmesi
/// (`entityType`, `nextCursor`), `payload` ise İSTEMCİNİN veritabanı satırı
/// (`occurred_year`) ve sunucu onu olduğu gibi aynalıyor.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz, bu yüzden private
// alanlara `this._client` biçiminde initializing formal kullanamıyoruz
// (aynı gerekçe account_api.dart ve api_client.dart'ta da geçerli).
// ignore_for_file: prefer_initializing_formals

import 'package:iz/core/network/api_client.dart';
import 'package:iz/core/result/result.dart';

/// `POST /v1/devices` yanıtı.
final class RemoteDevice {
  const RemoteDevice({required this.id, required this.platform});

  /// Sunucunun ürettiği kimlik. `SecureKey.izDeviceId`'ye yazılır.
  final String id;

  final String platform;

  static RemoteDevice fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return RemoteDevice(
      id: map['id']! as String,
      platform: map['platform']! as String,
    );
  }
}

/// Push'a giden tek bir kuyruk satırı.
final class SyncPushChange {
  const SyncPushChange({
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.baseVersion,
    this.payload,
  });

  final String entityType;
  final String entityId;

  /// `upsert` · `delete`. Sunucu `create`/`update` da kabul ediyor.
  final String op;

  /// Gönderim anındaki yerel sürüm; yeni kayıtta 0.
  final int baseVersion;

  /// Outbox'taki `payloadJson`'ın çözülmüş hâli — `{ v, entity, links }`.
  ///
  /// Silmede `null` olabilir: silmek için gövde gerekmiyor ve
  /// `deviceOnly`ye çevrilen bir günlük kaydının silme isteği YALNIZ kimlik
  /// taşıyor (TR-M3-02). Tam gövdeyi koymak, "bu cihazda kalsın" denen metni
  /// silme isteğinin içinde buluta göndermek olurdu.
  final Object? payload;

  Map<String, Object?> toJson() => {
    'entityType': entityType,
    'entityId': entityId,
    'op': op,
    'baseVersion': baseVersion,
    'payload': payload,
  };
}

/// Sunucunun bir değişiklik için verdiği karar.
enum SyncPushStatus {
  /// Yazıldı (ya da zaten o hâldeydi).
  applied,

  /// Sunucudaki sürüm bizimkinden farklı; HİÇBİR ŞEY yazılmadı.
  conflict,

  /// Sunucu bu satırı hiç işleyemedi; sebebi [SyncPushChangeResult.reason].
  rejected,

  /// Sunucu bizim tanımadığımız bir durum bildirdi.
  ///
  /// SUNUCUDAN YENİ BİR İSTEMCİ olduğumuz anlamına gelir. Ayrıştırma
  /// hatasına çevirmiyoruz: tek bir bilinmeyen durum, o kullanıcının BÜTÜN
  /// kuyruğunu okunamaz yapardı. Motor bunu "başarısız deneme" sayıp satırı
  /// kuyrukta bırakıyor — kayıp değil, görünür bir bekleme.
  unknown;

  static SyncPushStatus parse(String? raw) => switch (raw) {
    'applied' => SyncPushStatus.applied,
    'conflict' => SyncPushStatus.conflict,
    'rejected' => SyncPushStatus.rejected,
    _ => SyncPushStatus.unknown,
  };
}

/// Çakışmada sunucunun elindeki hâl.
final class SyncServerVersion {
  const SyncServerVersion({required this.version, required this.payload});

  final int version;

  /// Sunucudaki satır — snake_case, istemcinin sütun adlarıyla.
  final Map<String, Object?> payload;
}

final class SyncPushChangeResult {
  const SyncPushChangeResult({
    required this.entityId,
    required this.status,
    this.version,
    this.seq,
    this.server,
    this.reason,
  });

  /// Gönderdiğimiz metnin AYNISI — outbox satırını bununla eşleştiriyoruz.
  final String entityId;

  final SyncPushStatus status;

  /// Yazmadan sonraki sunucu sürümü. Yerel satıra bu yazılıyor.
  final int? version;

  /// Değişiklik hiçbir alanı değiştirmediyse `null` — sunucu günlüğe satır
  /// düşürmemiş demektir. Hata değil.
  final int? seq;

  final SyncServerVersion? server;

  /// Yalnız redde dolu (`unknown_entity_type`, `payload_encoding_invalid`…).
  final String? reason;

  static SyncPushChangeResult fromJson(Map<String, Object?> map) {
    final server = map['server'] as Map<String, Object?>?;

    return SyncPushChangeResult(
      entityId: map['entityId']! as String,
      status: SyncPushStatus.parse(map['status'] as String?),
      version: map['version'] as int?,
      seq: map['seq'] as int?,
      server: server == null
          ? null
          : SyncServerVersion(
              version: server['version']! as int,
              payload: server['payload']! as Map<String, Object?>,
            ),
      reason: map['reason'] as String?,
    );
  }
}

final class SyncPushResponse {
  const SyncPushResponse({required this.results, required this.cursor});

  final List<SyncPushChangeResult> results;

  /// ⚠️ PULL CURSOR'I DEĞİL, bir İPUCU. Bunu doğrudan `SyncState.cursor`'a
  /// yazarsak, push ile aynı anda BAŞKA bir cihazın yazdığı satırları atlamış
  /// oluruz ve o değişiklikler bu cihaza HİÇ gelmez. Pull cursor'ını yalnız
  /// pull ilerletir (BACKEND_YOL_HARITASI §4.2).
  final int cursor;

  static SyncPushResponse fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return SyncPushResponse(
      results: [
        for (final item in map['results']! as List<Object?>)
          SyncPushChangeResult.fromJson(item! as Map<String, Object?>),
      ],
      cursor: map['cursor']! as int,
    );
  }
}

/// Pull'da inen tek bir kayıt.
final class SyncRemoteChange {
  const SyncRemoteChange({
    required this.seq,
    required this.entityType,
    required this.entityId,
    required this.isDelete,
    required this.version,
    this.deviceId,
    this.payload,
  });

  final int seq;
  final String entityType;
  final String entityId;

  /// Sunucu `op` olarak `upsert`/`delete` gönderiyor; burada boolean'a
  /// çeviriyoruz çünkü istemcide üçüncü bir ihtimal yok.
  final bool isDelete;

  final int version;

  /// Değişikliği GÖNDEREN cihaz. Kendi kimliğimizle eşleşiyorsa satırı
  /// atlıyoruz — echo önleme. Arka plan işlerinde `null`.
  final String? deviceId;

  /// Silmede `null`: sunucu gövde göndermiyor.
  final Map<String, Object?>? payload;

  static SyncRemoteChange fromJson(Map<String, Object?> map) =>
      SyncRemoteChange(
        seq: map['seq']! as int,
        entityType: map['entityType']! as String,
        entityId: map['entityId']! as String,
        isDelete: map['op'] == 'delete',
        version: map['version']! as int,
        deviceId: map['deviceId'] as String?,
        payload: map['payload'] as Map<String, Object?>?,
      );
}

final class SyncPullPage {
  const SyncPullPage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<SyncRemoteChange> changes;

  /// ⚠️ YALNIZ tüm değişiklikler yerel transaction'a yazıldıktan SONRA
  /// kaydedilir. Önce kaydedip araya bir çökme girerse o sayfa bir daha
  /// gelmez ve içindeki değişiklikler bu cihaza hiç ulaşmaz.
  final int nextCursor;

  final bool hasMore;

  static SyncPullPage fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return SyncPullPage(
      changes: [
        for (final item in map['changes']! as List<Object?>)
          SyncRemoteChange.fromJson(item! as Map<String, Object?>),
      ],
      nextCursor: map['nextCursor']! as int,
      hasMore: map['hasMore']! as bool,
    );
  }
}

/// `GET /v1/sync/state` — Yedekleme Sağlığı ekranının sunucu tarafındaki payı.
final class SyncServerState {
  const SyncServerState({
    required this.serverCursor,
    required this.pendingCount,
    this.lastChangeAt,
  });

  final int serverCursor;

  /// İNDİRİLMEYİ bekleyen değişiklik sayısı.
  ///
  /// ⚠️ TR-M11-13'teki "bekleyen öğe"nin TERSİ: oradaki, gönderilmeyi
  /// bekleyen yerel outbox satırları ve onu sunucu bilemez.
  final int pendingCount;

  /// Hesabın verisi SUNUCUDA en son ne zaman değişti.
  ///
  /// ⚠️ "Bu cihaz en son ne zaman eşitledi" DEĞİL — o, yerel `SyncState`
  /// tablosunun bilgisi (TR-M11-13). İkisini karıştırıp ekrana yazarsak
  /// kullanıcı, cihazı günlerdir çevrimdışıyken bile başka bir cihazın
  /// yazdığı taze bir tarih görür.
  final DateTime? lastChangeAt;

  static SyncServerState fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    final son = map['lastChangeAt'] as String?;

    return SyncServerState(
      serverCursor: map['serverCursor']! as int,
      pendingCount: map['pendingCount']! as int,
      lastChangeAt: son == null ? null : DateTime.parse(son),
    );
  }
}

/// `final` DEĞİL — testler sahteleyebilsin diye (`AccountApi` ile aynı kural).
///
/// Bu sınıfa DAVRANIŞ eklenmez, yalnız uç nokta çağrısı taşır; o yüzden
/// sahtelemek gerçeği ıskalamaz.
class SyncApi {
  const SyncApi({required IzApiClient client}) : _client = client;

  final IzApiClient _client;

  /// Cihazı kaydeder ya da "son görülme"sini tazeler.
  ///
  /// [id] verilmezse sunucu YENİ bir kimlik üretir. Verilir ve sunucuda yoksa
  /// (başka bir hesabın cihazı) yine yeni kimlik üretilir — kurbanın kaydına
  /// dokunulmaz.
  Future<Result<RemoteDevice>> registerDevice({
    String? id,
    required String platform,
    String? appVersion,
    int? schemaVersion,
  }) => _client.post(
    '/v1/devices',
    body: {
      'id': ?id,
      'platform': platform,
      'appVersion': ?appVersion,
      'schemaVersion': ?schemaVersion,
    },
    parse: RemoteDevice.fromJson,
  );

  /// Bekleyen değişiklikleri sunucuya yazar.
  ///
  /// [idempotencyKey] YENİDEN DENEMEDE AYNI KALMALI. Değişirse sunucu bunu
  /// yeni bir istek sayar; ilk denemede sürüm zaten arttığı için ikinci
  /// deneme `conflict` alır ve kullanıcıya KENDİ değişikliği "başka bir
  /// sürüm" diye gösterilir.
  ///
  /// `retryable: true` — POST normalde tekrarlanmıyor
  /// ([IzRetryInterceptor]) ama anahtar sayesinde artık güvenli. Ağ
  /// katmanındaki nota göre bu, Faz 3'ün açtığı kapı.
  Future<Result<SyncPushResponse>> push({
    required String deviceId,
    required String idempotencyKey,
    required List<SyncPushChange> changes,
  }) => _client.post(
    '/v1/sync/push',
    body: {
      'deviceId': deviceId,
      'changes': [for (final change in changes) change.toJson()],
    },
    headers: {'Idempotency-Key': idempotencyKey},
    retryable: true,
    parse: SyncPushResponse.fromJson,
  );

  /// [cursor]'dan sonraki değişiklikleri sayfa sayfa indirir.
  ///
  /// Yeni cihazda `cursor: 0` ile başlanır ve tüm veri iner (bootstrap).
  /// Ayrı bir "her şeyi ver" ucu YOK: ilk yükleme ile delta aynı yoldan
  /// geçtiği için o yol her gün test edilmiş oluyor.
  Future<Result<SyncPullPage>> pull({required int cursor, int? limit}) =>
      _client.get(
        '/v1/sync/pull',
        query: {'cursor': cursor, 'limit': ?limit},
        parse: SyncPullPage.fromJson,
      );

  /// Sunucuda bekleyen var mı — VERİ İNDİRMEDEN.
  ///
  /// Pull da cevaplardı ama bir sayfa veri indirerek; Yedekleme Sağlığı
  /// ekranı her açıldığında 200 kaydı indirip atmak gereksiz.
  Future<Result<SyncServerState>> state({required int cursor}) => _client.get(
    '/v1/sync/state',
    query: {'cursor': cursor},
    parse: SyncServerState.fromJson,
  );
}
