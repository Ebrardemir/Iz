/// İZ'in alt gezinme çubuğu: 4 sekme + ortada yükseltilmiş "Ekle" eylemi.
///
/// NEDEN MATERIAL'IN `NavigationBar`I DEĞİL?
/// Tasarımda seçili sekmenin arkasında gösterge hapı (indicator) yok ve
/// ortadaki daire bir SEKME DEĞİL, bir eylem — dokununca sayfa değişmiyor,
/// üstte yeni anı ekranı açılıyor. Material'ın bileşeni ikisini de
/// karşılamıyor; zorlamak yerine kendi çubuğumuzu çiziyoruz.
///
/// SAF WIDGET: router'ı, Riverpod'u bilmez. Hangi sekmenin seçili olduğunu
/// dışarıdan alır, dokunuşu dışarı bildirir. Bu sayede `ProviderScope` veya
/// `GoRouter` kurmadan test edilebilir.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Çubuktaki tek bir sekme.
typedef IzNavDestination = ({IconData icon, String label});

class IzBottomNav extends StatelessWidget {
  const IzBottomNav({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.addLabel,
    required this.addIcon,
    required this.onAdd,
    super.key,
  });

  /// Sekmeler. Ortadaki eylem BURAYA DAHİL DEĞİL — o ayrı bir kavram.
  /// Tasarım gereği 4 sekme bekleniyor: ikisi solda, ikisi sağda.
  final List<IzNavDestination> destinations;

  final int currentIndex;
  final ValueChanged<int> onSelect;

  final String addLabel;
  final IconData addIcon;
  final VoidCallback onAdd;

  /// Tasarımdaki çubuk yüksekliği.
  static const double height = 72;

  /// Uygulamanın DÖRT sekmesi, sırasıyla.
  ///
  /// Burada duruyor çünkü çubuğu iki yer kuruyor: ana kabuk (`AppShell`) ve
  /// kabuk dışında açılan tam ekran sayfalar (anı detayı). Listeyi ikisine de
  /// elle yazsaydık biri değişince öteki sessizce geride kalırdı — sıranın
  /// kayması derleyicinin göremediği bir hata (bkz. `AppRoute.tabs`).
  ///
  /// SAFLIK KORUNUYOR: burada yalnızca ikon ve etiket var, rota YOK. Hangi
  /// sekmenin nereye gittiğine çağıran karar veriyor.
  static List<IzNavDestination> appTabs(AppL10n l10n) => [
    (icon: AppIcons.navHome, label: l10n.navHome),
    (icon: AppIcons.navMyLife, label: l10n.navMyLife),
    (icon: AppIcons.navStore, label: l10n.navStore),
    (icon: AppIcons.navProfile, label: l10n.navProfile),
  ];

  /// Hiçbir sekmenin seçili olmadığı durum.
  ///
  /// Kabuk dışındaki bir sayfada (anı detayı) kullanıcı hiçbir sekmede
  /// değil; birini vurgulamak "buradasın" diye yanlış bir şey söylerdi.
  static const int noSelection = -1;

  /// Ortadaki dairenin çapı.
  static const double _addDiameter = 44;

  /// Etiketlerin en fazla kaç kat büyüyebileceği — bkz. `build`.
  static const double _kMaxLabelScale = 1.3;

