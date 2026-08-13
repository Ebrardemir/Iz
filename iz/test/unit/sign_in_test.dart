/// Giriş iş kuralları testi.
///
/// Rapor 18.1: "Unit test: domain kuralları ... ve validatorlar."
///
/// Bu dosyada Flutter, widget veya veritabanı YOK — saf Dart.
/// Hata METNİ değil hata KODU kontrol ediliyor; domain dil bilmez.
/// Metinlerin doğruluğu `l10n_test.dart` içinde ayrıca doğrulanıyor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';
import 'package:iz/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late SignInWithEmail signIn;

  const session = AuthSession(userId: 'u1', email: 'ebrar@example.com');

  setUpAll(() {
    registerFallbackValue(const AuthCredentials());
  });

  setUp(() {
    repository = _MockAuthRepository();
    when(
      () => repository.signInWithEmail(any()),
    ).thenAnswer((_) async => const Ok(session));
    signIn = SignInWithEmail(repository: repository);
  });

  /// Hatanın kodunu okumak için kısayol.
  ValidationCode? codeOf(Result<AuthSession> result) =>
      (result.failureOrNull as ValidationFailure?)?.code;

  group('e-posta doğrulaması', () {
    test('boş e-posta reddedilir', () async {
      final result = await signIn(const AuthCredentials(password: 'gizli123'));

      expect(codeOf(result), ValidationCode.emailRequired);
      // Repository'ye HİÇ gidilmemeli — ağ isteği boşa harcanmasın.
      verifyNever(() => repository.signInWithEmail(any()));
    });

    test('sadece boşluktan oluşan e-posta boş sayılır', () async {
      final result = await signIn(
        const AuthCredentials(email: '   ', password: 'gizli123'),
      );

      expect(codeOf(result), ValidationCode.emailRequired);
    });

    test('biçimi bozuk e-posta reddedilir', () async {
      for (final bad in [
        'ebrar',
        'ebrar@',
        '@example.com',
        'a b@c.com',
        'ebrar@example',
        'ebrar@@example.com',
      ]) {
        final result = await signIn(
          AuthCredentials(email: bad, password: 'gizli123'),
        );

        expect(
          codeOf(result),
          ValidationCode.emailInvalid,
          reason: '"$bad" geçersiz sayılmalıydı',
        );
      }
    });

    test('geçerli e-postalar kabul edilir', () async {
      for (final good in [
        'ebrar@example.com',
        'ebrar.arin@example.co.uk',
        'ebrar+iz@example.com',
        'e@x.io',
      ]) {
        final result = await signIn(
          AuthCredentials(email: good, password: 'gizli123'),
        );

        expect(result.isOk, isTrue, reason: '"$good" geçerli olmalıydı');
      }
    });

    test('baştaki/sondaki boşluk temizlenip gönderilir', () async {
      await signIn(
        const AuthCredentials(
          email: '  ebrar@example.com  ',
          password: 'gizli123',
        ),
      );

      final captured =
          verify(() => repository.signInWithEmail(captureAny())).captured.last
              as AuthCredentials;

      expect(captured.email, 'ebrar@example.com');
    });
  });

  group('şifre doğrulaması', () {
    test('boş şifre reddedilir', () async {
      final result = await signIn(
        const AuthCredentials(email: 'ebrar@example.com'),
      );

      expect(codeOf(result), ValidationCode.passwordRequired);
    });

    test('kısa şifre reddedilir ve asgari uzunluğu taşır', () async {
      final result = await signIn(
        const AuthCredentials(email: 'ebrar@example.com', password: '123'),
      );

      expect(codeOf(result), ValidationCode.passwordTooShort);
      // Bu sayı çeviriye "{min} karakter" olarak girer; kuralla mesaj
      // birbirinden ayrışmasın diye taşınıyor.
      expect(
        (result.failureOrNull! as ValidationFailure).limit,
        SignInWithEmail.minPasswordLength,
      );
    });

    test('asgari uzunluktaki şifre kabul edilir', () async {
      final result = await signIn(
        AuthCredentials(
          email: 'ebrar@example.com',
          password: 'a' * SignInWithEmail.minPasswordLength,
        ),
      );

      expect(result.isOk, isTrue);
    });
  });

  group('doğrulama sırası', () {
    test('e-posta hatası şifre hatasından önce bildirilir', () async {
      // İkisi de hatalı; kullanıcıya formun ÜSTTEKİ alanı gösterilmeli,
      // yoksa odak aşağıya kayar ve üstteki hata gözden kaçar.
      final result = await signIn(const AuthCredentials());

      expect(codeOf(result), ValidationCode.emailRequired);
    });
  });

  test('doğrulama geçince repository çağrılır', () async {
    final result = await signIn(
      const AuthCredentials(email: 'ebrar@example.com', password: 'gizli123'),
    );

    expect(result.valueOrNull, session);
    verify(() => repository.signInWithEmail(any())).called(1);
  });

  test('repository hatası olduğu gibi yukarı taşınır', () async {
    when(
      () => repository.signInWithEmail(any()),
    ).thenAnswer((_) async => const Err(AuthFailure()));

    final result = await signIn(
      const AuthCredentials(email: 'ebrar@example.com', password: 'gizli123'),
    );

    // UseCase hatayı YUTMAZ ve DEĞİŞTİRMEZ.
    expect(result.failureOrNull, isA<AuthFailure>());
  });
}
