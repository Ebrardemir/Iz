/// [Failure] → kullanıcıya gösterilecek metin köprüsü.
///
/// NEDEN AYRI DOSYA?
/// `Failure` domain katmanında yaşar ve Flutter'ı bilmez (test edilebilirlik).
/// Kullanıcı metni ise dile bağlıdır. İkisini bir extension ile birleştiriyoruz;
/// böylece domain temiz kalır, UI da `failure.message` gibi teknik metinleri
/// ekrana basmak zorunda kalmaz.
///
/// KULLANIM:
/// ```dart
/// Text(failure.localizedMessage(context.l10n))
/// ```
library;

import 'package:iz/core/error/failure.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';

extension FailureL10nX on Failure {
  String localizedMessage(AppL10n l10n) => switch (this) {
    DatabaseFailure() => l10n.errorDatabase,
    NotFoundFailure() => l10n.errorNotFound,
    // İç içe switch: önce hata TİPİ, sonra doğrulama KODU seçilir.
    // Yeni bir ValidationCode eklersen derleyici burayı işaret eder.
    ValidationFailure(:final code, :final limit) => switch (code) {
      ValidationCode.emptyMemory => l10n.errorValidationEmptyMemory,
      // `limit` bu kodda her zaman dolu gelir (bkz. SaveMemory);
      // yine de çökmemek için savunmacı varsayılan veriyoruz.
      ValidationCode.photoLimitExceeded => l10n.photoLimitReached(limit ?? 0),
      ValidationCode.futureDate => l10n.errorValidationFutureDate,
      ValidationCode.emailRequired => l10n.errorValidationEmailRequired,
      ValidationCode.emailInvalid => l10n.errorValidationEmailInvalid,
      ValidationCode.passwordRequired => l10n.errorValidationPasswordRequired,
      // `limit` burada asgari uzunluğu taşır (bkz. SignInWithEmail).
      ValidationCode.passwordTooShort => l10n.errorValidationPasswordTooShort(
        limit ?? 0,
      ),
      ValidationCode.nameRequired => l10n.errorValidationNameRequired,
      ValidationCode.passwordsDoNotMatch =>
        l10n.errorValidationPasswordsDoNotMatch,
    },
    AuthFailure() => l10n.errorSignInFailed,
    PermissionFailure(:final permanentlyDenied) =>
      permanentlyDenied
          ? '${l10n.errorPermission} ${l10n.errorPermissionSettings}'
          : l10n.errorPermission,
    MediaUnavailableFailure() => l10n.mediaMissingMessage,
    EntitlementFailure(:final requiredPlan) => l10n.paywallFeatureLocked(
      requiredPlan,
    ),
    NetworkFailure(:final isOffline) =>
      isOffline ? l10n.errorOffline : l10n.errorNetwork,
    UnexpectedFailure() => l10n.errorGeneric,
  };

  /// Kullanıcı bu hatayı "tekrar dene" ile aşabilir mi?
  /// Aşamıyorsa butonu göstermek sadece hayal kırıklığı yaratır.
  bool get isRetryable => switch (this) {
    DatabaseFailure() || NetworkFailure() || UnexpectedFailure() => true,
    NotFoundFailure() ||
    ValidationFailure() ||
    PermissionFailure() ||
    MediaUnavailableFailure() ||
    // Kimlik hatasında "tekrar dene" anlamsız — bilgiyi düzeltmek gerek.
    AuthFailure() ||
    EntitlementFailure() => false,
  };

  /// Bu hata bir paywall açmalı mı? (FR-130)
  bool get shouldShowPaywall => this is EntitlementFailure;
}
