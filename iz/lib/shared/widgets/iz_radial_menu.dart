/// Ekranın ortasında bir HALKA olarak açılan ekleme menüsü.
///
/// Alt çubuktaki "+" düğmesi bunu açıyor: arka plan buğulanıyor, ortada
/// seçenekler bir daire üzerinde beliriyor, en altta kapatma düğmesi duruyor.
///
/// NEDEN HALKA, NEDEN LİSTE DEĞİL?
/// Beş seçenek dikey bir listede sıraya girdiğinde "form" gibi okunuyor ve
/// hepsi eşit ağırlık kazanıyor. Halkada ise en üstteki yuva doğal olarak
/// öne çıkıyor (oraya ANI konuyor — asıl eylem), gerisi çevresine yayılıyor.
/// Üstelik daireler başparmağın erişim yayına oturuyor.
///
/// GEOMETRİ SAYIYA GÖRE TÜRETİLİYOR, 5'E SABİT DEĞİL.
/// [resolveRadialSlots] yuva açılarını eylem sayısından hesaplıyor: n eylem +
/// 1 kapatma = n+1 yuva, 360/(n+1) derece aralıkla. Altıncı bir seçenek
/// eklendiğinde halka kendini yeniden bölüyor, hiçbir sayıyı elle
/// güncellemek gerekmiyor.
///
/// SAF: hiçbir feature tipini bilmez — ikon, etiket ve geri çağırma alır
/// (bkz. ARCHITECTURE.md, `shared/` yalnızca `core/`u bilir).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// Menüdeki tek bir seçenek.
typedef IzRadialAction = ({
  IconData icon,
  String label,
  VoidCallback onPressed,
});

/// Halka menüyü açar.
///
/// SIRA ÖNEMLİ: seçilen eylemin geri çağırması menü KAPANDIKTAN sonra
/// çalışıyor. Böylece eylem yeni bir sayfa açacaksa iki yüzey üst üste
/// binmiyor ve `Navigator` yığını temiz kalıyor.
///
/// [semanticTitle] ekranda yazılı DEĞİL; tasarımda başlık yok, seçenekler
/// kendini anlatıyor. Ekran okuyucuya ne açıldığını söylemek için var.
/// [bottomInset] kadar alt şerit BUĞULANMAZ.
///
/// Menüyü açan şey alt çubuktaki "+" düğmesi; referans tasarımda o çubuk net
/// kalıyor ve kullanıcı nereden geldiğini görüyor. Buğu tüm ekranı kaplasa
/// uygulamanın çerçevesi kayboluyor, menü havada duruyormuş gibi oluyor.
///
/// Şerit GÖRÜNÜR ama ETKİSİZ: oraya dokunmak sekme değiştirmiyor, menüyü
/// kapatıyor. Açıkken sekme değiştirilebilseydi menü arkada başka bir ekranın
/// üzerinde kalırdı.
Future<void> showIzRadialMenu(
  BuildContext context, {
  required List<IzRadialAction> actions,
  required String semanticTitle,
  double bottomInset = 0,
}) async {
  final chosen = await showGeneralDialog<IzRadialAction>(
    context: context,
    // Perdeyi KENDİMİZ çiziyoruz (buğu + örtü), bu yüzden Material'ın
    // karartmasını kapatıyoruz — üst üste binince zemin çamurlaşıyor.
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: AppDuration.normal,
    routeSettings: const RouteSettings(name: 'iz-radial-menu'),
    pageBuilder: (dialogContext, animation, _) {
      return IzRadialMenuScope(
        actions: actions,
        semanticTitle: semanticTitle,
        animation: animation,
        bottomInset: bottomInset,
      );
    },
  );

  chosen?.onPressed();
}

