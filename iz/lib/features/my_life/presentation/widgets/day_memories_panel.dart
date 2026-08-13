/// Takvimin ALTINDAKİ panel: seçili günün anıları.
///
/// SAF WIDGET: hangi günün seçili olduğunu ve o güne ait anıları DIŞARIDAN
/// alır. "Bugün" ya da veri kaynağı hakkında hiçbir şey bilmez; böylece
/// `ProviderScope` kurmadan, istenen günle test edilebiliyor.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   panel   → 390 × 222, top 550, dikey dolgu 8, bloklar arası 10
///             üst köşeler 40, ÜST KENARLIK 2px Brand-Default
///   başlık  → 350 × 24 (sayfa marjı 20), yatay dolgu 12, space-between
///             tarih: Poppins SemiBold 14/20, Text-Secondary
///             sayaç: Poppins Regular 10/18, Text-Secondary
///   kartlar → 330, left 30 (bkz. [DayMemoryCard])
///
/// 222 NEDEN "TAM" BİR SAYI?
/// Panel Figma'da 550'de başlıyor ve 772'de bitiyor — 772 tam olarak alt
/// çubuğun üst kenarı (844 − 72). Yani 222, ekranda takvimden sonra KALAN
/// alandır. İçini de tam dolduruyor:
///   8 + 24 (başlık) + 10 + 172 + 8 = 222
/// ve o 172, ya iki kartın yüksekliği (81 + 10 + 81) ya da boş durumun
/// kendisi. Tasarım kazara değil, iki kart üzerine kurulmuş.
///
/// AMA PANEL SABİT 222 DEĞİL — bilerek.
/// Bir günde kaç anı olacağını bilemeyiz. Üç anı varsa panel büyür ve sayfa
/// kaydırılır (`MyLifeView` zaten bir `SingleChildScrollView` içinde).
/// 222 bu yüzden ASGARİ yükseklik: az içerikte tasarımdaki oran korunur,
/// çok içerikte panel uzar. Sabit verseydik üçüncü kart taşardı.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';
import 'package:iz/features/my_life/presentation/widgets/day_memory_card.dart';

class DayMemoriesPanel extends StatelessWidget {
  const DayMemoriesPanel({
    required this.day,
    required this.onOpenMemory,
    required this.onAddMemory,
    this.memories = const [],
    super.key,
  });

  /// Takvimde seçili gün. Başlıktaki tarih bundan üretiliyor.
  final DateTime day;

  /// O güne ait anılar. Boş liste → boş durum çizilir.
  final List<DayMemoryData> memories;

  final ValueChanged<DayMemoryData> onOpenMemory;

  /// Boş günde "bir iz bırak" davetinin eylemi.
  final VoidCallback onAddMemory;

  /// Bkz. dosya başındaki "222 neden tam bir sayı" notu.
  static const double kMinHeight = 222;

  /// Figma: panelin dikey dolgusu 8, blokları arası 10.
  static const double _kPaddingVertical = AppSpacing.sm;
  static const double _kGap = 10;

  /// Figma: başlık satırı 24, kendi yatay dolgusu 12.
  static const double _kHeaderHeight = 24;
  static const double _kHeaderPadding = 12;

