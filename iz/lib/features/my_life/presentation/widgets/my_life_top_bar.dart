/// "Hayatım" ekranının üst şeridi: solda başlık, sağda arama ve filtre.
///
/// ŞERİDİN KENDİSİ ARTIK `shared/` ALTINDA ([IzScreenHeader]).
/// "Kişilerim" ekranı da aynı şeridi taşıyor; ölçüleri (durum çubuğu payı,
/// kenar marjı, Cormorant 24) iki yere elle yazmak birini değiştirdiğimizde
/// ötekinin sessizce geride kalması demekti. Burada kalan tek şey BU EKRANA
/// AİT olan: hangi başlık, hangi eylemler.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/shared/widgets/iz_icon_action.dart';
import 'package:iz/shared/widgets/iz_screen_header.dart';

class MyLifeTopBar extends StatelessWidget {
  const MyLifeTopBar({
    required this.onSearch,
    required this.onFilter,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onFilter;

  /// Şeridin üstten uzaklığı — testler ve öteki bloklar buna bakıyor.
  static const double kTopInset = IzScreenHeader.kTopInset;

  @override
  Widget build(BuildContext context) {
    return IzScreenHeader(
      title: context.l10n.myLifeTitle,
      actions: [
        IzIconAction(
          icon: AppIcons.search,
          tooltip: context.l10n.commonSearch,
          onPressed: onSearch,
          color: context.colors.primary,
        ),
        IzIconAction(
          icon: AppIcons.filter,
          tooltip: context.l10n.commonFilter,
          onPressed: onFilter,
          color: context.colors.primary,
        ),
      ],
    );
  }
}
