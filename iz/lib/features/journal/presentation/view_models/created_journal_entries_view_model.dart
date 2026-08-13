/// Bu oturumda yazılan günlük kayıtları.
///
/// ⚠️ GEÇİCİ DEPO — VERİTABANI DEĞİL. `JournalDao`/`JournalRepository`
/// yazılmadı (bkz. `journal_view.dart` başlığındaki reçete); "Kaydı Oluştur"a
/// basıldığında kayıt hiçbir yere yazılmıyor. Ama akışın sonunun GÖRÜNMESİ
/// gerekiyor: yazdığı şey Günlük sekmesinde belirmezse kullanıcı düğmenin
/// çalışmadığını düşünür.
///
/// Seri ve koleksiyon tarafındaki depolarla aynı gerekçe, aynı ömür: veri
/// hattı kurulduğunda üçü de silinecek.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';

/// Formun ürettiği kayıt.
///
/// [entry] gerçek domain nesnesi; [photos] ise onun DIŞINDA duruyor çünkü
/// entity yalnızca medya KİMLİKLERİ taşıyor (`mediaIds`) ve medya hattı
/// kurulmadığı için elimizde kimlik değil dosya yolu var.
typedef CreatedJournalEntry = ({JournalEntry entry, List<MediaItem> photos});

class CreatedJournalEntriesViewModel
    extends Notifier<List<CreatedJournalEntry>> {
  @override
  List<CreatedJournalEntry> build() => const [];

  /// Yeni kaydı listenin BAŞINA ekliyor: günlük tersten okunur, en yeni gün
  /// en üstte durur.
  void add(CreatedJournalEntry entry) => state = [entry, ...state];

  /// Yıldızı açıp kapatır.
  ///
  /// Listeyi yeniden kuruyoruz (`state = [...]`) çünkü kayıtlar değişmez
  /// (immutable) ve Riverpod yalnızca YENİ bir listeyi değişiklik sayıyor —
  /// eskisinin içini değiştirmek ekranı güncellemezdi.
  void toggleFavorite(String id) => state = [
    for (final item in state)
      if (item.entry.id == id)
        (
          entry: item.entry.copyWith(isFavorite: !item.entry.isFavorite),
          photos: item.photos,
        )
      else
        item,
  ];
}

final createdJournalEntriesProvider =
    NotifierProvider<CreatedJournalEntriesViewModel, List<CreatedJournalEntry>>(
      CreatedJournalEntriesViewModel.new,
    );