  /// Kartlar sayfa marjından 10 daha içeride: 20 + 10 = 30.
  static const double _kCardInset = MyLifeLayout.pageInset + 10;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinHeight),
      child: CustomPaint(
        painter: _RoundedTopPanelPainter(
          // Açık temada panel rengi sayfa zeminiyle aynıdır; paneli ayıran
          // şey renk değil, yuvarlatılmış üst kenar ve o 2px çizgi.
          // Koyu temada ikisi ayrışıyor (bkz. app_theme.dart).
          fill: colors.surfaceContainerLow,
          border: colors.outlineVariant,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _kPaddingVertical),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(day: day, count: memories.length),
              const SizedBox(height: _kGap),

              if (memories.isEmpty)
                _DayEmptyState(onAddMemory: onAddMemory)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _kCardInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < memories.length; i++) ...[
                        if (i > 0) const SizedBox(height: _kGap),
                        DayMemoryCard(
                          memory: memories[i],
                          onTap: () => onOpenMemory(memories[i]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "15 Ağustos 2026" ····· "3 anı"
class _Header extends StatelessWidget {
  const _Header({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final locale = Localizations.localeOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MyLifeLayout.pageInset + DayMemoriesPanel._kHeaderPadding,
      ),
      child: SizedBox(
        height: DayMemoriesPanel._kHeaderHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                // DİLİ AÇIKÇA GEÇİYORUZ: `AppDateFormats` boş bırakılırsa
                // `Intl.defaultLocale` genel değişkenine düşer; o da uygulama
                // açılışında ayarlanıyor ama widget'ı tek başına kurunca
                // (test, önizleme) ayarlanmamış oluyor ve tarih İngilizce
                // çıkıyor. Aynı gerekçe `month_navigator.dart`ta da var.
                AppDateFormats.long(day, locale: locale.toLanguageTag()),
                // FIGMA: Poppins SemiBold 14/20 → `labelLarge`.
                style: context.text.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Sayaç çeviriden geliyor ve ÇOĞUL DUYARLI: Türkçede sayıdan
            // sonra çoğul eki gelmez ("3 anı") ama İngilizcede gelir
            // ("3 memories"). `memoryCount` bu ayrımı kendi içinde yapıyor.
            Text(
              context.l10n.memoryCount(count),
              // FIGMA: Poppins Regular 10/18 → `bodyTiny`.
              style: context.textStyles.bodyTiny.copyWith(
                color: colors.onSurfaceVariant,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçili günde anı yokken gösterilen hâl.
///
/// TASARIM NİYETİ — NEDEN BOŞ BIRAKMADIK?
///
/// Kullanıcı takvimde gezinirken çoğu güne dokunduğunda burayı görecek;
/// yani bu, "istisnai" bir ekran değil, panelin EN SIK hâli. Bomboş bir
/// alan o yüzden "uygulama yüklenmedi mi?" hissi verirdi.
///
/// Ana sayfanın boş durumundan (`_RecentEmptyState`) bir farkı var: ORADA
/// buton YOK, çünkü fotoğrafın üzerinde zaten "Anı Ekle" duruyor ve ikinci
/// bir çağrı ikisini de zayıflatıyordu. BURADA ise ekranda o güne anı
/// eklemeyi öneren başka hiçbir şey yok — alt çubuktaki "Ekle" bile seçili
/// güne değil bugüne ait bir anı açar. Davet bu yüzden yerini hak ediyor.
///
/// Dil de bilinçli: "Bu güne henüz iz düşmedi" bir eksiklik değil bir
/// bekleyiş anlatıyor; uygulamanın adı da, vaadi de bu.
class _DayEmptyState extends StatelessWidget {
  const _DayEmptyState({required this.onAddMemory});

  final VoidCallback onAddMemory;

  /// Boş durum, iki kartın kapladığı alanın TAM KARŞILIĞI: 81 + 10 + 81.
  /// Böylece panel dolu da boş da olsa tasarımdaki 222'de kalıyor.
  static const double kHeight =
      DayMemoryCard.kHeight * 2 + DayMemoriesPanel._kGap;

  /// İzin boyu: kartların yanında lekeye dönüşmeyecek kadar küçük.
  static const double _kTraceSize = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      height: kHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ayak izi — markanın kendi metaforu. Genel bir "kutu boş"
            // simgesi yerine bunu kullanıyoruz (bkz. app_icons.dart).
            Icon(
              AppIcons.emptyTrace,
              size: _kTraceSize,
              color: context.colors.tertiary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: AppSpacing.sm),

            Text(
              l10n.myLifeDayEmptyTitle,
              // Serif — markanın duygusal sesi. Boş durum bir hata mesajı
              // değil, bir davet.
              style: context.text.headlineSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Dokunma hedefi 48'e temadan geliyor (`textButtonTheme`),
            // yani 10 puntoluk bir metni parmakla ıskalama sorunu yok.
            TextButton(
              onPressed: onAddMemory,
              child: Text(l10n.myLifeDayEmptyAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Üst köşeleri yuvarlak, YALNIZCA üst kenarı çizgili panel.
///
/// NEDEN `BoxDecoration` DEĞİL?
/// Flutter, `borderRadius` verilmiş bir dekorasyonda tek kenarlı `Border`a
/// izin vermiyor ("A borderRadius can only be given for a uniform Border").
/// `Border.all` ise panelin yanlarına da çizgi koyardı; panel tam genişlikte
/// olduğu için o çizgiler ekranın iki kenarında dikey şeritler olarak
/// görünürdü — tasarımda yok.
///
/// Kendi yolumuzu çizmek ayrıca doğru sonucu veriyor: çizgi 40'lık kavisi
/// TAKİP ediyor, `ClipRRect` + düz çizgi çözümünde olduğu gibi köşelerde
/// kesilmiyor.
class _RoundedTopPanelPainter extends CustomPainter {
  const _RoundedTopPanelPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  /// Figma: üst köşeler 40 → `AppRadius.xxl`.
  static const double _kRadius = 40;

  /// Figma: `border-top-width: 2px`.
  static const double _kBorderWidth = 2;

  /// Canvas çizgiyi yolun İKİ YANINA eşit dağıtır; yarısı panelin dışına
  /// taşardı. CSS'te `border-top` kutunun içinde durur — yolu yarım
  /// kalınlık içeri alarak aynı sonucu alıyoruz.
  static const double _kInset = _kBorderWidth / 2;
  static const double _kInnerRadius = _kRadius - _kInset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.width, size.height),
        topLeft: const Radius.circular(_kRadius),
        topRight: const Radius.circular(_kRadius),
      ),
      Paint()..color = fill,
    );

    // Sol kenarın kavis başlangıcından sağ kenarın kavis bitişine.
    final topEdge = Path()
      ..moveTo(_kInset, _kInset + _kInnerRadius)
      ..arcToPoint(
        const Offset(_kInset + _kInnerRadius, _kInset),
        radius: const Radius.circular(_kInnerRadius),
      )
      ..lineTo(size.width - _kInset - _kInnerRadius, _kInset)
      ..arcToPoint(
        Offset(size.width - _kInset, _kInset + _kInnerRadius),
        radius: const Radius.circular(_kInnerRadius),
      );

    canvas.drawPath(
      topEdge,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _kBorderWidth,
    );
  }

  @override
  bool shouldRepaint(_RoundedTopPanelPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}
