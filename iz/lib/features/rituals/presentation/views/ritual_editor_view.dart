/// Yeni ritüel ekranı — FR-075.
///
/// YERLEŞİM (referans tasarım):
///   ┌──────────────────────────────┐
///   │ ‹         Yeni Seri          │
///   │ ┌──────────────────────────┐ │
///   │ │   ⛰ çizim          (+)   │ │  kapak: dokun → galeri
///   │ │   Kapak Görseli Ekle     │ │
///   │ └──────────────────────────┘ │
///   │ [ T  │ Ritüel Adı         ]  │
///   │ [ ≡  │ Açıklama           ]  │
///   │ [ ⟳  │ Tekrarlama      ⌄  ]  │  → Her yıl / ay / hafta
///   │ [ 👥 │ İlgili Kişiler   ⌄  ]  │  → kişilerim listesi
///   │ [ 🏷 │ Kategori         ⌄  ]  │  → sistem kategorileri
///   │ [ 📷 │ Bu Yıla Anı Ekle ›  ]  │  → anı seçme sayfası
///   │ [     Ritüeli Oluştur      ] │
///   └──────────────────────────────┘
///
/// REFERANSTAKİ "BAŞLANGIÇ TARİHİ" SATIRI YOK — kullanıcının kararı ve doğru:
/// ritüelin tarihi ANILARDAN geliyor. On anı bağlıysa en erken ve en geç anı
/// zaten aralığı veriyor; kullanıcıdan ayrıca tarih istemek onu iki kez
/// çalıştırıp iki kaynağın çelişme riskini üretirdi. Seçilen anıların yıl
/// aralığı satırın altında görünüyor.
///
/// SEÇİCİLER AŞAĞI DOĞRU AÇILIYOR (akordeon), diyalog ya da alt sayfa DEĞİL.
/// Anı formunda diyalog kullandık; orada dört seçim de kısa listelerdi ve
/// forma "iliştirilmiş küçük bir karar" gibi durması iyiydi. Burada kullanıcı
/// açıkça "aşağı doğru açılsın" dedi — ve haklı: ritüel kurarken tekrarlama,
/// kişiler ve kategori birlikte düşünülüyor, her biri için ekranı terk etmek
/// bağlamı koparıyor.
///
/// AYNI ANDA TEK SATIR AÇIK. Hepsi birden açılabilse form üç ekran boyu
/// uzayıp "Oluştur" düğmesi görünmez oluyordu. Koleksiyon kartlarındaki
/// kuralın aynısı.
///
/// ⚠️ KAYIT HATTI YOK. `RitualDao` yazılmadı; oluşturulan ritüel oturum
/// belleğinde duruyor (`createdRitualsProvider`) ve "Serilerim"de görünüyor.
/// Hat kurulduğunda `_create` içindeki tek çağrı değişecek.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/categories/domain/entities/memory_category.dart';
import 'package:iz/features/categories/presentation/category_l10n.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/presentation/ritual_l10n.dart';
import 'package:iz/features/rituals/presentation/view_models/created_rituals_view_model.dart';
import 'package:iz/shared/preview/form_preview_data.dart';
import 'package:iz/shared/widgets/iz_cover_picker.dart';
import 'package:iz/shared/widgets/iz_form_row.dart';
import 'package:iz/shared/widgets/iz_memory_picker_view.dart';
import 'package:iz/shared/widgets/iz_selection_dialog.dart';

/// Formdaki açılabilir satırlar.
///
/// Enum, bool üçlüsü DEĞİL: "hangisi açık" tek bir değer ve bunu tek bir
/// alanda tutmak akordeon kuralını (aynı anda tek satır) kodun kendisine
/// yazıyor — üç bool'la o kural her `setState`te elle korunmak zorundaydı.
enum _RitualSection { recurrence, people, category }

class RitualEditorView extends ConsumerStatefulWidget {
  const RitualEditorView({super.key});

  /// FR-075 — ritüel adı (`Rituals.title` kolonu 1..120).
  static const int kTitleMaxLength = 120;

  /// Kısa açıklama.
  static const int kDescriptionMaxLength = 280;

  @override
  ConsumerState<RitualEditorView> createState() => _RitualEditorViewState();
}

