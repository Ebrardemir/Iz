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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/l10n/generated/app_localizations.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/view_models/memory_form_options.dart';
import 'package:iz/features/rituals/domain/entities/ritual.dart';
import 'package:iz/features/rituals/domain/repositories/ritual_repository.dart';
import 'package:iz/features/rituals/presentation/ritual_l10n.dart';
import 'package:iz/features/rituals/rituals_providers.dart';
import 'package:iz/shared/widgets/iz_cover_picker.dart';
import 'package:iz/shared/widgets/iz_form_row.dart';
import 'package:iz/shared/widgets/iz_selection_dialog.dart';

/// Formdaki açılabilir satırlar.
///
/// Enum, bool üçlüsü DEĞİL: "hangisi açık" tek bir değer ve bunu tek bir
/// alanda tutmak akordeon kuralını (aynı anda tek satır) kodun kendisine
/// yazıyor — üç bool'la o kural her `setState`te elle korunmak zorundaydı.
enum _RitualSection { recurrence, person }

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

  /// Kapak görseli.
  ///
  /// ⚠️ GEÇİCİ [MediaItem]: medya hattı (dosyayı uygulama alanına kopyalama,
  /// önizleme üretme) kurulmadı, elimizde yalnızca dosya yolu var.
  /// ⚠️ KAYDEDİLMİYOR: `Rituals` tablosunda kapak sütunu yok (TRD M6.1).
  /// Seri kartının görselleri zaten bağlı ANILARDAN geliyor, ayrı bir kapağa
  /// ihtiyaç duymuyor. Alanın kaldırılması bir tasarım kararı; şimdilik
  /// duruyor ama hiçbir yere yazılmıyor.
  MediaItem? _cover;

  /// Referansta "Her yıl" seçili geliyor ve doğrusu bu: ritüellerin çoğu
  /// yıllık (doğum günü, yıldönümü). Boş bırakmak kullanıcıyı zorunlu bir
  /// karara sokardı.
  RecurrenceType _recurrence = RecurrenceType.yearly;

  /// FR-064 — seriye bağlı KİŞİ.
  ///
  /// TASARIM ÇOKLU SEÇİM İSTİYORDU ("aile yemeği birden fazla kişiyle
  /// paylaşılıyor") ama `Rituals` tablosunda tekil bir `relatedPersonId`
  /// sütunu var (TRD M6.1). Çoklu seçim ayrı bir bağ tablosu gerektiriyor;
  /// şemayı tek başına genişletmek yerine bugün tekil kaydediyoruz ve karar
  /// ürün tarafına bırakılıyor. TRD'deki örnek de tekil: "Annemin Doğum
  /// Günleri".
  String? _relatedPersonId;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // SEÇENEKLERİ BURADA İZLİYORUZ, dokunma anında OKUMUYORUZ: `ref.read`
    // bir `StreamProvider`ı ilk kez okuduğunda akış henüz değer yaymamış
    // olur ve liste boş açılırdı.
    final peopleOptions =
        ref.watch(memoryPeopleOptionsProvider).value ??
        const <IzSelectionOption>[];

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

          // --- İLGİLİ KİŞİ ---------------------------------------------------
          IzExpandableRow(
            icon: AppIcons.people,
            label: l10n.ritualFieldPeople,
            value: _personLabel(peopleOptions),
            hint: l10n.ritualFieldPeopleHint,
            isExpanded: _openSection == _RitualSection.person,
            onToggle: () => _toggleSection(_RitualSection.person),
            children: [
              for (final person in peopleOptions)
                IzOptionTile(
                  label: person.label,
                  icon: person.icon,
                  isSelected: _relatedPersonId == person.id,
                  // TEK SEÇİM: sütun tekil (`relatedPersonId`). Aynısına
                  // tekrar dokunmak seçimi kaldırıyor — kişi zorunlu değil.
                  allowMultiple: false,
                  onTap: () => setState(() {
                    _relatedPersonId = _relatedPersonId == person.id
                        ? null
                        : person.id;
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

  /// Seçili kişilerin adları — "Annem, Babam".
  /// Seçili kişinin adı — seçilmemişse null.
  String? _personLabel(List<IzSelectionOption> options) {
    final id = _relatedPersonId;
    if (id == null) return null;

    for (final option in options) {
      if (option.id == id) return option.label;
    }
    // Kişi silinmişse etiketi yok; satır ipucunu gösteriyor.
    return null;
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
    final selected = await context.pushNamed<List<Memory>>(
      AppRoute.memoryPicker.name,
      // Zaten seçili olanlar işaretli açılsın: kullanıcı ikinci kez girdiğinde
      // sıfırdan başlamamalı.
      extra: {for (final memory in _memories) memory.id},
    );
    if (selected == null || !mounted) return;

    setState(() {
      // Ekran seçilen anıların KENDİSİNİ döndürüyor; burada çevirecek
      // bir şey yok.
      _memories = selected;
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

    unawaited(_persist(title));
  }

  /// Kaydeder ve ekranı kapatır.
  ///
  /// HATADA ekran KAPANMIYOR: form dolu kalıyor ki kullanıcı yazdıklarını
  /// kaybetmesin. Kişi ve koleksiyon formlarındaki kararın aynısı.
  Future<void> _persist(String title) async {
    final result = await ref
        .read(ritualRepositoryProvider)
        .save(
          RitualDraft(
            title: title,
            recurrenceType: _recurrence,
            relatedPersonId: _relatedPersonId,
            // BR-012 — bağ hangi YILA ait olduğunu taşımak zorunda. Yılı
            // anının tarihinden alıyoruz: kullanıcı forma tarih girmiyor,
            // seçtiği anıların yılları şeridi kuruyor.
            occurrences: [
              for (final memory in _memories)
                (memoryId: memory.id, year: memory.occurredAt.year),
            ],
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        // Kullanıcı listeye değil geldiği yere dönüyor ve yeni seriyi
        // göremiyor; gördüğü şeyi tekrar söylemiyoruz, görmediğini haber
        // veriyoruz.
        context
          ..pop()
          ..showSnack(context.l10n.ritualCreated);
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
