/// "Son Yazılarım" listesindeki tek satır: solda tarih bloğu, sonra görsel,
/// ortada başlık + iki satır önizleme + saat, sağda yıldız düğmesi.
///
/// TARİH SOLDA BİR BLOK, satır içinde bir metin değil.
/// Günlük TARİHLE okunuyor: "26 Temmuz'da ne yazmışım?" Blok, gözün listeyi
/// tarihe göre taramasını sağlıyor; aynı bilgi satırın içinde küçük bir yazı
/// olsaydı başlıkla yarışırdı.
///
/// GÖRSEL HER SATIRDA VAR — kullanıcı fotoğraf eklemediyse VARSAYILAN bir
/// görsel çiziliyor ([kFallbackAsset]). Boş bir kutu bırakmak listeyi tırtıklı
/// gösteriyordu; sabit bir görsel ise satırların ritmini koruyor.
///
/// YILDIZ, YER İMİ DEĞİL: referansta bir yer imi vardı ama kullanıcı
/// "yıldızla" dedi. Lucide bir çizgi seti olduğu için dolu yıldız yok;
/// işaretli hâli DOLU ZEMİN + renk + ekran okuyucu etiketiyle veriliyor
/// (anı kartındaki kalple aynı desen, NFR-031).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

/// Satırın gösterdiği kayıt.
///
/// Ekranın kendi kaydı, `JournalEntry` DEĞİL: satırın fotoğrafa (entity'de
/// yalnızca kimlik var) ve yıldız durumuna ihtiyacı var, `promptId` ya da
/// gizlilik moduna yok.
typedef JournalRowData = ({
  String id,
  DateTime date,

  /// Yazıldığı an — "21:30". null ise saat satırı çizilmiyor.
  DateTime? createdAt,

  /// Boşsa satır yalnızca önizleme metnini gösteriyor.
  String? title,
  String preview,
  MediaItem? photo,
  bool isFavorite,
});

class JournalEntryRow extends StatelessWidget {
  const JournalEntryRow({
    required this.entry,
    required this.onTap,
    required this.onToggleFavorite,
    this.showTimestamp = true,
    super.key,
  });

  final JournalRowData entry;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  /// Soldaki tarih bloğu ve saat satırı çizilsin mi?
  ///
  /// ANA SAYFADA AÇIK: liste karışık günlerden geliyor ve her satır kendi
  /// tarihini taşımalı.
  ///
  /// "TÜM GÜNLÜKLER" EKRANINDA KAPALI: orada kayıtlar güne göre gruplanıyor
  /// ve tarih başlıkta yazıyor. Aynı bilgiyi her satırda tekrar etmek kutuyu
  /// daraltıyordu — kullanıcı "yandaki saat kısmı olmasın, kutu satırı
  /// kaplasın" dedi.
  final bool showTimestamp;

  /// Fotoğrafı olmayan kayıtların görseli.
  ///
  /// ⚠️ GEÇİCİ: kendi varsayılan görselin gelince YALNIZCA bu sabiti değiştir.
  static const String kFallbackAsset = 'assets/images/auth/hero_light.jpg';

  /// Referanstaki ölçüler.
  static const double kThumbWidth = 64;
  static const double kThumbHeight = 64;
  static const double kDateBlockWidth = 52;

  static const Radius kRadius = Radius.circular(14);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: entry.title ?? entry.preview,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: const BorderRadius.all(kRadius),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(kRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showTimestamp) ...[
                  ExcludeSemantics(child: _DateBlock(date: entry.date)),
                  const SizedBox(width: AppSpacing.sm),
                ],

                ClipRRect(
                  borderRadius: const BorderRadius.all(AppRadius.sm),
                  child: SizedBox(
                    width: kThumbWidth,
                    height: kThumbHeight,
                    child: entry.photo == null
                        ? Image.asset(
                            kFallbackAsset,
                            fit: BoxFit.cover,
                            // Varsayılan görsel de bulunamazsa satır
                            // çökmesin (NFR-021).
                            errorBuilder: (context, error, stack) => ColoredBox(
                              color: colors.surfaceContainerHighest,
                            ),
                          )
                        : MediaThumbnail(
                            media: entry.photo!,
                            width: kThumbWidth,
                            height: kThumbHeight,
                            borderRadius: Radius.zero,
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.title case final title?) ...[
                        Text(
                          title,
                          style: context.text.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],

                      Text(
                        entry.preview,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                        // EN FAZLA İKİ SATIR (kullanıcının isteği): günlük
                        // uzun yazılabiliyor ve liste bir okuma ekranı değil,
                        // bir hatırlatma ekranı.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (showTimestamp)
                        if (entry.createdAt case final createdAt?) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            // Saat DİLE duyarlı biçimleniyor: 24 saat mi 12
                            // saat mi olduğuna dil karar veriyor.
                            DateFormat.Hm(
                              context.l10n.localeName,
                            ).format(createdAt),
                            style: context.text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                    ],
                  ),
                ),

                _FavoriteButton(
                  isFavorite: entry.isFavorite,
                  onPressed: onToggleFavorite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soldaki tarih bloğu: gün / ay / yıl alt alta.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final locale = context.l10n.localeName;

    return SizedBox(
      width: JournalEntryRow.kDateBlockWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // GÜN en büyük ve koyu: blokta gözün ilk gittiği yer.
            DateFormat.d(locale).format(date),
            style: context.text.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            DateFormat.MMMM(locale).format(date),
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            DateFormat.y(locale).format(date),
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sağdaki yıldız.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return IconButton(
      onPressed: onPressed,
      icon: const Icon(AppIcons.star),
      iconSize: AppIconSize.md,
      // ÜÇ SİNYAL: zemin (şekil), renk ve etiket. Yalnızca renkle vermek
      // renk körü kullanıcıda hiçbir şey söylemiyor (NFR-031).
      color: isFavorite ? colors.onSecondaryContainer : colors.onSurfaceVariant,
      style: isFavorite
          ? IconButton.styleFrom(backgroundColor: colors.secondaryContainer)
          : null,
      tooltip: isFavorite
          ? l10n.journalFavoriteRemove
          : l10n.journalFavoriteAdd,
    );
  }
}
