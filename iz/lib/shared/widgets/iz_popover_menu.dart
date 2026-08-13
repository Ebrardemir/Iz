/// Dokunulan öğenin ALTINDA açılan küçük eylem menüsü.
///
/// NEDEN ALTTAN AÇILAN SAYFA DEĞİL?
/// Önce `showModalBottomSheet` kullanıyorduk. İşliyordu ama iki sorunu vardı:
///   • İki satırlık bir menü için ekranın dibinden koca bir yüzey kalkıyor;
///     ağırlığı içeriğiyle uyumsuz.
///   • Dokunulan satırla BAĞI kopuyor. Üç noktaya bastıktan sonra sayfa
///     ekranın öbür ucunda açılıyor ve "hangi anı için?" sorusunu başlıkla
///     telafi etmek gerekiyor.
/// Çıpalanan menü ikisini de çözüyor: küçük, hafif ve tam dokunduğun yerin
/// altında.
///
/// NEDEN MATERIAL'IN `showMenu`'SU DEĞİL?
/// Görünüşü Material'ın kendi dili: keskin köşeler, `elevation` gölgesi,
/// kendi satır yükseklikleri. İZ'in dili ince çerçeve + yumuşak gölge +
/// 16 köşe. Temayla zorlamak yerine kendi menümüzü çiziyoruz — `IzBottomNav`
/// ve `CurvedTopPanel` ile aynı gerekçe.
///
/// YERLEŞİM MANTIĞI SAF BİR FONKSİYONDA: [resolveIzPopoverOffset]. Ekran
/// kenarına yakın bir satırda menünün nereye gideceği kolayca yanlış yazılan
/// bir hesap; ayrı tutunca widget kurmadan test edilebiliyor
/// (bkz. test/unit/iz_popover_menu_test.dart).
///
/// SAF: hiçbir feature tipini bilmez, yalnızca ikon + etiket + geri çağırma
/// alır (bkz. ARCHITECTURE.md — `shared/` sadece `core/`u bilir).
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Menüdeki tek bir eylem.
///
/// [isDestructive] geri alınamayan eylemi işaretler: kırmızıya boyanır ve
/// listenin SONUNA konur. NFR-031 gereği renk tek başına bilgi taşımaz —
/// ikon ve metin de zaten ayırt edici.
typedef IzMenuAction = ({
  IconData icon,
  String label,
  bool isDestructive,
  VoidCallback onPressed,
});

