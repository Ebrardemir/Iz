/// [FirebaseAuthRepository] — Firebase hata kodlarının uygulama hata
/// sözlüğüne çevrilmesi.
///
/// NEDEN ASIL TEST EDİLEN ŞEY ÇEVİRİ?
/// Bu sınıfın kendi mantığı neredeyse yok: Firebase'i çağırıyor ve sonucu
/// aktarıyor. Değer ürettiği tek yer hata eşlemesi — ve orada yapılan bir
/// hata kullanıcıya yanlış şey söyletir. "Çok fazla deneme yaptın"ı "şifren
/// yanlış" diye göstermek, kilitlenmiş kullanıcıyı şifresini değiştirmeye
/// iter ve sorunu büyütür.
///
/// Firebase'e GERÇEKTEN bağlanmıyoruz: test ağa çıkmamalı.
library;

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:iz/features/auth/domain/entities/auth_credentials.dart';
import 'package:iz/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements fb.FirebaseAuth {}

class _MockUser extends Mock implements fb.User {}

class _MockUserCredential extends Mock implements fb.UserCredential {}

void main() {
  late _MockFirebaseAuth auth;
  late FirebaseAuthRepository repository;

  const credentials = AuthCredentials(
    email: 'ebru@ornek.com',
    password: 'gizli123',
  );

  setUp(() {
    auth = _MockFirebaseAuth();
    repository = FirebaseAuthRepository(auth: auth);
  });

  /// Firebase'in başarılı yanıtını taklit eder.
  ///
  /// Kullanıcı mock'u da geri döndürülüyor: testler onun üzerinde
  /// doğrulama yapıyor ve `credential.user!` üzerinden kurmak, mock'u
  /// kurulum sırasında çağırdığı için güvenilir değil.
  ({_MockUserCredential credential, _MockUser user}) credentialWith({
    String uid = 'firebase-uid-1',
    String? email = 'ebru@ornek.com',
    String? displayName,
  }) {
    final user = _MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => user.email).thenReturn(email);
    when(() => user.displayName).thenReturn(displayName);
    when(() => user.updateDisplayName(any())).thenAnswer((_) async {});

    final credential = _MockUserCredential();
    when(() => credential.user).thenReturn(user);
    return (credential: credential, user: user);
  }

  /// Girişte belirtilen Firebase hatasını fırlatır.
  void signInThrows(Object error) {
    when(
      () => auth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(error);
  }

  /// Girişin döndürdüğü hatayı verir; testin her satırında desen
  /// eşlemesi yazmamak için.
  Future<Failure> signInFailure() async {
    final result = await repository.signInWithEmail(credentials);
    return switch (result) {
      Err(:final failure) => failure,
      Ok() => fail('Hata bekleniyordu, başarı döndü.'),
    };
  }

  group('giriş', () {
    test('başarılı girişte oturum döner', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credentialWith(displayName: 'Ebru').credential);

      final result = await repository.signInWithEmail(credentials);

      expect(result, isA<Ok<AuthSession>>());
      final session = (result as Ok<AuthSession>).value;
      expect(session.userId, 'firebase-uid-1');
      expect(session.email, 'ebru@ornek.com');
      expect(session.displayName, 'Ebru');
    });

    test('e-posta baştaki boşluklardan arındırılarak gönderilir', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credentialWith().credential);

      await repository.signInWithEmail(
        const AuthCredentials(email: '  ebru@ornek.com ', password: 'gizli123'),
      );

      verify(
        () => auth.signInWithEmailAndPassword(
          email: 'ebru@ornek.com',
          password: 'gizli123',
        ),
      ).called(1);
    });

    test('yanlış şifre kimlik reddi olur', () async {
      signInThrows(fb.FirebaseAuthException(code: 'wrong-password'));

      final failure = await signInFailure();

      expect(failure, isA<AuthFailure>());
      expect(
        (failure as AuthFailure).reason,
        AuthFailureReason.invalidCredentials,
      );
    });

    test('birleşik invalid-credential kodu da kimlik reddi olur', () async {
      // Yeni Firebase "kullanıcı yok" ile "şifre yanlış"ı ayırmıyor;
      // ayırmak saldırgana hangi e-postaların kayıtlı olduğunu söylerdi.
      signInThrows(fb.FirebaseAuthException(code: 'invalid-credential'));

      expect(await signInFailure(), isA<AuthFailure>());
    });

    test('çok fazla deneme AYRI bir sebeple işaretlenir', () async {
      // Bu testin varlık sebebi: kullanıcıya "şifren yanlış" dersek
      // şifresini değiştirmeye çalışır ve kilidi uzatır.
      signInThrows(fb.FirebaseAuthException(code: 'too-many-requests'));

      final failure = await signInFailure();

      expect(
        (failure as AuthFailure).reason,
        AuthFailureReason.tooManyAttempts,
      );
    });

    test('kapatılmış hesap ayrı sebeple işaretlenir', () async {
      signInThrows(fb.FirebaseAuthException(code: 'user-disabled'));

      final failure = await signInFailure();

      expect(
        (failure as AuthFailure).reason,
        AuthFailureReason.accountDisabled,
      );
    });

    test('e-posta/şifre yöntemi kapalıysa sağlayıcı hatası döner', () async {
      signInThrows(fb.FirebaseAuthException(code: 'operation-not-allowed'));

      final failure = await signInFailure();

      expect(
        (failure as AuthFailure).reason,
        AuthFailureReason.providerUnavailable,
      );
    });

    test('ağ hatası çevrimdışı olarak işaretlenir', () async {
      signInThrows(fb.FirebaseAuthException(code: 'network-request-failed'));

      final failure = await signInFailure();

      expect(failure, isA<NetworkFailure>());
      expect((failure as NetworkFailure).isOffline, isTrue);
    });

    test('tanınmayan kod kimlik reddine ÇEVRİLMEZ', () async {
      // Bilinmeyen bir arızayı "şifren yanlış" diye göstermek, sunucu
      // sorununu kullanıcının hatası gibi gösterir ve gerçek arızayı gizler.
      signInThrows(fb.FirebaseAuthException(code: 'bilinmeyen-bir-kod'));

      expect(await signInFailure(), isA<UnexpectedFailure>());
    });

    test('Firebase hiç başlatılmamışsa geliştiriciye söyler', () async {
      signInThrows(fb.FirebaseException(plugin: 'core', code: 'no-app'));

      final failure = await signInFailure();

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.message, contains('Firebase is not initialized'));
    });

    test('Firebase kullanıcısız başarı döndürürse hata sayılır', () async {
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(null);
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);

      expect(await signInFailure(), isA<AuthFailure>());
    });
  });

  group('kayıt', () {
    const draft = SignUpDraft(
      fullName: '  Ebru Demir ',
      email: 'ebru@ornek.com',
      password: 'gizli123',
      confirmPassword: 'gizli123',
    );

    test('hesap açılır ve ad yazılır', () async {
      final fake = credentialWith();
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => fake.credential);

      final result = await repository.signUpWithEmail(draft);

      expect(result, isA<Ok<AuthSession>>());
      expect((result as Ok<AuthSession>).value.displayName, 'Ebru Demir');
      // Formdaki baştaki/sondaki boşluklar temizlenmiş olmalı.
      verify(() => fake.user.updateDisplayName('Ebru Demir')).called(1);
    });

    test('ad yazılamazsa kayıt YİNE DE başarılı sayılır', () async {
      // Hesap Firebase'de açıldı. "Kayıt olamadın" dersek kullanıcı tekrar
      // dener ve bu sefer "bu e-posta kullanımda" hatası alır — çıkışsız
      // bir döngüye sokmuş oluruz.
      final fake = credentialWith();
      when(
        () => fake.user.updateDisplayName(any()),
      ).thenThrow(fb.FirebaseAuthException(code: 'network-request-failed'));
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => fake.credential);

      final result = await repository.signUpWithEmail(draft);

      expect(result, isA<Ok<AuthSession>>());
    });

    test('kullanımdaki e-posta FORM hatası olur, kimlik reddi değil', () async {
      // Kullanıcının düzeltebileceği bir alan var; hata o alanın altında
      // gösterilmeli (TRD §1.2).
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(fb.FirebaseAuthException(code: 'email-already-in-use'));

      final result = await repository.signUpWithEmail(draft);
      final failure = (result as Err<AuthSession>).failure;

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure as ValidationFailure).code,
        ValidationCode.emailAlreadyInUse,
      );
      expect(failure.code.field, AuthFormField.email);
    });

    test('zayıf şifre sınırı domain kuralıyla AYNI sayıyı taşır', () async {
      // Bu test iki sabitin ayrışmasını yakalar: Firebase'in reddettiği
      // şifre için kullanıcıya gösterilen sayı, uygulamanın kendi kuralıyla
      // aynı olmalı. Ayrışırsa kullanıcı "en az 6" der, 6 girer, yine reddedilir.
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(fb.FirebaseAuthException(code: 'weak-password'));

      final result = await repository.signUpWithEmail(draft);
      final failure = (result as Err<AuthSession>).failure as ValidationFailure;

      expect(failure.code, ValidationCode.passwordTooShort);
      expect(failure.limit, SignInWithEmail.minPasswordLength);
    });
  });

  group('oturum ve çıkış', () {
    test('oturum yoksa bu bir hata değildir', () async {
      when(() => auth.currentUser).thenReturn(null);

      final result = await repository.currentSession();

      expect(result, isA<Ok<AuthSession?>>());
      expect((result as Ok<AuthSession?>).value, isNull);
    });

    test('açık oturum geri döner', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('firebase-uid-9');
      when(() => user.email).thenReturn('ebru@ornek.com');
      when(() => user.displayName).thenReturn('Ebru');
      when(() => auth.currentUser).thenReturn(user);

      final result = await repository.currentSession();

      expect((result as Ok<AuthSession?>).value?.userId, 'firebase-uid-9');
    });

    test('çıkış Firebase e devredilir', () async {
      when(auth.signOut).thenAnswer((_) async {});

      final result = await repository.signOut();

      expect(result, isA<Ok<Unit>>());
      verify(auth.signOut).called(1);
    });

    test('şifre sıfırlama e-postası gönderilir', () async {
      when(
        () => auth.sendPasswordResetEmail(email: any(named: 'email')),
      ).thenAnswer((_) async {});

      final result = await repository.sendPasswordReset('  ebru@ornek.com ');

      expect(result, isA<Ok<Unit>>());
      verify(
        () => auth.sendPasswordResetEmail(email: 'ebru@ornek.com'),
      ).called(1);
    });
  });

  group('sosyal giriş', () {
    test('bağlanmamış sağlayıcı DÜRÜST bir sebeple reddedilir', () async {
      // "Giriş başarısız" deseydik kullanıcı şifresini sorgulardı; oysa
      // sorun onun bilgilerinde değil, bizim henüz bağlamamış olmamızda.
      for (final provider in AuthProvider.values) {
        final result = await repository.signInWithProvider(provider);
        final failure = (result as Err<AuthSession>).failure;

        expect(failure, isA<AuthFailure>());
        expect(
          (failure as AuthFailure).reason,
          AuthFailureReason.providerUnavailable,
          reason: '$provider için sebep yanlış',
        );
      }
    });
  });
}
