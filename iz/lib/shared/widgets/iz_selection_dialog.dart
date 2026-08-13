/// Ekranın ORTASINDA açılan seçim diyaloğu.
///
/// Anı formundaki dört satır (kişiler, kategori, koleksiyon, seri) bunu
/// kullanıyor. Dördü için tek bir bileşen var çünkü aralarındaki tek fark
/// SEÇİM KİPİ ve listenin içeriği — geri kalan her şey (yerleşim, işaretleme,
/// en alttaki ekleme satırı) aynı.
///
/// SEÇİM KİPİ DOMAINDEN GELİYOR, tasarımdan değil:
///   kategori → TEK   (FR-017: bir anı tek kategoriye bağlanır)
///   seri     → TEK   (FR-017: isteğe bağlı tek ritüel)
///   kişiler  → ÇOK   (FR-016: bir anı birden fazla kişiyle ilişkilendirilir)
///   koleksiyon → ÇOK (FR-074: bir anı birden fazla koleksiyona bağlanabilir)
/// `MemoryDraft` alanları da bunu söylüyor: `categoryId`/`ritualId` tek,
/// `personIds`/`collectionIds` liste.
///
/// NEDEN ALT SAYFA (bottom sheet) DEĞİL?
/// Listeler kısa (birkaç kişi, sekiz kategori) ve seçim yaptıktan sonra
/// forma dönülüyor. Alttan açılan bir sayfa ekranın yarısını kaplayıp formu
/// gözden kaçırıyordu; ortadaki diyalog seçimi "forma iliştirilmiş küçük bir
/// karar" gibi tutuyor.
///
/// SAF: hiçbir feature tipini bilmez — kimlik ve etiket alır
/// (bkz. ARCHITECTURE.md, `shared/` yalnızca `core/`u bilir).
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Seçilebilir tek bir öğe.
typedef IzSelectionOption = ({String id, String label, IconData? icon});

/// Diyaloğun sonucu.
///
/// `null` DÖNMEZ: kullanıcı vazgeçerse `showIzSelectionDialog` null döner ve
/// çağıran taraf hiçbir şey değiştirmez. Onaylarsa seçili kimlikler gelir.
typedef IzSelectionResult = Set<String>;

/// Seçim diyaloğunu açar.
///
/// [allowMultiple] false ise bir öğeye dokunmak diyaloğu ANINDA kapatıyor —
/// tek seçimde ayrıca "Tamam"a basmak gereksiz bir adım. Çok seçimde ise
/// kullanıcı birkaç kişiyi işaretleyip sonra onaylıyor.
///
/// [onAddNew] verilirse en altta bir "+ Yeni ekle" satırı çıkıyor. Ona
/// dokunmak diyaloğu kapatıp geri çağırmayı çalıştırıyor: yeni kayıt ekranı
/// diyaloğun ÜSTÜNE açılmamalı.
Future<IzSelectionResult?> showIzSelectionDialog(
  BuildContext context, {
  required String title,
  required List<IzSelectionOption> options,
  required Set<String> selectedIds,
  required bool allowMultiple,
  VoidCallback? onAddNew,
}) async {
  var addNewRequested = false;

  final result = await showDialog<IzSelectionResult>(
    context: context,
    builder: (dialogContext) => _IzSelectionDialog(
      title: title,
      options: options,
      selectedIds: selectedIds,
      allowMultiple: allowMultiple,
      onAddNew: onAddNew == null
          ? null
          : () {
              addNewRequested = true;
              Navigator.of(dialogContext).pop();
            },
    ),
  );

  // Ekleme isteği diyalog KAPANDIKTAN sonra çalışıyor; yeni kayıt ekranı
  // diyaloğun üstüne binmesin ve `Navigator` yığını temiz kalsın.
  if (addNewRequested) {
    onAddNew?.call();
    return null;
  }

  return result;
}

class _IzSelectionDialog extends StatefulWidget {
  const _IzSelectionDialog({
    required this.title,
    required this.options,
    required this.selectedIds,
    required this.allowMultiple,
    required this.onAddNew,
  });

  final String title;
  final List<IzSelectionOption> options;
  final Set<String> selectedIds;
  final bool allowMultiple;
  final VoidCallback? onAddNew;

  /// Liste uzarsa diyalog ekranı kaplamasın.
  static const double _kMaxListHeight = 320;

  @override
  State<_IzSelectionDialog> createState() => _IzSelectionDialogState();
}

class _IzSelectionDialogState extends State<_IzSelectionDialog> {
  late final Set<String> _selected = {...widget.selectedIds};