/// Menüyü [anchor] dikdörtgeninin altında açar.
///
/// [anchor] EKRAN koordinatlarında olmalı — çağıran taraf dokunulan
/// düğmenin kutusunu şöyle hesaplar:
/// ```dart
/// final box = key.currentContext!.findRenderObject()! as RenderBox;
/// final anchor = box.localToGlobal(Offset.zero) & box.size;
/// ```
///
/// SIRA ÖNEMLİ: eylemin geri çağırması menü KAPANDIKTAN sonra çalışır.
/// Böylece eylem yeni bir diyalog (silme onayı) açacaksa iki yüzey üst üste
/// binmez ve `Navigator` yığını temiz kalır.
Future<void> showIzPopoverMenu(
  BuildContext context, {
  required Rect anchor,
  required List<IzMenuAction> actions,
}) async {
  final chosen = await showGeneralDialog<IzMenuAction>(
    context: context,
    // Perde GÖRÜNMEZ: menü küçük ve bağlamsal, ekranı karartmak onu
    // "diyalog" ağırlığına çıkarırdı.
    barrierColor: Colors.transparent,
    // AMA DOKUNUŞU YAKALIYOR. `showGeneralDialog`ın varsayılanı `false`
    // (`showDialog`ın aksine) ve unutulduğunda menü yalnızca bir eylem
    // seçilerek kapanır — yıkıcı eylem içeren bir menüde bu kabul edilemez.
    // `my_life_view_test.dart` içindeki "menü dışına dokunmak onu kapatır"
    // testi bunu yakaladı.
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: AppDuration.fast,
    pageBuilder: (dialogContext, _, _) {
      return CustomSingleChildLayout(
        delegate: _IzPopoverLayout(
          anchor: anchor,
          safeArea: MediaQuery.viewPaddingOf(dialogContext),
        ),
        child: _IzPopoverCard(actions: actions),
      );
    },
    transitionBuilder: (dialogContext, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: curved,
        // ÇIPADAN BÜYÜYOR: ölçek başlangıcı sağ üst köşe, yani dokunulan üç
        // noktanın olduğu yer. Menünün oradan çıktığı hissi bu hizadan
        // geliyor; merkezden büyüseydi "ortaya bir kutu düştü" gibi olurdu.
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );

  chosen?.onPressed();
}

/// Menünün ekran koordinatlarındaki sol-üst köşesini hesaplar.
///
/// KURALLAR
///   1. Menü çıpanın ALTINA, [gap] kadar boşlukla açılır.
///   2. SAĞ kenarları hizalanır: üç nokta satırın sağ ucunda duruyor, menü
///      de oradan aşağı açılmalı. Sola hizalasaydık menü satırın ortasına
///      doğru kayardı.
///   3. Altta yer kalmadıysa çıpanın ÜSTÜNE geçer — yoksa menü ekranın
///      dışında kalır ve kullanıcı hiçbir şey göremez.
///   4. Her hâlde ekran içinde ve güvenli alanın [margin] kadar içinde kalır.
///
/// Saf fonksiyon: widget kurmadan test edilebilir.
Offset resolveIzPopoverOffset({
  required Rect anchor,
  required Size popover,
  required Size screen,
  EdgeInsets safeArea = EdgeInsets.zero,
  double gap = AppSpacing.xs,
  double margin = AppSpacing.sm,
}) {
  // --- Yatay: sağ kenarlar hizalı, ekran içine sıkıştırılmış -------------
  final minX = safeArea.left + margin;
  final maxX = screen.width - safeArea.right - margin - popover.width;
  final rawX = anchor.right - popover.width;
  // `maxX < minX` ekran menüden daha darsa olur; o durumda sol kenara yasla.
  final x = maxX < minX ? minX : rawX.clamp(minX, maxX);

  // --- Dikey: altta yer varsa aşağı, yoksa yukarı ------------------------
  final minY = safeArea.top + margin;
  final maxY = screen.height - safeArea.bottom - margin;

  final below = anchor.bottom + gap;
  final above = anchor.top - gap - popover.height;

  final fitsBelow = below + popover.height <= maxY;
  final rawY = fitsBelow ? below : above;

  final y = maxY - popover.height < minY
      // İkisi de sığmıyor (çok kısa ekran): üstten başla, taşmayı kabul et.
      ? minY
      : rawY.clamp(minY, maxY - popover.height);

  return Offset(x, y);
}

class _IzPopoverLayout extends SingleChildLayoutDelegate {
  const _IzPopoverLayout({required this.anchor, required this.safeArea});

  final Rect anchor;
  final EdgeInsets safeArea;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Menü içeriği kadar geniş olsun ama ekranı zorlamasın.
    return BoxConstraints(
      maxWidth: constraints.maxWidth - 2 * AppSpacing.sm,
      maxHeight: constraints.maxHeight - 2 * AppSpacing.sm,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      resolveIzPopoverOffset(
        anchor: anchor,
        popover: childSize,
        screen: size,
        safeArea: safeArea,
      );

  @override
  bool shouldRelayout(_IzPopoverLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.safeArea != safeArea;
}

/// Menünün görünen yüzeyi.
class _IzPopoverCard extends StatelessWidget {
  const _IzPopoverCard({required this.actions});

  final List<IzMenuAction> actions;

  /// Menü ne kadar dar olabilir? İki kelimelik etiketler ("Anıya git")
  /// yan yana sıkışmasın diye bir taban veriyoruz.
  static const double _kMinWidth = 200;
  static const double _kMaxWidth = 280;

  /// Satır yüksekliği — NFR-033 asgari dokunma hedefi.
  static const double _kItemHeight = AppSpacing.minTapTarget;

  /// Menü yüzeyinin yumuşak gölgesi.
  ///
  /// Açık temada kart rengi sayfa zeminine çok yakın; menüyü ayıran şey
  /// ince çerçeve VE bu gölge. Kart gölgelerinden (blur 12, %4) belirgin
  /// şekilde daha güçlü, çünkü bu yüzey gerçekten sayfanın ÜSTÜNDE duruyor.
  static const List<BoxShadow> _kShadow = [
    BoxShadow(
      color: Color(0x24000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinWidth,
        maxWidth: _kMaxWidth,
      ),
      // `IntrinsicWidth` OLMADAN menü HER ZAMAN azami genişlikte açılıyordu.
      //
      // Sebep: aşağıdaki `Column` `stretch` hizasında ve gevşek bir kısıt
      // aldığında kendini verilen en geniş ölçüye yayıyor. Kısa bir etiket
      // ("Sil") için 280 px'lik bir kutu, iki kelimelik bir menüyü gereksiz
      // yere ağırlaştırıyor.
      //
      // Bu, en geniş satırın kendi genişliğini ölçüp onu kullanıyor;
      // yukarıdaki alt/üst sınırlar da hem çok dar hem çok geniş olmasını
      // engelliyor. İki-üç satır için maliyeti ihmal edilebilir.
      child: IntrinsicWidth(
        child: Container(
          // Köşeleri kırp: satırların dalga efekti (`InkWell`) yuvarlatılmış
          // köşenin dışına taşmasın. Gölge kırpılmaz — dekorasyon çocuktan
          // ÖNCE çizilir, bu yüzden ikisi tek kutuda birlikte durabiliyor.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            // Diyalog ve alt sayfalarla AYNI yüzey rengi — bu da yükseltilmiş
            // bir yüzey (bkz. app_theme.dart `dialogTheme`).
            color: colors.surfaceContainerLowest,
            borderRadius: AppRadius.card,
            border: Border.all(color: colors.outlineVariant),
            boxShadow: _kShadow,
          ),
          // `Material` ŞART, ama YÜZEY İÇİN DEĞİL — satırlardaki `InkWell`
          // için. `showDialog` içeriğini kendiliğinden bir `Material`a sarar;
          // `showGeneralDialog` SARMAZ ve dalga efekti "No Material widget
          // found" ile düşer. Rengi, kenarlığı ve gölgeyi yukarıdaki kutu
          // veriyor, bu yüzden burada saydam.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final action in actions) ...[
                  if (action != actions.first)
                    // Saç teli çizgi — uygulamanın her yerindeki ayırıcı dili.
                    SizedBox(
                      height: 1,
                      child: ColoredBox(color: colors.outlineVariant),
                    ),
                  _IzPopoverItem(action: action, height: _kItemHeight),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IzPopoverItem extends StatelessWidget {
  const _IzPopoverItem({required this.action, required this.height});

  final IzMenuAction action;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive
        ? context.semanticColors.danger
        : context.colors.onSurface;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(action),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(action.icon, size: AppIconSize.md, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.label,
                    style: context.text.bodyMedium?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
