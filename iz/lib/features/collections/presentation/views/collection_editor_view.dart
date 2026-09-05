/// Yeni koleksiyon ekranı — FR-074, FR-078.
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
///   │ [ 👥 │ İlgili Kişiler   ⌄  ]  │  → kişilerim listesi
///   │ [ 🏷 │ Kategori         ⌄  ]  │  → sistem kategorileri
///   │ [ 🖼 │ İlk Anıları Ekle ›  ]  │  → anı seçme sayfası
///   │ [   Koleksiyonu Oluştur    ] │
///   └──────────────────────────────┘
///
/// SERİ FORMUYLA AYNI PARÇALAR: kapak kutusu, satırlar, açılır seçiciler ve
/// anı seçme ekranı `shared/`ta yaşıyor (`IzCoverPicker`, `IzFormRow`,
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
/// KİŞİ VE KATEGORİ ALANLARI KAYDEDİLMİYOR — bilinçli değil, EKSİK.
/// TRD M6.1'e göre `Collections` tablosunda yalnız `title`, `description`,
/// `coverMediaId`, `visibility`, `startDate`, `endDate` var; kategori ise
/// TR-M6-03 gereği ANIYA ait. Form bu ikisini topluyor ama gidecek sütun
/// yok. Ya formdan kaldırılmalı ya da veri modeli genişletilmeli; karar
/// verilene kadar burada AÇIKÇA yazıyor ki sessizce kaybolmasın.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:iz/features/categories/domain/entities/memory_category.dart';
import 'package:iz/features/categories/presentation/category_l10n.dart';
import 'package:iz/features/collections/data/repositories/collection_repository_impl.dart';
import 'package:iz/features/collections/domain/repositories/collection_repository.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/shared/preview/form_preview_data.dart';
import 'package:iz/shared/widgets/iz_cover_picker.dart';
import 'package:iz/shared/widgets/iz_form_row.dart';
import 'package:iz/shared/widgets/iz_memory_picker_view.dart';
import 'package:iz/shared/widgets/iz_selection_dialog.dart';

/// Formdaki açılabilir satırlar.
///
/// Enum, bool ikilisi DEĞİL: "hangisi açık" tek bir değer ve akordeon kuralını
/// (aynı anda tek satır) kodun kendisine yazıyor.
enum _CollectionSection { people, category }

class CollectionEditorView extends ConsumerStatefulWidget {
  const CollectionEditorView({super.key});

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

  /// ⚠️ GEÇİCİ [MediaItem]: medya hattı kurulmadı, elimizde yalnızca dosya
  /// yolu var (seri ve kişi formlarıyla aynı durum).
  MediaItem? _cover;

  DateTimeRange? _dateRange;

  final Set<String> _personIds = {};
  String? _categoryId;

  List<Memory> _memories = const [];

  _CollectionSection? _openSection;

  /// Ad boşken "Oluştur"a basılırsa görünüyor.
  String? _titleError;

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
      appBar: AppBar(centerTitle: true, title: Text(l10n.collectionNewTitle)),

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

