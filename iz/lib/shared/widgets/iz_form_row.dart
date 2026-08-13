/// Form satırları — seri ve koleksiyon formları bunu paylaşıyor.
///
/// SATIR YAPISI (referans tasarım):
///   ┌──────────────────────────────────────┐
///   │  ⟳  │  Tekrarlama                 ⌄ │
///   │     │  Her yıl                      │
///   └──────────────────────────────────────┘
///     ikon│ etiket (küçük) + değer      chevron
///
/// İKONDAN SONRA DİKEY ÇİZGİ: referansın imzası bu. Çizgi ikonu satırın geri
/// kalanından ayırıp ona bir "sütun" veriyor; altı satır alt alta dizildiğinde
/// bütün ikonlar aynı hizada duruyor ve form bir tablo gibi okunuyor.
///
/// HER SATIR AYRI KART, tek bir bölünmüş kart DEĞİL.
/// Anı formunda tersini yaptık (`MemoryInfoCard` — tek kart, aralarında
/// çizgi). Buradaki fark: bu satırlar AÇILIYOR. Açılan bir satırın içeriği
/// kendi kartının içinde kalmalı, yoksa hangi satıra ait olduğu kayboluyor.
/// Aralarındaki 8 piksel de o sınırı gösteriyor.
///
/// AYNI ANDA TEK SATIR AÇIK (akordeon) — bunu satır değil EKRAN yönetiyor
/// (bkz. `RitualEditorView`, `CollectionEditorView`). Koleksiyon kartlarında da aynı kural var:
/// durumu listeye vermek, "kapat" işini tek bir yerde bırakıyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Satırların ortak kabuğu: zemin, köşe, kenarlık.
class IzFormCard extends StatelessWidget {
  const IzFormCard({required this.child, super.key});

  final Widget child;

  /// Referansta köşe ~14; kartın kendisi küçük olduğu için 16 (AppRadius.lg)
  /// fazla yuvarlak duruyordu.
  static const Radius kRadius = Radius.circular(14);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Sayfa zemininden bir ton AÇIK: kapak kutusu koyu, satırlar açık —
        // ikisi arasındaki karşıtlık formu iki bloğa ayırıyor.
        color: colors.surfaceContainerLowest,
        borderRadius: const BorderRadius.all(kRadius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ClipRRect(
        // Açılan içerik kartın köşesinden taşmasın.
        borderRadius: const BorderRadius.all(kRadius),
        child: child,
      ),
    );
  }
}

/// İkon + dikey çizgi + (etiket, içerik) + sağdaki widget.
///
/// Hem metin alanları hem açılır satırlar bunu kullanıyor: ikisinin de sol
/// tarafı aynı, sağı farklı.
class IzFormRow extends StatelessWidget {
  const IzFormRow({
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Etiketin altındaki satır: değer metni ya da bir metin alanı.
  final Widget child;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// İkon sütununun genişliği.
  ///
  /// Referansta çizgi soldan ~53 pikselde; 20'lik ikon ortalanınca 52 çıkıyor.
  static const double kIconColumnWidth = 52;

  /// Satırın en az yüksekliği — referansta 60.
  static const double kMinHeight = 60;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: kIconColumnWidth,
            child: Icon(
              icon,
              size: AppIconSize.md,
              // Etiketle aynı ağırlıkta: ikon dekor değil, satırın adı.
              color: colors.onSurface,
            ),
          ),

          // DİKEY ÇİZGİ: referansın imzası. Yüksekliği içerikle büyümüyor
          // (sabit), çünkü açılan satırlarda kartın altına kadar uzayan bir
          // çizgi listeyi ikiye bölüyordu.
          Container(
            width: 1,
            height: 32,
            color: colors.outlineVariant,
            margin: const EdgeInsets.only(right: AppSpacing.md - 2),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                child,
              ],
            ),
          ),

          if (trailing case final trailingWidget?) ...[
            const SizedBox(width: AppSpacing.sm),
            trailingWidget,
            const SizedBox(width: AppSpacing.md),
          ] else
            const SizedBox(width: AppSpacing.md),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinHeight),
      child: onTap == null
          ? row
          : InkWell(
              onTap: onTap,
              // TÜM SATIR tıklanabilir, yalnızca chevron değil: küçük bir oka
              // nişan almak zorunda kalan kullanıcı iki kez deniyor.
              child: row,
            ),
    );
  }
}

/// Satırın değer metni — seçim yoksa ipucu rengiyle.
class IzFormValue extends StatelessWidget {
  const IzFormValue({required this.value, required this.hint, super.key});

  /// Seçilen değer; boşsa [hint] görünüyor.
  final String? value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = value;
    final isEmpty = text == null || text.isEmpty;

