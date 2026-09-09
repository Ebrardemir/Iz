/// Hesap açılmadan ÖNCE oluşturulmuş kayıtları kuyruğa taşır.
///
/// NEDEN GEREKLİ?
/// Kuyruk yalnız YENİ yazmalarda doluyor (TR-M13-01). Kullanıcı hesap açana
/// kadar biriktirdiği anıların kuyrukta satırı yok; motor onları hiçbir zaman
/// göndermez. Yol haritası bunu "Faz 1'in en riskli parçası" diye
/// işaretlemiş: bu akış atlanırsa mevcut kullanıcıların verisi HİÇBİR ZAMAN
/// buluta çıkmaz — ve kimse fark etmez, çünkü uygulama sorunsuz görünür.
///
/// "YAPILDI" İŞARETİ AYRI BİR YERDE TUTULMUYOR.
/// Sinyal verinin kendisinde: sahipli tablolarda `ownerId == 'local'` satır
/// kaldı mı? Doldurma o satırlara gerçek kimliği yazınca sinyal kendiliğinden
/// kapanıyor. Ayrı bir bayrak (SharedPreferences ya da yeni bir sütun) iki
/// gerçek kaynağı olurdu ve biri diğerinden ayrıştığı gün ya doldurma hiç
/// çalışmaz ya her açılışta yeniden çalışırdı.
///
/// Sinyal HER KURULUMDA doğru başlıyor: kategoriler veritabanı açılırken
/// `ownerId` varsayılanıyla ('local') tohumlanıyor.
///
/// AYNI CİHAZDA İKİNCİ BİR HESAP açılırsa doldurma çalışmıyor — ve doğrusu
/// bu: ilk kullanıcının verisi ikincinin hesabına gitmemeli.
library;

import 'package:drift/drift.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/auth/data/tables/user_tables.dart';
import 'package:iz/features/categories/data/tables/category_tables.dart';
import 'package:iz/features/collections/data/tables/collection_tables.dart';
import 'package:iz/features/journal/data/tables/journal_tables.dart';
import 'package:iz/features/media/data/tables/media_tables.dart';
import 'package:iz/features/memories/data/tables/memory_tables.dart';
import 'package:iz/features/people/data/tables/person_tables.dart';
import 'package:iz/features/rituals/data/tables/ritual_tables.dart';
import 'package:iz/features/sync/data/daos/outbox_dao.dart';
import 'package:iz/features/sync/data/outbox_payload.dart';
import 'package:iz/features/sync/data/tables/sync_tables.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

part 'sync_backfill_dao.g.dart';

/// Medyada gövdeye GİRMEYEN sütunlar — `media_dao.dart` ile aynı liste.
///
/// İkisi ayrışırsa doldurmadan giden gövde, normal yazmadan gidenden farklı
/// olur; aynı kayıt iki farklı biçimde sunucuya ulaşır.
const _cihazaOzguSutunlar = {
  'local_preview_path',
  'gallery_asset_id',
  'last_verified_at',
};

