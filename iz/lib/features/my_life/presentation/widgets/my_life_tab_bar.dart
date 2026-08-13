/// "Hayatım" ekranının hap biçimli sekme çubuğu: TAKVİM / KOLEKSİYONLAR /
/// SERİLERİM.
///
/// SAF WIDGET: hangi sekmenin seçili olduğunu BİLMEZ, dışarıdan alır ve
/// dokunmayı yukarı bildirir. Seçim durumu ekranın işi; ileride sekmeye
/// göre içerik gelince o durum bir ViewModel'e taşınacak ve bu widget
/// hiç değişmeyecek.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   çubuk → 350 × 40, top 76, left 20, space-between, köşe 999 (hap),
///           kenarlık 1px #E8E3D9, dolgu (4, 8, 4, 8), zemin #FFFDFA
///   hap   → 28 yüksek, köşe 999, dolgu (6, 12, 6, 12)
///           seçili: zemin #294A35 (Brand-Primary)
///           seçili değil: zeminsiz — referansta yalnızca yazı görünüyor
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';

/// Ekranın üç bölümü.
///
/// Sıralama ekrandaki sırayla aynı. Etiket ÇEVİRİDEN geliyor: enum'un
/// kendisi metin taşımaz — `failure_l10n.dart` ile aynı kural.
enum MyLifeTab {
  calendar,
  collections,
  series;

  String label(AppL10n l10n) => switch (this) {
    MyLifeTab.calendar => l10n.myLifeTabCalendar,
    MyLifeTab.collections => l10n.myLifeTabCollections,
    MyLifeTab.series => l10n.myLifeTabSeries,
  };

  /// Rotadaki `?tab=` değerinden sekmeyi bulur; tanımadığı değerde null.
  ///
  /// Ana sayfadaki sayaçlar buraya derin bağlantıyla geliyor
  /// (`/my-life?tab=series`). ENUM ADI kullanılıyor, ayrı bir sözlük değil:
  /// yeni bir sekme eklendiğinde bağlantı kendiliğinden çalışıyor.
  ///
  /// `null` DÖNMESİ BİR HATA DEĞİL: elle yazılmış ya da eski bir bağlantı
  /// tanınmayan bir değer taşıyabilir. Çağıran taraf varsayılan sekmeyi
  /// gösteriyor — kullanıcı hata ekranı değil, ekranın kendisini görüyor.
  static MyLifeTab? fromQuery(String? value) =>
      MyLifeTab.values.where((tab) => tab.name == value).firstOrNull;
}

class MyLifeTabBar extends StatelessWidget {
  const MyLifeTabBar({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MyLifeTab selected;
  final ValueChanged<MyLifeTab> onSelected;

  /// Figma: çubuk 40 yüksekliğinde, iç dolgusu 4/8.
  static const double kHeight = 40;
  static const double _kPaddingVertical = AppSpacing.xs;
  static const double _kPaddingHorizontal = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MyLifeLayout.pageInset),
      child: Container(
        height: kHeight,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: AppRadius.pill,
          border: Border.all(color: colors.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: _kPaddingVertical,
          horizontal: _kPaddingHorizontal,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ÜÇ HAP DAR EKRANA SIĞMAYABİLİR: 390'da rahat sığıyor ama
            // 320'de etiketler toplam genişliği aşıyor. Kırpmak ya da
            // küçültmek yerine YATAY KAYDIRMAYA izin veriyoruz — etiketler
            // tam okunur kalıyor.
            //
            // `minWidth` şart: sığdığında satır tüm genişliği kaplasın ve
            // `space-between` tasarımdaki gibi çalışsın.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final tab in MyLifeTab.values)
                      _TabPill(
                        label: tab.label(context.l10n),
                        isSelected: tab == selected,
                        onPressed: () => onSelected(tab),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tek sekme hapı.
class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  /// Figma: hap 28 yüksek, dolgu (6, 12, 6, 12).
  static const double _kHeight = 28;
  static const double _kPaddingHorizontal = 12;

  /// Etiketler BÜYÜK HARF; harf arası açılmazsa sıkışık okunuyor.
  /// Referansta da harfler belirgin şekilde aralıklı.
  ///
  /// Punto 10'dan 12'ye çıkınca 1'den 0.5'e indirdik: aralık, küçük puntonun
  /// okunurluk açığını kapatmak içindi. 12'de o açık yok ve 1'lik aralık
  /// "KOLEKSİYONLAR"ı gereksiz yere uzatıp çubuğu erken kaydırılabilir
  /// hâle getiriyordu.
  static const double _kLetterSpacing = 0.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.pill,
        child: Container(
          height: _kHeight,
          padding: const EdgeInsets.symmetric(horizontal: _kPaddingHorizontal),
          decoration: BoxDecoration(
            // Seçili değilken zemin YOK: referansta çubuğun kendi rengi
            // görünüyor, ikinci bir kutu çizilmiyor.
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: AppRadius.pill,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            // Poppins Medium 12/16 (`labelMedium`).
            //
            // TASARIM 10 DİYORDU, BÜYÜTTÜK. Ekranda etiketler hem küçük hem
            // soluk kalıyordu: bunlar sayfanın ana gezinme aracı, okunması
            // için gözün zorlanmaması gerekiyor. Satır yüksekliği ikisinde de
            // 16 olduğu için hapın 28'lik boyu değişmedi.
            style: context.text.labelMedium?.copyWith(
              // SEÇİLİ OLMAYAN ETİKET Text-PRIMARY.
              //
              // Önce Text-Secondary'ydi (#6F6C65) ve silik duruyordu. Seçili
              // sekmeyi zaten DOLU YEŞİL HAP belirtiyor; ayırt etme işini
              // yazının solukluğuna yüklemek gerekmiyor. Böylece seçili
              // olmayan sekmeler de rahat okunuyor ama hangisinin açık
              // olduğu hâlâ tartışmasız.
              color: isSelected ? colors.onPrimary : colors.onSurface,
              letterSpacing: _kLetterSpacing,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
