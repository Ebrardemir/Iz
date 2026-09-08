/// Şema doğrulama testi (TR-A-02).
///
/// NEDEN VAR?
/// `schemaVersion`i artırmayı ya da migration adımını yazmayı unutmak, kod
/// incelemesinde en kolay gözden kaçan hatadır — ve sonucu kullanıcının
/// cihazında "no such column" ile çöken bir uygulamadır.
///
/// Bu test `drift_schemas/` altındaki anlık görüntüyle canlı şemayı
/// karşılaştırır. Bir tablo veya sütun eklediğinde bu test KIRILIR; düzeltmek
/// için önce migration adımını yaz, sonra yeni anlık görüntüyü al:
///
///   fvm dart run drift_dev schema dump lib/app/database/app_database.dart drift_schemas/
///   fvm dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
///
/// KURAL: sütun EKLEYEN her sürüme bir de "veri kaybetmiyor" testi yazılır.
/// v5 yalnız indeks kuruyordu, o yüzden gerekmemişti; v6, v7 ve v8 için
/// aşağıda var. v8 en riskli olanı: bileşik anahtarlı bağ tabloları
/// değişiyor (TR-M2-01). Şema kütüğü TRD → Ek A'da.
library;

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/features/auth/data/tables/user_tables.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';

import '../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('canlı şema, v8 anlık görüntüsüyle birebir aynı', () async {
    final connection = await verifier.startAt(8);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 8);

    await db.close();
  });

  test('v4 → v8 yükseltmesi sorunsuz tamamlanıyor', () async {
    // TR-A-01: kullanıcı ARADAKİ sürümleri atlayabilir. Uygulamayı aylardır
    // güncellemeyen biri v4'ten doğrudan v6'ya çıkar; adımların sırayla ve
    // eksiksiz çalıştığını doğrulayan test budur.
    //
    // v4 en eski anlık görüntümüz: depoda tek commit olduğu için v1–v3
    // geriye dönük üretilemedi (TRD → Ek A / TR-A-02).
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 8);

    await db.close();
  });

  test('v6 → v7 seri ↔ kişi bağı TAŞINIYOR, kaybolmuyor', () async {
    // v7 tekil `related_person_id` sütununu kaldırıp çoklu bir bağ tablosu
    // kuruyor. Migration'ın işi yalnız tabloyu açmak değil, VAR OLAN BAĞI
    // yeni tabloya taşımak — taşımasaydı kullanıcının seçtiği kişi sessizce
    // silinirdi. Bu testin varlık sebebi o.
    final schema = await verifier.schemaAt(6);

    final eski = schema.newConnection();
    await eski.executor.ensureOpen(_NoOpUser(6));
    await eski.executor.runCustom(
      "INSERT INTO people (id, name) VALUES ('kisi-1', 'Annem')",
      const [],
    );
    await eski.executor.runCustom(
      'INSERT INTO rituals (id, title, related_person_id) '
      "VALUES ('seri-1', 'Annemin Doğum Günleri', 'kisi-1')",
      const [],
    );
    // Kişisi olmayan seri de var: taşınacak bağı yok ve migration onu
    // atlamalı, hata vermemeli.
    await eski.executor.runCustom(
      "INSERT INTO rituals (id, title) VALUES ('seri-2', 'Yaz Tatilleri')",
      const [],
    );
    await eski.executor.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final seriler = await db.select(db.rituals).get();
    expect(seriler, hasLength(2));

    final baglar = await db.select(db.ritualPeople).get();
    expect(baglar, hasLength(1));
    expect(baglar.single.ritualId, 'seri-1');
    expect(baglar.single.personId, 'kisi-1');

    await db.close();
  });

  test('v5 → v6 yükseltmesi mevcut kişileri KAYBETMİYOR', () async {
    // v6 SÜTUN ekliyor; v5'inkiler yalnız indeks kuruyordu. Sütun eklemek
    // SQLite'ta tabloyu yeniden yazabildiği için burada verinin hayatta
    // kaldığını da doğruluyoruz — dosya başındaki nota göre bu şart.
    final schema = await verifier.schemaAt(5);

    // v5 şeması ham tablo olarak üretiliyor (companion yok), bu yüzden
    // kaydı SQL ile yazıyoruz. Yalnız zorunlu sütunlar veriliyor; geri
    // kalanların SQL varsayılanı var.
    final eski = schema.newConnection();
    await eski.executor.ensureOpen(_NoOpUser(5));
    await eski.executor.runCustom(
      "INSERT INTO people (id, name) VALUES ('kisi-1', 'Annem')",
      const [],
    );
    await eski.executor.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final kisiler = await db.select(db.people).get();
    expect(kisiler, hasLength(1));
    expect(kisiler.single.name, 'Annem');
    // Yeni sütun eski kayıtta boş: "ilişki adı yazılmamış" geçerli bir durum.
    expect(kisiler.single.relationLabel, isNull);

    await db.close();
  });

  test('v7 → v8 mevcut BAĞLAR kopmuyor ve hepsi CANLI kalıyor', () async {
    // v8 bağ tablolarına `updatedAt/deletedAt/version` ekliyor. SQLite'ta
    // sütun eklemek tabloyu yeniden yazabiliyor ve bağ tablolarının anahtarı
    // BİLEŞİK — en riskli migration'ımız bu.
    //
    // İki şeyi birden doğruluyoruz: bağ duruyor mu, ve `deletedAt` NULL
    // geldi mi. İkincisi atlanırsa var olan tüm ilişkiler "silinmiş" sayılıp
    // ekrandan topluca kaybolurdu.
    final schema = await verifier.schemaAt(7);

    final eski = schema.newConnection();
    await eski.executor.ensureOpen(_NoOpUser(7));
    await eski.executor.runCustom(
      // Tarih parçaları ayrı sütunlarda ve hepsi NOT NULL — "hangi
      // yıl/ay/gün" sorguları indeksten okunsun diye (FR-076). Tarihler
      // TEXT/ISO-8601 (bkz. build.yaml → store_date_time_values_as_text).
      'INSERT INTO memories '
      '(id, title, occurred_at, occurred_year, occurred_month, occurred_day) '
      "VALUES ('ani-1', 'Kahve Molası', '2026-07-26T10:00:00.000', 2026, 7, 26)",
      const [],
    );
    await eski.executor.runCustom(
      "INSERT INTO people (id, name) VALUES ('kisi-1', 'Annem')",
      const [],
    );
    await eski.executor.runCustom(
      'INSERT INTO memory_people (memory_id, person_id) '
      "VALUES ('ani-1', 'kisi-1')",
      const [],
    );
    await eski.executor.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final baglar = await db.select(db.memoryPeople).get();
    expect(baglar, hasLength(1), reason: 'bağ migration sırasında kayboldu');
    expect(baglar.single.memoryId, 'ani-1');
    expect(baglar.single.personId, 'kisi-1');
    // BURASI KRİTİK: dolu gelseydi var olan tüm ilişkiler silinmiş sayılırdı.
    expect(baglar.single.deletedAt, isNull);
    expect(baglar.single.version, 1);

    await db.close();
  });

  test('v7 → v8 YEREL KULLANICI satırı açılıyor', () async {
    // TR-M1-01 — her tablodaki `ownerId` varsayılanı `'local'`. `Users`
    // tablosu gelince bu değerin gerçek bir satıra işaret etmesi gerekiyor;
    // satır açılmasaydı hesap eklendiği gün binlerce `ownerId` taşınacaktı.
    final schema = await verifier.schemaAt(7);

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final kullanicilar = await db.select(db.users).get();
    expect(kullanicilar, hasLength(1));
    expect(kullanicilar.single.id, Users.localId);
    // Hesap henüz yok: e-posta boş olmalı, uydurulmamalı.
    expect(kullanicilar.single.email, isNull);

    await db.close();
  });

  test('YENİ KURULUMDA da yerel kullanıcı ve kategoriler var', () async {
    // Yükseltme yolu ile `onCreate` yolu AYRI kod. Birine eklenip diğerine
    // eklenmeyen tohum, yalnız yeni kullanıcılarda görünen bir hata olurdu.
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    final kullanicilar = await db.select(db.users).get();
    expect(kullanicilar.single.id, Users.localId);

    final kategoriler = await db.select(db.categories).get();
    expect(kategoriler, hasLength(DefaultCategories.seed.length));

    await db.close();
  });

  test('senkronizasyon defterleri kuruluyor ve BOŞ başlıyor', () async {
    // Faz 2'nin çıkış kriteri: tablolar var, motor yok. Outbox'ın boş
    // başlaması önemli — dolu başlasaydı ilk eşitlemede uydurma değişiklikler
    // sunucuya giderdi.
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    expect(await db.select(db.outboxEntries).get(), isEmpty);
    expect(await db.select(db.syncConflicts).get(), isEmpty);
    expect(await db.select(db.syncState).get(), isEmpty);

    await db.close();
  });

  test('schemaVersion, elimizdeki en yeni anlık görüntüyle uyumlu', () async {
    // Anlık görüntü almadan schemaVersion artırmayı yakalar.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(
      db.schemaVersion,
      8,
      reason:
          'schemaVersion artırıldıysa drift_schemas/ altına yeni bir anlık '
          'görüntü alıp bu testi güncelle (bkz. dosya başındaki komutlar).',
    );
    await db.close();
  });
}

/// `QueryExecutor.ensureOpen` bir `QueryExecutorUser` istiyor ama biz yalnız
/// ham SQL çalıştıracağız: şema zaten kurulu, migration çalıştırmıyoruz.
///
/// SÜRÜM PARAMETRE — sabit DEĞİL. Bu değer veritabanının `user_version`ına
/// yazılıyor; sabit bıraksaydık (bir süre 5'ti) daha yeni bir şemadan
/// başlayan test yanlış sürümden göç etmeye kalkar ve zaten var olan
/// sütunu ikinci kez eklemeye çalışırdı.
final class _NoOpUser extends QueryExecutorUser {
  _NoOpUser(this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
