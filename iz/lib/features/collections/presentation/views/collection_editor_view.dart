/// Koleksiyon formu — FR-074, FR-078.
///
/// TEK EKRAN, İKİ KİP. [collectionId] null ise "Yeni Koleksiyon", doluysa
/// "Koleksiyonu Düzenle". Ayrı bir düzenleme ekranı yazmak aynı alanları,
/// aynı doğrulamayı ve aynı anı seçicisini ikinci kez yazmak olurdu; ikisi
/// zamanla birbirinden ayrılırdı. Kişi formundaki kararın aynısı.
///
/// DÜZENLEME KİPİ NEDEN GEREKLİ: koleksiyon kurulduktan sonra içindeki
/// anıları değiştirmenin başka yolu yoktu. Veri katmanı bunu baştan beri
/// destekliyordu (`CollectionDraft.memoryIds`), eksik olan ekrandı.
///
/// YERLEŞİM (referans tasarım):
///   ┌──────────────────────────────┐
///   │ ‹      Yeni Koleksiyon       │
///   │ ┌──────────────────────────┐ │
///   │ │   ⛰ çizim          (+)   │ │  kapak: dokun → galeri
///   │ │   Kapak Görseli Ekle     │ │
///   │ └──────────────────────────┘ │
///   │ [ T  │ Koleksiyon Adı     ]  │
///   │ [ ≡  │ Açıklama           ]  │
///   │ [ 📅 │ Tarih Aralığı      ]  │  → tek takvimde başlangıç ve bitiş
///   │ [ 🖼 │ İlk Anıları Ekle ›  ]  │  → anı seçme sayfası
///   │ [   Koleksiyonu Oluştur    ] │
///   └──────────────────────────────┘
///
/// SERİ FORMUYLA AYNI PARÇALAR: kapak kutusu, satırlar ve anı seçme ekranı
/// `shared/`ta yaşıyor (`IzCoverPicker`, `IzFormRow`,
/// `IzMemoryPickerView`). İki form birbirinin kopyası değil, aynı parçaların
/// iki farklı dizilişi — biri düzeltilince öteki de düzeliyor.
///
/// TARİH ARALIĞI VAR, seride YOK — ikisi de bilinçli.
/// Seride tarih sormuyoruz çünkü ritüelin zamanı anılarından geliyor (kullanıcı
/// böyle istedi). Koleksiyon ise çoğu zaman anılardan ÖNCE kuruluyor: "Kapadokya
/// 2026" seyahate çıkmadan açılıyor ve tarih aralığı o boş koleksiyona kimliğini
/// veren şey. Alan zaten domainde de var (`MemoryCollection.startDate/endDate`).
/// Yine de OPSİYONEL: boş bırakılırsa koleksiyon tarihsiz yaşıyor.
///
/// APPBAR'DA TİK YOK — seri formundaki kararın aynısı: iki ayrı "bitir"
/// düğmesi hangisinin ne yaptığını sorduruyor. Oluşturma tek yerde, sayfanın
/// sonundaki düğmede.
///
/// KİŞİ VE KATEGORİ ALANLARI KALDIRILDI — sebebi burada yazılı.
///
/// Form bir süre ikisini de soruyordu ama `Collections` tablosunda karşılık
/// gelen sütun yok (TRD M6.1) ve kategori zaten ANIYA ait (TR-M6-03).
/// Yani kullanıcı seçim yapıyor, hiçbir yere yazılmıyordu — sessiz veri
/// kaybı. Üstelik kişi listesi de önizleme verisiydi.
///
/// KATEGORİ tamamen kalktı: anının özelliği, anı formunda çalışıyor.
///
/// KİŞİ bilgisi KAYBOLMADI, yerini TÜRETMEYE bıraktı: koleksiyonun kişileri
/// = içindeki anılarda etiketli kişiler. Elle yazılan liste eskir (sonradan
/// eklenen anıdaki kişiyi bilmez), türetilen liste eskimez. Görüntülendiği
/// yer koleksiyon detay ekranı olacak.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/composition/collections_with_memories.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/extensions/date_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/collections/collections_providers.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/media/media_providers.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/shared/widgets/iz_cover_picker.dart';
import 'package:iz/shared/widgets/iz_form_row.dart';

