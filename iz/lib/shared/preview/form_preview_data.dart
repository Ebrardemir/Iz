/// FORMLARDAKİ SEÇİM LİSTELERİ İÇİN GEÇİCİ VERİ (seri ve koleksiyon).
///
/// ⚠️ ÜRETİM VERİSİ DEĞİL. Kişileri ve anıları okuyacak katman yok
/// (`PersonDao`, `RitualDao` yazılmadı); formun seçicilerinin GERÇEKTEN
/// çalıştığını görebilmek için listeleri elle yazıyoruz. Veri bağlandığında bu
/// dosya silinecek, `RitualEditorView` içindeki iki çağrı provider'a dönüşecek.
///
/// ANI LİSTESİ NEDEN "BAĞSIZ" ANILARDAN OLUŞUYOR?
/// BR — bir anı YALNIZCA BİR ritüele bağlanabilir. Yani seçiciye gelen liste
/// "tüm anılar" değil, "henüz bir ritüele bağlı olmayan anılar". Burada bunu
/// elle temsil ediyoruz ([unlinkedMemories]); backend geldiğinde sorgunun
/// `WHERE ritual_id IS NULL` koşulunu taşıması gerekiyor — kaybetmemek için
/// hem burada hem `ritual_memory_picker_view.dart` başlığında yazılı.
///
/// İçindeki "Annem", "Kahve Molası" gibi metinler KULLANICI VERİSİ taklidi —
/// çeviriden geçmezler, geçmemeleri de gerekir (`l10n_test.dart` istisnası
/// yalnızca bu dosyaya açıldı; `memory_form_preview_data.dart` ile aynı
/// gerekçe).
library;

import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/shared/widgets/iz_selection_dialog.dart';

/// Seçicide listelenen tek anı.
///
/// [dateLabel] hazır METİN: tarihi biçimlemek bir sunum kararı ve bu veri
/// dosyasının üstünde çözülüyor (`my_life_preview_data.dart` de böyle yapıyor).
typedef FormMemoryOption = ({
  String id,
  String imageAsset,
  String title,
  String dateLabel,

  /// Anının yılı — ritüel oluşurken tarih aralığı BUNLARDAN türetiliyor.
  int year,
});

abstract final class FormPreviewData {
  /// FR-064 — ritüele bağlanabilecek kişiler.
  ///
  /// İkon HEPSİNDE AYNI: gerçek veride kişinin fotoğrafı olacak. Farklı
  /// ikonlar koymak "kişilerin ikonu olur" gibi yanlış bir izlenim bırakırdı.
  static const List<IzSelectionOption> people = [
    (id: 'person-annem', label: 'Annem', icon: AppIcons.person),
    (id: 'person-babam', label: 'Babam', icon: AppIcons.person),
    (id: 'person-elif', label: 'Elif', icon: AppIcons.person),
    (id: 'person-ayse', label: 'Ayşe', icon: AppIcons.person),
    (id: 'person-dede', label: 'Dede', icon: AppIcons.person),
  ];

  /// Henüz hiçbir ritüele BAĞLI OLMAYAN anılar.
  ///
  /// Kimlikler ve başlıklar öteki önizleme verileriyle aynı ("preview-kahve",
  /// "Kahve Molası"): uygulama içinde dolaşan kullanıcı aynı anıları görsün.
  /// Yıllar BİLEREK farklı — ritüelin tarih aralığı ("2024 – 2026") ancak
  /// böyle görünür hâle geliyor.
  static const List<FormMemoryOption> unlinkedMemories = [
    (
      id: 'preview-kahve',
      imageAsset: 'assets/images/home/memory_coffee.jpg',
      title: 'Kahve Molası',
      dateLabel: '9 Ağustos 2026',
      year: 2026,
    ),
    (
      id: 'preview-izmir',
      imageAsset: 'assets/images/home/hero_today.jpg',
      title: 'İlk İzmir Tatilimiz',
      dateLabel: '18 Ağustos 2025',
      year: 2025,
    ),
    (
      id: 'preview-sahil',
      imageAsset: 'assets/images/home/memory_coffee.jpg',
      title: 'Sahilde Sabah',
      dateLabel: '3 Temmuz 2024',
      year: 2024,
    ),
    (
      id: 'preview-venedik',
      imageAsset: 'assets/images/auth/hero_light.jpg',
      title: 'Venedik Balayımız',
      dateLabel: '12 Mayıs 2024',
      year: 2024,
    ),
    (
      id: 'preview-dogum',
      imageAsset: 'assets/images/home/hero_today.jpg',
      title: 'Annemin Doğum Günü',
      dateLabel: '18 Nisan 2023',
      year: 2023,
    ),
  ];
}
