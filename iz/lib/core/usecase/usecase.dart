/// UseCase (kullanım senaryosu) temel sözleşmeleri.
///
/// NE ZAMAN UseCase YAZILIR?
/// Her repository çağrısı için DEĞİL. UseCase yaz eğer:
///   1. İş kuralı varsa            → FR-012 "boş anı kaydedilemez"
///   2. Birden fazla repository'yi birleştiriyorsan → FR-034 günlükten anıya
///   3. Entitlement kapısı varsa   → FR-048 video sadece İZ+
///   4. Aynı mantık iki ViewModel'de tekrar ediyorsa
///
/// Aksi hâlde ViewModel doğrudan repository'yi çağırsın. Gereksiz UseCase
/// katmanı sadece dosya sayısını artırır.
///
/// `call` operatörü sayesinde kullanım doğal görünür:
/// ```dart
/// final result = await createMemory(params);
/// ```
library;

import 'package:iz/core/result/result.dart';

/// Parametre alan asenkron senaryo.
abstract base class UseCase<Out, In> {
  const UseCase();
  Future<Result<Out>> call(In params);
}

/// Parametresiz asenkron senaryo.
abstract base class NoParamsUseCase<Out> {
  const NoParamsUseCase();
  Future<Result<Out>> call();
}

/// Sürekli akış döndüren senaryo (Drift `watch` sorguları için).
///
/// DİKKAT: Stream içinde Result taşıyoruz ki hata akışı kesmesin —
/// `Stream<Result<T>>`, `Stream<T>`nin error kanalından daha güvenlidir,
/// çünkü hata sonrası stream kapanmaz.
abstract base class StreamUseCase<Out, In> {
  const StreamUseCase();
  Stream<Result<Out>> call(In params);
}

/// Parametre gerektirmeyen senaryolar için işaretleyici.
final class NoParams {
  const NoParams();
}
