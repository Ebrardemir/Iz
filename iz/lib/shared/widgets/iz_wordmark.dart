/// "İZ" logo yazısı (+ isteğe bağlı altın filiz).
///
/// Marka adı ÇEVRİLMEZ — bir logodur, arayüz metni değil. Yine de metni
/// `appTitle` çevirisinden okuyoruz: değeri her dilde aynı, böylece sabit
/// metin yasağına istisna açmadan tek kaynaktan geliyor.
///
/// NEDEN `shared/` ALTINDA?
/// Önce giriş ekranının bir parçasıydı. Ana sayfa da logoyu kullanınca
/// `features/home` → `features/auth` bağımlılığı doğacaktı; özellikler
/// birbirini TANIMAZ. Marka imzası ortak bir varlık, yeri burası.
///
/// İKİ KULLANIM BİÇİMİ:
///   • Kimlik ekranları — büyük, marka yeşili, filizli (varsayılan).
///   • Ana sayfa — fotoğrafın üzerinde küçük, beyaz, filizsiz.
/// Tek dosyada tutuyoruz ki punto/aralık kararları ikiye ayrışmasın.
///
/// FİLİZ NEDEN İKON DEĞİL, ÇİZİM?
/// Önce Lucide'ın hazır ikonları denendi (`leaf`, `wheat`, `sprout`).
/// Hepsi 2px sabit kalınlıkta çizilmiş arayüz ikonları; logonun yanında
/// hantal ve "buton simgesi" gibi duruyorlardı. Referans tasarımdaki dokunuş
/// ince çizgili, uzayan bir dal. Bu yüzden ince konturlu kendi çizimimizi
/// kullanıyoruz — tek yerde, yalnızca logo için.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// İnce konturlu botanik dal. Renk `colorFilter` ile temadan verilir,
/// bu yüzden çizim tek renk (siyah) tanımlanıyor.
///
/// GEOMETRİ — ORTA DAMAR YAPRAĞIN TAM ORTASINDAN GEÇER.
///
/// Önce sapın iki yanına dizilmiş ayrı yapraklar denendi; büyütünce çizgi
/// yaprakların ortasından değil aralarından geçiyordu ve şekil "örgü/halat"
/// gibi okunuyordu. Şimdi tek bir yaprak var: dış kontur iki simetrik eğri,
/// içinden geçen düz çizgi ise orta damar. İki eğri de aynı iki uç noktada
/// ((5,27) ve (27,5)) buluştuğu için damar tanım gereği tam ortadan geçer.
/// Yan damarlar yaprağı botanik bir çizime dönüştürüyor.
const String _sprigSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <g fill="none" stroke="#000" stroke-width="1.1"
     stroke-linecap="round" stroke-linejoin="round">
    <path d="M5 27 Q8 11 27 5 Q21 24 5 27 Z"/>
    <path d="M5 27 L27 5"/>
    <path d="M11 21 L11.5 15.5"/>
    <path d="M15 17 L16 12"/>
    <path d="M19 13 L20 9"/>
    <path d="M11 21 L16.5 20"/>
    <path d="M15 17 L20 16"/>
    <path d="M19 13 L23 12.5"/>
  </g>
</svg>
''';

class IzWordmark extends StatelessWidget {
  const IzWordmark({
    this.size = kIzWordmarkSize,
    this.color,
    this.showSprig = true,
    this.shadows,
    super.key,
  });

  /// Kimlik ekranlarının büyük logosu.
  static const double kIzWordmarkSize = 76;

  /// Harflerin puntosu. `height: 1` olduğu için kutu yüksekliği de bu değere
  /// eşittir — Figma'daki yükseklik doğrudan buraya yazılabilir.
  final double size;

  /// Boş bırakılırsa marka yeşili (`primary`). Fotoğraf üzerinde beyaz
  /// verilir; orada tema rengi zemine göre değil, GÖRSELE göre seçilir.
  final Color? color;

  /// Filiz yalnızca kimlik ekranlarında var; küçük puntoda lekeye dönüşüyor.
  final bool showSprig;

  /// Fotoğraf üzerinde okunurluk için gölge.
  final List<Shadow>? shadows;

  /// Filiz, harf puntosunun yarısı kadar. Sabit oran: punto değişince
  /// filizin oranı bozulmasın.
  double get _sprigSize => size / 2;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      context.l10n.appTitle,
      // Cormorant Garamond — markanın sesi serif.
      //
      // NEDEN ÖLÇEĞİN DIŞINDA BİR PUNTO?
      // Tipografi ölçeğinin tepesi 48 (Display). Logo bir metin değil
      // MARKA İMZASI; ekranın odak noktası olması için ölçeğin üstüne
      // çıkıyoruz. Bu, "widget'ta fontSize yazma" kuralının bilinçli ve
      // tek istisnası — başka hiçbir yerde yapmıyoruz.
      style: context.text.displayLarge?.copyWith(
        fontSize: size,
        color: color ?? context.colors.primary,
        // Logoda harfler biraz açık dursun.
        letterSpacing: 2,
        // SATIR YÜKSEKLİĞİ 1.0 — GÖRÜNMEZ BOŞLUĞU KESER.
        //
        // Gövde metninde 1.2 doğru: satırlar birbirine yapışmasın diye.
        // Ama burası TEK SATIRLIK bir logo; 1.2 harflerin üstüne ve
        // altına ~16'şar piksel boş alan koyuyordu. Ekranda "logo çok
        // yukarıda, gerisi sıkışık" hissini yaratan şey buydu.
        height: 1,
        shadows: shadows,
      ),
    );

    if (!showSprig) return text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      // Filiz, harflerin ALT hizasından çıkar — üstten değil.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        text,
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Transform.rotate(
            angle: -0.15,
            child: SvgPicture.string(
              _sprigSvg,
              width: _sprigSize,
              height: _sprigSize,
              colorFilter: ColorFilter.mode(
                context.colors.tertiary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
