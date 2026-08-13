/// Alt gezinme çubuğunu barındıran kabuk.
///
/// `navigationShell.goBranch` ile sekme değiştiriyoruz; bu, her sekmenin
/// kendi geçmişini ve kaydırma konumunu korumasını sağlar. Aynı sekmeye
/// tekrar basıldığında `initialLocation: true` ile o sekmenin köküne dönülür.
///
/// SEKME SIRASI, `app_router.dart`taki `branches` SIRASIYLA BİREBİR AYNI
/// OLMALI — `navigationShell.currentIndex` doğrudan o sıraya karşılık gelir.
/// Sıra kaydığında ekranlar sessizce yanlış sekmede açılır: derleyici susar,
/// uygulama açılır, sadece "Hayatım"a dokunan kullanıcı Mağaza'yı görür.
///
/// Bekçisi `test/widget/app_shell_test.dart`: her sekmeye ADIYLA dokunup
/// beklenen rotanın açıldığını doğruluyor. Sekme eklerken/taşırken o testteki
/// `_expectedTabs` listesini de güncellemen gerekir — kasten öyle yazıldı.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_add_menu.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: IzBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          // Aynı sekmeye tekrar dokunulduysa o sekmenin köküne dön.
          initialLocation: index == navigationShell.currentIndex,
        ),
        // Sekme listesi TEK YERDE (bkz. `IzBottomNav.appTabs`): anı detayı da
        // aynı çubuğu kuruyor ve iki listenin ayrışması sessiz bir hata.
        destinations: IzBottomNav.appTabs(l10n),

        // Ortadaki daire bir SEKME DEĞİL, bir eylem: sekme değiştirmiyor,
        // ekranın ortasında bir halka menü açıyor. Bu yüzden `goBranch`
        // kullanmıyoruz — kullanıcı menüden çıktığında hangi sekmedeyse
        // orada kalır.
        addIcon: AppIcons.add,
        addLabel: l10n.navAdd,
        onAdd: () => showAppAddMenu(context),
      ),
    );
  }

  /// Alt çubuktaki "+" düğmesinin açtığı ekleme menüsü.
  ///
}
