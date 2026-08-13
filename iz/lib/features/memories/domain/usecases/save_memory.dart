/// Anı kaydetme senaryosu.
///
/// BU NEDEN BİR UseCase? (usecase.dart'taki kurallara göre)
///   ✔ İş kuralı var    → FR-012: boş anı kaydedilemez
///   ✔ Entitlement kapısı → FR-041: ücretsiz planda foto limiti
///   ✔ İki ViewModel kullanacak → editör ve "günlükten anıya" akışı (FR-034)
///
/// ViewModel doğrudan repository'yi çağırsaydı, bu kuralları iki yerde
/// tekrarlamak ve ikisini de test etmek zorunda kalırdık.
///
/// PROVIDER BURADA DEĞİL: bu dosya `domain/` altında ve ARCHITECTURE.md
/// domain'in Flutter'ı (dolayısıyla Riverpod'u) ve `data/` katmanını
/// bilmesini yasaklıyor. Kurulum
/// `presentation/providers/memory_providers.dart` içinde.
library;

// Dart'ta isimli parametreler alt çizgiyle başlayamaz — bkz. repository impl.
// ignore_for_file: prefer_initializing_formals

import 'package:iz/core/entitlement/entitlement.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/usecase/usecase.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';

final class SaveMemory extends UseCase<String, MemoryDraft> {
  const SaveMemory({
    required MemoryRepository repository,
    required Entitlements entitlements,
    required Clock clock,
  }) : _repository = repository,
       _entitlements = entitlements,
       _clock = clock;

  final MemoryRepository _repository;
  final Entitlements _entitlements;

  /// `DateTime.now()` yerine saat KAYNAĞI enjekte ediliyor. FR-013'ün
  /// "gelecek tarih" kuralı doğrudan bugüne bağlı; sabit bir saat olmadan
  /// bu kuralın testi çalıştırıldığı güne göre sonuç değiştirir
  /// (bkz. core/utils/clock.dart).
  final Clock _clock;

  /// Gelecek tarih toleransı.
  ///
  /// Tam olarak "şimdi"yi sınır yapmıyoruz: kullanıcının cihaz saati
  /// yanlış olabilir, saat dilimi farkı bir günü kaydırabilir ve bugün
  /// yaşanmış bir anı reddedilirse bu kullanıcıya bir HATA gibi görünür.
  /// Bir günlük pay, gerçek "gelecek tarih" girişlerini yine yakalıyor.
  static const Duration futureTolerance = Duration(days: 1);

  @override
  Future<Result<String>> call(MemoryDraft draft) async {
    // 1) FR-012 — "Bir Anı en az metin veya en az bir medya öğesi
    //    içerebilmelidir; tamamen boş kayıt kaydedilmemelidir."
    // DİKKAT: Buradan kullanıcı metni DÖNMÜYORUZ, sadece kod dönüyoruz.
    // Domain dili bilmez; çeviriyi core/l10n/failure_l10n.dart seçer.
    if (!draft.hasContent) {
      return const Err(ValidationFailure(code: ValidationCode.emptyMemory));
    }

    // 2) FR-041 — medya limiti. Limit uzaktan yapılandırılabilir olduğu için
    //    sabit 3 yazmıyoruz, entitlement matrisinden okuyoruz.
    if (_entitlements.exceeds(IzLimit.photosPerMemory, draft.mediaIds.length)) {
      return Err(
        ValidationFailure(
          code: ValidationCode.photoLimitExceeded,
          // Limit çeviriye {limit} olarak girer: "en fazla 3 fotoğraf…"
          limit: _entitlements.limit(IzLimit.photosPerMemory),
        ),
      );
    }

    // 3) Gelecek tarihli anı mantıksız — FR-013 geçmişe izin verir,
    //    geleceğe değil. (Zaman Kapsülü FR-170 ayrı bir özelliktir.)
    if (draft.occurredAt.isAfter(_clock.now().add(futureTolerance))) {
      return const Err(ValidationFailure(code: ValidationCode.futureDate));
    }

    // 4) Kapak görseli seçilmişse gerçekten listede olmalı (tutarlılık).
    final cover = draft.coverMediaId;
    final normalized = (cover != null && !draft.mediaIds.contains(cover))
        ? draft.copyWith(coverMediaId: draft.mediaIds.firstOrNull)
        : draft;

    return _repository.saveDraft(normalized);
  }
}
