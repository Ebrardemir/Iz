/// Anı feature'ının **DI bağlantıları** — UseCase provider'ları.
///
/// NEDEN `domain/usecases/` İÇİNDE DEĞİL?
/// ARCHITECTURE.md bölüm 4: *"`domain/` klasöründe
/// `import 'package:flutter/...'` GÖRÜRSEN bir şey yanlıştır."*
/// Bir provider tanımlamak için `flutter_riverpod`ı, onu kurmak için de
/// somut repository'nin (yani `data/` katmanının) provider'ını import etmek
/// gerekiyor. İkisi de domain'in bilmemesi gereken şeyler.
///
/// UseCase sınıfı domain'de saf Dart olarak kalıyor; onu bağımlılıklarıyla
/// KURAN kod ise burada. Böylece `SaveMemory` testinde Riverpod'a hiç
/// ihtiyaç duymuyoruz (bkz. test/unit/save_memory_test.dart) — sınıfı
/// doğrudan `new`liyoruz.
///
/// `presentation/` bu bilgiyi taşımaya yetkili: repository provider'larını
/// zaten ViewModel'ler de okuyor (bkz. ARCHITECTURE.md "Yeni feature ekleme
/// reçetesi", Adım 5–6).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/entitlement/entitlement.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/usecases/save_memory.dart';

final saveMemoryProvider = Provider<SaveMemory>((ref) {
  return SaveMemory(
    repository: ref.watch(memoryRepositoryProvider),
    entitlements: ref.watch(entitlementsProvider),
    clock: ref.watch(clockProvider),
  );
});
