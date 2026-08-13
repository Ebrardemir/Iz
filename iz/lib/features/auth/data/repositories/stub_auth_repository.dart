/// ⚠️ GEÇİCİ implementasyon — gerçek kimlik doğrulama YOK.
///
/// NEDEN VAR?
/// Backend'in Firebase mi kendi API'niz mi olacağı henüz belli değil. Ekranı
/// bu karar verilmeden tasarlayabilmek için sözleşmeyi (`AuthRepository`)
/// sahte bir sınıfla karşılıyoruz. Ekran gerçek bir repository'ye bağlı gibi
/// çalışır: yükleniyor durumu döner, hata döndürebilir, başarı döndürebilir.
///
/// BACKEND GELDİĞİNDE YAPILACAK TEK ŞEY:
/// ```dart
/// final authRepositoryProvider = Provider<AuthRepository>((ref) {
///   return FirebaseAuthRepository(...);   // ← sadece bu satır
/// });
/// ```
/// Hiçbir View, hiçbir ViewModel, hiçbir UseCase değişmez. Mimarinin
/// "bir katman kendisinden somut olanı bilmez" kuralının somut karşılığı bu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';

final class StubAuthRepository implements AuthRepository {
  StubAuthRepository({required IdGenerator idGenerator}) : _ids = idGenerator;

  final IdGenerator _ids;

  /// Ağ gecikmesi taklidi. Olmasaydı yükleniyor göstergesi hiç görünmez ve
  /// o durumu tasarlarken test edemezdik.
  static const Duration _fakeLatency = Duration(milliseconds: 900);

  /// Hata durumunu ekranda görebilmek için: bu şifreyle giriş her zaman
  /// başarısız olur. Gerçek repository gelince silinecek.
  static const String rejectedPassword = 'hatali';

  AuthSession? _session;

  @override
  Future<Result<AuthSession>> signInWithEmail(
    AuthCredentials credentials,
  ) async {
    await Future<void>.delayed(_fakeLatency);

    if (credentials.password == rejectedPassword) {
      return const Err(AuthFailure());
    }

    final session = AuthSession(
      userId: _ids.newId(),
      email: credentials.normalizedEmail,
    );
    _session = session;
    return Ok(session);
  }

  @override
  Future<Result<AuthSession>> signUpWithEmail(SignUpDraft draft) async {
    await Future<void>.delayed(_fakeLatency);

    if (draft.password == rejectedPassword) {
      return const Err(AuthFailure());
    }

    final session = AuthSession(
      userId: _ids.newId(),
      email: draft.normalizedEmail,
      displayName: draft.normalizedName,
    );
    _session = session;
    return Ok(session);
  }

  @override
  Future<Result<AuthSession>> signInWithProvider(AuthProvider provider) async {
    await Future<void>.delayed(_fakeLatency);

    final session = AuthSession(
      userId: _ids.newId(),
      displayName: provider.name,
    );
    _session = session;
    return Ok(session);
  }

  @override
  Future<Result<Unit>> sendPasswordReset(String email) async {
    await Future<void>.delayed(_fakeLatency);
    return okUnit;
  }

  @override
  Future<Result<Unit>> signOut() async {
    _session = null;
    return okUnit;
  }

  @override
  Future<Result<AuthSession?>> currentSession() async => Ok(_session);
}

/// BACKEND GELDİĞİNDE DEĞİŞECEK TEK SATIR BURASI.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return StubAuthRepository(idGenerator: ref.watch(idGeneratorProvider));
});
