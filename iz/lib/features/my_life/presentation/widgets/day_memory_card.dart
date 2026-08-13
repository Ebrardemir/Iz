/// Seçili günün anı listesindeki tek kart: solda geniş kapak, sağda başlık
/// ve "tarih • kategori" satırı.
///
/// SAF WIDGET: veri almaz, verilen [DayMemoryData]'yı çizer ve dokunmayı
/// yukarı bildirir. Böylece `ProviderScope` kurmadan test edilebiliyor.
///
/// ANA SAYFADAKİ [MemoryRowCard]'DAN NEDEN AYRI?
/// İkisi de "resim + başlık + tarih" ama tasarım kararları farklı:
///   • kapak burada 86 × 64 (yatay), orada 64 × 64 (kare)
///   • burada kartın KENDİSİ bir kutu (krem zemin, 16 köşe, alt çizgi),
///     orada kutu yok — çizgi yalnızca yazı bloğunun altında
///   • burada sağ ok yok; kart kendi kutusu olduğu için tıklanabilirliği
///     zaten belli
/// Ortak bir bileşene zorlasaydık ikisini de bozan bir sürü bayrak
/// (`showBox`, `thumbAspect`, `showChevron`…) çıkardı.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   kart    → 330 × 81, left 30 (sayfa marjı 20 + 10), dolgu 8, köşe 16
///             zemin Background-Card, ALT KENARLIK 1px Brand-Default
///   kapak   → 86 × 64, köşe 12, kırparak sığdır
///   yazı    → kapakla arası 12; başlık 20, boşluk 10, tarih 18 → 48
///   başlık  → Poppins Regular 14/20, Text-Primary
///   tarih   → Poppins Regular 10/18, Text-Primary
///
/// 81 NEREDEN GELİYOR? 8 + 64 + 8 = 80 içerik, üstüne 1px alt çizgi.
/// Yani tasarımdaki tek pikselin sebebi çizginin kendisi.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Kartta gösterilecek anı.
///
/// [dateLabel] ve [categoryLabel] hazır METİN olarak geliyor: tarih
/// biçimlemesi ve kategori adının çevirisi birer sunum kararıdır ve bu
/// widget'ın üstünde çözülür (bkz. `category_l10n.dart`).
typedef DayMemoryData = ({
  String id,
  String imageAsset,
  String title,
  String dateLabel,
  String categoryLabel,
});

class DayMemoryCard extends StatelessWidget {
  const DayMemoryCard({required this.memory, required this.onTap, super.key});

  final DayMemoryData memory;
  final VoidCallback onTap;

  /// Figma: 8 + 64 + 8 + 1px alt çizgi.
  static const double kHeight = 81;

  /// Figma: kapak 86 × 64.
  static const double kCoverWidth = 86;
  static const double kCoverHeight = 64;

  /// Figma: kart köşesi 16, kapak köşesi 12.
  static const Radius _kRadius = AppRadius.lg;
  static const Radius _kCoverRadius = AppRadius.md;

  /// Figma: kart dolgusu 8, kapak–yazı arası 12, başlık–tarih arası 10.
  static const double _kPadding = AppSpacing.sm;
  static const double _kCoverGap = 12;
  static const double _kTextGap = 10;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(_kRadius),
        child: SizedBox(
          height: kHeight,
          // `clipBehavior` ŞART.
          //
          // Alt çizgiyi `BoxDecoration.border`a veremiyoruz: Flutter,
          // `borderRadius` verilmiş bir dekorasyonda TEK KENARLI Border'a
          // izin vermiyor ("A borderRadius can only be given for a uniform
          // Border" assertion'ı ile düşüyor). Bu yüzden çizgi, içeriğin
          // altında ayrı bir satır. Kırpma olmadan o satır yuvarlatılmış
          // köşelerin dışına taşardı.
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              // Açık temada kart rengi sayfa zeminiyle AYNIDIR (ikisi de
              // #FAF8F3); kartı ayıran şey renk değil köşe ve alt çizgidir.
              // Koyu temada ikisi ayrışıyor (bkz. app_theme.dart).
              color: colors.surfaceContainerLow,
              borderRadius: const BorderRadius.all(_kRadius),
            ),
            child: Column(
              // `stretch` UNUTULMAMALI.
              //
              // Varsayılan `center` hizasında Column çocuklarına GEVŞEK yatay
              // kısıt verir. Alt çizgi de çocuksuz bir `ColoredBox` olduğu
              // için kendini 0 genişlikte ölçüyordu: çizgi hiç çizilmiyordu
              // ve açık temada kart rengi panelin rengiyle aynı olduğu için
              // ekranda fark edilmiyordu. (`day_memories_panel_test.dart`
              // içindeki "alt çizgi" testi tam bunu yakaladı.)
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(_kPadding),
                    child: Row(
                      children: [
                        _Cover(asset: memory.imageAsset),
                        const SizedBox(width: _kCoverGap),
                        Expanded(child: _Texts(memory: memory)),
                      ],
                    ),
                  ),
                ),
                // Figma: 1px alt kenarlık, Brand-Default.
                SizedBox(
                  height: 1,
                  child: ColoredBox(color: colors.outlineVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Texts extends StatelessWidget {
  const _Texts({required this.memory});

  final DayMemoryData memory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Yazı bloğu 48, kapak 64 → dikeyde ortalanıyor.
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          memory.title,
          // FIGMA: Poppins Regular 14/20 → `bodyMedium`.
          style: context.text.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: DayMemoryCard._kTextGap),

        // "15 Ağustos 2026 • Aile"
        //
        // AYIRICI ÇEVİRİDEN GELMİYOR — bilerek. "•" bir noktalama işareti,
        // arayüz metni değil; her dilde aynı. Çeviri dosyasına
        // "{date} • {category}" gibi bir kalıp koysaydık çevirmenin
        // bozabileceği bir şey eklemiş olurduk.
        Text(
          '${memory.dateLabel} • ${memory.categoryLabel}',
          // FIGMA: Poppins Regular 10/18 → `bodyTiny`.
          // Renk Text-Primary (Text-Secondary DEĞİL): tasarımda bu satır
          // soluk bir dipnot değil, kartın ikinci bilgi katmanı.
          style: context.textStyles.bodyTiny,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Anının kapak fotoğrafı.
///
/// ⚠️ Şimdilik asset. Veri bağlandığında burası `Memory.coverMedia`den
/// gelecek — değişecek tek yer bu widget (bkz. `MediaThumbnail`).
class _Cover extends StatelessWidget {
  const _Cover({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(DayMemoryCard._kCoverRadius),
      child: Image.asset(
        asset,
        width: DayMemoryCard.kCoverWidth,
        height: DayMemoryCard.kCoverHeight,
        // Figma: `scale: crop` — oranı bozmadan kutuyu doldur.
        fit: BoxFit.cover,
        // Kapak bulunamazsa kart çökmesin.
        errorBuilder: (context, error, stack) => ColoredBox(
          color: context.colors.surfaceContainerHigh,
          child: SizedBox(
            width: DayMemoryCard.kCoverWidth,
            height: DayMemoryCard.kCoverHeight,
            child: Icon(
              AppIcons.photo,
              size: AppIconSize.md,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
