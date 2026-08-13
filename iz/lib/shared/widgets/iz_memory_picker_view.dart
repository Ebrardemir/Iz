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
/// ⚠️ BURADA LİSTELENEN ANILAR "BAĞSIZ" OLMAK ZORUNDA.
/// BR — bir anı yalnızca BİR ritüele bağlanabilir. Bu yüzden liste "tüm
/// anılar" değil, "hiçbir ritüele bağlı olmayan anılar". Şimdilik önizleme
/// verisi bunu temsil ediyor; veri hattı kurulduğunda sorgunun
/// `WHERE ritual_id IS NULL` koşulunu taşıması gerekiyor — yoksa kullanıcı bir
/// anıyı iki ritüele bağlayıp sessizce ilk bağı koparır.
///
/// SEÇİM EKRANDA YAŞIYOR, çağıran formda değil.
/// Kullanıcı burada işaretleyip "Bitti"ye basıyor; ekran seçilen kimlikleri
/// `pop` ile döndürüyor. Vazgeçerse (✕ ya da geri) null dönüyor ve form hiçbir
/// şeyi değiştirmiyor — `showIzSelectionDialog` ile aynı sözleşme.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/shared/preview/form_preview_data.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';
import 'package:iz/shared/widgets/iz_form_row.dart';

class IzMemoryPickerView extends StatefulWidget {
  const IzMemoryPickerView({this.initialSelection = const {}, super.key});

  /// Formda ZATEN seçili olan anılar: ekran ikinci kez açıldığında kullanıcı
  /// seçimlerini işaretli bulmalı, sıfırdan başlamamalı.
  final Set<String> initialSelection;

  @override
  State<IzMemoryPickerView> createState() => _IzMemoryPickerViewState();
}

class _IzMemoryPickerViewState extends State<IzMemoryPickerView> {
  late final Set<String> _selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const memories = FormPreviewData.unlinkedMemories;

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

      body: memories.isEmpty
          ? AppEmptyState(icon: AppIcons.memory, title: l10n.memoryPickerEmpty)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              itemCount: memories.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final memory = memories[index];

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

  final FormMemoryOption memory;
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
      label: memory.title,
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
                ClipRRect(
                  borderRadius: const BorderRadius.all(AppRadius.sm),
                  child: Image.asset(
                    memory.imageAsset,
                    width: _kCoverSize,
                    height: _kCoverSize,
                    fit: BoxFit.cover,
                    // Kapak bulunamazsa liste çökmesin (NFR-021).
                    errorBuilder: (context, error, stack) => ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: const SizedBox.square(dimension: _kCoverSize),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md - 4),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        memory.title,
                        style: context.text.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        memory.dateLabel,
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
