/// Uygulamanın "beklenen hata" sözlüğü.
///
/// NEDEN VAR?
/// Katmanlar arasında ham `Exception` fırlatmak yerine, domain'in anladığı
/// sonlu bir hata kümesi taşıyoruz. Böylece ViewModel `catch (e)` yapıp
/// `e.toString()` basmak zorunda kalmaz; hangi hatayı nasıl göstereceğine
/// derleyici desteğiyle karar verir.
///
/// `sealed` olduğu için `switch` ifadesinde tüm alt tipleri ele almazsan
/// derleyici seni uyarır — yeni bir Failure eklediğinde onu görmezden
/// gelemezsin.
library;

import 'package:equatable/equatable.dart';

/// `implements Exception`: bir Failure'ı Riverpod'un `AsyncValue.error`
/// kanalına taşımak için fırlatabilmemiz gerekiyor (bkz. ViewModel'ler).
/// `only_throw_errors` lint kuralı da bunu şart koşar.
sealed class Failure extends Equatable implements Exception {
  const Failure({required this.message, this.cause, this.stackTrace});

  /// Log/debug için teknik mesaj. Kullanıcıya BUNU göstermeyin —
  /// kullanıcıya gösterilecek metin l10n'dan seçilir (bkz. FailureL10nX).
  final String message;

  /// Hatanın asıl kaynağı (DriftException, PlatformException, ...).
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [runtimeType, message, cause];

  @override
  String toString() => '$runtimeType: $message';
}

/// Yerel veritabanı hatası (Drift/SQLite).
final class DatabaseFailure extends Failure {
  const DatabaseFailure({
    super.message = 'Yerel veritabanı işlemi başarısız oldu.',
    super.cause,
    super.stackTrace,
  });
}

/// İstenen kayıt yok (silinmiş ya da hiç var olmamış).
final class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required this.entity,
    required this.id,
    super.cause,
    super.stackTrace,
  }) : super(message: 'Kayıt bulunamadı');

  final String entity;
  final String id;

  @override
  List<Object?> get props => [...super.props, entity, id];
}

/// Doğrulama hatalarının **kod** listesi.
///
/// NEDEN METİN DEĞİL KOD?
/// Domain katmanı Flutter'ı ve dili bilmez. Buraya hazır bir cümle yazarsak
/// ("Bir anı en az bir not içermeli") uygulamanın dili değişse bile o cümle
/// Türkçe kalır. Kod taşırsak çeviriyi UI katmanı seçer
/// (bkz. `core/l10n/failure_l10n.dart`).
///
/// `enum` olduğu için `switch` tüm değerleri ele almazsan derleyici uyarır —
/// yeni bir kural eklediğinde çevirisini yazmayı UNUTAMAZSIN.
enum ValidationCode {
  /// FR-012 — anı en az bir not veya bir medya içermeli.
  emptyMemory(field: MemoryFormField.note),

  /// FR-041 — plana göre fotoğraf limiti.
  photoLimitExceeded(field: MemoryFormField.media),

  /// FR-013 — geçmişe izin var, geleceğe yok.
  futureDate(field: MemoryFormField.occurredAt),

  // --- Kimlik doğrulama ---------------------------------------------------
  emailRequired(field: AuthFormField.email),
  emailInvalid(field: AuthFormField.email),
  passwordRequired(field: AuthFormField.password),
  passwordTooShort(field: AuthFormField.password),

  // --- Kayıt ---------------------------------------------------------------
  nameRequired(field: AuthFormField.fullName),

  /// Bu e-postayla zaten bir hesap var (TRD M1.5 — kayıt ekranı durumu).
  ///
  /// Sunucudan gelmesine rağmen [ValidationFailure]: kullanıcının
  /// düzeltebileceği bir ALAN var ve hata o alanın altında gösterilmeli.
  /// [AuthFailure] olsaydı formun tepesinde genel bir uyarı olarak çıkardı.
  emailAlreadyInUse(field: AuthFormField.email),

  /// Hata İKİNCİ şifre alanında gösterilir: kullanıcının düzeltmesi gereken
  /// alan odaktakidir, ilk şifre değil.
  passwordsDoNotMatch(field: AuthFormField.confirmPassword);

  const ValidationCode({this.field});

  /// Hata hangi form alanının altında gösterilmeli?
  /// `null` → alanla eşleşmiyor, SnackBar'da gösterilir.
  final String? field;
}

/// Form alanı adları. Düz string yazmak yerine sabit kullanıyoruz ki
/// `'occuredAt'` gibi bir yazım hatası sessizce "hata görünmüyor"a dönüşmesin.
abstract final class MemoryFormField {
  static const String title = 'title';
  static const String note = 'note';
  static const String media = 'media';
  static const String occurredAt = 'occurredAt';
}

abstract final class AuthFormField {
  static const String fullName = 'fullName';
  static const String email = 'email';
  static const String password = 'password';
  static const String confirmPassword = 'confirmPassword';
}

