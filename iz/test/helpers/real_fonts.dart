/// Testin GERÇEK fontlarla koşmasını sağlar.
///
/// `flutter test` varsayılan olarak metrikleri farklı bir yedek font kullanır;
/// o fontla ölçülen yükseklikler uygulamadakinden sapar ve "ekrana sığıyor mu"
/// testi YANLIŞ cevap verir — bu daha önce 70 px'lik hayalî bir taşma olarak
/// karşımıza çıktı. Fontları elle yükleyerek testi üretimle aynı zemine
/// oturtuyoruz.
///
/// ⚠️ Paket fontlarında aile adı `packages/<paket>/<aile>` olmak ZORUNDA;
/// yoksa metin boş kutu olarak çizilir.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadRealFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }

  await load('CormorantGaramond', [
    'assets/fonts/CormorantGaramond-Variable.ttf',
  ]);
  await load('Poppins', [
    'assets/fonts/Poppins-Regular.ttf',
    'assets/fonts/Poppins-Medium.ttf',
    'assets/fonts/Poppins-SemiBold.ttf',
  ]);
  await load('packages/lucide_icons_flutter/Lucide', [
    'packages/lucide_icons_flutter/assets/lucide.ttf',
  ]);
  await load('packages/font_awesome_flutter/FontAwesomeBrands', [
    'packages/font_awesome_flutter/lib/fonts/'
        'Font-Awesome-7-Brands-Regular-400.otf',
  ]);
}
