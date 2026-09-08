/// Outbox gövdesinin BİÇİMİ — tek yerde tanımlı.
///
/// NEDEN SATIR, DOMAIN NESNESİ DEĞİL?
/// Senkronizasyon SATIRLARI taşıyor. Domain nesnesini serileştirseydik
/// gövde ekranın gördüğü şekle bağlanırdı; `Memory` bir gün ikiye bölünse
/// kullanıcının cihazında bekleyen eski kuyruk okunamaz hâle gelirdi.
///
/// NEDEN BAĞLAR DA İÇERİDE?
/// "Anıdan kişiyi çıkardım" tek başına bir varlık değişikliği değil, bir BAĞ
/// değişikliği — ve outbox'ın `entityId`si tekil. Bağları anının gövdesiyle
/// birlikte göndermek, rapor §1.1'deki "çıkarılan kişi ikinci cihazda geri
/// geliyor" hatasını kapatmanın en doğrudan yolu.
///
/// TOMBSTONE'LAR DA GİDİYOR: yalnız canlı bağları gönderseydik sunucu
/// "eksik olan henüz gelmemiş" ile "eksik olan silinmiş"i ayırt edemezdi.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

/// Gövdenin sürüm etiketi.
///
/// Kuyruk uygulama güncellemesinden sağ çıkıyor (kullanıcının cihazında
/// bekliyor olabilir). Biçim değişirse eski satırları okuyan taraf bunu
/// buradan anlar.
const kOutboxPayloadVersion = 1;

/// Bir veritabanı satırını gövdeye çevirir.
///
/// Anahtarlar SQL SÜTUN ADI (`occurred_year`), Dart alan adı değil — bkz.
/// `build.yaml` → `use_sql_column_name_as_json_key`.
Map<String, Object?> outboxRowJson(DataClass row) =>
    row.toJson(serializer: const _IsoValueSerializer());

String encodeOutboxPayload({
  required Map<String, Object?> entity,
  Map<String, List<Map<String, Object?>>> links = const {},
}) {
  return jsonEncode({
    'v': kOutboxPayloadVersion,
    'entity': entity,
    if (links.isNotEmpty) 'links': links,
  });
}

/// Dart'ta `DateTime?` bir tip LİTERALİ olarak yazılamıyor; `T == ...`
/// karşılaştırması için takma ad gerekiyor.
typedef _NullableDateTime = DateTime?;

/// Tarihleri ISO-8601 METİN olarak yazan serileştirici.
///
/// Drift'in varsayılanı epoch milisaniye. İki sorun:
///   1. Veritabanı zaten ISO-8601 TEXT saklıyor (`build.yaml` →
///      `store_date_time_values_as_text`); epoch'a çevirip geri çevirmek
///      gereksiz bir dönüşüm ve zaman dilimi bilgisini düşürüyor.
///   2. Gövde sunucuyla aramızdaki sözleşme. Çıplak bir sayı gördüğünde
///      okuyan tarafın saniye mi milisaniye mi olduğunu TAHMİN etmesi
///      gerekirdi.
class _IsoValueSerializer extends ValueSerializer {
  const _IsoValueSerializer();

  static const _inner = ValueSerializer.defaults();

  @override
  T fromJson<T>(Object? json) {
    if (json is String && (T == DateTime || T == _NullableDateTime)) {
      return DateTime.parse(json) as T;
    }
    return _inner.fromJson<T>(json);
  }

  @override
  Object? toJson<T>(T value) {
    if (value is DateTime) return value.toIso8601String();
    return _inner.toJson<T>(value);
  }
}