  /// ETİKETLERİN ORTAK TABAN HATTI: çubuğun altından bu kadar yukarıda.
  ///
  /// Beş etiket de aynı hatta oturmak zorunda. Önce her öğe kendi içinde
  /// dikey ORTALANIYORDU ve ortadaki daire (44) yandaki ikonlardan (28) büyük
  /// olduğu için "Ekle" ötekilerden ~27 piksel aşağı düşüyordu — çubuk kaymış
  /// gibi görünüyordu.
  ///
  /// 4, keyfi bir değer değil: etiket ve bu pay sabit, ÜSTTEKİ ikon/daire ise
  /// kalan alanı esnek olarak alıyor (bkz. `_NavItem`). Çubuğun 72 pikseline
  /// en büyük öğenin (44'lük daire) en büyük yazı ölçeğinde de sığması
  /// gerekiyor: 72 − 21 (1.3 ölçekte etiket) − 4 = 47 ≥ 44. Payı 8 yaptığımızda
  /// 43 kalıyordu ve daire 5 piksel taşıyordu.
  static const double _kLabelBaseline = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    // Sekmeler ortadaki eylemin İKİ YANINA eşit bölünür.
    final half = destinations.length ~/ 2;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          // İnce üst çizgi: çubuk içerikten ayrılsın. Gölge kullanmıyoruz —
          // koyu temada gölge görünmez, çizgi her iki temada da çalışır.
          border: Border(top: BorderSide(color: context.colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          // ETİKETLERİN YAZI ÖLÇEĞİ SINIRLI.
          //
          // Çubuk sabit yükseklikte (72) ve etiketler çok kısa ("Hayatım",
          // "Ekle"). Sistem yazı ölçeği 2x'e çıktığında ikon + etiket bu
          // yüksekliğe sığmıyor ve `Column` taşıyor — bir kişiler ekranı
          // testinde tam bunu yakaladık.
          //
          // Ölçeği KIRPMAK, çubuğu büyütmekten iyi: çubuk büyüdükçe içeriğin
          // yeri daralıyor ve asıl okunması gereken şey ekranın kendisi.
          // Material'ın `NavigationBar`ı da aynı yolu izliyor. 1.3, en uzun
          // etiketin ("Ana Sayfa") hâlâ tek satırda sığdığı üst sınır.
          //
          // ⚠️ YALNIZCA ÇUBUĞU kırpıyor: ekranın geri kalanı sistem ölçeğini
          // tam olarak kullanmaya devam ediyor (NFR-032).
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: _kMaxLabelScale,
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    Expanded(
                      child: _NavItem(
                        destination: destinations[i],
                        selected: i == currentIndex,
                        onTap: () => onSelect(i),
                      ),
                    ),
                    // Ortadaki eylem, sekmelerin tam ortasına girer.
                    if (i == half - 1)
                      Expanded(
                        child: _AddAction(
                          icon: addIcon,
                          label: addLabel,
                          diameter: _addDiameter,
                          onTap: onAdd,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final IzNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Seçili sekme marka yeşiliyle işaretlenir. NFR-031 gereği renk tek
    // başına bilgi taşımamalı; `Semantics.selected` ekran okuyucuya durumu
    // ayrıca söylüyor.
    final color = selected
        ? context.colors.primary
        : context.colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        // NFR-033: dokunma hedefi ikonun kendisinden geniş olmalı.
        radius: AppSpacing.minTapTarget,
        // ETİKET SABİT TABANDA, İKON ESNEK ALANDA.
        //
        // `Expanded` kalan yüksekliği alıyor; etiket ve alt payı sabit.
        // Böylece beş etiket kesin aynı hatta oturuyor VE hiçbir yazı
        // ölçeğinde taşma olamıyor — ortalamaya bıraksaydık ikisi de
        // ölçeğe göre kayardı (bkz. `_kLabelBaseline`).
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Icon(
                  destination.icon,
                  size: AppIconSize.lg,
                  color: color,
                ),
              ),
            ),
            Text(
              destination.label,
              style: context.text.labelMedium?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: IzBottomNav._kLabelBaseline),
          ],
        ),
      ),
    );
  }
}

/// Ortadaki yükseltilmiş eylem: dolu daire + altında etiket.
class _AddAction extends StatelessWidget {
  const _AddAction({
    required this.icon,
    required this.label,
    required this.diameter,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double diameter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: AppSpacing.minTapTarget,
        // Yandaki sekmelerle AYNI yapı: etiket sabit tabanda, daire kalan
        // alanda ortalı. Etiketler tek hatta oturuyor, daire kendi ölçüsünü
        // koruyor.
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    // Daireye sığması için ölçekten bir kademe küçük.
                    size: AppIconSize.md,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: IzBottomNav._kLabelBaseline),
          ],
        ),
      ),
    );
  }
}
