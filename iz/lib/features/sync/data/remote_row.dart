/// Sunucudan inen bir SATIRIN okunması.
///
/// `outbox_payload.dart`ın ters yönü: orası yerel satırı gövdeye çeviriyor,
/// burası gövdeyi yerel satıra çeviriyor. Anahtarlar aynı — SQL sütun adı
/// (`occurred_year`), çünkü sunucu istemcinin satırını olduğu gibi aynalıyor.
///
/// OKUYUCU BİLEREK BAĞIŞLAYICI. Eksik alan, `null` ya da beklenmedik tipteki
/// bir değer istisna atmıyor; varsayılana düşüyor. Gerekçesi TR-M13-22'nin
/// istemci tarafındaki karşılığı: katı bir okuyucu, sunucudan gelen tek bir
/// bozuk alan yüzünden O SAYFANIN TAMAMINI uygulanamaz yapardı ve cursor
/// hiç ilerlemezdi — kullanıcı bir daha asla eşitlenemezdi.
///
/// ⚠️ ENUM SÜTUNLARI İSTEMCİDE DAR, SUNUCUDA METİN. Sunucu bilinçli olarak
/// dar tip kullanmıyor (yeni bir değer eklendiğinde eski sunucunun kuyruğu
/// kilitlemesin diye). İstemcide ise sütun `textEnum` ve tanımadığı bir
/// değeri saklayamaz. Bu yüzden çeviri VARSAYILANA DÜŞÜYOR: kayıt yazılır,
/// yalnız o alan bilinen bir değere sabitlenir. Alternatifi kaydı hiç
/// yazmamaktı — kullanıcı anısını ikinci cihazında hiç göremezdi.
library;

final class RemoteRow {
  const RemoteRow(this._map);

  final Map<String, Object?> _map;

  Object? operator [](String field) => _map[field];

  bool has(String field) => _map.containsKey(field);

  String? text(String field) {
    final value = _map[field];
    return value is String ? value : null;
  }

  String textOr(String field, String fallback) => text(field) ?? fallback;

  /// SQLite boolean'ı 0/1 saklıyor; sunucu ise gerçek `true`/`false`
  /// gönderiyor. İkisini de kabul etmek eski bir gövdeyi kurtarır.
  bool boolean(String field) {
    final value = _map[field];
    return switch (value) {
      final bool it => it,
      final int it => it != 0,
      _ => false,
    };
  }

  int? integer(String field) {
    final value = _map[field];
    return switch (value) {
      final int it => it,
      // JSON sayısı `double` olarak gelebilir (ör. 2026.0).
      final double it => it.toInt(),
      _ => null,
    };
  }

  int integerOr(String field, int fallback) => integer(field) ?? fallback;

  double? real(String field) {
    final value = _map[field];
    return switch (value) {
      final double it => it,
      final int it => it.toDouble(),
      _ => null,
    };
  }

  /// ISO-8601 metni → `DateTime`.
  ///
  /// Sonuç YERELE ÇEVRİLİYOR (`toLocal`) çünkü Drift tarihleri UTC olarak
  /// saklıyor ve uygulamanın geri kalanı öyle bekliyor; sunucu da ISO-8601
  /// offset'iyle gönderiyor. Çeviriyi atlarsak +03:00'lik bir damga UTC
  /// sanılır ve anı üç saat kayar.
  DateTime? dateTime(String field) {
    final raw = text(field);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  DateTime dateTimeOr(String field, DateTime fallback) =>
      dateTime(field) ?? fallback;

  /// Metni bir enum değerine çevirir; tanımıyorsa [fallback].
  ///
  /// Gerekçesi dosya başındaki notta: kaydı hiç yazmamaktansa o alanı bilinen
  /// bir değere sabitlemek.
  T enumOr<T extends Enum>(String field, List<T> values, T fallback) {
    final raw = text(field);
    if (raw == null) return fallback;

    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}
