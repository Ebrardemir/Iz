/// Ağ katmanının kimlik ihtiyacını karşılayan sözleşme.
///
/// NEDEN AYRI BİR ARAYÜZ?
/// `core/` hiçbir feature'ı bilmez (ARCHITECTURE.md §2). Ama her isteğe
/// `Authorization` başlığı eklemek `core/network/`in işi ve token
/// `features/auth/`ta üretiliyor. Doğrudan import etmek katman kuralını
/// kırardı; bu arayüz oku tersine çeviriyor:
///
///   core/network  →  AuthTokenProvider (sözleşme)
///                          ▲
///                          │ uygular
///                    features/auth/data (Firebase)
///
/// Somut örneği bağlayan yer `app/bootstrap.dart` — her şeyi bilmeye
/// yetkili tek katman.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class AuthTokenProvider {
  /// Geçerli ID token'ı döndürür; oturum yoksa `null`.
  ///
  /// [forceRefresh] yalnız sunucu 401 dediğinde kullanılır: elimizdeki
  /// token'ın süresi dolmuş olabilir ve SDK henüz yenilememiş olabilir.
  Future<String?> currentIdToken({bool forceRefresh = false});
}

/// Oturum yokmuş gibi davranan varsayılan.
///
/// Uygulama hesapsız da tam çalışıyor (ADR-B12), dolayısıyla "token yok"
/// geçerli bir durum ve hata değil. Kimlik isteyen bir uca token'sız
/// gidilirse sunucu 401 döner ve bu doğru davranıştır.
final class UnauthenticatedTokenProvider implements AuthTokenProvider {
  const UnauthenticatedTokenProvider();

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async => null;
}

/// `app/bootstrap.dart` içinde Firebase tabanlı gerçeğiyle override edilir.
///
/// Varsayılan PATLAMIYOR (bkz. [UnauthenticatedTokenProvider]): patlasaydı,
/// hesabı hiç kullanmayan birinin uygulaması ilk ağ isteğinde çökerdi.
final authTokenProviderProvider = Provider<AuthTokenProvider>((ref) {
  return const UnauthenticatedTokenProvider();
});
