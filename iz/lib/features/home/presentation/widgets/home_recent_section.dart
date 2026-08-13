/// Ana sayfanın en alt bölümü: "SON ANILAR" başlığı ve altındaki içerik.
///
/// ŞU AN YALNIZCA BOŞ DURUM VAR. Kullanıcının hiç anısı yokken gösterilen
/// hâl bu; anı kartları bir sonraki adımda eklenecek. Boş durum geçici bir
/// yer tutucu DEĞİL — her yeni kullanıcı önce burayı görür ve uygulamanın
/// ilk izlenimini o belirler.
///
/// SAF WIDGET: veri almaz, dokunmayı yukarı bildirir.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   bölüm   → left 20, width 350 (sayfanın geri kalanıyla AYNI hizada)
///   başlık  → 350 × 38, padding 10, space-between
///   "SON ANILAR" → Poppins Regular 12/18, Text-Secondary
///   "Tümünü Gör" → Poppins Medium 12/18, Brand-Primary
///
/// İçerideki 30-32'lik hizayı sık karıştırdım: bölümün kendisi 20'de, ama
/// başlığın 10'luk dolgusu yazıyı 30'a, kartın 8'lik dolgusu küçük resmi
/// 28'e itiyor. Referans ölçümüyle birebir uyuyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/home/presentation/home_layout.dart';
import 'package:iz/features/home/presentation/widgets/memory_row_card.dart';

class HomeRecentSection extends StatelessWidget {
  const HomeRecentSection({
    required this.onSeeAll,
    required this.onOpenMemory,
    this.memories = const [],
    super.key,
  });

  /// Boş liste → boş durum çizilir.
  final List<MemoryRowData> memories;

  final VoidCallback onSeeAll;
  final ValueChanged<MemoryRowData> onOpenMemory;

  /// Figma: başlık satırı 38 yüksekliğinde, 10 dolgulu.
  static const double _kHeaderPadding = 10;

  @override
  Widget build(BuildContext context) {
    final isEmpty = memories.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HomeLayout.pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(_kHeaderPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.homeRecentTitle,
                  // FIGMA: Poppins Regular 12/18 → `bodySmall`.
                  // Bölüm başlığı bir ETİKET, içeriğin önüne geçmemeli.
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),

                // "Tümünü Gör" yalnızca gösterilecek bir şey varken anlamlı.
                if (!isEmpty)
                  _SeeAllButton(onPressed: onSeeAll)
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),

          if (isEmpty)
            const _RecentEmptyState()
          else
            for (var i = 0; i < memories.length; i++) ...[
              MemoryRowCard(
                memory: memories[i],
                onTap: () => onOpenMemory(memories[i]),
                // Son satırda çizgi yok: liste "yarım kalmış" görünmesin.
                showDivider: i < memories.length - 1,
              ),
              // Figma: kartlar arası 12.
              if (i < memories.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

/// "Tümünü Gör" — bölümün ikincil eylemi.
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      // Dokunma alanını yazının ötesine taşır; 12 puntoluk bir metin
      // parmakla zor yakalanır.
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        child: Text(
          context.l10n.commonSeeAll,
          // FIGMA: Poppins Medium 12/18, Brand-Primary → `titleSmall`.
          style: context.text.titleSmall?.copyWith(
            color: context.colors.primary,
          ),
        ),
      ),
    );
  }
}

/// "Burada henüz bir iz yok" — davetkâr boş durum.
///
/// TASARIM NİYETİ
///
/// Boş bir liste kolayca "eksik bir şey var" hissi verir. Buradaki amaç
/// tersi: sessiz ama umutlu bir bekleyiş. Üç karar bunu taşıyor.
///
/// 1. KUTU YOK. Üstte zaten kenarlıklı bir sayaç ızgarası var; ikinci bir
///    çerçeve sayfayı kalabalıklaştırıyor ve boş durumu "doldurulmamış form
///    alanı" gibi gösteriyordu. Açık, havadar bir blok ise bilinçli bir
///    sessizlik gibi okunuyor.
///
/// 2. BUTON YOK. Fotoğrafın üzerinde zaten "Anı Ekle" var; ikinci bir
///    çağrı ikisini de zayıflatıyordu. Bu blok teşvik ediyor, emretmiyor.
///
/// 3. İZLER YOLDA. Üç ayak izi soldan sağa BÜYÜYEREK ve netleşerek geliyor.
///    Söylediği şey "burası boş" değil, "izler buraya doğru geliyor" —
///    uygulamanın adı da, vaadi de bu.
class _RecentEmptyState extends StatelessWidget {
  const _RecentEmptyState();

  /// Metin okunur genişlikte kalsın; geniş ekranda satırlar uzamasın.
  static const double _kMaxContentWidth = 300;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ArrivingTrail(),
              const SizedBox(height: AppSpacing.lg),

              Text(
                l10n.homeRecentEmptyTitle,
                // Serif — markanın duygusal sesi.
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                l10n.homeRecentEmptyMessage,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soldan sağa büyüyerek gelen üç ayak izi.
///
/// Yön BİLİNÇLİ: solda küçük ve soluk, sağda büyük ve net. Tersi olsaydı
/// (uzaklaşan izler) veda gibi okunurdu; böyleyken "geliyor" diyor.
///
/// Üç iz de aynı çizgide değil — hafif yükseliyor ve hafif dönüyor, çünkü
/// gerçek bir yol düz değildir. Bu küçük düzensizlik şekli "ikon dizisi"
/// olmaktan çıkarıp yürüyüşe benzetiyor.
class _ArrivingTrail extends StatelessWidget {
  const _ArrivingTrail();

  /// (boyut, saydamlık, dikey kayma, eğim) — soldan sağa.
  static const List<(double, double, double, double)> _steps = [
    (20, 0.22, 10, -0.20),
    (28, 0.45, 4, -0.10),
    (38, 1.00, 0, 0),
  ];

  @override
  Widget build(BuildContext context) {
    final gold = context.colors.tertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (size, opacity, dy, tilt) in _steps) ...[
          Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: tilt,
              child: Icon(
                AppIcons.emptyTrace,
                size: size,
                color: gold.withValues(alpha: opacity),
              ),
            ),
          ),
          if (size != _steps.last.$1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}
