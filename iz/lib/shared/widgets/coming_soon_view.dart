/// Henüz tasarlanmamış sekmelerin yer tutucusu.
///
/// NEDEN AYRI BİR BİLEŞEN?
/// Alt çubukta yeni sekmeler var ama ekranları henüz tasarlanmadı. Her biri
/// için ayrı bir "boş ekran" yazmak, tasarım geldiğinde silinecek üç kopya
/// demek olurdu. Tek bileşen: sekme adını ve ikonunu alır.
///
/// ⚠️ GEÇİCİ. Bir sekmenin tasarımı geldiğinde bu ekran o sekme için gerçek
/// View ile değiştirilir; hepsi bittiğinde bu dosya silinir.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';

class ComingSoonView extends StatelessWidget {
  const ComingSoonView({required this.title, required this.icon, super.key});

  /// Sekmenin adı — AppBar'da görünür.
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AppEmptyState(
        icon: icon,
        title: l10n.screenComingSoon,
        message: l10n.screenComingSoonMessage,
      ),
    );
  }
}