@DriftAccessor(
  tables: [
    Memories,
    Locations,
    MediaItems,
    Categories,
    Collections,
    Rituals,
    People,
    MemoryPeople,
    MemoryCollections,
    MemoryRituals,
    RitualPeople,
    MemoryMedia,
    JournalEntries,
    JournalMedia,
    OutboxEntries,
  ],
)
class SyncBackfillDao extends DatabaseAccessor<AppDatabase>
    with _$SyncBackfillDaoMixin {
  SyncBackfillDao(super.db);

  /// Doldurma gerekiyor mu?
  ///
  /// Sahipli tablolardan HERHANGİ BİRİNDE `'local'` sahipli satır varsa evet.
  /// Tombstone'lar da sayılıyor: silinmiş bir kaydın sahibi de düzeltilmeli,
  /// yoksa geride 'local' satır kalır ve sinyal hiç kapanmaz.
  Future<bool> needsBackfill() async {
    for (final sorgu in [
      select(memories)..where((t) => t.ownerId.equals(Users.localId)),
      select(journalEntries)..where((t) => t.ownerId.equals(Users.localId)),
      select(people)..where((t) => t.ownerId.equals(Users.localId)),
      select(categories)..where((t) => t.ownerId.equals(Users.localId)),
      select(collections)..where((t) => t.ownerId.equals(Users.localId)),
      select(rituals)..where((t) => t.ownerId.equals(Users.localId)),
    ]) {
      if (await (sorgu..limit(1)).getSingleOrNull() != null) return true;
    }
    return false;
  }

  /// Sahipliği düzeltir ve mevcut kayıtları kuyruğa koyar.
  ///
  /// TEK TRANSACTION. Yarıda kesilirse hiçbiri yazılmıyor; aksi hâlde
  /// sahiplik güncellenmiş ama kuyruk boş kalabilir ve sinyal kapandığı için
  /// doldurma BİR DAHA çalışmazdı — veri sessizce yerelde kalırdı.
  ///
  /// Döndürdüğü sayı kuyruğa eklenen satır adedi.
  Future<int> run({
    required String ownerId,
    required DateTime now,
    required String Function() nextOutboxId,
  }) => transaction(() async {
    await _sahipligiDuzelt(ownerId);

    // ZATEN KUYRUKTA OLANLAR ATLANIYOR. Aynı kayıt için ikinci bir satır
    // açsaydık ikisi de gönderilir, ikincisi `baseVersion: 0` ile gelip
    // çakışma üretirdi — kullanıcıya kendi verisini "iki sürüm" diye
    // gösteren, tamamen uydurma bir çakışma.
    final kuyruktakiler = {
      for (final satir in await select(outboxEntries).get())
        '${satir.entityType}/${satir.entityId}',
    };

    var eklenen = 0;

    Future<void> ekle(
      String entityType,
      String entityId,
      Map<String, Object?> entity, {
      Map<String, List<Map<String, Object?>>> links = const {},
    }) async {
      if (kuyruktakiler.contains('$entityType/$entityId')) return;

      await OutboxDao(attachedDatabase).enqueue(
        id: nextOutboxId(),
        entityType: entityType,
        entityId: entityId,
        // SUNUCUDA HİÇ YOK: işlem `create`, `baseVersion` 0.
        op: OutboxOperation.create,
        payloadJson: encodeOutboxPayload(entity: entity, links: links),
        baseVersion: 0,
        now: now,
      );
      eklenen++;
    }

    // --- Bağlar bir kez okunup ana kayda göre gruplanıyor ----------------
    //
    // Her anı için ayrı sorgu atsaydık 2.000 anılık bir cihazda 8.000 sorgu
    // olurdu; doldurma açılışta çalıştığı için o bekleme doğrudan kullanıcıya
    // yazılırdı.
    final aniKisiler = _grupla(
      await select(memoryPeople).get(),
      (r) => r.memoryId,
    );
    final aniKoleksiyonlar = _grupla(
      await select(memoryCollections).get(),
      (r) => r.memoryId,
    );
    final aniSeriler = _grupla(
      await select(memoryRituals).get(),
      (r) => r.memoryId,
    );
    final aniMedyalar = _grupla(
      await select(memoryMedia).get(),
      (r) => r.memoryId,
    );
    final seriKisiler = _grupla(
      await select(ritualPeople).get(),
      (r) => r.ritualId,
    );
    final seriAnilar = _grupla(
      await select(memoryRituals).get(),
      (r) => r.ritualId,
    );
    final koleksiyonAnilar = _grupla(
      await select(memoryCollections).get(),
      (r) => r.collectionId,
    );
    final gunlukMedyalar = _grupla(
      await select(journalMedia).get(),
      (r) => r.journalEntryId,
    );

    // --- Ana kayıtlar ---------------------------------------------------
    //
    // TOMBSTONE'LAR GÖNDERİLMİYOR: sunucuda o kayıt hiç var olmadı, "silindi"
    // demenin bir alıcısı yok. Çöp kutusundaki kayıt yerelde duruyor ve
    // kullanıcı geri yüklerse normal yoldan kuyruğa giriyor.
    for (final row in await (select(
      memories,
    )..where((t) => t.deletedAt.isNull())).get()) {
      await ekle(
        'memory',
        row.id,
        outboxRowJson(row),
        links: {
          'memory_people': _json(aniKisiler[row.id]),
          'memory_collections': _json(aniKoleksiyonlar[row.id]),
          'memory_rituals': _json(aniSeriler[row.id]),
          'memory_media': _json(aniMedyalar[row.id]),
        },
      );
    }

    for (final row in await (select(
      journalEntries,
    )..where((t) => t.deletedAt.isNull())).get()) {
      // ⚠️ `deviceOnly` KAYITLAR ATLANIYOR (FR-035). Kullanıcıya "bu cihazdan
      // çıkmayacak" denen metni doldurma sırasında göndermek, sözü tam da
      // fark edilmeyecek yerde bozmak olurdu.
      if (row.privacyMode.name == 'deviceOnly') continue;

      await ekle(
        'journal_entry',
        row.id,
        outboxRowJson(row),
        links: {'journal_media': _json(gunlukMedyalar[row.id])},
      );
    }

    for (final row in await (select(
      people,
    )..where((t) => t.deletedAt.isNull())).get()) {
      await ekle('person', row.id, outboxRowJson(row));
    }

    for (final row in await (select(
      rituals,
    )..where((t) => t.deletedAt.isNull())).get()) {
      await ekle(
        'ritual',
        row.id,
        outboxRowJson(row),
        links: {
          'ritual_people': _json(seriKisiler[row.id]),
          'memory_rituals': _json(seriAnilar[row.id]),
        },
      );
    }

    for (final row in await (select(
      collections,
    )..where((t) => t.deletedAt.isNull())).get()) {
      await ekle(
        'collection',
        row.id,
        outboxRowJson(row),
        links: {'memory_collections': _json(koleksiyonAnilar[row.id])},
      );
    }

    for (final row in await (select(
      locations,
    )..where((t) => t.deletedAt.isNull())).get()) {
      await ekle('location', row.id, outboxRowJson(row));
    }

    for (final row in await (select(
      mediaItems,
    )..where((t) => t.deletedAt.isNull())).get()) {
      await ekle(
        'media_item',
        row.id,
        outboxRowJson(row)
          ..removeWhere((sutun, _) => _cihazaOzguSutunlar.contains(sutun)),
      );
    }

    // ⚠️ SİSTEM KATEGORİLERİ GÖNDERİLMİYOR.
    // Kimlikleri sabit (`cat_travel`…) ve her cihazda aynı tohumlanıyor, yani
    // anının `categoryId`si ikinci cihazda zaten çözülüyor. Göndermek her
    // kullanıcı için sekiz gereksiz satır olurdu. Kullanıcının kendi
    // kategorisi henüz yok (CategoryDao'da yazma metodu yok); o özellik
    // geldiğinde burası da açılacak.

    return eklenen;
  });

  /// `'local'` sahipli satırlara gerçek kimliği yazar.
  ///
  /// `updatedAt`e DOKUNMUYOR: kaydın içeriği değişmedi, yalnız kime ait
  /// olduğu netleşti. Tazeleseydik kullanıcının bütün anıları "bugün
  /// düzenlendi" görünürdü.
  Future<void> _sahipligiDuzelt(String ownerId) async {
    // `OwnedTable` bir MIXIN, tablo değil — Drift ona companion üretmiyor.
    // Altı tablo için altı ayrı companion yazmak yerine ham sütun adıyla
    // yazıyoruz; `owner_id` mixin'in tanımladığı tek sütun ve adı sabit.
    Future<int> duzelt<T extends Table, D>(
      TableInfo<T, D> tablo,
      GeneratedColumn<String> sahip,
    ) => (update(tablo)..where((_) => sahip.equals(Users.localId))).write(
      RawValuesInsertable<D>({'owner_id': Variable<String>(ownerId)}),
    );

    await duzelt(memories, memories.ownerId);
    await duzelt(journalEntries, journalEntries.ownerId);
    await duzelt(people, people.ownerId);
    await duzelt(categories, categories.ownerId);
    await duzelt(collections, collections.ownerId);
    await duzelt(rituals, rituals.ownerId);
  }

  static Map<String, List<T>> _grupla<T>(
    List<T> satirlar,
    String Function(T) anahtar,
  ) {
    final gruplar = <String, List<T>>{};
    for (final satir in satirlar) {
      (gruplar[anahtar(satir)] ??= []).add(satir);
    }
    return gruplar;
  }

  /// Bağ satırlarını gövdeye çeviriyor.
  ///
  /// TOMBSTONE'LANMIŞ BAĞLAR DA GİDİYOR: yalnız canlı olanları gönderseydik
  /// sunucu "eksik olan henüz gelmemiş" ile "eksik olan silinmiş"i ayırt
  /// edemezdi (rapor §1.1).
  static List<Map<String, Object?>> _json<T extends DataClass>(List<T>? rows) =>
      [for (final row in rows ?? <T>[]) outboxRowJson(row)];
}
