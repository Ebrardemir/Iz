/// Senkronizasyon defterleri: nerede kaldık, ne çakıştı.
///
/// SORUMLULUĞU: SQL. Sadece SQL.
///
/// ⚠️ BU TABLOLAR ASLA SENKRONİZE EDİLMİYOR. Senkronizasyonun KENDİSİNİ
/// anlatıyorlar, senkronize edilecek veriyi değil; sunucuya göndermek
/// özyineleme olurdu. `SyncableTable` kullanmamalarının sebebi de bu.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/sync/data/tables/sync_tables.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState, SyncConflicts])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  /// Tek satırlık defteri okur; hiç yoksa açar.
  ///
  /// Satırı burada AÇMAK önemli: `SyncState` tablosu migration'da
  /// tohumlanmıyor ve ilk eşitleme denemesinde "satır yok" durumunu her
  /// çağıranın ayrıca düşünmesi gerekirdi.
  Future<SyncStateRow> current() async {
    final varOlan = await (select(
      syncState,
    )..where((t) => t.id.equals(SyncState.singletonId))).getSingleOrNull();

    if (varOlan != null) return varOlan;

    await into(syncState).insert(const SyncStateCompanion());
    return (select(
      syncState,
    )..where((t) => t.id.equals(SyncState.singletonId))).getSingle();
  }

  Stream<SyncStateRow?> watch() => (select(
    syncState,
  )..where((t) => t.id.equals(SyncState.singletonId))).watchSingleOrNull();

  /// İndirilen sayfa yerele YAZILDIKTAN SONRA çağrılır.
  ///
  /// ⚠️ SIRA HAYATİ. Cursor'ı önce kaydedip sonra yazsaydık ve araya bir
  /// çökme girseydi o sayfa BİR DAHA GELMEZDİ: içindeki değişiklikler bu
  /// cihaza hiç ulaşmaz ve kimse fark etmezdi (BACKEND_YOL_HARITASI §4.2).
  /// ⚠️ `update` DEĞİL UPSERT. Defter satırı ilk eşitlemeye kadar YOK ve
  /// `update` sıfır satırı etkileyip sessizce hiçbir şey yazmaz. Bu tam
  /// olarak yaşandı: ilk turda ağ koptuğunda hata deftere hiç düşmedi ve
  /// Yedekleme Sağlığı ekranı "sorun yok" gösterecekti.
  Future<void> saveCursor(int cursor) => into(
    syncState,
  ).insertOnConflictUpdate(SyncStateCompanion.insert(cursor: Value('$cursor')));

  /// Tur bittiğinde defteri günceller.
  ///
  /// [error] `null` verilirse önceki hata TEMİZLENİYOR: başarılı bir turdan
  /// sonra ekranda eski bir hata durursa kullanıcı hâlâ bozuk sanır.
  /// [saveCursor] ile aynı sebeple UPSERT.
  Future<void> finish({
    required DateTime at,
    required int pendingCount,
    String? error,
  }) => into(syncState).insertOnConflictUpdate(
    SyncStateCompanion.insert(
      lastSyncAt: Value(at),
      pendingCount: Value(pendingCount),
      lastError: Value(error),
    ),
  );

  /// Çakışmayı kaydeder — KULLANICI SEÇENE KADAR hiçbir sürüm silinmiyor
  /// (TR-M13-10, TR-M13-11).
  ///
  /// Aynı alan için açık bir kayıt varsa YENİSİ AÇILMIYOR, mevcut olan
  /// tazeleniyor. Yoksa arka arkaya üç kez eşitlenen bir cihaz aynı çakışmayı
  /// üç kez gösterirdi.
  Future<void> recordConflict({
    required String id,
    required String entityType,
    required String entityId,
    required String field,
    required DateTime detectedAt,
    String? localValue,
    String? serverValue,
  }) async {
    final acikOlan =
        await (select(syncConflicts)..where(
              (t) =>
                  t.entityType.equals(entityType) &
                  t.entityId.equals(entityId) &
                  t.field.equals(field) &
                  t.resolvedAt.isNull(),
            ))
            .getSingleOrNull();

    if (acikOlan != null) {
      await (update(
        syncConflicts,
      )..where((t) => t.id.equals(acikOlan.id))).write(
        SyncConflictsCompanion(
          localValue: Value(localValue),
          serverValue: Value(serverValue),
          detectedAt: Value(detectedAt),
        ),
      );
      return;
    }

    await into(syncConflicts).insert(
      SyncConflictsCompanion.insert(
        id: id,
        entityType: entityType,
        entityId: entityId,
        field: field,
        localValue: Value(localValue),
        serverValue: Value(serverValue),
        detectedAt: Value(detectedAt),
      ),
    );
  }

  /// Çözülmemiş çakışma sayısı — Yedekleme Sağlığı ekranı bunu gösteriyor
  /// (TR-M13-12).
  Stream<int> watchUnresolvedConflicts() {
    final sorgu = selectOnly(syncConflicts)
      ..addColumns([syncConflicts.id.count()])
      ..where(syncConflicts.resolvedAt.isNull());

    return sorgu
        .map((row) => row.read(syncConflicts.id.count()) ?? 0)
        .watchSingle();
  }
}