/// Halka üzerindeki eylem yuvalarının, halka merkezine göre konumları.
///
/// KURALLAR
///   1. Yuva sayısı = eylem sayısı + 1. Fazladan yuva EN ALTTA duran kapatma
///      düğmesinin; o yüzden eylemler alt yuvayı asla kullanmıyor.
///   2. Yuvalar eşit aralıklı: 360 / (n+1) derece.
///   3. ORTADAKİ eylem tam TEPEDE (90°). Liste tek sayıdaysa ortadaki öğe
///      doğal olarak en görünür yuvaya düşüyor; çift sayıdaysa tepe boşta
///      kalıp iki yanına simetrik dağılıyorlar.
///   4. Sıra SOLDAN SAĞA: ilk eylem sol alta, son eylem sağ alta.
///
/// Beş eylemde referans tasarımın yerleşimini birebir üretiyor:
///   210° Koleksiyon · 150° Ritüel · 90° Anı · 30° Günlük · 330° Kişi
///
/// Ekran koordinatı: y AŞAĞI doğru artıyor, bu yüzden sinüsün işareti ters.
///
/// Saf fonksiyon: widget kurmadan test edilebilir
/// (bkz. test/unit/iz_radial_menu_test.dart).
List<Offset> resolveRadialSlots({
  required int actionCount,
  required double radius,
}) {
  if (actionCount <= 0) return const [];

  final step = 2 * math.pi / (actionCount + 1);
  final middle = (actionCount - 1) / 2;

  return [
    for (var i = 0; i < actionCount; i++)
      _polar(radius, math.pi / 2 - (i - middle) * step),
  ];
}

/// Kapatma düğmesinin konumu — her zaman EN ALT yuva (270°).
///
/// Alt çubuktaki "+" düğmesinin hemen üstüne düşüyor: menüyü açan parmak
/// kapatmak için de aynı yere gidiyor.
Offset resolveRadialCloseSlot({required double radius}) =>
    _polar(radius, -math.pi / 2);

Offset _polar(double radius, double angle) =>
    Offset(radius * math.cos(angle), -radius * math.sin(angle));

/// Menünün kök katmanı.
///
/// AÇIK (public) çünkü testler "menü açıldı mı" sorusunu bunun varlığıyla
/// soruyor; etiketlere bakmak yanıltıyordu ("Koleksiyon" kelimesi ekranın
/// kendisinde de geçebiliyor).
class IzRadialMenuScope extends StatelessWidget {
  const IzRadialMenuScope({
    required this.actions,
    required this.semanticTitle,
    required this.animation,
    required this.bottomInset,
    super.key,
  });

  final List<IzRadialAction> actions;
  final String semanticTitle;
  final Animation<double> animation;
  final double bottomInset;

  /// Halkanın yarıçapı — daire çapının iki katı (referans tasarımdan ölçüldü).
  static const double kRadius = 2 * _RadialItem.kCircleSize;

  /// Zeminin buğu gücü.
  ///
  /// İLK DENEMEDE 18'Dİ VE FAZLAYDI: arka plan tanınmaz hâle geliyor,
  /// kullanıcı hangi ekranda olduğunu kaybediyordu. Referansta zemin
  /// belirgin biçimde SEÇİLİYOR — kartların, sayaçların şekli okunuyor.
  /// Amaç zemini yok etmek değil, geri plana ALMAK.
  static const double _kBlurSigma = 6;

  /// Buğunun üzerine serilen açık örtü.
  ///
  /// Buğu tek başına yetmiyor: koyu bir fotoğrafın bulanığı da koyu kalıyor
  /// ve koyu etiketler üzerinde okunmuyor. Sayfanın kendi kremi bu yüzden
  /// üste geliyor.
  ///
  /// %72'DEN %45'E İNDİ (buğuyla birlikte): ikisi bir aradayken zemin
  /// tamamen silinmişti. Şimdi donuk ama seçilir.
  static const double _kScrimOpacity = 0.45;

  /// Kapatma düğmesinin alt kenarı ile alt çubuk arasındaki boşluk.
  ///
  /// Halka ekranın ortasında DEĞİL, alt çubuğun hemen üstünde duruyor:
  /// menüyü açan parmak "+" düğmesinin üzerinde ve kapatma düğmesi de tam
  /// oraya, parmağın zaten bulunduğu yere düşüyor. Ortada dursaydı hem
  /// açılış hem kapanış hareketi ekranın yarısını kat ediyordu.
  static const double _kGapAboveNav = AppSpacing.md;

  /// Kutunun DİBİNDEKİ görünmez pay.
  ///
  /// Kutu, eylem öğesinin yüksekliğine ([_RadialItem.kHeight]) göre
  /// boyutlanıyor; en alt yuvadaki kapatma düğmesi ise daha küçük (56).
  /// Aradaki fark kutunun dibinde boş kalıyor. Halkayı alt çubuğa göre
  /// hizalarken bunu düşmeseydik kapatma düğmesi 26 px daha yukarıda
  /// dururdu ve boşluk "çok az" olmazdı.
  static const double _kBottomSlack =
      (_RadialItem.kHeight - _CloseButton.kSize) / 2;

