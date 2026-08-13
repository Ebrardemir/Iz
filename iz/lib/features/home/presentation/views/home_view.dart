/// Ana sayfa — MVVM'in **View** katmanı.
///
/// ⚠️ BU EKRAN HİÇBİR VERİ KAYNAĞINA BAĞLI DEĞİL — bilinçli.
///
/// Ne yerel veritabanını ne de bir servisi okur; gördüğün her şey sabit.
/// Görsel bir yer tutucu asset (kaynak/lisans: docs/assets/images.md),
/// fotoğrafın üzerindeki blok da her zaman "boş durum" varyantı.
///
/// Şu an TASARIM aşamasındayız: önce ekranlar bitecek, veri bağlantısına
/// (yerel mi, arkadaşımın backend'i mi) sonra karar verilecek. Bu yüzden
/// burada bir ViewModel yok ve `ref` de yok — ekranın veriye bağlı olduğu
/// izlenimini vermesin diye.
///
/// BAĞLANDIĞINDA NE OLACAK? Fotoğrafın üzerindeki blok zaten iki varyantlı
/// (bkz. [HomeHeroOverlay]); `memory` alanına bir kayıt verildiği anda
/// "bugünün izi" görünümüne geçiyor. Tasarımda değişiklik gerekmeyecek.
///
/// ⚠️ YAPIM AŞAMASINDA: kavisin altına istatistik kartları ve son anılar
/// listesi gelecek.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_colors.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/home/presentation/views/home_preview_data.dart';
import 'package:iz/features/home/presentation/widgets/home_hero_overlay.dart';
import 'package:iz/features/home/presentation/widgets/home_recent_section.dart';
import 'package:iz/features/home/presentation/widgets/home_stats_grid.dart';
import 'package:iz/shared/widgets/curved_top_panel.dart';

/// Fotoğrafın üzerine serilen karartma — tasarımdan: `#00000059`.
///
/// Kapak fotoğrafı kullanıcıdan geleceği için rengi öngörülemez; bu katman
/// beyaz metinlerin her fotoğrafta okunmasını garantiliyor.
const Color _kHeroScrim = Color(0x59000000);

/// TASARIM ÖNİZLEME ANAHTARI.
///
/// Ekran veriye bağlı olmadığı için "kullanıcının anısı var mı" sorusunun
/// cevabını burada elle veriyoruz. `false` yaparsan ekranın boş hâli
/// görünür: fotoğrafın üzerinde "İlk İzini Bırak", altta "Burada henüz bir
/// iz yok" bloğu.
///
/// Veri bağlandığında bu sabit silinecek; yerine ViewModel'in ürettiği
/// state gelecek. İkisi de TASARLANDI ve test edildi, hangisinin
/// gösterileceği yalnızca veriye bakacak.
const bool _kPreviewHasMemories = true;

class HomeView extends StatelessWidget {
  const HomeView({this.hasMemories = _kPreviewHasMemories, super.key});

  /// Kullanıcının anısı var mı?
  ///
  /// ⚠️ GEÇİCİ. Ekran veriye bağlı olmadığı için bu bilgiyi dışarıdan
  /// alıyoruz; varsayılanı [_kPreviewHasMemories]. Testler iki hâli de
  /// açıkça kurabilsin diye parametre — yoksa dosya sabitini değiştirmeden
  /// boş hâli sınamak imkânsız olurdu.
  ///
  /// Veri bağlandığında bu alan silinecek, yerine ViewModel gelecek.
  final bool hasMemories;

