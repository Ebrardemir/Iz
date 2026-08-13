/// Başarı **veya** hata taşıyan dönüş tipi.
///
/// NEDEN VAR?
/// `Future<Memory>` bir hata durumunda exception fırlatır ve çağıran taraf
/// bunu `try/catch` ile yakalamayı *unutabilir* — derleyici zorlamaz.
/// `Future<Result<Memory>>` ise hatayı tip sistemine sokar: değeri almak için
/// hata dalını ele almak zorundasın.
///
/// KURAL: Repository ve UseCase katmanları `Result` döner, exception fırlatmaz.
/// Exception'lar yalnızca data source'ların içinde yaşar ve orada `Result`a
/// çevrilir (bkz. [guard]).
library;

import 'dart:async';

import 'package:iz/core/error/failure.dart';

sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Değeri varsa döner, yoksa null. Hızlı okuma için; kritik akışlarda
  /// [fold] veya `switch` kullanmayı tercih et.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Hata varsa [fallback] döner. Örn: `count.getOrElse(0)`
  T getOrElse(T fallback) => valueOrNull ?? fallback;

  /// İki dalı da ele almaya zorlar. UI'da en çok kullanacağın metot.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(Failure failure) onErr,
  }) => switch (this) {
    Ok<T>(:final value) => onOk(value),
    Err<T>(:final failure) => onErr(failure),
  };

  /// Başarı değerini dönüştürür, hatayı olduğu gibi taşır.
  /// Örn: `rowResult.map(MemoryMapper.toDomain)`
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Hata durumunda yan etki (loglama gibi) çalıştırır, zinciri bozmaz.
  Result<T> onFailure(void Function(Failure failure) action) {
    if (this case Err<T>(:final failure)) {
      action(failure);
    }
    return this;
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T> && other.failure == failure);

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}

/// Değer taşımayan işlemler için kısayol: `Future<Result<Unit>>`.
/// `void` generic olarak kullanılamadığı için bu tipi tanımlıyoruz.
final class Unit {
  const Unit._();
  static const Unit value = Unit._();

  @override
  String toString() => '()';
}

const Result<Unit> okUnit = Ok<Unit>(Unit.value);

/// Exception fırlatan bir bloğu güvenle `Result`a çevirir.
///
/// Data source'larda kullan:
/// ```dart
/// Future<Result<MemoryRow>> findById(String id) => guard(
///   () => _db.memoryDao.findById(id),
///   onError: (e, s) => DatabaseFailure(cause: e, stackTrace: s),
/// );
/// ```
Future<Result<T>> guard<T>(
  Future<T> Function() body, {
  required Failure Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    return Ok(await body());
  } on Object catch (e, s) {
    return Err(onError(e, s));
  }
}
