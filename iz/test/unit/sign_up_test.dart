/// Kayıt iş kuralları testi.
///
/// Hata METNİ değil hata KODU kontrol ediliyor; domain dil bilmez.
/// Metinlerin doğruluğu `l10n_test.dart` içinde ayrıca doğrulanıyor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/repositories/auth_repository.dart';
import 'package:iz/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:iz/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late SignUpWithEmail signUp;

  const session = AuthSession(userId: 'u1');

  /// Tümü geçerli bir taslak; testler bunun tek bir alanını bozar.
  const valid = SignUpDraft(
    fullName: 'Ebrar Arın',
    email: 'ebrar@example.com',
    password: 'gizli123',
    confirmPassword: 'gizli123',
  );

  setUpAll(() => registerFallbackValue(const SignUpDraft()));

  setUp(() {
    repository = _MockAuthRepository();
    when(
      () => repository.signUpWithEmail(any()),
    ).thenAnswer((_) async => const Ok(session));
    signUp = SignUpWithEmail(repository: repository);
  });

  ValidationCode? codeOf(Result<AuthSession> r) =>
      (r.failureOrNull as ValidationFailure?)?.code;

  test('geçerli taslak kaydedilir', () async {
    final result = await signUp(valid);

    expect(result.valueOrNull, session);
    verify(() => repository.signUpWithEmail(any())).called(1);
  });

  group('ad soyad', () {
    test('boşsa reddedilir', () async {
      final result = await signUp(valid.copyWith(fullName: ''));

      expect(codeOf(result), ValidationCode.nameRequired);
      verifyNever(() => repository.signUpWithEmail(any()));
    });

    test('sadece boşluksa reddedilir', () async {
      final result = await signUp(valid.copyWith(fullName: '   '));

      expect(codeOf(result), ValidationCode.nameRequired);
    });

    test('baştaki/sondaki boşluk temizlenip gönderilir', () async {
      await signUp(valid.copyWith(fullName: '  Ebrar Arın  '));

      final captured =
          verify(() => repository.signUpWithEmail(captureAny())).captured.last
              as SignUpDraft;

      expect(captured.fullName, 'Ebrar Arın');
    });
  });

  group('şifre tekrarı', () {
    test('eşleşmiyorsa reddedilir', () async {
      final result = await signUp(
        valid.copyWith(confirmPassword: 'baskabirsey'),
      );

      expect(codeOf(result), ValidationCode.passwordsDoNotMatch);
      verifyNever(() => repository.signUpWithEmail(any()));
    });

    test('hata İKİNCİ şifre alanında gösterilir', () async {
      // Kullanıcının düzeltmesi gereken alan odaktaki alandır; hatayı ilk
      // şifreye koymak onu yukarı bakmaya zorlar.
      final result = await signUp(valid.copyWith(confirmPassword: 'x'));

      expect(
        (result.failureOrNull! as ValidationFailure).code.field,
        AuthFormField.confirmPassword,
      );
    });

    test('boşluk farkı önemsenir', () async {
      // Şifrede boşluk anlamlıdır; trim edip "eşleşiyor" saymak, kullanıcının
      // giremediği bir şifreyle hesap açmasına yol açar.
      final result = await signUp(
        valid.copyWith(password: 'gizli123', confirmPassword: 'gizli123 '),
      );

      expect(codeOf(result), ValidationCode.passwordsDoNotMatch);
    });
  });

  group('girişle ORTAK kurallar burada da geçerli', () {
    test('geçersiz e-posta reddedilir', () async {
      final result = await signUp(valid.copyWith(email: 'ebrar@'));

      expect(codeOf(result), ValidationCode.emailInvalid);
    });

    test('kısa şifre reddedilir ve asgari uzunluğu taşır', () async {
      final result = await signUp(
        valid.copyWith(password: '123', confirmPassword: '123'),
      );

      expect(codeOf(result), ValidationCode.passwordTooShort);
      expect(
        (result.failureOrNull! as ValidationFailure).limit,
        SignInWithEmail.minPasswordLength,
      );
    });
  });

  group('doğrulama sırası — formun ÜSTTEKİ hatası önce', () {
    test('her şey boşken önce ad istenir', () async {
      final result = await signUp(const SignUpDraft());

      expect(codeOf(result), ValidationCode.nameRequired);
    });

    test('ad doluyken önce e-posta istenir', () async {
      final result = await signUp(const SignUpDraft(fullName: 'Ebrar'));

      expect(codeOf(result), ValidationCode.emailRequired);
    });

    test('e-posta doluyken önce şifre istenir', () async {
      final result = await signUp(
        const SignUpDraft(fullName: 'Ebrar', email: 'e@x.io'),
      );

      expect(codeOf(result), ValidationCode.passwordRequired);
    });
  });

  test('repository hatası olduğu gibi yukarı taşınır', () async {
    when(
      () => repository.signUpWithEmail(any()),
    ).thenAnswer((_) async => const Err(AuthFailure()));

    final result = await signUp(valid);

    expect(result.failureOrNull, isA<AuthFailure>());
  });
}
