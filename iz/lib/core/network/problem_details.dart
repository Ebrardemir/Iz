/// Sunucunun hata gövdesi — RFC 9457 (ProblemDetails).
///
/// Sunucu HER hatada bunu döndürüyor; kural orada da yazılı
/// (`api/src/Iz.Api/Program.cs`, rapor 22.1). İstemci tarafında bu tipin
/// varlık sebebi: gövdeyi tek bir yerde ayrıştırmak ve
/// `Map<String, dynamic>` erişimini uygulamanın geri kalanına sızdırmamak.
///
/// ÖNEMLİ: kullanıcıya [title] veya [detail] GÖSTERİLMEZ (TR-C-10). Onlar
/// geliştirici ve log içindir; kullanıcının göreceği metin [errorCode]'a
/// bakılarak `failure_l10n.dart`'tan seçilir.
library;

final class ProblemDetails {
  const ProblemDetails({
    required this.status,
    this.errorCode,
    this.title,
    this.detail,
    this.field,
    this.traceId,
  });

  /// HTTP durum kodu.
  final int status;

  /// Makine okunur hata kodu — istemcinin dallandığı alan.
  ///
  /// Sunucu bunu her yanıtta dolduruyor; yine de `null` olabileceğini
  /// varsayıyoruz. Araya giren bir vekil sunucu (proxy) kendi hata
  /// sayfasını döndürebilir ve o sayfa bizim sözleşmemizi bilmez.
  final String? errorCode;

  final String? title;
  final String? detail;

  /// Hatanın ait olduğu form alanı (ör. `displayName`).
  final String? field;

  /// Sunucu logunda aynı isteği bulmaya yarar.
  final String? traceId;

  /// Gövdeyi ayrıştırır; gövde beklenen biçimde değilse `null` döner.
  ///
  /// `null` dönmesi bir hata değil, bilgi: çağıran taraf "sunucu bizim
  /// sözleşmemizle konuşmadı" bilgisini kullanarak farklı davranır.
  static ProblemDetails? tryParse(Object? body, {required int status}) {
    if (body is! Map) {
      return null;
    }

    String? asString(Object? value) => value is String ? value : null;

    // `status` gövdede varsa onu tercih ediyoruz: HTTP katmanı bir vekil
    // tarafından değiştirilmiş olabilir, gövdeyi uygulama yazdı.
    final bodyStatus = body['status'];

    return ProblemDetails(
      status: bodyStatus is int ? bodyStatus : status,
      errorCode: asString(body['errorCode']),
      title: asString(body['title']),
      detail: asString(body['detail']),
      field: asString(body['field']),
      traceId: asString(body['traceId']),
    );
  }

  @override
  String toString() =>
      'ProblemDetails(status: $status, errorCode: $errorCode, '
      'field: $field, traceId: $traceId)';
}