    return Text(
      isEmpty ? hint : text,
      style: context.text.bodyMedium?.copyWith(
        // Dolu değer KOYU, ipucu soluk: kullanıcı hangi satırları
        // doldurduğunu tek bakışta görüyor.
        color: isEmpty ? colors.onSurfaceVariant : colors.onSurface,
        fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w500,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Aşağı doğru açılan satır: başlık satırı + altında içerik.
class IzExpandableRow extends StatelessWidget {
  const IzExpandableRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String hint;

  final bool isExpanded;
  final VoidCallback onToggle;

  /// Açıldığında görünen seçenekler.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IzFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IzFormRow(
            icon: icon,
            label: label,
            onTap: onToggle,
            // Chevron DÖNÜYOR, ikon değişmiyor: dönen bir ok "bu açılıyor"
            // der, değişen bir ikon "bu başka bir şey oldu" der.
            trailing: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: AppDuration.fast,
              child: Icon(
                AppIcons.expand,
                size: AppIconSize.md,
                color: colors.onSurfaceVariant,
              ),
            ),
            child: IzFormValue(value: value, hint: hint),
          ),

          // AÇILMA ANİMASYONU `AnimatedSize` ile: seçenekler ekranda AŞAĞI
          // doğru büyüyor. Alt sayfa (bottom sheet) açmak da bir seçenekti;
          // kullanıcı "aşağı doğru açılsın" dedi ve haklı — formdan
          // ayrılmadan seçim yapmak bağlamı korur.
          AnimatedSize(
            duration: AppDuration.normal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seçenekleri başlıktan ayıran çizgi, ikon sütununun
                      // hizasından başlıyor.
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: IzFormRow.kIconColumnWidth,
                        color: colors.outlineVariant,
                      ),
                      ...children,
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Açılan listedeki tek seçenek: (ikon) + etiket + işaret.
///
/// TEK ve ÇOK seçim AYNI SATIR: fark yalnızca sağdaki işarette — tek seçimde
/// dolu bir onay dairesi, çok seçimde işaretli bir kare. Kullanıcı hangi
/// kipte olduğunu o işaretten anlıyor (Material'ın radio/checkbox dili).
class IzOptionTile extends StatelessWidget {
  const IzOptionTile({
    required this.label,
    required this.isSelected,
    required this.allowMultiple,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool isSelected;
  final bool allowMultiple;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(
            // Seçenekler ikon sütununun sağından başlıyor: başlıkla aynı
            // hizada durunca hangisinin başlık olduğu anlaşılmıyordu.
            left: IzFormRow.kIconColumnWidth,
            right: AppSpacing.md,
            top: AppSpacing.sm + 2,
            bottom: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              if (icon case final optionIcon?) ...[
                Icon(
                  optionIcon,
                  size: AppIconSize.sm,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],

              Expanded(
                child: Text(
                  label,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    // Seçili olan KALIN: renk tek başına yeterli bir sinyal
                    // değil (NFR-031 — renk körlüğü).
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              _Mark(isSelected: isSelected, allowMultiple: allowMultiple),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seçim işareti.
class _Mark extends StatelessWidget {
  const _Mark({required this.isSelected, required this.allowMultiple});

  final bool isSelected;
  final bool allowMultiple;

  static const double _kSize = 22;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!isSelected) {
      // BOŞ ÇERÇEVE: seçilmemiş seçeneğin de bir yeri olmalı, yoksa
      // işaretlendiğinde satırın içeriği yana kayıyor.
      return SizedBox.square(
        dimension: _kSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: allowMultiple ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: allowMultiple
                ? const BorderRadius.all(AppRadius.xs)
                : null,
            border: Border.all(color: colors.outline),
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: _kSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary,
          shape: allowMultiple ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: allowMultiple
              ? const BorderRadius.all(AppRadius.xs)
              : null,
        ),
        child: Icon(AppIcons.check, size: 14, color: colors.onPrimary),
      ),
    );
  }
}

/// Satırın içindeki metin alanı — seri ve koleksiyon formları kullanıyor.
///
/// `IzFieldInput` DEĞİL: o bileşen kendi zeminini ve köşesini çiziyor (kişi
/// formundaki kutular). Burada kutu SATIRIN kendisi; alanın yalnızca imleci ve
/// ipucu metni olmalı, ikinci bir çerçeve satırın içinde kutu içinde kutu
/// görüntüsü veriyordu.
class IzInlineField extends StatelessWidget {
  const IzInlineField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: 1,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: context.text.bodyMedium?.copyWith(color: colors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: context.text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        // Temanın dolgusunu, çerçevesini ve sayaç metnini kapatıyoruz: satırın
        // içinde yalnızca yazı kalsın.
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        counterText: '',
        // Temanın `constraints: minHeight 48`i satırın kendi yüksekliğiyle
        // üst üste binip 64 piksellik satırlar üretiyordu (anı formunda tam
        // bunu yaşadık).
        constraints: const BoxConstraints(),
      ),
    );
  }
}
