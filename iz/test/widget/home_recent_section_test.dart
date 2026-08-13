/// Ana sayfanın "SON ANILAR" bölümü — şu an yalnızca boş durum.
///
/// Bu bölümün Figma çizimi yok: referans tasarımda kullanıcının anıları var.
/// Boş durumu biz tasarladık, o yüzden testler ölçüden çok SÖZLEŞMEYİ
/// koruyor — hangi metinler görünür, buton eyleme bağlı mı, iki temada da
/// çiziliyor mu, dar ekranda taşıyor mu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/features/home/presentation/widgets/home_recent_section.dart';
import 'package:iz/features/home/presentation/widgets/memory_row_card.dart';

import '../helpers/real_fonts.dart';

Future<void> pumpSection(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: const Locale('tr'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: HomeRecentSection(onSeeAll: _noop, onOpenMemory: _ignore),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  testWidgets('başlık ve metinler görünür', (tester) async {
    await pumpSection(tester);

    expect(find.text('SON ANILAR'), findsOneWidget);
    expect(find.text('Burada henüz bir iz yok.'), findsOneWidget);
    expect(
      find.text('İlk anını eklediğinde burada görünmeye başlayacak.'),
      findsOneWidget,
    );
  });

  testWidgets('simge markanın kendi metaforu', (tester) async {
    await pumpSection(tester);

    // Genel bir "boş kutu" ikonu değil, ayak izleri: uygulamanın adı İZ.
    expect(find.byIcon(AppIcons.emptyTrace), findsNWidgets(3));
  });

  testWidgets('BURADA BUTON YOK', (tester) async {
    await pumpSection(tester);

    // Fotoğrafın üzerinde zaten "Anı Ekle" var. İkinci bir çağrı ikisini de
    // zayıflatıyordu; bu blok teşvik ediyor, emretmiyor.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Anı Ekle'), findsNothing);
  });

  testWidgets('izler soldan sağa büyüyerek gelir', (tester) async {
    await pumpSection(tester);

    // Yön BİLİNÇLİ: uzaklaşan (küçülen) izler veda gibi okunurdu.
    final icons = tester
        .widgetList<Icon>(find.byIcon(AppIcons.emptyTrace))
        .toList();
    expect(icons, hasLength(3));
    for (var i = 1; i < icons.length; i++) {
      expect(icons[i].size!, greaterThan(icons[i - 1].size!));
      expect(icons[i].color!.a, greaterThan(icons[i - 1].color!.a));
    }
  });

  testWidgets('başlık ekran kenarından 30 px içeride', (tester) async {
    await pumpSection(tester);

    // Bölümün KENDİSİ 20'de — sayfanın geri kalanıyla aynı hizada.
    // Başlığın kendi 10'luk dolgusu yazıyı 30'a itiyor; referans
    // ölçümünde de yazı 30-32 arasında çıkıyor.
    expect(tester.getRect(find.text('SON ANILAR')).left, 30);
  });

  testWidgets('başlık, gövde metninden küçük ve soluk', (tester) async {
    await pumpSection(tester);

    final section = tester.widget<Text>(find.text('SON ANILAR'));
    final title = tester.widget<Text>(find.text('Burada henüz bir iz yok.'));

    // Bölüm başlığı bir ETİKET: içeriğin önüne geçmemeli.
    expect(section.style!.fontSize, lessThan(title.style!.fontSize!));
    expect(section.style!.color, AppTheme.light().colorScheme.onSurfaceVariant);
  });

  for (final size in const [
    Size(320, 568), // en küçük telefon
    Size(390, 844),
    Size(430, 932),
    Size(600, 1024), // tablet
  ]) {
    testWidgets('${size.width.toInt()} px genişlikte taşmaz', (tester) async {
      await pumpSection(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Burada henüz bir iz yok.'), findsOneWidget);
    });
  }

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpSection(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(AppIcons.emptyTrace), findsNWidgets(3));
  });
}

void _noop() {}

void _ignore(MemoryRowData _) {}