  @override
  Widget build(BuildContext context) {
    final slots = resolveRadialSlots(
      actionCount: actions.length,
      radius: kRadius,
    );

    // Perde ve içerik AYRI eğrilerle geliyor: buğu doğrusal açılıyor
    // (yumuşak bir geçiş), daireler ise yaylanarak dışa fırlıyor.
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: semanticTitle,
      explicitChildNodes: true,
      child: Stack(
        children: [
          // --- ZEMİN: buğu + örtü + boşluğa dokunarak kapatma -------------
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              // `HitTestBehavior.opaque`: buğu bir görsel katman, dokunuşu
              // kendiliğinden yakalamıyor. Dokunma alanı TÜM EKRAN — alt
              // şerit buğulanmasa da oraya dokunmak menüyü kapatıyor.
              behavior: HitTestBehavior.opaque,
              child: FadeTransition(
                opacity: fade,
                child: Padding(
                  // Alt çubuk net kalsın (bkz. [showIzRadialMenu.bottomInset]).
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: _kBlurSigma,
                      sigmaY: _kBlurSigma,
                    ),
                    child: ColoredBox(
                      color: context.colors.surface.withValues(
                        alpha: _kScrimOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- HALKA -------------------------------------------------------
          //
          // ALT ÇUBUĞA GÖRE hizalanıyor, ekranın ortasına göre DEĞİL.
          // `bottom` değeri kapatma düğmesinin ALT KENARINI hedefliyor;
          // kutunun dibindeki boş payı düştüğümüz için sonuç tam
          // [_kGapAboveNav] kadar boşluk (bkz. [_kBottomSlack]).
          //
          // `Positioned.bottom` NEGATİF olabiliyor — `Padding` olamıyor.
          // Kutu alt çubuğun içine birkaç piksel sarkıyor ama GÖRÜNEN
          // hiçbir şey sarkmıyor; sarkan kısım o görünmez pay.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + _kGapAboveNav - _kBottomSlack,
            child: Center(
              child: SizedBox(
                // HER İKİ ÖLÇÜ DE ŞART.
                //
                // Yükseklik verilmediğinde içteki `Stack` kendini EN BÜYÜK
                // ÇOCUĞUNA göre ölçüyor (108 px) ve ±128 kaydırılan daireler
                // kutusunun dışına düşüyor. Ekranda görünüyorlar — çünkü
                // `Transform` boyayı taşırıyor — ama `RenderBox` kendi
                // boyunun dışındaki bir noktayı çocuklarına sormadığı için
                // DOKUNULAMIYORLAR. Tıpkı etiket tuzağı gibi; testler ikisini
                // de yakaladı.
                width: 2 * kRadius + _RadialItem.kWidth,
                height: 2 * kRadius + _RadialItem.kHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < actions.length; i++)
                      _FlyOut(
                        animation: animation,
                        slot: slots[i],
                        // KADEMELİ: daireler aynı anda değil, sırayla açılıyor.
                        // Hepsi birden belirdiğinde hareket "sıçrama" gibi
                        // duruyordu; 40 ms'lik gecikmeler onu bir açılma
                        // hissine çeviriyor.
                        order: i,
                        child: _RadialItem(
                          action: actions[i],
                          onTap: () => Navigator.of(context).pop(actions[i]),
                        ),
                      ),

                    _FlyOut(
                      animation: animation,
                      slot: resolveRadialCloseSlot(radius: kRadius),
                      order: actions.length,
                      child: _CloseButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Öğeyi merkezden yuvasına doğru "fırlatan" sarmalayıcı.
class _FlyOut extends StatelessWidget {
  const _FlyOut({
    required this.animation,
    required this.slot,
    required this.order,
    required this.child,
  });

  final Animation<double> animation;
  final Offset slot;
  final int order;
  final Widget child;

  /// Her öğe arasındaki gecikme, animasyonun toplam süresine oranla.
  static const double _kStagger = 0.08;

  @override
  Widget build(BuildContext context) {
    final start = (order * _kStagger).clamp(0.0, 0.4);
    final curved = CurvedAnimation(
      parent: animation,
      // `easeOutBack` sonda hafifçe aşıp yerine oturuyor — dairelerin
      // merkezden fırlatıldığı hissini veren şey bu.
      curve: Interval(start, 1, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        return Transform.translate(
          // Yuvaya doğru açılıyor: t=0'da merkezde, t=1'de yerinde.
          offset: slot * t,
          child: Opacity(
            // Saydamlık `easeOutBack`in taşmasından etkilenmesin diye
            // ayrı ve sınırlı.
            opacity: t.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }
}

/// Tek seçenek: beyaz daire + altında etiket.
class _RadialItem extends StatelessWidget {
  const _RadialItem({required this.action, required this.onTap});

  final IzRadialAction action;
  final VoidCallback onTap;

  /// Dairenin çapı. Uygulamanın başka yerlerindeki 64'lük görsellerle aynı
  /// ölçü (gün panelindeki kapak, kapalı koleksiyon kartı).
  static const double kCircleSize = 64;

  /// Etiket dairenin altında; "Günlük Kaydı" sığsın diye kutu daireden geniş.
  static const double kWidth = 96;
  static const double _kLabelGap = 6;
  static const double _kLabelHeight = 16;
  static const double _kLabelBlock = _kLabelGap + _kLabelHeight;

  /// Kutu, dairenin ÜSTÜNE de etiket bloğu kadar boşluk bırakıyor.
  ///
  /// NEDEN? Öğe halkanın bir yuvasına ORTALANARAK yerleştiriliyor ve
  /// ortalanan şey KUTUDUR. Kutu yalnızca daire + etiket olsaydı kutunun
  /// merkezi ikisinin arasına düşer, daire yuvadan yukarı kayardı ve halka
  /// dairesel olmaktan çıkardı. Üstte simetrik bir boşluk bırakınca kutunun
  /// merkezi = dairenin merkezi oluyor.
  ///
  /// ⚠️ BU İŞİ `Transform.translate` İLE YAPMAYA ÇALIŞMAYIN — bir kez denendi
  /// ve etiket TIKLANAMAZ hâle geldi. Sebep: `Transform` görseli kaydırıyor
  /// ama aradaki `Opacity`nin dokunma kutusu yerinde kalıyor; `RenderBox`
  /// kendi boyunun dışındaki bir noktayı çocuklarına hiç sormuyor. Yani
  /// etiket çiziliyor ama dokunma alanının dışında kalıyordu.
  static const double kHeight = _kLabelBlock + kCircleSize + _kLabelBlock;

  /// Dairenin yumuşak gölgesi — buğulu zeminde kenarını belli ediyor.
  static const List<BoxShadow> _kShadow = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 6),
      blurRadius: 18,
      spreadRadius: -4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: SizedBox(
        width: kWidth,
        height: kHeight,
        // DOKUNMA ALANI TÜM ÖĞE — sadece daire değil.
        //
        // Önce `InkWell` yalnızca daireyi sarıyordu ve ETİKETE DOKUNMAK
        // HİÇBİR ŞEY YAPMIYORDU. Kullanıcı gözüyle etiket düğmenin bir
        // parçası; ayrıca 12 puntoluk bir yazı parmakla zor yakalanır.
        // (`app_smoke_test.dart` içindeki "menüdeki Anı yeni anı ekranını
        //  açar" testi tam bunu yakaladı.)
        //
        // `MaterialType.transparency`: dalga efekti için Material şart ama
        // yüzeyi çizmesini istemiyoruz — daireyi aşağıdaki `DecoratedBox`
        // çiziyor, dalga onun ARKASINDA kalıyor.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.contentCard,
            child: Column(
              children: [
                // Dairenin üstündeki simetrik boşluk — bkz. [kHeight].
                const SizedBox(height: _kLabelBlock),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Yükseltilmiş yüzey — diyalog ve alt sayfalarla aynı.
                    color: colors.surfaceContainerLowest,
                    boxShadow: _kShadow,
                  ),
                  child: SizedBox.square(
                    dimension: kCircleSize,
                    child: Icon(
                      action.icon,
                      size: AppIconSize.lg,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: _kLabelGap),
                SizedBox(
                  height: _kLabelHeight,
                  child: Text(
                    action.label,
                    // Poppins Medium 12/16 → `labelMedium`.
                    style: context.text.labelMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
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

/// Halkanın altındaki kapatma düğmesi.
///
/// Seçeneklerden AYRI görünüyor: dolu marka yeşili, etiketsiz. Bir seçenek
/// değil, çıkış yolu — beyaz dairelerin arasına altıncı bir beyaz daire
/// koysaydık kullanıcı onu da "eklenecek bir şey" sanardı.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  static const double kSize = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: context.l10n.commonClose,
      excludeSemantics: true,
      child: Material(
        color: colors.primary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: kSize,
            child: Icon(
              // Material'ın `close`u değil Lucide'ın `x`i — uygulamanın
              // ikon seti tek (bkz. app_icons.dart).
              AppIcons.clear,
              size: AppIconSize.lg,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
