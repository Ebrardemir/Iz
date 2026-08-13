/// Kullanıcının yazdığı ilişki metninden [RelationType] çıkarma.
///
/// NEDEN `domain/`?
/// Bu bir SUNUM işi değil, bir veri yorumlama kuralı: kullanıcının yazdığı
/// metinden anlam çıkarıp iş kurallarını (filtreleme, doğum günü ritüeli
/// önerileri — FR-064) besliyor. Ekranın hangi metni gösterdiğiyle ilgisi yok.
///
/// Ayrıca burada durması çeviri koruma testiyle de uyumlu: aşağıdaki Türkçe
/// kelimeler ÇEVRİLECEK METİN DEĞİL, tanınacak kök. Test `presentation/`
/// altındaki Türkçe metinleri arıyor ve orada dururken haklı olarak
/// yakalıyordu.
library;

import 'package:iz/core/text/search_key.dart';
import 'package:iz/features/people/domain/entities/person.dart';

/// Kullanıcının yazdığı ilişki metninden [RelationType] tahmin eder.
///
/// NEDEN TAHMİN? Kullanıcı ilişkiyi kendi kelimeleriyle yazıyor ("Annem",
/// "Kankam") ama filtreleme ve doğum günü ritüeli önerileri (FR-064) bir TÜRE
/// ihtiyaç duyuyor. Ondan bir de listeden seçim istemek formu iki kez aynı
/// soruyu sorar hâle getirirdi.
///
/// TAHMİN YANLIŞ OLABİLİR ve sorun değil: ekranda görünen şey kullanıcının
/// yazdığı metin (bkz. [relationDisplay]). Tür yalnızca arka plandaki
/// önerileri besliyor; tanınmayan her şey [RelationType.other] oluyor.
///
/// SAF FONKSİYON: dili bilmiyor, Türkçe kökleri tanıyor. Uygulama başka bir
/// dile açıldığında burası o dilin köklerini de bilmek zorunda kalacak —
/// o gün geldiğinde tablo dile göre bölünecek.
RelationType guessRelationType(String label) {
  final key = localeSearchKey(label);
  if (key.isEmpty) return RelationType.other;

  // SIRA ÖNEMLİ: "anneanne" hem "anne" hem "anneanne" ile eşleşiyor ve
  // büyükanne olarak tanınması gerekiyor, o yüzden uzun kökler önce.
  const roots = <(String, RelationType)>[
    ('anneanne', RelationType.grandparent),
    ('babaanne', RelationType.grandparent),
    ('dede', RelationType.grandparent),
    ('büyükanne', RelationType.grandparent),
    ('büyükbaba', RelationType.grandparent),
    ('torun', RelationType.grandchild),
    ('anne', RelationType.parent),
    ('baba', RelationType.parent),
    ('kardeş', RelationType.sibling),
    ('abla', RelationType.sibling),
    ('abi', RelationType.sibling),
    ('ağabey', RelationType.sibling),
    ('kız', RelationType.child),
    ('oğl', RelationType.child),
    ('eş', RelationType.partner),
    ('kocam', RelationType.partner),
    ('karım', RelationType.partner),
    ('sevgili', RelationType.partner),
    ('nişanlı', RelationType.partner),
    ('arkadaş', RelationType.friend),
    ('kanka', RelationType.friend),
    ('dost', RelationType.friend),
    ('meslektaş', RelationType.colleague),
    ('iş arkadaş', RelationType.colleague),
    ('teyze', RelationType.relative),
    ('hala', RelationType.relative),
    ('amca', RelationType.relative),
    ('dayı', RelationType.relative),
    ('kuzen', RelationType.relative),
    ('yeğen', RelationType.relative),
    ('kedi', RelationType.pet),
    // 'köpe', 'köpek' DEĞİL: ünsüz yumuşaması. "köpeğim" içinde "köpek"
    // geçmiyor (k → ğ) ve tam kök yazınca en yaygın hâli kaçırıyorduk.
    ('köpe', RelationType.pet),
    ('kuş', RelationType.pet),
    ('ben', RelationType.self),
    ('kendim', RelationType.self),
  ];

  for (final (root, type) in roots) {
    if (key.contains(localeSearchKey(root))) return type;
  }
  return RelationType.other;
}
