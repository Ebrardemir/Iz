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
/// V6 GELDİĞİNDE: join tablolarına updatedAt/deletedAt/version eklenecek
/// (TR-M2-01). O adım SÜTUN ekliyor, dolayısıyla buraya "veri kaybetmiyor"
/// testi de yazılmalı — v5'teki indeksler veri dönüştürmediği için gerekmedi.
library;

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

  test('canlı şema, v5 anlık görüntüsüyle birebir aynı', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 5);

    await db.close();
  });

  test('v4 → v5 yükseltmesi sorunsuz tamamlanıyor', () async {
    // TR-A-01: kullanıcı v4'ten v5'e atlıyor. Bu adım yalnız indeks kuruyor,
    // sütun eklemiyor — ama migration'ın gerçekten çalıştığını ve şemanın
    // beklenen hâle geldiğini doğrulamak gerekiyor.
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 5);

    await db.close();
  });

  test('schemaVersion, elimizdeki en yeni anlık görüntüyle uyumlu', () async {
    // Anlık görüntü almadan schemaVersion artırmayı yakalar.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(
      db.schemaVersion,
      5,
      reason:
          'schemaVersion artırıldıysa drift_schemas/ altına yeni bir anlık '
          'görüntü alıp bu testi güncelle (bkz. dosya başındaki komutlar).',
    );
    await db.close();
  });
}
