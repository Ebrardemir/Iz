/// Medya veri erişim nesnesi (DAO).
///
/// SORUMLULUĞU: SQL. Sadece SQL.
/// Burada iş kuralı YOK, domain tipi YOK, `Result` YOK — gerekçesi
/// `memory_dao.dart` başındaki notta.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/outbox_payload.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

part 'media_dao.g.dart';

/// Medya ÜSTVERİSİNİN outbox'taki karşılığı.
///
/// ⚠️ DOSYANIN KENDİSİ DEĞİL (ADR-B07): medya yükleme bu haritanın dışında.
/// Giden şey yalnız "burada bir fotoğraf vardı" bilgisi; ikinci cihaz onu
/// yer tutucu olarak gösteriyor. Üstveriyi de göndermezsek ikinci cihaz
/// fotoğrafın VARLIĞINDAN bile habersiz kalır.
const kMediaEntityType = 'media_item';

/// Gövdeden ÇIKARILAN sütunlar — cihaza özgü oldukları için.
///
/// Üçü de başka bir cihazda anlamsız, hatta yanıltıcı:
///   • `local_preview_path` — bu cihazın sandbox'ındaki dosya yolu. Var
///     olmayan bir yolu gerçek sanmak, "medyan kayıp" demekten daha kötü.
///   • `gallery_asset_id` — iOS PHAsset / Android MediaStore kimliği; başka
///     cihazın galerisinde karşılığı yok.
///   • `last_verified_at` — "BU cihaz orijinali en son ne zaman gördü".
///
/// Sunucuda ilk ikisinin sütunu bile yok (BACKEND_YOL_HARITASI §4.6). Yine de
/// burada çıkarıyoruz: göndermeseydik bile sunucu yok sayardı, ama kullanıcının
/// cihazındaki bir DOSYA YOLUNU ağa çıkarmanın hiçbir gerekçesi yok.
const _cihazaOzguSutunlar = {
  'local_preview_path',
  'gallery_asset_id',
  'last_verified_at',
};

@DriftAccessor(tables: [MediaItems])
class MediaDao extends DatabaseAccessor<AppDatabase> with _$MediaDaoMixin {
  MediaDao(super.db);

  Future<MediaRow?> findMedia(String id) => (select(
    mediaItems,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  Future<List<MediaRow>> findMany(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);

    return (select(
      mediaItems,
    )..where((t) => t.id.isIn(ids) & t.deletedAt.isNull())).get();
  }

  /// Oluşturur veya günceller.
  ///
  /// `version` YAZAN TARAF artırır (TR-C-31) — tek yazma yolu burası.
  ///
  /// [now] DIŞARIDAN GELİYOR (TR-C-41): satırın damgası ile kuyruk satırının
  /// damgası AYNI an olmalı; DAO kendi saatini okusaydı ikisi milisaniyelerle
  /// ayrışırdı.
  Future<void> upsertMedia(
    MediaItemsCompanion media, {
    required String outboxId,
    required DateTime now,
  }) => transaction(() async {
    final id = media.id.value;
    final current = await (select(
      mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    await into(mediaItems).insertOnConflictUpdate(
      media.copyWith(
        updatedAt: Value(now),
        version: Value((current?.version ?? 0) + 1),
      ),
    );

    await _enqueue(
      id,
      op: current == null ? OutboxOperation.create : OutboxOperation.update,
      baseVersion: current?.version ?? 0,
      outboxId: outboxId,
      now: now,
    );
  });

  /// TR-M4-13 — orijinal bulunamadı. Satır SİLİNMİYOR.
  ///
  /// Önizleme hâlâ duruyor olabilir ve kart onunla anlaşılır kalıyor;
  /// kullanıcıya yalnızca rozet gösteriliyor. Kaydı silmek, anının
  /// görselini bir daha geri getirilemez şekilde koparmak olurdu.
  ///
  /// ⚠️ KUYRUĞA GİRMİYOR — bilinçli. Bu kontrolün cevabı CİHAZA ÖZGÜ: A
  /// telefonunda orijinal duruyor olabilirken B'de silinmiş olabilir.
  /// Gönderseydik iki cihaz aynı alanı sırayla ezer, her eşitlemede birbirine
  /// "kayıp" / "duruyor" deyip dururdu. `lastVerifiedAt`in sunucuda sütunu
  /// bile yok.
  Future<void> markOriginalStatus(
    String id,
    MediaOriginalStatus status, {
    required DateTime verifiedAt,
  }) async {
    final current = await (select(
      mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (current == null) return;

    await (update(mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        originalStatus: Value(status),
        lastVerifiedAt: Value(verifiedAt),
        updatedAt: Value(verifiedAt),
        version: Value(current.version + 1),
      ),
    );
  }

  /// TR-C-32 — tombstone.
  Future<void> softDelete(
    String id, {
    required String outboxId,
    required DateTime now,
  }) => transaction(() async {
    final current = await (select(
      mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (current == null) return;

    await (update(mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        version: Value(current.version + 1),
      ),
    );

    await _enqueue(
      id,
      op: OutboxOperation.delete,
      baseVersion: current.version,
      outboxId: outboxId,
      now: now,
    );
  });

  /// Değişikliği outbox'a düşürür — AYNI TRANSACTION İÇİNDEN.
  ///
  /// Gerekçesi `memory_dao.dart`taki `_enqueue` notunda: ayrı transaction
  /// olsaydı ikisinin arasında çöken bir uygulama değişikliği kalıcı olarak
  /// kaybederdi.
  Future<void> _enqueue(
    String id, {
    required OutboxOperation op,
    required int baseVersion,
    required String outboxId,
    required DateTime now,
  }) async {
    final row = await (select(
      mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final govde = outboxRowJson(row)
      ..removeWhere((sutun, _) => _cihazaOzguSutunlar.contains(sutun));

    await OutboxDao(attachedDatabase).enqueue(
      id: outboxId,
      entityType: kMediaEntityType,
      entityId: id,
      op: op,
      payloadJson: encodeOutboxPayload(entity: govde),
      baseVersion: baseVersion,
      now: now,
    );
  }
}
