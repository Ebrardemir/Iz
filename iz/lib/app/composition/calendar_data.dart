/// "Hayatım" takviminin gerçek verisi: ayın kapakları ve günün anıları.
///
/// NEDEN `features/my_life/` ALTINDA DEĞİL?
/// İki feature'ı birleştiriyor — anı ve kategori. Bir feature başka
/// feature'ın yalnız `domain/`ini görebilir (TR-C-03).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';

/// Bir AYIN anıları.
///
/// AY BAZINDA SORGULUYORUZ, tümünü çekip süzmüyoruz: takvim tek bir ay
/// gösteriyor ve kullanıcının 2.000 anısı olabilir (NFR-003). `family`
/// sayesinde her ay kendi aboneliğini tutuyor; kullanıcı ay değiştirince
/// yalnız yeni ay yükleniyor.
final monthMemoriesProvider = StreamProvider.family<List<Memory>, DateTime>((
  ref,
  month,
) {
  // Ayın ilk ve son ANI: `to` gün başlangıcı olsaydı ayın son gününe
  // yazılmış anılar listeye girmezdi.
  final from = DateTime(month.year, month.month);
  final to = DateTime(
    month.year,
    month.month + 1,
  ).subtract(const Duration(microseconds: 1));

  return ref
      .watch(memoryRepositoryProvider)
      .watchMemories(MemoryFilter(from: from, to: to))
      .unwrap();
});

/// Takvim hücrelerindeki küçük kapaklar: gün → o günün ilk anısının kapağı.
///
/// GÜNÜN İLK ANISI: bir güne birden çok anı düşebilir ama hücrede tek bir
/// kare var. En eskisini seçiyoruz — liste zaten en yeniden eskiye sıralı
/// olduğu için sondaki.
final monthCoversProvider = Provider.family<Map<DateTime, MediaItem>, DateTime>(
  (ref, month) {
    final memories = ref.watch(monthMemoriesProvider(month)).value ?? const [];

    final covers = <DateTime, MediaItem>{};
    for (final memory in memories) {
      final cover = memory.coverMedia;
      if (cover == null) continue;
      covers[_dayOf(memory.occurredAt)] = cover;
    }
    return covers;
  },
);

/// Seçili günün anıları.
///
/// AYIN LİSTESİNDEN SÜZÜYORUZ, yeni sorgu açmıyoruz: ay zaten bellekte ve
/// kullanıcı gün değiştirdikçe her seferinde veritabanına gitmek gereksiz.
final dayMemoriesProvider = Provider.family<List<Memory>, DateTime>((ref, day) {
  final month = ref.watch(monthMemoriesProvider(DateTime(day.year, day.month)));
  final target = _dayOf(day);

  return [
    for (final memory in month.value ?? const <Memory>[])
      if (_dayOf(memory.occurredAt) == target) memory,
  ];
});

/// Saat bilgisini atıp TAKVİM gününe indirger.
///
/// Karşılaştırmayı `DateTime` üzerinde doğrudan yapsaydık aynı güne ait iki
/// anı farklı saatlerde farklı anahtarlara düşerdi.
DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);
