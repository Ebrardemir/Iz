/// Takvim ızgarası: ayın günleri, bugünün vurgusu ve anısı olan günlerde
/// küçük kapak.
///
/// SAF WIDGET: hangi ayda olduğumuzu, bugünün hangi gün olduğunu ve hangi
/// günde anı bulunduğunu DIŞARIDAN alır. Böylece "bugün" testte sabitlenip
/// vurgunun doğru güne düştüğü sınanabiliyor.
///
/// ÖLÇÜLER (Figma, 390 genişlikte çerçeve):
///   ızgara → 350 × 336, top 216, left 20
///   hücre  → 48.86 × 48, gap 2, köşe 8
///   kapak  → 24 × 20, köşe 5, kırparak sığdır
///
/// ÖLÇÜLER NASIL UZLAŞTIRILDI?
/// Figma hücreyi 48.86 diyor ama 7 × 48.86 + 6 × 2 = 354 > 350. Tutarlı
/// tek okuma şu: sütun adımı 350 / 7 = 50, hücre 48, aradaki 2 boşluk.
/// Yükseklik de bunu doğruluyor — 6 hafta × (48 + 8) = 336, yani tam
/// tasarımdaki ızgara yüksekliği.
///
/// Sütun adımı gün başlığı satırıyla AYNI (`Expanded`); başlıkların
/// günlerden kayması yapısal olarak imkânsız.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/my_life/presentation/calendar_month.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    required this.month,
    required this.today,
    required this.onDaySelected,
    this.selectedDay,
    this.covers = const {},
    super.key,
  });

  /// Gösterilen ay. Yalnızca yıl ve ay kullanılır.
  final DateTime month;

  /// "Bugün" — dışarıdan geliyor ki test sabitleyebilsin.
  final DateTime today;

  /// Seçili gün. Boşsa bugün seçili sayılır.
  final DateTime? selectedDay;

  /// Anısı olan günlerin kapak görselleri: gün → asset yolu.
  final Map<DateTime, String> covers;

  final ValueChanged<DateTime> onDaySelected;

  /// Figma: hücre 48 yüksek.
  static const double kCellHeight = 48;

  /// Figma ızgara yüksekliği 336; 6 hafta → satır adımı 56 → 48 + 8.
  static const double kRowGap = AppSpacing.sm;

  /// Bugünün yuvarlağı.
  ///
  /// 28 SEÇİLDİ ÇÜNKÜ TAM OTURUYOR: bir gün hem bugün olabilir hem de anısı
  /// bulunabilir; o zaman hücre içinde daire + kapak alt alta gelir.
  /// 28 + 20 = 48, yani hücrenin tam boyu. Daha büyük bir daire (32
  /// denedik) o durumda taşıyordu.
  static const double kTodayCircle = AppIconSize.lg;

  /// Figma: kapak 24 × 20, köşe 5.
  static const double kCoverWidth = 24;
  static const double kCoverHeight = 20;

  @override
  Widget build(BuildContext context) {
    final days = CalendarMonth.daysOf(month);
    final selected = selectedDay ?? today;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MyLifeLayout.pageInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (
            var week = 0;
            week * MyLifeLayout.weekdayCount < days.length;
            week++
          ) ...[
            if (week > 0) const SizedBox(height: kRowGap),
            Row(
              children: [
                for (var i = 0; i < MyLifeLayout.weekdayCount; i++)
                  // EŞİT SÜTUNLAR: gün başlığı satırıyla aynı bölme.
                  Expanded(
                    child: _DayCell(
                      day: days[week * MyLifeLayout.weekdayCount + i],
                      month: month,
                      today: today,
                      selected: selected,
                      cover: _coverFor(
                        days[week * MyLifeLayout.weekdayCount + i],
                      ),
                      onPressed: onDaySelected,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _coverFor(DateTime day) {
    for (final entry in covers.entries) {
      if (CalendarMonth.isSameDay(entry.key, day)) return entry.value;
    }
    return null;
  }
}

/// Tek gün hücresi.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.month,
    required this.today,
    required this.selected,
    required this.cover,
    required this.onPressed,
  });

  final DateTime day;
  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final String? cover;
  final ValueChanged<DateTime> onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isToday = CalendarMonth.isSameDay(day, today);
    final isSelected = CalendarMonth.isSameDay(day, selected);
    final isInMonth = CalendarMonth.isInMonth(day, month);

    // Komşu ayın günleri SOLUK. Tasarımda zemin rengi sayfanınkiyle aynı
    // (#FAF8F3), yani ayrı bir kutu çizilmiyor — fark yalnızca yazıda.
    final numberColor = isToday
        ? colors.onPrimary
        : isInMonth
        ? colors.onSurface
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () => onPressed(day),
        borderRadius: const BorderRadius.all(AppRadius.sm),
        child: SizedBox(
          height: CalendarGrid.kCellHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  // Bugün: dolu yeşil daire. Seçili ama bugün olmayan gün
                  // için ayrı bir vurgu tasarımda yok.
                  color: isToday ? colors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: CalendarGrid.kTodayCircle,
                  height: CalendarGrid.kTodayCircle,
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: context.text.bodyMedium?.copyWith(
                        color: numberColor,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              if (cover != null) _DayCover(asset: cover!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Günün altındaki küçük kapak — o gün bir anı var demek.
class _DayCover extends StatelessWidget {
  const _DayCover({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      child: Image.asset(
        asset,
        width: CalendarGrid.kCoverWidth,
        height: CalendarGrid.kCoverHeight,
        // Figma: `scale: crop` — oranı bozmadan kutuyu doldur.
        fit: BoxFit.cover,
        // Kapak bulunamazsa hücre çökmesin.
        errorBuilder: (context, error, stack) => SizedBox(
          width: CalendarGrid.kCoverWidth,
          height: CalendarGrid.kCoverHeight,
          child: Icon(
            AppIcons.photo,
            size: AppIconSize.sm,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
