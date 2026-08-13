/// Widget testi örneği.
///
/// Rapor 18.1: "Widget/UI test: onboarding, anı formu, günlükten anıya,
/// paywall ve boş durumlar."
///
/// `MemoryCard` saf bir widget olduğu için (Riverpod'a bağlı değil)
/// ProviderScope kurmadan test edilebiliyor — bu, widget'ları Riverpod'dan
/// bağımsız yazmanın somut getirisidir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/widgets/memory_card.dart';

/// Test edilecek widget'ı gerçek uygulama bağlamına (tema + çeviri)
/// sarmalayan yardımcı. Her testte tekrarlamamak için.
Widget wrapWidget(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('tr'),
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: const [
      AppL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

Memory buildMemory({
  String? title,
  String? note,
  bool isFavorite = false,
  int mediaCount = 0,
  int personCount = 0,
  MediaItem? cover,
  String? locationLabel,
}) => Memory(
  id: 'm1',
  occurredAt: DateTime(2026, 3, 12),
  title: title,
  note: note,
  isFavorite: isFavorite,
  mediaCount: mediaCount,
  personCount: personCount,
  coverMedia: cover,
  locationLabel: locationLabel,
);

void main() {
  testWidgets('başlık ve tarih gösterilir', (tester) async {
    await tester.pumpWidget(
      wrapWidget(MemoryCard(memory: buildMemory(title: 'Kapadokya balon'))),
    );

    expect(find.text('Kapadokya balon'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
  });

  testWidgets('başlık yoksa notun ilk satırı gösterilir', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        MemoryCard(
          memory: buildMemory(note: 'Sabah erken kalktık\nSonra kahvaltı'),
        ),
      ),
    );

    expect(find.text('Sabah erken kalktık'), findsOneWidget);
  });

  testWidgets('favori durumu ekran okuyucuya bildirilir', (tester) async {
    // Lucide çizgi setidir; dolu/boş kalp ikilisi YOK. Durum zemin + renk
    // ile gösteriliyor — ama NFR-031 gereği görsel fark tek başına yetmez.
    // Bu yüzden testin doğru sorusu "ikon değişti mi" değil,
    // "durum metinsel olarak da ifade edildi mi".
    await tester.pumpWidget(
      wrapWidget(MemoryCard(memory: buildMemory(title: 'A'))),
    );
    expect(find.byTooltip('Favorilere ekle'), findsOneWidget);

    await tester.pumpWidget(
      wrapWidget(MemoryCard(memory: buildMemory(title: 'A', isFavorite: true))),
    );
    expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);

    // İkonun kendisi her iki durumda da aynı olmalı.
    expect(find.byIcon(AppIcons.favorite), findsOneWidget);
  });

  testWidgets('favori butonuna basınca callback tetiklenir', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrapWidget(
        MemoryCard(
          memory: buildMemory(title: 'A'),
          onFavoriteToggle: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(AppIcons.favorite));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('karta dokununca onTap tetiklenir', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrapWidget(
        MemoryCard(
          memory: buildMemory(title: 'A'),
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('A'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('medya ve kişi sayıları rozet olarak görünür', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        MemoryCard(
          memory: buildMemory(title: 'A', mediaCount: 3, personCount: 2),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('BR-007 — orijinali kayıp medya kartta uyarı gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWidget(
        MemoryCard(
          memory: buildMemory(
            title: 'A',
            cover: const MediaItem(
              id: 'media-1',
              type: MediaType.photo,
              originalStatus: MediaOriginalStatus.missing,
            ),
          ),
        ),
      ),
    );

    // Uyarı hem ikon hem METİN ile gösterilmeli (NFR-031).
    expect(find.text('Orijinal fotoğraf bulunamadı'), findsOneWidget);
    expect(find.byIcon(AppIcons.mediaMissing), findsWidgets);
  });
}
