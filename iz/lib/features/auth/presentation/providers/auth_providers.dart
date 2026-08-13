/// Kimlik doğrulama feature'ının **DI bağlantıları** — UseCase provider'ları.
///
/// NEDEN `domain/usecases/` İÇİNDE DEĞİL?
/// Gerekçe anı tarafındakiyle aynı; bkz.
/// `features/memories/presentation/providers/memory_providers.dart`.
/// Kısaca: provider tanımlamak `flutter_riverpod`ı, onu kurmak da somut
/// repository'yi (`data/`) gerektiriyor. ARCHITECTURE.md domain'in ikisini de
/// bilmesini yasaklıyor, bu yüzden kurulum presentation katmanında.
///
/// `SignInWithEmail` / `SignUpWithEmail` sınıfları domain'de saf Dart olarak
/// duruyor ve testlerde doğrudan kurulabiliyor (bkz. test/unit/sign_in_test.dart).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/features/auth/data/repositories/stub_auth_repository.dart';
import 'package:iz/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:iz/features/auth/domain/usecases/sign_up_with_email.dart';

final signInWithEmailProvider = Provider<SignInWithEmail>((ref) {
  return SignInWithEmail(repository: ref.watch(authRepositoryProvider));
});

final signUpWithEmailProvider = Provider<SignUpWithEmail>((ref) {
  return SignUpWithEmail(repository: ref.watch(authRepositoryProvider));
});