class _RitualEditorViewState extends ConsumerState<RitualEditorView> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Kapak görseli.
  ///
  /// ⚠️ GEÇİCİ [MediaItem]: medya hattı (dosyayı uygulama alanına kopyalama,
  /// önizleme üretme) kurulmadı, elimizde yalnızca dosya yolu var.
  MediaItem? _cover;

  /// Referansta "Her yıl" seçili geliyor ve doğrusu bu: ritüellerin çoğu
  /// yıllık (doğum günü, yıldönümü). Boş bırakmak kullanıcıyı zorunlu bir
  /// karara sokardı.
  RecurrenceType _recurrence = RecurrenceType.yearly;

  final Set<String> _personIds = {};
  String? _categoryId;

  /// Seçilen anılar — tarih aralığı bunlardan türetiliyor.
  List<Memory> _memories = const [];

  /// Açık olan satır; hiçbiri açık değilse null.
  _RitualSection? _openSection;

  /// Ad boşken "Oluştur"a basılırsa görünüyor. Önceden gösterilmiyor:
  /// kullanıcı henüz yazmaya başlamadan onu suçlamak olurdu.
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
      // APPBAR'DA TİK YOK — kullanıcının kararı ve doğrusu bu.
      //
      // Referansta bir tik vardı ve alttaki düğmeyle aynı işi yapıyordu; iki
      // ayrı "bitir" düğmesi hangisinin ne yaptığını sorduruyor. Oluşturma
      // tek bir yerde: sayfanın sonundaki düğme. Formun sonuna inmek zaten
      // "her şeyi doldurdum" demek.
      appBar: AppBar(centerTitle: true, title: Text(l10n.ritualNewTitle)),

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
              label: l10n.ritualFieldName,
              child: IzInlineField(
                controller: _titleController,
                hint: l10n.ritualFieldNameHint,
                maxLength: RitualEditorView.kTitleMaxLength,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  // Yazmaya başlayınca hata kalksın: kullanıcı sorunu
                  // çözüyor, uyarının orada kalması onu takip etmek olur.
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
              label: l10n.ritualFieldDescription,
              child: IzInlineField(
                controller: _descriptionController,
                hint: l10n.ritualFieldDescriptionHint,
                maxLength: RitualEditorView.kDescriptionMaxLength,
                textCapitalization: TextCapitalization.sentences,
                // İki satıra kadar büyüyor: "kısa açıklama" sözü tutuluyor
                // ama uzun yazan kullanıcının satırı kesilmiyor.
                maxLines: 2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // --- TEKRARLAMA ----------------------------------------------------
          IzExpandableRow(
            icon: AppIcons.recurrence,
            label: l10n.ritualFieldRecurrence,
            value: _recurrenceLabel(l10n),
            hint: '',
            isExpanded: _openSection == _RitualSection.recurrence,
            onToggle: () => _toggleSection(_RitualSection.recurrence),
            children: [
              for (final type in _kOfferedRecurrences)
                IzOptionTile(
                  label: _labelOf(type, l10n),
                  isSelected: _recurrence == type,
                  // TEK SEÇİM: bir ritüel ya yıllık ya aylık ya haftalık.
                  allowMultiple: false,
                  onTap: () => setState(() {
                    _recurrence = type;
                    // Seçim yapılınca KAPANIYOR: tek seçimde kullanıcının
                    // orada işi bitti (`showIzSelectionDialog` de böyle).
                    _openSection = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // --- İLGİLİ KİŞİLER ------------------------------------------------
          IzExpandableRow(
            icon: AppIcons.people,
            label: l10n.ritualFieldPeople,
            value: _joinLabels(FormPreviewData.people, _personIds),
            hint: l10n.ritualFieldPeopleHint,
            isExpanded: _openSection == _RitualSection.people,
            onToggle: () => _toggleSection(_RitualSection.people),
            children: [
              for (final person in FormPreviewData.people)
                IzOptionTile(
                  label: person.label,
                  icon: person.icon,
                  isSelected: _personIds.contains(person.id),
                  // ÇOK SEÇİM: bir ritüel birden fazla kişiyle paylaşılıyor
                  // (aile yemeği). Bu yüzden seçimde satır KAPANMIYOR.
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
            label: l10n.ritualFieldCategory,
            value: _categoryLabel(l10n),
            hint: l10n.ritualFieldCategoryHint,
            isExpanded: _openSection == _RitualSection.category,
            onToggle: () => _toggleSection(_RitualSection.category),
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
                    // Aynısına tekrar dokunmak SEÇİMİ KALDIRIYOR: kategori
                    // zorunlu değil ve yanlış seçen kullanıcının geri dönüş
                    // yolu olmalı.
                    _categoryId = _categoryId == category.id
                        ? null
                        : category.id;
                    _openSection = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // --- BU YILA ANI EKLE ----------------------------------------------
          IzFormCard(
            child: IzFormRow(
              icon: AppIcons.photoLibrary,
              label: l10n.ritualFieldMemories,
              // AÇILMIYOR, SAYFA AÇIYOR: anı listesi uzun ve her satırda
              // görsel var; forma sığdırmak onu ikinci bir ekrana çevirirdi.
              // Bu yüzden chevron değil ok.
              trailing: Icon(
                AppIcons.forward,
                size: AppIconSize.md,
                color: context.colors.onSurfaceVariant,
              ),
              onTap: _pickMemories,
              child: IzFormValue(
                value: _memories.isEmpty
                    ? null
                    : l10n.ritualSelectedMemories(_memories.length),
                hint: l10n.ritualFieldMemoriesHint,
              ),
            ),
          ),

          // TARİH ARALIĞI: kullanıcı tarih girmiyor, seçtiği anılar söylüyor.
          // Satır yalnızca anı seçilince çiziliyor — boş bir "Tarih aralığı: —"
          // eksik bir alan gibi görünürdü.
          if (_dateRangeLabel(l10n) case final range?) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                range,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          FilledButton.icon(
            onPressed: _create,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            // Referanstaki parıltı ikonu: bu düğme bir şey KURUYOR, kaydetmek
            // değil. "Oluştur" fiiliyle birlikte akışın sonunu kutluyor.
            icon: const Icon(AppIcons.celebrate, size: AppIconSize.md),
            label: Text(l10n.ritualCreateAction),
          ),
        ],
      ),
    );
  }

  /// Formda sunulan tekrar türleri.
  ///
  /// Domain'de beş tür var (`seasonal`, `custom` de dahil) ama forma üçünü
  /// koyuyoruz: kullanıcı "yıl / ay / hafta" dedi. Ötekiler veri modelinde
  /// duruyor çünkü içe aktarma ve eski kayıtlar onları üretebiliyor.
  static const List<RecurrenceType> _kOfferedRecurrences = [
    RecurrenceType.yearly,
    RecurrenceType.monthly,
    RecurrenceType.weekly,
  ];

  /// Bir satırı açar, ötekileri kapatır. Açık olana tekrar dokunmak kapatıyor.
  void _toggleSection(_RitualSection section) => setState(() {
    _openSection = _openSection == section ? null : section;
  });

  String _recurrenceLabel(AppL10n l10n) => _labelOf(_recurrence, l10n);

  /// Tekrar türünün ekranda görünen adı.
  ///
  /// `ritual_l10n.dart`taki köprüyü kullanıyor: metinler tek yerde duruyor ve
  /// seri kartındaki alt satırla birebir aynı kalıyor.
  String _labelOf(RecurrenceType type, AppL10n l10n) =>
      Ritual(id: '', title: '', recurrenceType: type).recurrenceLabel(l10n);

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

  /// "Tarih aralığı: 2024 – 2026" — tek yıl varsa "2026".
  String? _dateRangeLabel(AppL10n l10n) {
    if (_memories.isEmpty) return null;

    final years = [for (final memory in _memories) memory.occurredAt.year]
      ..sort();
    final from = years.first;
    final to = years.last;

    // EN DASH (–) ile birleştiriyoruz, kısa çizgiyle değil: tarih aralığı
    // tipografide böyle yazılıyor ve `AppDateFormats.range` da bunu kullanıyor.
    return l10n.ritualDateRange(from == to ? '$from' : '$from – $to');
  }

  /// Galeriden tek kapak.
  Future<void> _pickCover() async {
    // LİMİT 1: ritüelin bir kapağı var. Plana bağlı bir kota değil
    // (FR-041 anı fotoğrafları için), kavramsal bir sınır.
    final result = await ref.read(mediaPickerProvider).pickImages(limit: 1);

    // Seçici uygulamanın DIŞINDA çalışıyor; dönüşte bu ekran hâlâ ayakta mı
    // diye bakmak zorundayız (use_build_context_synchronously).
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

  /// Anı seçme sayfasını açar ve dönen seçimi alır.
  Future<void> _pickMemories() async {
    final selected = await context.pushNamed<Set<String>>(
      AppRoute.memoryPicker.name,
      // Zaten seçili olanlar işaretli açılsın: kullanıcı ikinci kez girdiğinde
      // sıfırdan başlamamalı.
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

    // FR-075 — ad zorunlu. Tek doğrulama bu: ötekilerin hepsi opsiyonel ve
    // tekrarlama zaten seçili geliyor.
    if (title.isEmpty) {
      setState(() => _titleError = l10n.ritualNameRequired);
      return;
    }

    // ⚠️ VERİTABANI YOK: kayıt oturum belleğine gidiyor
    // (bkz. `created_rituals_view_model.dart`). Hat kurulduğunda burası
    // `ref.read(saveRitualProvider)(...)` olacak, formun geri kalanı aynı
    // kalacak.
    //
    // Kimlik ZAMANDAN üretiliyor çünkü repository yok; gerçek kimliği
    // veritabanı verecek.
    ref.read(createdRitualsProvider.notifier).add((
      id: 'ritual-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      description: _descriptionController.text.trim(),
      recurrence: _recurrence,
      personIds: {..._personIds},
      categoryId: _categoryId,
      cover: _cover,
      memories: _memories,
    ));

    context
      ..pop()
      ..showSnack(l10n.ritualCreated);
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
