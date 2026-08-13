/// Anı oluşturma/düzenleme ekranı — akışın İKİNCİ adımı.
///
/// Birinci adım fotoğraf seçimi (`MemoryNewPhotosView`); buraya seçilen dosya
/// yollarıyla geliniyor.
///
/// YERLEŞİM (referans tasarım):
///   ┌─────────────────────────────┐
///   │ ←   Detayları Gir           │  AppBar
///   │  [foto] [foto] [foto]       │  seçilen kareler, küçük
///   │ ┌─────────────────────────┐ │
///   │ │ ✎  Başlık   │ ………………… │ │  tek kart, satırlar çizgiyle ayrık
///   │ │ 📅 Tarih    │ 12.08.26 │ │
///   │ │ 📍 Konum    │ ………………… │ │
///   │ │ 📝 Not      │ ………………… │ │
///   │ │ 👥 Kişiler  │ Seç    › │ │  → ortada açılan diyalog
///   │ └─────────────────────────┘ │
///   │        [ Kaydet ]           │
///   └─────────────────────────────┘
///
/// `ConsumerStatefulWidget` KULLANIYORUZ çünkü `TextEditingController`
/// yaratıp dispose etmemiz gerekiyor. Kural şu:
///   • Widget'a ait teknik state (controller, focus, animasyon) → State
///   • İş state'i (seçili kişiler, kaydediliyor mu, hatalar) → ViewModel
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iz/core/entitlement/entitlement.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';
import 'package:iz/features/categories/presentation/category_l10n.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/presentation/view_models/memory_editor_view_model.dart';
import 'package:iz/features/memories/presentation/views/memory_form_preview_data.dart';
import 'package:iz/features/memories/presentation/widgets/memory_info_card.dart';
import 'package:iz/shared/widgets/iz_photo_strip.dart';
import 'package:iz/shared/widgets/iz_selection_dialog.dart';

class MemoryEditorView extends ConsumerStatefulWidget {
  const MemoryEditorView({
    this.memoryId,
    this.pickedPhotoPaths = const [],
    super.key,
  });

  /// null → yeni anı, dolu → düzenleme.
  final String? memoryId;

  /// Akışın ilk adımında (fotoğraf seçimi) seçilen dosya yolları.
  ///
  /// ⚠️ GEÇİCİ TAŞIYICI. Medya hattı henüz yok: dosyaları uygulama alanına
  /// kopyalama, önizleme üretme ve `MediaItems` tablosuna yazma yapılmıyor.
  /// Bu yüzden yollar `MemoryDraft.mediaIds`e girmiyor, yalnızca ekranda
  /// gösteriliyor — kullanıcı seçtiğini görüyor.
  ///
  /// Medya hattı kurulduğunda burası kalkacak: seçilen dosyalar
  /// `MediaItems`e yazılıp id'leri `viewModel.addMedia(...)`ya geçecek ve
  /// FR-041 limiti de doğal olarak `SaveMemory`de doğrulanacak.
  final List<String> pickedPhotoPaths;

  /// FR-011 — başlık üst sınırı.
  ///
  /// Kural asıl olarak domainde (`SaveMemory`) duruyor; buradaki
  /// `maxLength` onun İKİZİ değil, KULLANICI DENEYİMİ tarafı: 30. karakterden
  /// sonra yazmayı engellemek, kaydete basınca hata görmekten iyidir.
  static const int kTitleMaxLength = 30;

  @override
  ConsumerState<MemoryEditorView> createState() => _MemoryEditorViewState();
}