  /// Görselin ekran yüksekliğine oranı. Kavisli panel bunun üzerine biner.
  ///
  /// Figma'da fotoğraf 346/844 ≈ %41. Bizde %47, çünkü fotoğrafın üzerindeki
  /// her şey tasarımdakinden bilerek büyük: başlık 28 yerine 36, ikincil
  /// satır 12 yerine 16, buton yazısı 10 yerine 16, buton öncesi boşluk 8
  /// yerine 24. Blok bu yüzden 166 değil ~215 px. Daha küçük oranlarda dolu
  /// varyant (iki satır başlık) sığmayıp küçülerek çiziliyordu — özellikle
  /// 360×800 gibi yaygın telefonlarda.
  /// Testler de bu değeri kullanıyor: elle kopyalanınca ölçüler sessizce
  /// birbirinden ayrılıyor (bir kez tam bunu yaşadık).
  static const double kHeroRatio = 0.47;
  static const double kHeroMin = 240;
  static const double kHeroMax = 420;

  /// Fotoğrafın yüksekliği. Fotoğrafın üzerine çizen her şey (metin bloğu,
  /// kavis) buna bağlı olduğu için tek bir yerden hesaplanıyor.
  static double heroHeightFor(double screenHeight) =>
      (screenHeight * kHeroRatio).clamp(kHeroMin, kHeroMax);

  /// Sayacın özetlediği bölüme gider.
  ///
  /// SEKME ROTALARINA `go`, ÖTEKİLERE `push`.
  ///
  /// Fark önemli: "Hayatım" alt çubuktaki bir sekme ve oraya gitmek EKRAN
  /// DEĞİŞTİRMEK değil SEKME DEĞİŞTİRMEK. `push` etseydik Hayatım ana
  /// sayfanın üstüne biner, alt çubuk hâlâ "Ana Sayfa"yı vurgular ve geri
  /// tuşu kullanıcıyı beklenmedik bir yere düşürürdü. Günlük ve Kişiler ise
  /// tam ekran sayfalar; onlar üste açılıyor ve geri tuşuyla kapanıyor.
  static void _openSection(
    BuildContext context,
    AppRoute route, {
    Map<String, String> query = const {},
  }) {
    if (AppRoute.tabs.contains(route)) {
      context.goNamed(route.name, queryParameters: query);
      return;
    }
    // `pushNamed` bir `Future` döner (sayfa kapanınca sonucu); burada
    // beklenecek bir sonuç yok.
    unawaited(context.pushNamed(route.name, queryParameters: query));
  }

