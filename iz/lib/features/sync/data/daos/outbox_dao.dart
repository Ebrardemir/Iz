/// Outbox veri erişim nesnesi (DAO) — TR-M13-01.
///
/// SORUMLULUĞU: SQL. Sadece SQL. Gerekçesi `memory_dao.dart` başındaki notta.
///
/// ⚠️ MOTOR YOK. Faz 2'de kuyruk yalnız DOLUYOR; boşaltan taraf Faz 3'te
/// geliyor (`SyncEngine`). Kuyruğun erken dolmaya başlaması bilinçli: ilk
/// eşitleme günü kullanıcının geçmişi de gitsin diye değil — o iş bootstrap'in
/// (TR-M13-23) — kuyruğun gerçek yükte çalıştığını Faz 3'ten ÖNCE görmek için.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/sync/data/tables/sync_tables.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [OutboxEntries])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// Kuyruğa bir değişiklik ekler.
  ///
  /// ÇAĞIRAN TARAF VERİYİ YAZAN TRANSACTION'IN İÇİNDEN ÇAĞIRMALI.
  /// Ayrı transaction olsaydı ikisinin arasında çöken bir uygulama
  /// değişikliği kalıcı olarak kaybederdi: veri yerelde değişmiş ama
  /// sunucuya gideceği hiçbir yere yazılmamış olurdu.
  ///
  /// Drift'in transaction'ı zone tabanlı: aynı veritabanının başka bir
  /// DAO'sundan çağrılsa bile dıştaki transaction'a KATILIR.
  Future<void> enqueue({
    required String id,
    required String entityType,
    required String entityId,
    required OutboxOperation op,
    required String payloadJson,
    required int baseVersion,
    required DateTime now,
  }) {
    return into(outboxEntries).insert(
      OutboxEntriesCompanion.insert(
        id: id,
        entityType: entityType,
        entityId: entityId,
        op: op,
        payloadJson: payloadJson,
        baseVersion: baseVersion,
        createdAt: Value(now),
      ),
    );
  }

  /// Gönderilmeyi bekleyen değişiklikler, ESKİDEN YENİYE.
  ///
  /// Sıra önemli: aynı kaydın "oluştur" ve "güncelle" satırları ters sırayla
  /// giderse sunucu var olmayan bir kaydı güncellemeye çalışır.
  Stream<List<OutboxEntryRow>> watchPending() {
    return (select(
      outboxEntries,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();
  }

  Future<List<OutboxEntryRow>> pending({int? limit}) {
    final query = select(outboxEntries)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Yedekleme Sağlığı ekranındaki "bekleyen öğe" sayacı (FR-614).
  Stream<int> watchPendingCount() {
    final query = selectOnly(outboxEntries)
      ..addColumns([outboxEntries.id.count()]);

    return query
        .map((row) => row.read(outboxEntries.id.count()) ?? 0)
        .watchSingle();
  }

  /// Başarısız denemeyi kaydeder — TR-M13-03'ün üstel geri çekilme sayacı.
  ///
  /// Satır SİLİNMİYOR: çevrimdışında kuyruk büyür, veri kaybolmaz.
  Future<void> recordFailure(String id, String error) {
    return transaction(() async {
      final current = await (select(
        outboxEntries,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (current == null) return;

      await (update(outboxEntries)..where((t) => t.id.equals(id))).write(
        OutboxEntriesCompanion(
          attemptCount: Value(current.attemptCount + 1),
          lastError: Value(error),
        ),
      );
    });
  }

  /// Sunucu onayladı — satır kuyruktan düşüyor.
  Future<void> remove(String id) =>
      (delete(outboxEntries)..where((t) => t.id.equals(id))).go();
}
