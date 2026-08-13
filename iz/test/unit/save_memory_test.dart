/// UseCase testi — İŞ KURALLARI burada doğrulanır.
///
/// Rapor 18.1: "Unit test: domain kuralları, premium limit, tarih/ritüel
/// hesapları, mapping ve validatorlar."
///
/// Dikkat: bu testin hiçbir yerinde Flutter, widget veya veritabanı yok.
/// Saf Dart — milisaniyeler içinde koşar.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/entitlement/entitlement.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/repositories/memory_repository.dart';
import 'package:iz/features/memories/domain/usecases/save_memory.dart';
import 'package:mocktail/mocktail.dart';

class _MockMemoryRepository extends Mock implements MemoryRepository {}

/// Testin "bugünü" — SABİT.
///
/// FR-013'ün gelecek tarih kuralı bugüne bağlı. `DateTime.now()` kullansaydık
/// test çalıştırıldığı güne göre sonuç değiştirirdi; sabit saatle kural her
/// gün aynı şeyi kanıtlıyor (bkz. core/utils/clock.dart).
final _now = DateTime(2026, 8, 12, 14, 30);

void main() {
  late _MockMemoryRepository repository;

  setUpAll(() {
    // mocktail, `any()` kullanabilmek için varsayılan değer bilmeli.
    registerFallbackValue(MemoryDraft(occurredAt: DateTime(2026)));
  });

  setUp(() {
    repository = _MockMemoryRepository();
    when(
      () => repository.saveDraft(any()),
    ).thenAnswer((_) async => const Ok('mem-1'));
  });

  SaveMemory buildUseCase({IzPlan plan = IzPlan.free}) => SaveMemory(
    repository: repository,
    entitlements: Entitlements(
      plan: plan,
      matrix: EntitlementMatrix.defaults(),
    ),
    clock: FixedClock(_now),
  );

  group('FR-012 — boş anı kaydedilemez', () {
    test('ne metin ne medya varsa ValidationFailure döner', () async {
      final result = await buildUseCase()(
        MemoryDraft(occurredAt: DateTime(2026, 3, 12)),
      );

      expect(result.isErr, isTrue);
      // Hata METNİ değil KODU kontrol ediliyor: domain dil bilmez, bu yüzden
      // testi de bir cümleye bağlamıyoruz. Çeviri l10n_test.dart'ta doğrulanır.
      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having(
          (f) => f.code,
          'code',
          ValidationCode.emptyMemory,
        ),
      );
      // Repository'ye HİÇ gidilmemeli.
      verifyNever(() => repository.saveDraft(any()));
    });

    test('sadece boşluk içeren başlık geçerli sayılmaz', () async {
      final result = await buildUseCase()(
        MemoryDraft(occurredAt: DateTime(2026, 3, 12), title: '   '),
      );

      expect(result.isErr, isTrue);
    });

    test('sadece not varsa kaydedilir', () async {
      final result = await buildUseCase()(
        MemoryDraft(
          occurredAt: DateTime(2026, 3, 12),
          note: 'Bugün ilk adımını attı',
        ),
      );

      expect(result.isOk, isTrue);
      verify(() => repository.saveDraft(any())).called(1);
    });

    test('sadece medya varsa kaydedilir', () async {
      final result = await buildUseCase()(
        MemoryDraft(occurredAt: DateTime(2026, 3, 12), mediaIds: const ['m1']),
      );

      expect(result.isOk, isTrue);
    });
  });

  group('FR-041 — ücretsiz planda fotoğraf limiti', () {
    test('Free planda 3 fotoğraf geçer', () async {
      final result = await buildUseCase()(
        MemoryDraft(
          occurredAt: DateTime(2026, 3, 12),
          mediaIds: const ['m1', 'm2', 'm3'],
        ),
      );

      expect(result.isOk, isTrue);
    });

    test('Free planda 4 fotoğraf reddedilir', () async {
      final result = await buildUseCase()(
        MemoryDraft(
          occurredAt: DateTime(2026, 3, 12),
          mediaIds: const ['m1', 'm2', 'm3', 'm4'],
        ),
      );

      expect(result.isErr, isTrue);
      // Limit de taşınmalı — çeviride "{limit} fotoğraf" yerine geçecek.
      expect(
        result.failureOrNull,
        isA<ValidationFailure>()
            .having((f) => f.code, 'code', ValidationCode.photoLimitExceeded)
            .having((f) => f.limit, 'limit', 3),
      );
    });

    test('İZ+ planında 4 fotoğraf geçer', () async {
      final result = await buildUseCase(plan: IzPlan.plus)(
        MemoryDraft(
          occurredAt: DateTime(2026, 3, 12),
          mediaIds: const ['m1', 'm2', 'm3', 'm4'],
        ),
      );

      expect(result.isOk, isTrue);
    });
  });

  group('FR-013 — tarih kuralları', () {
    test('geçmiş tarih kabul edilir', () async {
      final result = await buildUseCase()(
        MemoryDraft(occurredAt: DateTime(1998, 5, 2), note: 'Eski bir anı'),
      );

      expect(result.isOk, isTrue);
    });

    test('gelecek tarih reddedilir', () async {
      final result = await buildUseCase()(
        MemoryDraft(
          occurredAt: _now.add(const Duration(days: 30)),
          note: 'Henüz olmadı',
        ),
      );

      expect(result.isErr, isTrue);
      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having(
          (f) => f.code,
          'code',
          ValidationCode.futureDate,
        ),
      );
    });

    test('bugün kaydedilen anı reddedilmez', () async {
      // Sınırın tam üstünde: kullanıcının BUGÜN yaşadığı anı geçmelidir.
      // Saat dilimi farkı bir günü kaydırabildiği için
      // [SaveMemory.futureTolerance] kadar pay var; bu test o payın
      // sessizce kaldırılmasını engelliyor.
      final result = await buildUseCase()(
        MemoryDraft(occurredAt: _now, note: 'Bugün oldu'),
      );

      expect(result.isOk, isTrue);
    });
  });

  test('listede olmayan kapak görseli ilk medyaya düzeltilir', () async {
    await buildUseCase()(
      MemoryDraft(
        occurredAt: DateTime(2026, 3, 12),
        mediaIds: const ['m1', 'm2'],
        coverMediaId: 'silinmis-medya',
      ),
    );

    final captured =
        verify(() => repository.saveDraft(captureAny())).captured.single
            as MemoryDraft;

    expect(captured.coverMediaId, 'm1');
  });
}