/// Kimlik doğrulamanın reddedilme sebebi.
///
/// NEDEN TEK BİR AuthFailure YETMİYOR?
/// Firebase üç ayrı durumu ayrı ayrı bildiriyor ve üçünde kullanıcının
/// yapması gereken şey FARKLI:
///   • yanlış şifre       → tekrar dene
///   • çok fazla deneme   → **bekle**, tekrar denemek işe yaramaz
///   • kapatılmış hesap   → destekle iletişime geç
/// Üçüne birden "e-posta veya şifre hatalı" demek, geçici olarak kilitlenmiş
/// kullanıcıyı şifresini değiştirmeye iter — yani sorunu büyütür.
enum AuthFailureReason {
  /// E-posta veya şifre tutmuyor. Varsayılan.
  invalidCredentials,

  /// Firebase hız sınırı devrede; hesap geçici olarak kilitli.
  tooManyAttempts,

  /// Hesap yönetici tarafından devre dışı bırakılmış.
  accountDisabled,

  /// Oturum düştü veya token artık geçerli değil; yeniden giriş gerekiyor.
  sessionExpired,

  /// İstenen giriş yöntemi bu sürümde bağlanmadı (Apple/Google).
  ///
  /// Kullanıcıya "şifren yanlış" demektense "bu yöntem şu an kullanılamıyor"
  /// demek dürüst olanı. Yöntem bağlandığında bu değer kullanılmaz olur.
  providerUnavailable,
}

/// Kimlik doğrulama başarısız (kullanıcı adı/şifre hatalı, oturum süresi
/// dolmuş). [ValidationFailure]'dan AYRI bir tip çünkü bu bir form hatası
/// değil: kullanıcı doğru biçimde doldurdu ama sunucu reddetti.
final class AuthFailure extends Failure {
  const AuthFailure({
    this.reason = AuthFailureReason.invalidCredentials,
    super.message = 'authentication failed',
    super.cause,
    super.stackTrace,
  });

  final AuthFailureReason reason;

  @override
  List<Object?> get props => [...super.props, reason];
}

/// İş kuralı ihlali. Örn. FR-012: "boş anı kaydedilemez".
///
/// Kullanıcıya gösterilecek metin BURADA DEĞİL, [code]'un çevirisinde durur.
final class ValidationFailure extends Failure {
  const ValidationFailure({required this.code, this.limit})
    : super(message: 'validation');

  final ValidationCode code;

  /// Çeviride yerine geçecek sayısal bağlam (örn. fotoğraf limiti).
  final int? limit;

  @override
  List<Object?> get props => [...super.props, code, limit];

  @override
  String toString() => 'ValidationFailure(${code.name}, limit: $limit)';
}

/// Platform izni reddedildi (galeri, konum, bildirim).
/// NFR-051: sınırlı fotoğraf erişimi de bu yolla raporlanır.
final class PermissionFailure extends Failure {
  const PermissionFailure({
    required this.permission,
    this.permanentlyDenied = false,
    super.cause,
  }) : super(message: 'İzin verilmedi');

  final String permission;

  /// true ise kullanıcıyı sistem ayarlarına yönlendirmek gerekir.
  final bool permanentlyDenied;

  @override
  List<Object?> get props => [...super.props, permission, permanentlyDenied];
}

/// BR-007 / FR-044: galerideki orijinal medya artık yok.
/// Bu bir "çökme" değil, gösterilmesi gereken bir üründür durumu.
final class MediaUnavailableFailure extends Failure {
  const MediaUnavailableFailure({
    required this.mediaId,
    this.hasPreview = false,
    super.cause,
  }) : super(message: 'Orijinal medya bulunamadı');

  final String mediaId;

  /// Önizleme cache'i duruyorsa kullanıcıya hâlâ bir görsel gösterebiliriz.
  final bool hasPreview;

  @override
  List<Object?> get props => [...super.props, mediaId, hasPreview];
}

/// FR-130: özellik kullanıcının planına kapalı. ViewModel bunu görünce
/// hata değil *paywall* göstermelidir.
final class EntitlementFailure extends Failure {
  const EntitlementFailure({
    required this.featureKey,
    required this.requiredPlan,
  }) : super(message: 'Bu özellik mevcut planında yok');

  final String featureKey;
  final String requiredPlan;

  @override
  List<Object?> get props => [...super.props, featureKey, requiredPlan];
}

/// V1.5+ ağ katmanı hataları.
final class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Bağlantı kurulamadı.',
    this.statusCode,
    this.isOffline = false,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
  final bool isOffline;

  @override
  List<Object?> get props => [...super.props, statusCode, isOffline];
}

/// Yakalanamayan/sınıflandırılamayan her şey. Buraya çok düşüyorsa,
/// muhtemelen yeni bir Failure tipi tanımlaman gerekiyordur.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'Beklenmeyen bir hata oluştu.',
    super.cause,
    super.stackTrace,
  });
}