          // --- İLGİLİ KİŞİLER ------------------------------------------------
          IzExpandableRow(
            icon: AppIcons.people,
            label: l10n.collectionFieldPeople,
            value: _joinLabels(FormPreviewData.people, _personIds),
            hint: l10n.collectionFieldPeopleHint,
            isExpanded: _openSection == _CollectionSection.people,
            onToggle: () => _toggleSection(_CollectionSection.people),
            children: [
              for (final person in FormPreviewData.people)
                IzOptionTile(
                  label: person.label,
                  icon: person.icon,
                  isSelected: _personIds.contains(person.id),
                  // ÇOK SEÇİM: bir koleksiyon birden fazla kişiyle
                  // paylaşılıyor, bu yüzden seçimde satır kapanmıyor.
                  allowMultiple: true,
                  onTap: () => setState(() {
                    _personIds.contains(person.id)
                        ? _personIds.remove(person.id)
                        : _personIds.add(person.id);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // --- KATEGORİ ------------------------------------------------------
          IzExpandableRow(
            icon: AppIcons.fallbackCategory,
            label: l10n.collectionFieldCategory,
            value: _categoryLabel(l10n),
            hint: l10n.collectionFieldCategoryHint,
            isExpanded: _openSection == _CollectionSection.category,
            onToggle: () => _toggleSection(_CollectionSection.category),
            children: [
              for (final category in SystemCategory.values)
                IzOptionTile(
                  label:
                      systemCategoryName(category.nameKey, l10n) ??
                      category.nameKey,
                  icon: AppIcons.forKey(category.iconKey),
                  isSelected: _categoryId == category.id,
                  allowMultiple: false,
                  onTap: () => setState(() {
                    // Aynısına tekrar dokunmak seçimi KALDIRIYOR: kategori
                    // zorunlu değil.
                    _categoryId = _categoryId == category.id
                        ? null
                        : category.id;
                    _openSection = null;
                  }),
                ),
            ],
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
            label: Text(l10n.collectionCreateAction),
          ),
        ],
      ),
    );
  }

  /// Bir satırı açar, ötekini kapatır. Açık olana tekrar dokunmak kapatıyor.
  void _toggleSection(_CollectionSection section) => setState(() {
    _openSection = _openSection == section ? null : section;
  });

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

  String? _categoryLabel(AppL10n l10n) {
    final id = _categoryId;
    if (id == null) return null;

    final category = SystemCategory.values.where((c) => c.id == id).firstOrNull;
    if (category == null) return null;

    return systemCategoryName(category.nameKey, l10n) ?? category.nameKey;
  }

  /// Seçili kişilerin adları — "Annem, Babam".
  String? _joinLabels(List<IzSelectionOption> options, Set<String> selected) {
    final labels = [
      for (final option in options)
        if (selected.contains(option.id)) option.label,
    ];
    return labels.isEmpty ? null : labels.join(', ');
  }

  /// Galeriden tek kapak.
  Future<void> _pickCover() async {
    // LİMİT 1: koleksiyonun bir kapağı var — kavramsal bir sınır.
    final result = await ref.read(mediaPickerProvider).pickImages(limit: 1);

    // Seçici uygulamanın DIŞINDA çalışıyor; dönüşte ekran hâlâ ayakta mı?
    if (!mounted) return;

    result.fold(
      onOk: (images) {
        final path = images.firstOrNull?.path;
        if (path == null) return; // vazgeçti — bir hata değil, bir karar
        setState(
          () => _cover = MediaItem(
            id: 'picked:$path',
            type: MediaType.photo,
            originalStatus: MediaOriginalStatus.available,
            localPreviewPath: path,
          ),
        );
      },
      onErr: (failure) =>
          context.showSnack(failure.localizedMessage(context.l10n)),
    );
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
    final selected = await context.pushNamed<Set<String>>(
      AppRoute.memoryPicker.name,
      // Zaten seçili olanlar işaretli açılsın.
      extra: {for (final memory in _memories) memory.id},
    );
    if (selected == null || !mounted) return;

    setState(() {
      // Seçilenleri GERÇEK anı listesinden çözüyoruz. Sıra listenin kendi
      // sırası: aynı seçim her zaman aynı görünsün.
      _memories = [
        for (final memory
            in ref.read(pickableMemoriesProvider).value ?? const <Memory>[])
          if (selected.contains(memory.id)) memory,
      ];
    });
  }

  /// Doğrular, oluşturur, kapatır.
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
            title: title,
            description: _descriptionController.text,
            coverMediaId: _cover?.id,
            startDate: _dateRange?.start,
            endDate: _dateRange?.end,
            // Kullanıcının formda dizdiği sıra korunuyor.
            memoryIds: [for (final memory in _memories) memory.id],
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
          ..showSnack(context.l10n.collectionCreated);
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
