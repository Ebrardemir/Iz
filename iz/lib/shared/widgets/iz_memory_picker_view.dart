/// Anı bağlama ekranı: anılar kutu kutu, sağ üstte "Bitti".
///
/// PAYLAŞILAN: seri formundaki "Bu Yıla Anı Ekle" ve koleksiyon formundaki
/// "İlk Anıları Ekle" aynı ekranı açıyor.
///
/// YERLEŞİM (kullanıcının anlatımı):
///   ┌──────────────────────────────┐
///   │ ✕      Anı Seç        Bitti  │
///   │ ┌──────────────────────────┐ │
///   │ │ [img] Kahve Molası    ✓  │ │  seçili → dolu yeşil daire
///   │ │       9 Ağustos 2026     │ │
///   │ └──────────────────────────┘ │
///   │ ┌──────────────────────────┐ │
///   │ │ [img] Sahilde Sabah   ○  │ │  seçilmemiş → boş çerçeve
///   │ └──────────────────────────┘ │
///   └──────────────────────────────┘
///
/// LİSTE GERÇEK ANILARDAN GELİYOR (`MemoryRepository`).
///
/// Önce önizleme verisi gösteriyordu ve kimlikleri (`preview-kahve` gibi)
/// veritabanında yoktu: koleksiyona böyle bir anı bağlamaya çalışmak yabancı
/// anahtar kısıtını düşürüyor ve kullanıcı "Verilerine şu anda
/// ulaşılamıyor" hatası alıyordu.
///
/// ⚠️ RİTÜEL İÇİN EKSİK KOŞUL VAR.
/// BR — bir anı yalnızca BİR ritüele bağlanabilir; ritüel formu bu ekranı
/// açtığında listenin "hiçbir ritüele bağlı olmayan anılar" olması gerekiyor.
/// `MemoryFilter` bugün "ritüeli boş olanlar" diye bir koşul ifade edemiyor;
/// ritüel veri hattı yazılırken o koşul eklenmeli, yoksa kullanıcı bir anıyı
/// iki ritüele bağlayıp sessizce ilk bağı koparar.
///
/// SEÇİM EKRANDA YAŞIYOR, çağıran formda değil.
/// Kullanıcı burada işaretleyip "Bitti"ye basıyor; ekran seçilen kimlikleri
/// `pop` ile döndürüyor. Vazgeçerse (✕ ya da geri) null dönüyor ve form hiçbir
/// şeyi değiştirmiyor — `showIzSelectionDialog` ile aynı sözleşme.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/result/result_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/domain/entities/memory_filter.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';
import 'package:iz/shared/widgets/async_value_view.dart';
import 'package:iz/shared/widgets/iz_form_row.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

/// Seçilebilir anılar.
///
/// `memoryListProvider` KULLANMIYORUZ bilerek: o, zaman tünelinin AKTİF
/// süzgecine bağlı. Kullanıcı zaman tünelinde "yalnız favoriler" seçtiyse
/// seçici de yarım liste gösterirdi ve sebebi anlaşılmazdı.
final pickableMemoriesProvider = StreamProvider<List<Memory>>((ref) {
  return ref
      .watch(memoryRepositoryProvider)
      .watchMemories(MemoryFilter.all)
      .unwrap();
});

class IzMemoryPickerView extends ConsumerStatefulWidget {
  const IzMemoryPickerView({this.initialSelection = const {}, super.key});

  /// Formda ZATEN seçili olan anılar: ekran ikinci kez açıldığında kullanıcı
  /// seçimlerini işaretli bulmalı, sıfırdan başlamamalı.
  final Set<String> initialSelection;

  @override
  ConsumerState<IzMemoryPickerView> createState() => _IzMemoryPickerViewState();
}

class _IzMemoryPickerViewState extends ConsumerState<IzMemoryPickerView> {
  late final Set<String> _selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final memories = ref.watch(pickableMemoriesProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.memoryPickerTitle),
        // ÇARPI: bu bir akışın adımı değil, formun üstüne açılan bir görev.
        leading: IconButton(
          icon: const Icon(AppIcons.clear),
          tooltip: l10n.commonClose,
          onPressed: () => context.pop(),
        ),
        actions: [
          // "BİTTİ" METİN DÜĞMESİ, tik ikonu değil: satırlardaki tikler
          // "bu anı seçili" diyor, buradaki eylem ise "seçimi bitir". Aynı
          // ikonu iki farklı anlamda kullanmak kafa karıştırıyordu.
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: () => context.pop(_selected),
              child: Text(l10n.memoryPickerDone),
            ),
          ),
        ],
      ),

      body: AsyncValueView<List<Memory>>(
        value: memories,
        // Hiç anı yoksa bu bir HATA DEĞİL: henüz anı biriktirmemiş kullanıcı
        // doğal bir durum. Koleksiyona bağlanacak bir şey yok, o kadar.
        emptyBuilder: () =>
            AppEmptyState(icon: AppIcons.memory, title: l10n.memoryPickerEmpty),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final memory = list[index];

            return _MemoryPickTile(
              memory: memory,
              isSelected: _selected.contains(memory.id),
              onTap: () => setState(() {
                // Dokunmak AÇIP KAPIYOR: ayrı bir "kaldır" yolu yok,
                // aynı satır iki işi de yapıyor.
                _selected.contains(memory.id)
                    ? _selected.remove(memory.id)
                    : _selected.add(memory.id);
              }),
            );
          },
        ),
      ),
    );
  }
}

/// Tek anı kutusu: solda görsel, ortada ad + tarih, sağda işaret.
class _MemoryPickTile extends StatelessWidget {
  const _MemoryPickTile({
    required this.memory,
    required this.isSelected,
    required this.onTap,
  });

  final Memory memory;
  final bool isSelected;
  final VoidCallback onTap;

  /// Kapak ölçüsü — kişi detayındaki koleksiyon satırıyla aynı ritim.
  static const double _kCoverSize = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: memory.displayTitle(context.l10n.memoryNew),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: const BorderRadius.all(IzFormCard.kRadius),
          // SEÇİLİ KUTUNUN KENARLIĞI MARKA RENGİNDE ve kalın: sağdaki küçük
          // tik tek başına yeterli bir sinyal değil, göz listeyi kaydırırken
          // seçili satırları bir bütün olarak görmeli.
          border: Border.all(
            color: isSelected ? colors.primary : colors.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(IzFormCard.kRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                // `MediaThumbnail` kapağı olmayanı ve dosyası kaybolanı
                // kendi içinde çiziyor (NFR-021) — burada ayrıca ele almıyoruz.
                MediaThumbnail(
                  media: memory.coverMedia,
                  size: _kCoverSize,
                  borderRadius: AppRadius.sm,
                ),
                const SizedBox(width: AppSpacing.md - 4),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        memory.displayTitle(context.l10n.memoryNew),
                        style: context.text.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppDateFormats.long(memory.occurredAt),
                        style: context.text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),
                _CheckMark(isSelected: isSelected),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sağdaki tik: seçiliyse dolu yeşil daire, değilse boş çerçeve.
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.isSelected});

  final bool isSelected;

  static const double _kSize = 26;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox.square(
      dimension: _kSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? colors.primary : colors.outline,
          ),
        ),
        // Tik SEÇİLMEDEN DE ÇİZİLİYOR ama görünmez (saydam): boş bir çerçeve
        // ile dolu daire arasında ölçü farkı olmasın, satır zıplamasın.
        child: Icon(
          AppIcons.check,
          size: AppIconSize.sm,
          color: isSelected ? colors.onPrimary : Colors.transparent,
        ),
      ),
    );
  }
}
