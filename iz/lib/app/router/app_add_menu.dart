/// Alt çubuktaki "+" düğmesinin açtığı halka menü.
///
/// NEDEN BURADA, `app/router/` ALTINDA?
/// Seçenekler beş ayrı feature'a gidiyor (koleksiyon, seri, anı, günlük,
/// kişi). Böyle bir listeyi ancak her şeyi bilmeye yetkili katman kurabilir —
/// composition root'un ta kendisi (bkz. ARCHITECTURE.md bölüm 2). Menü
/// widget'ının kendisi `shared/` altında ve hiçbir feature'ı bilmiyor.
///
/// NEDEN AYRI DOSYA VE NEDEN FEATURE EKRANLARI BUNU IMPORT EDİYOR?
/// Alt çubuk yalnızca sekmelerde değil; anı, kişi ve seri detaylarında,
/// günlük ekranlarında da duruyor. Menü kabuğun (`AppShell`) içinde kapalı
/// kaldığı sürece o ekranlar "+"a basınca ne yapacaklarını kendileri
/// uyduruyordu: kişiler ekranında anı formu, günlükte günlük formu açılıyordu
/// — kullanıcı ise her yerde AYNI menüyü bekliyor ve haklı.
///
/// Bu dosya `app_routes.dart` ile aynı istisnaya giriyor: SAF bir gezinme
/// sözleşmesi (widget yok, state yok), feature'lar onu import edebilir.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/iz_radial_menu.dart';

/// MENÜNÜN İÇERİĞİ NEDEN BURADA?
/// Seçenekler birden fazla feature'a gidiyor (anı, ritüel, günlük,
/// koleksiyon, kişi). Böyle bir listeyi ancak her şeyi bilmeye yetkili
/// katman kurabilir — `app/` composition root'un ta kendisi
/// (bkz. ARCHITECTURE.md bölüm 2). Menü widget'ının kendisi ise
/// `shared/` altında ve hiçbir feature'ı bilmiyor.
///
/// SIRA TASARIMDAN: soldan sağa Koleksiyon → Ritüel → Anı → Günlük → Kişi.
/// Ortadaki (Anı) halkanın TEPESİNE düşüyor, yani asıl eylem en görünür
/// yuvada (bkz. `resolveRadialSlots`).
Future<void> showAppAddMenu(BuildContext context) {
  final l10n = context.l10n;

  // ⚠️ İKONLAR uygulamanın kendi sözlüğünden (`AppIcons`) geliyor, referans
  // görselden birebir kopyalanmadı: aynı kavramın uygulamada iki ayrı
  // simgesi olmasın. Koleksiyon her yerde açık kitap, ritüel her yerde
  // takvim-kalp (bkz. app_icons.dart'taki gerekçeler).
  return showIzRadialMenu(
    context,
    semanticTitle: l10n.addMenuTitle,
    // Alt çubuk buğulanmasın: kullanıcı menüyü nereden açtığını görsün.
    // Çubuğun kendi yüksekliği + cihazın alt güvenli alanı.
    bottomInset: IzBottomNav.height + context.viewPadding.bottom,
    actions: [
      // "Koleksiyon" formu açıyor — bir süre "yakında" diyordu.
      (
        icon: AppIcons.collection,
        label: l10n.addMenuCollection,
        onPressed: () => context.pushNamed(AppRoute.collectionNew.name),
      ),
      // "Seri" ritüel formunu açıyor — bir süre "yakında" diyordu.
      (
        icon: AppIcons.ritual,
        label: l10n.addMenuSeries,
        onPressed: () => context.pushNamed(AppRoute.ritualNew.name),
      ),
      (
        icon: AppIcons.memory,
        label: l10n.addMenuMemory,
        onPressed: () => context.pushNamed(AppRoute.memoryNew.name),
      ),
      // "Günlük" formu açıyor — bir süre "yakında" diyordu.
      (
        icon: AppIcons.navJournal,
        label: l10n.addMenuJournal,
        onPressed: () => context.pushNamed(AppRoute.journalNew.name),
      ),
      // Menüdeki "Kişi" DOĞRUDAN yeni kişi formunu açıyor.
      //
      // Bir süre "Kişilerim" listesine götürüyordu çünkü form henüz yoktu;
      // menünün işi bir şey EKLEMEK ve artık ekleyebiliyor.
      (
        icon: AppIcons.person,
        label: l10n.addMenuPerson,
        onPressed: () => context.pushNamed(AppRoute.personNew.name),
      ),
    ],
  );
}
