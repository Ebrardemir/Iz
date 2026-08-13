/// ANI FORMUNDAKİ SEÇİM LİSTELERİ İÇİN GEÇİCİ VERİ.
///
/// ⚠️ ÜRETİM VERİSİ DEĞİL. Kişi, koleksiyon ve seri kayıtlarını okuyacak
/// katman henüz yok (`PersonDao`, `CollectionDao`, `RitualDao` yazılmadı).
/// Formdaki dört seçim satırının GERÇEKTEN çalıştığını görebilmek için
/// listelere elle veri koyuyoruz.
///
/// KATEGORİ BURADA YOK — bilerek. Sistem kategorileri kodda tanımlı
/// (`SystemCategory`) ve adları çeviriden geliyor; uydurmaya gerek yok.
/// Formda kategori seçenekleri doğrudan oradan üretiliyor.
///
/// Bu dosya, veri hattı bağlandığında SİLİNECEK: `memory_editor_view.dart`
/// içindeki üç `MemoryFormPreviewData.…` çağrısı provider'lara dönüşecek,
/// başka hiçbir satır değişmeyecek.
///
/// İçindeki "Annem", "Kapadokya 2026" gibi metinler KULLANICI VERİSİ taklidi —
/// çeviriden geçmezler, geçmemeleri de gerekir. Çeviri koruma testi
/// (`test/unit/l10n_test.dart`) sabit Türkçe metin arıyor; istisnayı ekranın
/// tamamına açmak yerine yalnızca bu dosyaya açtık — `home_preview_data.dart`
/// ve `my_life_preview_data.dart` ile aynı gerekçe.
library;

import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/shared/widgets/iz_selection_dialog.dart';

abstract final class MemoryFormPreviewData {
  /// FR-016 — anıya bağlanabilecek kişiler.
  ///
  /// İkon HERKESTE AYNI (tek kişi simgesi): gerçek veride burada kişinin
  /// fotoğrafı olacak, ikon değil. Şimdilik hepsine aynısını koymak,
  /// "kişiler farklı ikonlara sahip" gibi yanlış bir tasarım izlenimi
  /// bırakmamak için.
  static const List<IzSelectionOption> people = [
    (id: 'person_1', label: 'Annem', icon: AppIcons.person),
    (id: 'person_2', label: 'Babam', icon: AppIcons.person),
    (id: 'person_3', label: 'Elif', icon: AppIcons.person),
    (id: 'person_4', label: 'Deniz', icon: AppIcons.person),
    (id: 'person_5', label: 'Kerem', icon: AppIcons.person),
  ];

  /// FR-074 — bir anı birden fazla koleksiyona girebilir.
  static const List<IzSelectionOption> collections = [
    (id: 'collection_1', label: 'Kapadokya 2026', icon: AppIcons.collection),
    (
      id: 'collection_2',
      label: 'Üniversite Yılları',
      icon: AppIcons.collection,
    ),
    (id: 'collection_3', label: 'Mutfak Denemeleri', icon: AppIcons.collection),
  ];

  /// FR-017 — anı en çok bir seriye bağlanır.
  ///
  /// İkonlar `AppIcons.byKey` üzerinden: gerçek veride serinin `iconKey`i
  /// veritabanından gelecek, çeviriye değil o anahtara bakılacak.
  static final List<IzSelectionOption> series = [
    (
      id: 'series_1',
      label: 'Yaz Tatillerimiz',
      icon: AppIcons.forKey('summer'),
    ),
    (id: 'series_2', label: 'Doğum Günleri', icon: AppIcons.forKey('birthday')),
    (
      id: 'series_3',
      label: 'Evlilik Yıldönümü',
      icon: AppIcons.forKey('anniversary'),
    ),
  ];
}