class _MemoryEditorViewState extends ConsumerState<MemoryEditorView> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();

  /// Düzenleme modunda veriler asenkron gelir; controller'ları bir kez
  /// doldurmak için bayrak tutuyoruz (her rebuild'de imleci sıfırlamayalım).
  bool _prefilled = false;

  /// Tarih alanının EN SON YAZILAN hâli.
  ///
  /// Neden gerekli: tarih iki yoldan değişebiliyor (elle yazma, takvimden
  /// seçme). Takvimden seçilince metni güncellemeliyiz; ama kullanıcı YAZARKEN
  /// metne dokunmamalıyız — yoksa imleç her tuşta başa atlar. Bu alan, gelen
  /// state'in bizim yazdığımızdan farklı olup olmadığını anlamamızı sağlıyor.
  String _lastDateText = '';

  @override
  void initState() {
    super.initState();

    // İLK ADIMDAN GELEN FOTOĞRAFLARI ŞERİDE AKTAR.
    //
    // Bir KEZ olması gereken bir devir teslim: rota argümanı, ekranın kendi
    // durumuna dönüşüyor. Sonrasında tek doğru kaynak `state.photos` —
    // kullanıcı fotoğraf silip eklerken rota argümanı değişmiyor.
    //
    // NEDEN İLK KAREDEN SONRA? Riverpod, widget yaşam döngüsü içinde
    // (`build`, `initState`, `dispose`…) provider değiştirmeyi yasaklıyor:
    // aynı provider'ı dinleyen iki widget farklı state görebilirdi. Doğrudan
    // `initState`te çağırınca "Tried to modify a provider while the widget
    // tree was building" hatası düşüyor.
    if (widget.pickedPhotoPaths.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(memoryEditorProvider(widget.memoryId).notifier)
            .addPickedPhotos(widget.pickedPhotoPaths);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = memoryEditorProvider(widget.memoryId);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    final l10n = context.l10n;

    // GÖSTERİM UZUN BİÇİMDE: "12 Ağustos 2026".
    //
    // Referans tasarım böyle ve haklı: bu bir anının tarihi, bir fatura
    // numarası değil. "12.08.2026" formu doğru ama duygusuz; ay adı yazılınca
    // satır bir cümle gibi okunuyor.
    //
    // AYRIŞTIRMA İSE İKİ BİÇİMİ DE KABUL EDİYOR (bkz. `_submitDate`):
    // kullanıcıya uzun biçim gösterip yalnızca uzun biçimi kabul etmek,
    // "12.08.2026" yazan herkesi hataya düşürürdü.
    final dateFormat = DateFormat.yMMMMd(l10n.localeName);

    // Yüklenen anıyı controller'lara bir kez aktar.
    if (!_prefilled && !state.isLoading) {
      _titleController.text = state.draft.title ?? '';
      _noteController.text = state.draft.note ?? '';
      _locationController.text = state.locationLabel ?? '';
      _prefilled = true;
    }

    _syncDateText(dateFormat.format(state.draft.occurredAt));

    // FR-041 — plana göre fotoğraf limiti (Free 3, İZ+ 30).
    final photoLimit = ref
        .watch(entitlementsProvider)
        .limit(IzLimit.photosPerMemory);

    // Yan etkiler `build` içinde DEĞİL, `listen` ile ele alınır.
    _handleSideEffects(provider);

    return Scaffold(
      appBar: AppBar(
        // Yeni anıda "Detayları Gir": kullanıcı iki adımlık bir akışın
        // ikinci adımında ve başlık ona NE YAPACAĞINI söylüyor.
        // Düzenlemede akış yok, o yüzden ekranın adı yeter.
        // Yeni anıda "Detayları Gir" (akışın ikinci adımı, kullanıcıya ne
        // yapacağını söylüyor), düzenlemede referanstaki gibi kısa: "Düzenle".
        title: Text(
          widget.memoryId == null ? l10n.memoryDetailsTitle : l10n.commonEdit,
        ),
        centerTitle: true,
        actions: [
          // FR-019 favori işareti KARTIN İÇİNDE DEĞİL, burada.
          //
          // Kartın altında ayrı bir anahtar satırı olarak duruyordu; referans
          // tasarımın tek kart + tek düğme sadeliğini bozuyor ve "favori"yi
          // başlık, tarih, konumla aynı sırada bir ALAN gibi gösteriyordu.
          // Oysa favori bir alan değil, kaydın tamamına vurulan bir işaret —
          // yeri AppBar.
          IconButton(
            onPressed: viewModel.toggleFavorite,
            icon: const Icon(AppIcons.favorite),
            // Lucide çizgi setidir; dolu/boş kalp ikilisi yok. Durumu ÜÇ
            // sinyalle veriyoruz: dolu zemin (şekil), renk ve ekran okuyucu
            // etiketi — `memory_card.dart` ile birebir aynı desen. NFR-031
            // gereği renk tek başına bilgi taşımamalı.
            color: state.draft.isFavorite
                ? context.colors.onSecondaryContainer
                : context.colors.onSurface,
            style: state.draft.isFavorite
                ? IconButton.styleFrom(
                    backgroundColor: context.colors.secondaryContainer,
                  )
                : null,
            // NFR-032 — ekran okuyucu etiketi
            tooltip: state.draft.isFavorite
                ? l10n.memoryUnfavorite
                : l10n.memoryFavorite,
          ),
        ],
      ),

      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Fotoğraflar — yeni anıda ilk adımda seçilenler, düzenlemede
                // anıya kayıtlı olanlar. İkisi de aynı listede
                // (bkz. `MemoryEditorState.photos`).
                if (state.photos.isNotEmpty || photoLimit > 0) ...[
                  IzPhotoStrip(
                    photos: state.photos,
                    limit: photoLimit,
                    onRemove: (photo) => viewModel.removePhoto(photo.id),
                    onAdd: () => _addPhotos(viewModel, state.photos.length),
                    // Etiketler dışarıdan: şerit paylaşılan bir bileşen ve
                    // çeviri anahtarını bilemiyor.
                    removeLabel: l10n.memoryPhotoRemove,
                    addLabel: l10n.memoryPhotoAdd,
                  ),

                  // Limit dolduğunda ekleme kutusu KAYBOLUYOR; sebebini
                  // söylemek şeridin işi değil, bu satırın işi. Yoksa
                  // kullanıcı "+ nereye gitti?" diye kalıyor.
                  if (state.photos.length >= photoLimit) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.memoryPhotoLimitHint(photoLimit),
                      style: context.textStyles.caption.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],

                MemoryInfoCard(
                  rows: [
                    _titleRow(state, viewModel),
                    _dateRow(state, viewModel, dateFormat),
                    _locationRow(viewModel),
                    _noteRow(state, viewModel),
                    _peopleRow(state, viewModel),
                    _categoryRow(state, viewModel),
                    _collectionRow(state, viewModel),
                    _seriesRow(state, viewModel),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Kaydet ALTTA, AppBar'da değil: bu bir oluşturma akışının
                // sonu ve düğme "işi bitir" demeli. AppBar'daki metin düğmesi
                // kolay kaçırılıyordu.
                FilledButton(
                  // Yükseklik temanın 48'i değil 56: referanstaki düğme
                  // kartla aynı ritimde duruyor ve akışı bitiren tek eylem
                  // olarak ağırlığını hak ediyor.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: state.canSave ? viewModel.save : null,
                  child: state.isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          // Düzenlemede "Değişiklikleri Kaydet": kullanıcı yeni
                          // bir şey yaratmıyor, var olanı değiştiriyor ve düğme
                          // bunu söylemeli.
                          widget.memoryId == null
                              ? l10n.commonSave
                              : l10n.commonSaveChanges,
                        ),
                ),

                // SİL — yalnızca düzenlemede.
                //
                // Anı detayında sağ üstte bir çöp ikonu duruyordu ve oradan
                // kaldırdık: okumaya gelen kullanıcının parmağının altında en
                // yıkıcı eylemi bekletiyordu. Doğru yeri burası — kullanıcı
                // zaten anıyı DEĞİŞTİRMEK için bu ekranda.
                //
                // Kaydet'in ALTINDA ve düğme değil metin: ikisi eşit ağırlıkta
                // görünmemeli (referansta da öyle).
                if (widget.memoryId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    child: TextButton.icon(
                      onPressed: state.isSaving
                          ? null
                          : () => _confirmDelete(viewModel),
                      icon: const Icon(AppIcons.delete, size: AppIconSize.md),
                      label: Text(l10n.commonDelete),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.error,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  // --- Satırlar -------------------------------------------------------------

  Widget _titleRow(MemoryEditorState state, MemoryEditorViewModel viewModel) {
    final l10n = context.l10n;

    return MemoryInfoRow(
      icon: AppIcons.edit,
      label: l10n.memoryFieldTitle,
      child: _FormField(
        controller: _titleController,
        hintText: l10n.memoryFieldTitleHint,
        onChanged: viewModel.setTitle,
        // Sayaç GÖSTERİLMİYOR (`counterText: ''` içeride): satırın altında
        // "12/30" yazısı kartın çizgi düzenini bozuyordu. Sınıra dayanınca
        // yazı zaten girmiyor, kullanıcı sınırı hissediyor.
        maxLength: MemoryEditorView.kTitleMaxLength,
        errorText: state
            .errorFor(MemoryFormField.title)
            ?.localizedMessage(l10n),
      ),
    );
  }

  Widget _dateRow(
    MemoryEditorState state,
    MemoryEditorViewModel viewModel,
    DateFormat dateFormat,
  ) {
    final l10n = context.l10n;

    return MemoryInfoRow(
      icon: AppIcons.date,
      label: l10n.memoryFieldDate,
      // SATIRIN TAMAMI takvimi açıyor, sağdaki ikon bir DÜĞME DEĞİL.
      //
      // Önce `IconButton`dı. İki sorun çıkardı: kendi iç dolgusu yüzünden
      // ikon, öteki satırların okundan 10 piksel içeride kalıyordu (referansta
      // hepsi tek hatta), ve dokunma hedefi 40'a sıkışıyordu. Satırı
      // tıklanabilir yapınca ikon sade bir işarete dönüşüyor: hiza tam,
      // dokunma hedefi de satırın tamamı (56 piksel, NFR-033'ün üstünde).
      //
      // Metin alanına dokunmak yazmayı açmaya devam ediyor — dokunuş önce
      // çocuğa gidiyor, satıra sonra.
      onTap: () => _pickDate(viewModel, state.draft.occurredAt),
      trailing: const _RowIcon(AppIcons.date),
      child: _FormField(
        controller: _dateController,
        keyboardType: TextInputType.datetime,
        // Yazarken HER TUŞTA ayrıştırmıyoruz: "1" yazan kullanıcıya hemen
        // "tarihi anlayamadım" demek kaba olurdu. Alan odaktan çıkınca ya da
        // klavyeden onaylanınca değerlendiriyoruz.
        onSubmitted: (text) => _submitDate(text, viewModel, dateFormat),
        onFocusLost: () =>
            _submitDate(_dateController.text, viewModel, dateFormat),
        errorText: state.dateError,
      ),
    );
  }

  Widget _locationRow(MemoryEditorViewModel viewModel) {
    final l10n = context.l10n;

    return MemoryInfoRow(
      icon: AppIcons.location,
      label: l10n.relationLocation,
      child: _FormField(
        controller: _locationController,
        hintText: l10n.memoryFieldLocationHint,
        textCapitalization: TextCapitalization.words,
        onChanged: viewModel.setLocation,
      ),
    );
  }

  Widget _noteRow(MemoryEditorState state, MemoryEditorViewModel viewModel) {
    final l10n = context.l10n;

    return MemoryInfoRow(
      icon: AppIcons.navJournal,
      label: l10n.memoryFieldNote,
      child: _FormField(
        controller: _noteController,
        hintText: l10n.memoryFieldNoteHint,
        onChanged: viewModel.setNote,
        // ÜÇ SATIR ≈ ilk 20 kelime. Not uzun olabilir (FR-012 sınırı çok
        // yukarıda) ama form satırının bütün ekranı yutmasına izin vermiyoruz:
        // pencere sabit, içi kaydırılıyor.
        maxLines: 3,
        minLines: 1,
        errorText: state.errorFor(MemoryFormField.note)?.localizedMessage(l10n),
      ),
    );
  }

  Widget _peopleRow(MemoryEditorState state, MemoryEditorViewModel viewModel) {
    final l10n = context.l10n;

    return MemoryInfoRow(
      icon: AppIcons.people,
      label: l10n.relationPeople,
      onTap: () async {
        final result = await _openPicker(
          title: l10n.relationPeople,
          options: MemoryFormPreviewData.people,
          selected: state.people.map((p) => p.id).toSet(),
          allowMultiple: true,
        );
        if (result == null) return;
        viewModel.setPeople(
          _toSelections(MemoryFormPreviewData.people, result),
        );
      },
      trailing: const _RowIcon(AppIcons.forward),
      child: MemoryInfoValue(value: _joinLabels(state.people)),
    );
  }

  Widget _categoryRow(
    MemoryEditorState state,
    MemoryEditorViewModel viewModel,
  ) {
    final l10n = context.l10n;
    final options = _categoryOptions(l10n);

    // Kategori TASLAKTAN da okunabiliyor — öteki üç seçimden farkı bu.
    //
    // Mevcut bir anıyı düzenlerken taslak `categoryId`yi taşıyor (sistem
    // kategorileri veritabanında gerçekten var) ama ADI taşımıyor: ad dile
    // bağlı ve ViewModel dil bilmez. Kullanıcı henüz bir seçim yapmadıysa adı
    // burada, kimlikten çözüyoruz; yapmışsa seçim kazanıyor.
    final selectedId = state.category?.id ?? state.draft.categoryId;
    final label = options.where((o) => o.id == selectedId).firstOrNull?.label;

    return MemoryInfoRow(
      icon: AppIcons.fallbackCategory,
      label: l10n.memoryFieldCategory,
      onTap: () async {
        final result = await _openPicker(
          title: l10n.memoryFieldCategory,
          options: options,
          selected: selectedId == null ? const {} : {selectedId},
          allowMultiple: false,
        );
        if (result == null) return;
        viewModel.setCategory(_toSelections(options, result).firstOrNull);
      },
      trailing: const _RowIcon(AppIcons.forward),
      child: MemoryInfoValue(value: label),
    );
  }

  Widget _collectionRow(
    MemoryEditorState state,
    MemoryEditorViewModel viewModel,
  ) {
    final l10n = context.l10n;

    return MemoryInfoRow(
      icon: AppIcons.collection,
      label: l10n.memoryFieldCollection,
      onTap: () async {
        final result = await _openPicker(
          title: l10n.memoryFieldCollection,
          options: MemoryFormPreviewData.collections,
          selected: state.collections.map((c) => c.id).toSet(),
          allowMultiple: true,
        );
        if (result == null) return;
        viewModel.setCollections(
          _toSelections(MemoryFormPreviewData.collections, result),
        );
      },
      trailing: const _RowIcon(AppIcons.forward),
      child: MemoryInfoValue(value: _joinLabels(state.collections)),
    );
  }

  Widget _seriesRow(MemoryEditorState state, MemoryEditorViewModel viewModel) {
    final l10n = context.l10n;

    return MemoryInfoRow(
      icon: AppIcons.series,
      label: l10n.memoryFieldSeries,
      onTap: () async {
        final result = await _openPicker(
          title: l10n.memoryFieldSeries,
          options: MemoryFormPreviewData.series,
          selected: _idSet(state.series),
          allowMultiple: false,
        );
        if (result == null) return;
        viewModel.setSeries(
          _toSelections(MemoryFormPreviewData.series, result).firstOrNull,
        );
      },
      trailing: const _RowIcon(AppIcons.forward),
      child: MemoryInfoValue(value: state.series?.label),
    );
  }

  // --- Seçim ----------------------------------------------------------------

  /// Sistem kategorilerini seçim listesine çevirir.
  ///
  /// Bu liste UYDURMA DEĞİL: kategoriler kodda tanımlı (`SystemCategory`) ve
  /// adları çeviriden geliyor. Kullanıcının kendi açtığı kategoriler
  /// veritabanından gelecek ve buraya EKLENECEK — o yüzden burada bir
  /// "önizleme verisi" dosyasına ihtiyaç yok.
  List<IzSelectionOption> _categoryOptions(AppL10n l10n) => [
    for (final category in SystemCategory.values)
      (
        id: category.id,
        label: systemCategoryName(category.nameKey, l10n) ?? category.nameKey,
        icon: AppIcons.forKey(category.iconKey),
      ),
  ];

  /// Diyaloğu açar; "+ Yeni ekle" seçilirse ilgili oluşturma ekranına gider.
  Future<IzSelectionResult?> _openPicker({
    required String title,
    required List<IzSelectionOption> options,
    required Set<String> selected,
    required bool allowMultiple,
  }) => showIzSelectionDialog(
    context,
    title: title,
    options: options,
    selectedIds: selected,
    allowMultiple: allowMultiple,
    // ⚠️ Kişi/kategori/koleksiyon/seri OLUŞTURMA ekranları henüz yok.
    // Geri çağırmayı şimdiden bağlıyoruz ki diyaloğun "+" satırı tasarımda
    // görünsün; o ekranlar yazıldığında burası `context.pushNamed(...)`
    // olacak, diyalog tarafında tek satır değişmeyecek.
    //
    // Mesaj uygulamanın geri kalanıyla AYNI (bkz. home_view.dart,
    // my_life_view.dart, memory_detail_view.dart): "yakında".
    onAddNew: () => context.showSnack(context.l10n.screenComingSoonMessage),
  );

  /// Seçilen kimlikleri form değerine çevirir.
  ///
  /// Sıra SEÇENEK LİSTESİNİN sırası, kullanıcının dokunma sırası değil:
  /// "Annem, Elif" hep aynı sırayla görünsün, satır her seçimde
  /// karışmasın.
  static List<MemoryFormSelection> _toSelections(
    List<IzSelectionOption> options,
    IzSelectionResult ids,
  ) => [
    for (final option in options)
      if (ids.contains(option.id)) (id: option.id, label: option.label),
  ];

  /// Tek seçimli alanın seçili kimliği — yoksa boş küme.
  static Set<String> _idSet(MemoryFormSelection? selection) =>
      selection == null ? const {} : {selection.id};

  static String? _joinLabels(List<MemoryFormSelection> items) =>
      items.isEmpty ? null : items.map((i) => i.label).join(', ');

  // --- Tarih ----------------------------------------------------------------

  /// State'teki tarihi metin alanına yansıtır — kullanıcı yazarken DOKUNMADAN.
  void _syncDateText(String formatted) {
    if (formatted == _lastDateText) return;
    _lastDateText = formatted;
    _dateController.text = formatted;
  }

  void _submitDate(
    String text,
    MemoryEditorViewModel viewModel,
    DateFormat dateFormat,
  ) {
    final l10n = context.l10n;

    viewModel.setOccurredAtFromText(
      text,
      // İKİ BİÇİM DE KABUL: ekranda "12 Ağustos 2026" yazıyor ama kullanıcı
      // "12.08.2026" yazmayı da bekleyebilir. Yalnızca gösterdiğimiz biçimi
      // kabul etmek, tuş tasarrufu yapan herkesi hataya düşürürdü.
      //
      // `parseLoose`, `parseStrict` değil: "1.8.2026" da "01.08.2026" gibi
      // anlaşılıyor. Başarısızlıkta `FormatException` atıyor; ViewModel null
      // bekliyor.
      parse: (value) {
        for (final format in [dateFormat, DateFormat.yMd(l10n.localeName)]) {
          try {
            return format.parseLoose(value);
          } on FormatException {
            continue;
          }
        }
        return null;
      },
      invalidMessage: l10n.memoryDateInvalid(
        dateFormat.format(DateTime(2026, 8, 12)),
      ),
      futureMessage: l10n.memoryDateFuture,
    );
  }

  Future<void> _pickDate(
    MemoryEditorViewModel viewModel,
    DateTime current,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      // FR-013 — eski anılar sonradan eklenebilmeli.
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      viewModel.setOccurredAt(picked);
    }
  }

  /// Galeriyi açar ve seçilenleri şeride ekler.
  ///
  /// LİMİT KALAN KOTA KADAR: üç fotoğraflı bir plandan ikisi zaten seçiliyse
  /// galeri bir tane daha almaya izin veriyor. Tam limiti geçmek, kullanıcıya
  /// seçtirip sonra elinden almak olurdu.
  Future<void> _addPhotos(
    MemoryEditorViewModel viewModel,
    int currentCount,
  ) async {
    final limit =
        ref.read(entitlementsProvider).limit(IzLimit.photosPerMemory) -
        currentCount;
    if (limit <= 0) return;

    final result = await ref.read(mediaPickerProvider).pickImages(limit: limit);

    // Seçici uygulamanın DIŞINDA çalışıyor; dönüşte bu ekran hâlâ ayakta mı
    // diye bakmak zorundayız (use_build_context_synchronously).
    if (!mounted) return;

    result.fold(
      onOk: (images) =>
          viewModel.addPickedPhotos([for (final image in images) image.path]),
      onErr: (failure) =>
          context.showSnack(failure.localizedMessage(context.l10n)),
    );
  }

  /// NFR-034: kritik silme işleminde açık onay. FR-015: geri alınabilir.
  Future<void> _confirmDelete(MemoryEditorViewModel viewModel) async {
    final l10n = context.l10n;
    final memoryId = widget.memoryId;
    if (memoryId == null) return;

    final confirmed = await context.confirm(
      title: l10n.memoryDeleteTitle,
      message: l10n.memoryDeleteMessage,
      confirmLabel: l10n.memoryDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    // ÖNEMLİ: Container'ı ekran kapanmadan ÖNCE yakalıyoruz. Pop sonrası bu
    // widget dispose olur ve `ref` kullanılamaz hâle gelir; container ise
    // uygulama boyunca yaşar. "Geri al" eylemi bu yüzden container üzerinden
    // çalışıyor.
    final container = ProviderScope.containerOf(context, listen: false);

    final result = await viewModel.moveToTrash();
    if (!mounted) return;

    result.fold(
      onOk: (_) => context
        ..pop()
        ..showSnack(
          l10n.memoryDeleted,
          action: SnackBarAction(
            label: l10n.memoryRestore,
            onPressed: () => unawaited(
              container
                  .read(memoryRepositoryProvider)
                  .restoreFromTrash(memoryId),
            ),
          ),
        ),
      onErr: (failure) => context.showSnack(failure.localizedMessage(l10n)),
    );
  }

  /// Kaydetme başarısı ve hata bildirimlerini dinler.
  ///
  /// `ref.listen` build içinde çağrılır ama build sırasında DEĞİL,
  /// state değiştiğinde tetiklenir — navigasyon/SnackBar için doğru yer budur.
  void _handleSideEffects(
    NotifierProvider<MemoryEditorViewModel, MemoryEditorState> provider,
  ) {
    ref.listen(provider, (previous, next) {
      // Kaydedildi → ekranı kapat.
      if (next.savedId != null && previous?.savedId == null) {
        context.pop(next.savedId);
        return;
      }

      // Alanla eşleşmeyen hata → SnackBar.
      final failure = next.generalError;
      if (failure != null && previous?.generalError != failure) {
        context.showSnack(failure.localizedMessage(context.l10n));
        ref.read(provider.notifier).consumeError();
      }
    });
  }
}

/// Kart satırlarının içindeki metin girdisi.
///
/// NEDEN ÇIPLAK `TextField` DEĞİL?
/// Material'ın varsayılan `TextField`ı kendi çerçevesini, dolgusunu ve
/// etiketini taşır. Bu tasarımda çerçeveyi KART çiziyor, etiketi SATIR
/// yazıyor. Her satırda aynı sekiz satırlık `InputDecoration`ı tekrar etmek
/// yerine tek yerde topladık.
class _FormField extends StatefulWidget {
  const _FormField({
    required this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onFocusLost,
    this.errorText,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Alan odağı kaybettiğinde çağrılır — tarih alanı bunu kullanıyor.
  final VoidCallback? onFocusLost;

  final String? errorText;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) widget.onFocusLost?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      // Sınıra DAYANINCA yazma durur (varsayılan davranış), ama sayaç
      // gösterilmez: kartın içinde "12/30" satır düzenini bozuyordu.
      inputFormatters: widget.maxLength == null
          ? null
          : [LengthLimitingTextInputFormatter(widget.maxLength)],
      // Etiket, seçili değer ve yazılan metin TEK BİR AİLE: stil tek yerden,
      // `MemoryInfoRow.labelStyle`dan geliyor. Ayrı ayrı yazılsa biri
      // değiştiğinde ötekiler geride kalırdı.
      style: MemoryInfoRow.labelStyle(context),
      decoration: InputDecoration(
        isDense: true,
        // Girdinin kendi ÇERÇEVESİ ve ZEMİNİ YOK.
        //
        // Uygulamanın `inputDecorationTheme`ı `filled: true` veriyor — çünkü
        // öteki formlarda (giriş, kayıt) alanlar sayfadan ayrışsın diye.
        // Burada zemini KART çiziyor; temanın dolgusu bırakılınca her satırın
        // arkasında ayrı bir gri dikdörtgen çıkıyordu ve kart, içine
        // kutucuklar dizilmiş bir listeye benziyordu.
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        // Temanın 48 piksellik ASGARİ YÜKSEKLİĞİ burada geçersiz.
        //
        // Temada var çünkü giriş/kayıt formlarında alanın kendisi dokunma
        // hedefidir (NFR-033). Burada dokunma hedefini SATIR taşıyor
        // (`MemoryInfoRow.kMinHeight` = 48); ikisi üst üste binince metin
        // satırları 64, seçim satırları 48 piksel oluyor ve kartın ritmi
        // bozuluyordu. Girdi metni kadar ölçülüyor, yükseklik satırdan
        // geliyor.
        constraints: const BoxConstraints(),
        counterText: '',
        // Hata metni satırın altında kendi yerini alıyor; girdinin kendi
        // dolgusu olmadığı için ayrıca boşluk bırakmıyoruz.
        helperText: null,
        hintText: widget.hintText,
        hintStyle: MemoryInfoRow.labelStyle(context)?.copyWith(
          // `MemoryInfoValue`ın "Seç" yer tutucusuyla AYNI tonda: iki farklı
          // satır tipi olsa da boş alan aynı görünmeli.
          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        errorText: widget.errorText,
        // Hata girdiyle aynı kolonda, hemen altında.
        errorStyle: context.text.bodySmall?.copyWith(
          color: colors.error,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Satırın sonundaki işaret: seçim satırlarında ok, tarih satırında takvim.
///
/// TEK BİLEŞEN çünkü ikisinin de işi aynı: değerin sağında, hepsi tek dikey
/// hatta hizalı, metinle aynı koyulukta. Ayrı ayrı yazıldığında biri
/// ötekinden 10 piksel kaçmıştı.
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    // Metnin ilk satırıyla hizalı kalsın (satır üstten hizalı — bkz.
    // `MemoryInfoRow`).
    padding: const EdgeInsets.only(top: 2),
    child: Icon(
      icon,
      size: AppIconSize.md,
      // KOYU: referansta işaret, satırın öteki parçalarıyla aynı tonda.
      color: context.colors.onSurface,
    ),
  );
}
