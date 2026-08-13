/// `Result` ile Riverpod'un `AsyncValue`'su arasındaki köprü.
///
/// Repository katmanı `Stream<Result<T>>` döner (hata stream'i kapatmasın diye).
/// Riverpod'un `AsyncValue`'su ise hatayı kendi error kanalında bekler —
/// böylece View'da `.when(data:, loading:, error:)` yazabiliriz.
///
/// Bu uzantı çeviriyi tek satıra indirir.
library;

import 'package:iz/core/result/result.dart';

extension ResultStreamX<T> on Stream<Result<T>> {
  /// `Err`i exception'a çevirir → AsyncValue.error olarak yüzeye çıkar.
  ///
  /// Fırlatılan nesne bir [Failure]'dır; View tarafında
  /// `error is Failure ? error.localizedMessage(l10n) : ...` ile okunur.
  Stream<T> unwrap() => map(
    (result) => switch (result) {
      Ok<T>(:final value) => value,
      Err<T>(:final failure) => throw failure,
    },
  );
}

extension ResultFutureX<T> on Future<Result<T>> {
  Future<T> unwrap() async {
    final result = await this;
    return switch (result) {
      Ok<T>(:final value) => value,
      Err<T>(:final failure) => throw failure,
    };
  }
}