  /// Anı detayına gider.
  ///
  /// ÖNİZLEME KAYDINI YANINDA GÖTÜRÜYOR. Bu ekran henüz hiçbir veri kaynağına
  /// bağlı değil; gösterdiği anılar `HomePreviewData` içindeki sahte kayıtlar
  /// ve kimliklerinin veritabanında karşılığı yok. Düz bir geçiş kullanıcıyı
  /// "Bulunamadı" ekranına düşürürdü.
  ///
  /// Kimlik TANINMAZSA `extra` boş gidiyor ve detay ekranı eskisi gibi depodan
  /// okuyor — yani gerçek bir anı için doğru davranış bozulmuyor.
  ///
  /// Veri bağlandığında yalnızca `extra` argümanı silinecek.
  static void _openMemory(BuildContext context, String id) => context.pushNamed(
    AppRoute.memoryDetail.name,
    pathParameters: {'id': id},
    extra: HomePreviewData.detailFor(id),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final heroHeight = heroHeightFor(constraints.maxHeight);

          // Panel, yayın yüksekliği kadar görselin üzerine biner: yayın
          // tepesi tam olarak görselin bittiği yere denk gelsin diye.
          final curve = CurvedTopPanel.curveHeightFor(constraints.maxWidth);

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Stack(
                children: [
                  SizedBox(
                    height: heroHeight,
                    width: double.infinity,
                    // Yazılar fotoğrafın ÜZERİNDE: görsel tam ekran olduğu
                    // için marka, zil ve metin bloğu onun üstüne biniyor.
                    // `StackFit.expand` şart — katman fotoğrafın tamamını
                    // kaplamazsa dikey hizalama (aşağıdan sabitleme) çalışmaz.
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const _HomeHero(),

                        // KARARTMA KATMANI — tasarımdan: #00000059 (%35 siyah).
                        //
                        // Buradaki fotoğraf kullanıcının anısının kapağı;
                        // hangi renkte geleceğini bilemeyiz. Açık bir kare
                        // gelirse beyaz yazılar kaybolur. İnce bir karartma
                        // fotoğrafı bozmadan zemini öngörülebilir yapıyor.
                        const ColoredBox(color: _kHeroScrim),
                        HomeHeroOverlay(
                          memory: hasMemories ? HomePreviewData.today : null,
                          onViewMemory: () =>
                              _openMemory(context, HomePreviewData.today.id),
                          // Zil ŞİMDİDEN tıklanabilir: bildirim ekranı henüz
                          // tasarlanmadığı için hazır "yakında" metnini
                          // gösteriyor. Tıklanmayan buton bozuk gelir; ekran
                          // hazır olunca burası `pushNamed(...)` olacak.
                          onNotificationsPressed: () => context.showSnack(
                            context.l10n.screenComingSoonMessage,
                          ),
                          onAddMemory: () =>
                              context.pushNamed(AppRoute.memoryNew.name),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: heroHeight - curve),
                    // `width: double.infinity` UNUTULMAMALI.
                    // Stack, konumlandırılmamış çocuklarına GEVŞEK kısıt verir
                    // (minWidth: 0). İçerik boşken panel kendini 0 genişlikte
                    // ölçüyor ve yay hiç görünmüyordu. Burada genişliği açıkça
                    // ekrana eşitliyoruz.
                    child: SizedBox(
                      width: double.infinity,
                      child: ConstrainedBox(
                        // Panel sayfanın sonuna kadar uzasın.
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - heroHeight + curve,
                        ),
                        child: CurvedTopPanel(
                          color: context.colors.surface,
                          // İçerik, yayın EN ALÇAK noktasından (köşeler) sonra
                          // başlamalı; yoksa kenarlarda kırpılır.
                          child: Padding(
                            padding: EdgeInsets.only(top: curve),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Referansta ızgara fotoğrafın hemen altında
                                // başlıyor; araya boşluk KOYMUYORUZ. Nefesi
                                // hücrelerin kendi üst dolgusu (12) veriyor.
                                HomeStatsGrid(
                                  stats: HomePreviewData.stats(
                                    context,
                                    // Sayaçlar birer ÖZET: dokununca
                                    // özetledikleri bölüme götürüyorlar.
                                    onOpen: (route, {query = const {}}) =>
                                        _openSection(
                                          context,
                                          route,
                                          query: query,
                                        ),
                                  ),
                                ),

                                // Figma: ızgaranın altı 506, başlık satırı
                                // 512 → 6. Başlığın kendi 10'luk dolgusu
                                // görünen nefesi zaten veriyor.
                                const SizedBox(height: AppSpacing.sm),
                                HomeRecentSection(
                                  memories: hasMemories
                                      ? HomePreviewData.memories
                                      : const [],
                                  onSeeAll: () =>
                                      context.pushNamed(AppRoute.memories.name),
                                  onOpenMemory: (memory) =>
                                      _openMemory(context, memory.id),
                                ),

                                // Panelin dibinde nefes payı: son buton alt
                                // çubuğa yapışmasın.
                                const SizedBox(height: AppSpacing.xl),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Bugünün İzi" görseli.
///
/// SAF WIDGET: veri almaz, sadece çizer. Üzerine gelecek yazılar (başlık,
/// tarih, "Anıyı Gör" butonu) bir sonraki adımda buraya eklenecek.
class _HomeHero extends StatelessWidget {
  const _HomeHero();

  static const String _asset = 'assets/images/home/hero_today.jpg';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // Görsel yüklenemezse ekran çökmesin.
      errorBuilder: (context, error, stack) => ColoredBox(
        color: context.isDarkMode
            ? AppColorsDark.brandDefault
            : AppColorsLight.brandDefault,
        child: const Center(child: Icon(AppIcons.photo)),
      ),
    );
  }
}