class CollectionEditorView extends ConsumerStatefulWidget {
  const CollectionEditorView({this.collectionId, super.key});

  /// `null` → yeni koleksiyon; dolu → düzenleme.
  final String? collectionId;

  /// FR-074 — koleksiyon adı (`Collections.title` kolonu 1..120).
  static const int kTitleMaxLength = 120;

  /// Kısa açıklama.
  static const int kDescriptionMaxLength = 280;

  @override
  ConsumerState<CollectionEditorView> createState() =>
      _CollectionEditorViewState();
}

class _CollectionEditorViewState extends ConsumerState<CollectionEditorView> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Seçilen kapak — kalıcı bir [MediaItem].
  ///
  /// Dosya uygulama alanına kopyalanıp `MediaItems` tablosuna yazıldıktan
  /// sonra buraya konuyor; `coverMediaId` gerçek bir satıra işaret ediyor.
  MediaItem? _cover;

  DateTimeRange? _dateRange;

  List<Memory> _memories = const [];

  /// Ad boşken eylem düğmesine basılırsa görünüyor.
  String? _titleError;

  /// `didChangeDependencies` birden çok kez çağrılabiliyor (tema, klavye,
  /// dil değişimi). Bayrak olmasaydı ikinci çağrı kullanıcının yazdıklarının
  /// üstüne yazardı. Kişi formundaki notun aynısı.
  bool _loaded = false;

  bool get _isEditing => widget.collectionId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    final collectionId = widget.collectionId;
    if (collectionId == null) return;

    // FORMU DEPODAN DOLDURUYORUZ. Okuma asenkron olduğu için ayrı bir
    // metotta: ilk kare boş form, veri gelince alanlar doluyor.
    unawaited(_loadCollection(collectionId));
  }

  /// Düzenlenecek koleksiyonu okuyup alanları doldurur.
  ///
  /// Kayıt bulunamazsa form BOŞ KALIYOR ve ekran kapanmıyor: kullanıcı
  /// silinmiş bir koleksiyonun bağlantısına tıklamış olabilir; onu boş bir
  /// forma bırakmak, hata ekranına atmaktan daha az can sıkıcı.
  Future<void> _loadCollection(String collectionId) async {
    final result = await ref
        .read(collectionRepositoryProvider)
        .findCollection(collectionId);
    if (!mounted) return;

    final collection = switch (result) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (collection == null) return;

    _titleController.text = collection.title;
    _descriptionController.text = collection.description ?? '';

    if (collection.startDate case final start?) {
      _dateRange = DateTimeRange(
        start: start,
        end: collection.endDate ?? start,
      );
    }

    // MEVCUT KAPAĞI DA GERİ YÜKLÜYORUZ. Yüklemeseydik `_cover` boş kalır ve
    // kaydetme `coverMediaId: null` yazardı: kullanıcı yalnız adını
    // düzeltmek için formu açtığında kapağı sessizce silinirdi.
    if (collection.coverMediaId case final mediaId?) {
      final media = await ref.read(mediaRepositoryProvider).findMedia(mediaId);
      if (!mounted) return;
      if (media case Ok(:final value)) _cover = value;
    }

    await _loadMemories(collectionId);
    if (!mounted) return;

    setState(() {});
  }

  /// Koleksiyondaki anıları şeride yükler.
  ///
  /// KOMPOZİSYON KÖKÜNDEN okunuyor: bağ `CollectionRepository`de ama
  /// anıların kendisi `MemoryRepository`de ve bu form başka bir feature'ın
  /// veri katmanına uzanamaz (TR-C-03). İkisini birleştiren yer
  /// `app/composition/collections_with_memories.dart`.
  ///
  /// ANILAR YÜKLENMEZSE kaydetme `memoryIds: []` yazar ve koleksiyonun
  /// içindekiler sessizce boşalırdı — bu yüzden yükleme kaydetmenin ÖN
  /// KOŞULU (bkz. [_persist]).
  Future<void> _loadMemories(String collectionId) async {
    try {
      _memories = await ref.read(
        collectionMemoriesProvider(collectionId).future,
      );
      _memoriesLoaded = true;
    } on Object {
      // Yüklenemedi: `_memoriesLoaded` false kalıyor ve kaydetme bağlara
      // DOKUNMUYOR. Kullanıcı yine de adını düzeltebilsin.
      _memoriesLoaded = false;
    }
  }

  /// Düzenleme kipinde anılar okunabildi mi?
  ///
  /// Yeni koleksiyonda okunacak bir şey yok, o yüzden baştan `true`.
  bool _memoriesLoaded = true;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _isEditing ? l10n.collectionEditTitle : l10n.collectionNewTitle,
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          IzCoverPicker(cover: _cover, onPick: _pickCover),
          const SizedBox(height: AppSpacing.md),

          // --- AD ------------------------------------------------------------
          IzFormCard(
            child: IzFormRow(
              icon: AppIcons.textField,
              label: l10n.collectionFieldName,
              child: IzInlineField(
                controller: _titleController,
                hint: l10n.collectionFieldNameHint,
                maxLength: CollectionEditorView.kTitleMaxLength,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  // Yazmaya başlayınca hata kalksın.
                  if (_titleError != null) setState(() => _titleError = null);
                },
              ),
            ),
          ),
          if (_titleError case final error?) _ErrorNote(error),
          const SizedBox(height: AppSpacing.sm),

          // --- AÇIKLAMA ------------------------------------------------------
          IzFormCard(
            child: IzFormRow(
              icon: AppIcons.description,
              label: l10n.collectionFieldDescription,
              child: IzInlineField(
                controller: _descriptionController,
                hint: l10n.collectionFieldDescriptionHint,
                maxLength: CollectionEditorView.kDescriptionMaxLength,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // --- TARİH ARALIĞI -------------------------------------------------
          IzFormCard(
            child: IzFormRow(
              icon: AppIcons.date,
              label: l10n.collectionFieldDateRange,
              // TEK TAKVİMDE İKİ TARİH (`showDateRangePicker`): iki ayrı
              // seçici açmak kullanıcıyı iki kez aynı aya götürüyordu ve
              // "bitiş başlangıçtan önce olamaz" kuralını da elle korumak
              // gerekiyordu. Material'ın aralık seçicisi ikisini de çözüyor.
              onTap: _pickDateRange,
              child: IzFormValue(
                value: _rangeLabel(l10n),
                hint: l10n.collectionFieldDateRangeHint,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // --- İLK ANILAR ----------------------------------------------------
          IzFormCard(
            child: IzFormRow(
              icon: AppIcons.photoLibrary,
              label: l10n.collectionFieldMemories,
              // AÇILMIYOR, SAYFA AÇIYOR: anı listesi uzun ve her satırda
              // görsel var. Bu yüzden chevron değil ok.
              trailing: Icon(
                AppIcons.forward,
                size: AppIconSize.md,
                color: context.colors.onSurfaceVariant,
              ),
              onTap: _pickMemories,
              child: IzFormValue(
                value: _memories.isEmpty
                    ? null
                    : l10n.collectionSelectedMemories(_memories.length),
                hint: l10n.collectionFieldMemoriesHint,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton.icon(
            onPressed: _create,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(AppIcons.celebrate, size: AppIconSize.md),
            label: Text(
              _isEditing
                  ? l10n.collectionSaveAction
                  : l10n.collectionCreateAction,
            ),
          ),
        ],
      ),
    );
  }

  /// Bir satırı açar, ötekini kapatır. Açık olana tekrar dokunmak kapatıyor.

  /// "10-14 Mayıs 2026" — tekrar eden ay ve yıl bir kez yazılıyor.
  String? _rangeLabel(AppL10n l10n) {
    final range = _dateRange;
    if (range == null) return null;

    return AppDateFormats.range(
      range.start,
      range.end,
      // DİLİ AÇIKÇA GEÇİYORUZ: boş bırakılırsa `Intl.defaultLocale` genel
      // değişkenine düşüyor ve ay adı İngilizce çıkabiliyor.
      locale: l10n.localeName,
    );
  }

  /// Seçili kişilerin adları — "Annem, Babam".

  /// Galeriden tek kapak.
  Future<void> _pickCover() async {
    // LİMİT 1: koleksiyonun bir kapağı var — kavramsal bir sınır.
    final result = await ref.read(mediaPickerProvider).pickImages(limit: 1);

    // Seçici uygulamanın DIŞINDA çalışıyor; dönüşte ekran hâlâ ayakta mı?
    if (!mounted) return;

    switch (result) {
      case Err(:final failure):
        context.showSnack(failure.localizedMessage(context.l10n));
      case Ok(:final value):
        final path = value.firstOrNull?.path;
        // Vazgeçti — bir hata değil, bir karar.
        if (path == null) return;
        await _importCover(path);
    }
  }

  /// Seçilen kapağı KALICI hâle getirir.
  ///
  /// Önce yalnız dosya yolunu tutan geçici bir [MediaItem] üretiliyordu;
  /// `coverMediaId` var olmayan bir kimliğe işaret ediyor ve kapak hiçbir
  /// yerde görünmüyordu. Artık dosya uygulama alanına kopyalanıyor ve
  /// `MediaItems` tablosuna bir satır yazılıyor (TR-M4-11).
  Future<void> _importCover(String path) async {
    final imported = await ref.read(mediaRepositoryProvider).importPicked([
      path,
    ]);

    if (!mounted) return;

    switch (imported) {
      case Ok(:final value):
        if (value.isNotEmpty) setState(() => _cover = value.first);
      case Err(:final failure):
        context.showSnack(failure.localizedMessage(context.l10n));
    }
  }

  Future<void> _pickDateRange() async {
    final now = ref.read(clockProvider).now();

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      // GEÇMİŞ VE GELECEK İKİSİ DE AÇIK: koleksiyon anılardan önce de
      // kurulabiliyor ("Kapadokya 2026" seyahatten önce). Anı formundaki
      // "gelecek olamaz" kuralı burada geçerli değil.
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null || !mounted) return;

    setState(() => _dateRange = picked);
  }

  /// Anı seçme sayfasını açar ve dönen seçimi alır.
  Future<void> _pickMemories() async {
    final selected = await context.pushNamed<List<Memory>>(
      AppRoute.memoryPicker.name,
      // Zaten seçili olanlar işaretli açılsın.
      extra: {for (final memory in _memories) memory.id},
    );
    if (selected == null || !mounted) return;

    setState(() {
      // Ekran seçilen anıların KENDİSİNİ döndürüyor; burada çevirecek
      // bir şey yok.
      _memories = selected;
    });
  }

  /// Doğrular, kaydeder, kapatır.
  void _create() {
    final l10n = context.l10n;
    final title = _titleController.text.trim();

    // FR-074 — ad zorunlu. Tek doğrulama bu: ötekilerin hepsi opsiyonel.
    if (title.isEmpty) {
      setState(() => _titleError = l10n.collectionNameRequired);
      return;
    }

    unawaited(_persist(title));
  }

  /// Kaydeder ve ekranı kapatır.
  ///
  /// HATADA ekran KAPANMIYOR: form dolu kalıyor ki kullanıcı yazdıklarını
  /// kaybetmesin. Kişi formundaki kararın aynısı.
  Future<void> _persist(String title) async {
    final result = await ref
        .read(collectionRepositoryProvider)
        .save(
          CollectionDraft(
            id: widget.collectionId,
            title: title,
            description: _descriptionController.text,
            coverMediaId: _cover?.id,
            startDate: _dateRange?.start,
            endDate: _dateRange?.end,
            // `null` = "bağlara DOKUNMA", `[]` = "hepsini kaldır" — ikisi
            // ayrı şey. Düzenleme kipinde anılar okunamadıysa `null`
            // yolluyoruz: boş liste göndermek koleksiyonun içindekileri
            // sessizce boşaltırdı.
            memoryIds: _memoriesLoaded
                ? [for (final memory in _memories) memory.id]
                : null,
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        // Burada BAŞARI BİLDİRİMİ VAR, kişi formunda yok — çünkü koleksiyon
        // oluşturunca kullanıcı listeye değil, geldiği yere dönüyor ve yeni
        // koleksiyonu göremiyor. Gördüğü şeyi tekrar söylemiyoruz; görmediği
        // şeyi haber veriyoruz.
        context
          ..pop()
          ..showSnack(
            _isEditing
                ? context.l10n.collectionUpdated
                : context.l10n.collectionCreated,
          );
      case Err(:final failure):
        context.showSnack(failure.localizedMessage(context.l10n));
    }
  }
}

/// Ad boşken çıkan uyarı.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.sm + 2),
    child: Text(
      message,
      style: context.text.bodySmall?.copyWith(color: context.colors.error),
    ),
  );
}
