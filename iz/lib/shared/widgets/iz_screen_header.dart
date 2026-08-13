/// Bir ekranın üst şeridi: solda başlık, isteğe bağlı alt satır ve sağda ikon
/// eylemleri.
///
/// NEDEN `AppBar` DEĞİL?
/// Material'ın `AppBar`ı başlığı dikey ortalar, kendi yüksekliğini dayatır ve
/// alt satır için yer bırakmaz. Tasarımdaki şerit ise sayfanın kendi
/// içeriğinin ilk bloğu: sola yaslı, altında bir açıklama satırı olabilen,
/// yüksekliği içeriğinden gelen bir başlık.
///
/// NEDEN `shared/`?
/// "Hayatım" ve "Kişilerim" ekranları AYNI şeridi taşıyor. Ölçüleri (durum
/// çubuğu payı, kenar marjı, yazı ölçeği) iki yere elle yazmak, birini
/// değiştirdiğimizde ötekinin sessizce geride kalması demekti — kullanıcı da
/// tam bunu istedi: "aynı tasarım olsun".
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   şerit    → 350 × 52, top 24, left 20, padding 4, gap 12
///   eylemler → her ikon 28 × 28, aralarında 24
/// (Başlığın yazı tipi Figma'dan SAPIYOR — gerekçesi `build` içinde.)
///
/// ÖLÇÜLER BİRBİRİNİ DOĞRULUYOR:
///   250 + 12 (gap) + 80 = 342 = 350 − 2×4 (padding)
///   28 + 24 + 28 = 80
/// Bu yüzden sabit genişlik yazmıyoruz: başlık kalan yeri alıyor, eylemler
/// kendi boyunda duruyor. Her ekran genişliğinde aynı sonuç çıkıyor.
///
/// SAF WIDGET: veri almaz, dokunmayı yukarı bildirir.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/shared/widgets/iz_icon_action.dart';

class IzScreenHeader extends StatelessWidget {
  const IzScreenHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.trailing,
    super.key,
  });

  final String title;

  /// Başlığın altındaki tek satırlık açıklama.
  ///
  /// Boş geçilebilir: "Hayatım" ekranında yok, "Kişilerim"de var. Ekranın ne
  /// olduğunu bir cümleyle anlatmak boş bir listede daha çok işe yarıyor.
  final String? subtitle;

  final List<IzIconAction> actions;

  /// Başlığın sağındaki serbest içerik — ikon + metinli bir eylem gibi.
  ///
  /// [actions] YALNIZCA İKONLAR için: kendi görünen-boşluk hesabını taşıyor
  /// (bkz. `IzIconActionRow`). "+ Kişi Ekle" gibi metinli bir eylem o hesaba
  /// girmiyor; onu buraya veriyoruz.
  ///
  /// İKİSİ BİRDEN VERİLMEZ — ikisi de sağ tarafı ister. `assert` ile
  /// yakalamak istedik ama `const` bir kurucuda `actions.isEmpty` sabit ifade
  /// olmadığı için derlenmiyor; [actions] doluysa o kazanıyor.
  final Widget? trailing;

  /// Figma: şeridin üstten uzaklığı 24 — ÇERÇEVENİN tepesinden.
  ///
  /// Figma çerçevesinde durum çubuğu yok. Bu 24'ü çubuğun ÜSTÜNE eklersek
  /// başlık gerçek telefonda 24 + 47 = 71'e iner ve tasarımdan çok aşağıda
  /// kalır. Bu yüzden 24'ü TABAN kabul ediyoruz: çubuk yoksa tam 24,
  /// varsa onun hemen altında nefes payı kadar.
  static const double kTopInset = AppSpacing.lg;

  /// Figma: her blok `left: 20, width: 350`.
  ///
  /// Bu bir MARJDIR, ölçeklenmez: geniş ekranda bloklar genişler, kenar
  /// boşluğu sabit kalır.
  static const double kPageInset = 20;

  /// Figma: şeridin kendi 4'lük dolgusu.
  static const double _kPadding = AppSpacing.xs;

  /// Figma: iki ikonun GÖRÜNEN arası 24.
  static const double _kActionGap = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final safeTop = context.media.padding.top;
    final top = math.max(kTopInset, safeTop + AppSpacing.sm);

    return Padding(
      padding: EdgeInsets.fromLTRB(kPageInset, top, kPageInset, 0),
      child: Padding(
        padding: const EdgeInsets.all(_kPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    // POPPINS 26, Cormorant 24 DEĞİL.
                    //
                    // Figma serif söylüyordu ve bir süre öyle kaldı. Ama ekran
                    // başlığı sayfanın geri kalanıyla aynı sesle konuşmak
                    // zorunda: serif başlığın altındaki Poppins metinlerle
                    // arasında görünür bir kopukluk vardı ve 24 punto onların
                    // yanında küçük kalıyordu.
                    //
                    // Aynı kararı anı detayının başlığında da vermiştik; ikisi
                    // artık tek bir stili paylaşıyor (`AppTextStyles.screenTitle`).
                    // MARKA YEŞİLİ, siyaha yakın gri değil.
                    //
                    // Bu başlıklar ("Hayatım", "Kişilerim") uygulamanın KENDİ
                    // sesi — kullanıcının yazdığı bir şey değil. Yeşil onları
                    // sayfanın içeriğinden ayırıyor ve marka rengi ekranın en
                    // üstünde bir kez, en büyük yazıda görünüyor.
                    //
                    // Kullanıcının kendi metinleri (anı başlığı, kişi adı)
                    // aynı stili paylaşıyor ama KOYU kalıyor: onlar veri, bu
                    // ise etiket. Karşıtlık oranı iki temada da AA üstünde
                    // (açık: 9.9:1, koyu: 5.1:1) — `theme_contrast_test`.
                    style: context.textStyles.screenTitle.copyWith(
                      color: context.colors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  // Figma: başlık kutusuyla eylemler arası 12.
                  const SizedBox(width: 12),
                  IzIconActionRow(designGap: _kActionGap, actions: actions),
                ] else if (trailing case final widget?) ...[
                  const SizedBox(width: 12),
                  widget,
                ],
              ],
            ),

            if (subtitle case final text?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                text,
                style: context.textStyles.caption.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
