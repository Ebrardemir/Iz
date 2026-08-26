/// Ortada açılan seçim diyaloğu.
///
/// Buradaki testlerin ÇOĞU "kip" hakkında: tek seçim ve çok seçim aynı
/// bileşenden çıkıyor ve aralarındaki farkın kaybolması (örneğin tek seçimin
/// de "Tamam" beklemeye başlaması) tasarımı sessizce bozan bir hata olurdu.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/core/theme/app_theme.dart';
import 'package:iz/shared/widgets/iz_selection_dialog.dart';

import '../helpers/app_harness.dart';

const _options = <IzSelectionOption>[
  (id: 'a', label: 'Annem', icon: AppIcons.person),
  (id: 'b', label: 'Babam', icon: AppIcons.person),
  (id: 'c', label: 'Elif', icon: AppIcons.person),
];

/// Diyaloğu açar ve sonucunu döndüren bir kutu verir.
///
/// Sonucu `Future`la beklemiyoruz: diyalog açıkken test devam etmeli.
/// Kapanınca kutuya yazılıyor, biz de kutuya bakıyoruz.
Future<({List<IzSelectionResult?> results, VoidCallback open})> pumpDialog(
  WidgetTester tester, {
  required bool allowMultiple,
  Set<String> selected = const {},
  List<IzSelectionOption> options = _options,
  bool withAddNew = false,
  List<String>? addNewLog,
}) async {
  final results = <IzSelectionResult?>[];
  late BuildContext capturedContext;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Builder(
        builder: (context) {
          capturedContext = context;
          return const Scaffold();
        },
      ),
    ),
  );

  void open() {
    unawaited(
      showIzSelectionDialog(
        capturedContext,
        title: 'Kişiler',
        options: options,
        selectedIds: selected,
        allowMultiple: allowMultiple,
        onAddNew: withAddNew ? () => addNewLog?.add('tapped') : null,
      ).then(results.add),
    );
  }

  return (results: results, open: open);
}

void main() {
  testWidgets('başlık ve seçenekler görünüyor', (tester) async {
    final harness = await pumpDialog(tester, allowMultiple: false);
    harness.open();
    await settle(tester);

    expect(find.text('Kişiler'), findsOneWidget);
    for (final option in _options) {
      expect(find.text(option.label), findsOneWidget);
    }
  });

  testWidgets('TEK seçim: dokunmak hem seçer hem kapatır', (tester) async {
    // Tasarım kararı: tek seçimde ayrıca "Tamam"a basmak fazladan bir adım.
    final harness = await pumpDialog(tester, allowMultiple: false);
    harness.open();
    await settle(tester);

    expect(find.text('Tamam'), findsNothing, reason: 'tek seçimde onay yok');

    await tester.tap(find.text('Babam'));
    await settle(tester);

    expect(harness.results, [
      {'b'},
    ]);
    expect(find.text('Kişiler'), findsNothing, reason: 'diyalog kapanmalı');
  });

  testWidgets('ÇOK seçim: birkaç öğe işaretlenip onaylanıyor', (tester) async {
    final harness = await pumpDialog(tester, allowMultiple: true);
    harness.open();
    await settle(tester);

    await tester.tap(find.text('Annem'));
    await settle(tester);
    await tester.tap(find.text('Elif'));
    await settle(tester);

    // Henüz kapanmadı: çok seçimde onay bekliyoruz.
    expect(harness.results, isEmpty);

    await tester.tap(find.text('Tamam'));
    await settle(tester);

    expect(harness.results, [
      {'a', 'c'},
    ]);
  });

  testWidgets('ÇOK seçimde işaretli öğeye tekrar dokunmak kaldırıyor', (
    tester,
  ) async {
    final harness = await pumpDialog(
      tester,
      allowMultiple: true,
      selected: {'a', 'b'},
    );
    harness.open();
    await settle(tester);

    await tester.tap(find.text('Annem'));
    await settle(tester);
    await tester.tap(find.text('Tamam'));
    await settle(tester);

    expect(harness.results, [
      {'b'},
    ]);
  });

  testWidgets('vazgeçmek null döner — seçim değişmemiş sayılır', (
    tester,
  ) async {
    final harness = await pumpDialog(
      tester,
      allowMultiple: true,
      selected: {'a'},
    );
    harness.open();
    await settle(tester);

    await tester.tap(find.text('Babam')); // işaretle ama onaylama
    await settle(tester);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);

    expect(harness.results, [null], reason: 'çağıran taraf hiçbir şey yapmaz');
  });

  testWidgets('işaret biçimi kipi anlatıyor: kutu vs tik', (tester) async {
    // NFR-031 — renk tek başına bilgi taşımıyor; asıl kanal işaretin biçimi.
    final multi = await pumpDialog(
      tester,
      allowMultiple: true,
      selected: {'a'},
    );
    multi.open();
    await settle(tester);

    expect(find.byIcon(AppIcons.checkboxOn), findsOneWidget);
    expect(find.byIcon(AppIcons.checkboxOff), findsNWidgets(2));
    expect(find.byIcon(AppIcons.check), findsNothing);

    await tester.tap(find.text('Vazgeç'));
    await settle(tester);

    final single = await pumpDialog(
      tester,
      allowMultiple: false,
      selected: {'a'},
    );
    single.open();
    await settle(tester);

    expect(find.byIcon(AppIcons.check), findsOneWidget);
    expect(find.byIcon(AppIcons.checkboxOn), findsNothing);
    expect(find.byIcon(AppIcons.checkboxOff), findsNothing);
  });

  testWidgets('"+ Yeni ekle" diyaloğu KAPATIP sonra çağırıyor', (tester) async {
    // Sıra önemli: yeni kayıt ekranı diyaloğun üstüne açılmamalı.
    final log = <String>[];
    final harness = await pumpDialog(
      tester,
      allowMultiple: true,
      withAddNew: true,
      addNewLog: log,
    );
    harness.open();
    await settle(tester);

    await tester.tap(find.text('Yeni ekle'));
    await settle(tester);

    expect(log, ['tapped']);
    expect(find.text('Kişiler'), findsNothing, reason: 'önce kapandı');
    expect(harness.results, [
      null,
    ], reason: 'ekleme bir SEÇİM değil; çağıran taraf seçimi değiştirmemeli');
  });

  testWidgets('geri çağırma verilmezse "+" satırı hiç çıkmıyor', (
    tester,
  ) async {
    final harness = await pumpDialog(tester, allowMultiple: true);
    harness.open();
    await settle(tester);

    expect(find.text('Yeni ekle'), findsNothing);
  });

  testWidgets('liste boşken açıklama gösteriliyor', (tester) async {
    final harness = await pumpDialog(
      tester,
      allowMultiple: true,
      options: const [],
      withAddNew: true,
    );
    harness.open();
    await settle(tester);

    expect(
      find.text('Henüz hiç yok. Aşağıdan ekleyebilirsin.'),
      findsOneWidget,
    );
    expect(find.text('Yeni ekle'), findsOneWidget, reason: 'tek çıkış yolu');
  });

  testWidgets('satırlar dokunma hedefi ölçüsünü tutuyor', (tester) async {
    // NFR-033.
    final harness = await pumpDialog(tester, allowMultiple: false);
    harness.open();
    await settle(tester);

    for (final option in _options) {
      final row = find.ancestor(
        of: find.text(option.label),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(row.first).height,
        greaterThanOrEqualTo(AppSpacing.minTapTarget),
      );
    }
  });
}
