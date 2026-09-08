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
/// v5 yalnız indeks kuruyordu, o yüzden gerekmemişti; v6 sütun eklediği için
/// aşağıda var. v8'de (join tabloları + sync tabloları, TR-M2-01) aynısı
/// gerekecek ve orası çok daha riskli: composite anahtarlı tablolar
/// değişiyor. Şema kütüğü TRD → Ek A'da.
library;

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/app/database/app_database.dart';

import '../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('canlı şema, v7 anlık görüntüsüyle birebir aynı', () async {
    final connection = await verifier.startAt(7);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 7);

    await db.close();
  });

  test('v4 → v7 yükseltmesi sorunsuz tamamlanıyor', () async {
    // TR-A-01: kullanıcı ARADAKİ sürümleri atlayabilir. Uygulamayı aylardır
    // güncellemeyen biri v4'ten doğrudan v6'ya çıkar; adımların sırayla ve
    // eksiksiz çalıştığını doğrulayan test budur.
    //
    // v4 en eski anlık görüntümüz: depoda tek commit olduğu için v1–v3
    // geriye dönük üretilemedi (TRD → Ek A / TR-A-02).
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 7);

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
    await verifier.migrateAndValidate(db, 7);

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
    await verifier.migrateAndValidate(db, 7);

    final kisiler = await db.select(db.people).get();
    expect(kisiler, hasLength(1));
    expect(kisiler.single.name, 'Annem');
    // Yeni sütun eski kayıtta boş: "ilişki adı yazılmamış" geçerli bir durum.
    expect(kisiler.single.relationLabel, isNull);

    await db.close();
  });

  test('schemaVersion, elimizdeki en yeni anlık görüntüyle uyumlu', () async {
    // Anlık görüntü almadan schemaVersion artırmayı yakalar.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(
      db.schemaVersion,
      7,
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