  void _toggle(String id) {
    if (!widget.allowMultiple) {
      // TEK SEÇİM: dokunmak hem seçer hem kapatır.
      Navigator.of(context).pop({id});
      return;
    }

    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return AlertDialog(
      // Başlık ve içerik arasındaki Material varsayılan boşlukları kısıyoruz:
      // liste kendi satır dolgusunu taşıyor, üstüne bir de diyalog dolgusu
      // gelince diyalog gereksiz uzuyordu.
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: EdgeInsets.zero,
      // BAŞLIK POPPINS, Cormorant DEĞİL.
      //
      // İlk hâli `headlineSmall`dı (Cormorant Garamond 20). Serif, markanın
      // DUYGUSAL sesi: "Bu anıdan geriye hangi kareler kalsın?" gibi sorular
      // için doğru. Ama bu diyalog bir soru sormuyor, bir LİSTE başlığı
      // taşıyor — tek kelime ("Kategori", "Seri"). Serif tek kelimede süslü
      // duruyor ve hemen altındaki Poppins listeyle aynı aileden görünmüyordu.
      //
      // `titleLarge` = Poppins 20 SemiBold: formun yazı ailesinin en büyüğü,
      // yani "Detayları Gir" sayfasındaki satırlarla aynı ses, bir tık daha
      // yüksek. Artık TEMADAN geliyor (`dialogTheme.titleTextStyle`) — aynı
      // karar onay diyaloglarında da geçerli olduğu için tek yere taşındı.
      title: Text(widget.title),
      content: SizedBox(
        // Genişlik SABİT: içeriğe göre daralan bir diyalog, kısa etiketli
        // listelerde (tek kelimelik kategoriler) dar ve garip duruyordu.
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.options.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  l10n.pickerEmpty,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              // `Flexible` + `shrinkWrap`: liste kısaysa diyalog kısalıyor,
              // uzunsa üst sınıra dayanıp içi kayıyor. Sabit yükseklik
              // verirsek üç kategorilik listede altta boşluk kalırdı.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: _IzSelectionDialog._kMaxListHeight,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.options.length,
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      return _OptionRow(
                        option: option,
                        isSelected: _selected.contains(option.id),
                        allowMultiple: widget.allowMultiple,
                        onTap: () => _toggle(option.id),
                      );
                    },
                  ),
                ),
              ),

            // EKLEME SATIRI LİSTENİN EN ALTINDA, düğmelerin arasında DEĞİL.
            //
            // Neden: "yeni ekle" bir onay değil, listenin devamı — aradığını
            // bulamayan kullanıcı listeyi sonuna kadar okur ve çıkışı orada
            // bulur. Düğme sırasına konsa "Vazgeç"le yan yana durup bir
            // kapatma eylemi gibi okunurdu.
            if (widget.onAddNew != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: colors.outlineVariant),
                ),
              ),
              _AddNewRow(onTap: widget.onAddNew!),
            ],
          ],
        ),
      ),

      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      actions: [
        // TEK SEÇİMDE ONAY DÜĞMESİ YOK: dokunmak zaten kapatıyor.
        // Yalnızca vazgeçme yolu duruyor.
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        if (widget.allowMultiple)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text(l10n.commonDone),
          ),
      ],
    );
  }
}

/// Listenin sonundaki "yeni ekle" satırı.
///
/// Öteki satırlarla AYNI ölçüde ama MARKA RENGİNDE: aynı listenin parçası,
/// yine de bir seçenek değil bir eylem.
class _AddNewRow extends StatelessWidget {
  const _AddNewRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(AppIcons.add, size: AppIconSize.md, color: colors.primary),
            const SizedBox(width: 12),
            Text(
              context.l10n.pickerAddNew,
              style: context.text.bodyLarge?.copyWith(color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listedeki tek satır.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.isSelected,
    required this.allowMultiple,
    required this.onTap,
  });

  final IzSelectionOption option;
  final bool isSelected;
  final bool allowMultiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // NFR-033: dokunma hedefi.
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: AppIconSize.md,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: context.text.bodyLarge?.copyWith(
                    // Seçili satır BİR TIK daha belirgin. NFR-031: renk tek
                    // başına bilgi taşımıyor, sağdaki işaret asıl kanal.
                    color: isSelected ? colors.primary : colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ÇOK SEÇİMDE ONAY KUTUSU, TEK SEÇİMDE TİK.
              //
              // Fark bilinçli: onay kutusu "birkaç tane işaretleyebilirsin"
              // der, tik "şu an bu seçili" der. Kipi kullanıcıya işaretin
              // biçimiyle anlatıyoruz.
              if (allowMultiple)
                Icon(
                  isSelected ? AppIcons.checkboxOn : AppIcons.checkboxOff,
                  size: AppIconSize.md,
                  color: isSelected ? colors.primary : colors.outline,
                )
              else if (isSelected)
                Icon(
                  AppIcons.check,
                  size: AppIconSize.md,
                  color: colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
