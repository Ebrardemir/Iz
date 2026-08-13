/// Kimlik üretimi.
///
/// Rapor 12: "Kimlikler mümkünse cihazlar arası benzersiz UUID/ULID olmalıdır."
///
/// NEDEN auto-increment int DEĞİL?
/// V1.5'te bulut senkronizasyonu geldiğinde iki cihaz aynı anda kayıt
/// oluşturursa int id'ler çakışır. UUID v7 ile çakışma riski yok ve
/// **zaman sıralı** olduğu için veritabanı indeksi de verimli kalır
/// (rastgele UUID v4 index'i parçalar).
///
/// Arayüz üzerinden veriyoruz ki testlerde sabit id üretebilelim.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

abstract interface class IdGenerator {
  String newId();
}

final class UuidV7Generator implements IdGenerator {
  const UuidV7Generator(this._uuid);
  final Uuid _uuid;

  @override
  String newId() => _uuid.v7();
}

/// Testler için: 'test-id-1', 'test-id-2', ...
final class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'test-id-'});
  final String prefix;
  int _counter = 0;

  @override
  String newId() => '$prefix${++_counter}';
}

final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const UuidV7Generator(Uuid()),
);
