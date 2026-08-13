/// Yeni günlük ekranı — FR-030, FR-031.
///
/// YERLEŞİM (referans tasarım, kullanıcının çıkardıklarıyla):
///   ┌──────────────────────────────┐
///   │ ‹       Yeni Günlük          │  ⋮ YOK
///   │ ┌──────────────────────────┐ │
///   │ │ Merhaba          📖 çizim│ │
///   │ │ Bugün nasıl geçtiyse…    │ │
///   │ └──────────────────────────┘ │
///   │ Bugün kendini nasıl…?        │
///   │ 1 ──────♥7────────── 10      │  ucu kalp, içinde sayı
///   │ [ Başlık                  ]  │
///   │ [ Notlarım                ]  │  büyük kutu
///   │ Bugünden bir kare            │
///   │ [foto][foto][ + ]            │  en fazla 3, opsiyonel
///   │ [     Kaydı Oluştur       ]  │
///   └──────────────────────────────┘
///
/// REFERANSTAN ÇIKARILANLAR (kullanıcının kararı):
///   • AppBar'daki üç nokta (sil) — HENÜZ VAR OLMAYAN bir kaydı silmek
///     anlamsız; silme, kaydın kendi detayına ait bir eylem.
///   • Duygu etiketleri şeridi (Minnettar / Huzurlu / Enerjik…) — puan zaten
///     "nasıl hissediyorsun" sorusunu cevaplıyor, iki ayrı ölçek kullanıcıyı
///     aynı soruya iki kez cevap vermeye zorluyordu.
///
/// EKLENENLER: başlık alanı (kullanıcının isteği) ve daha büyük not kutusu.
///
/// FOTOĞRAF OPSİYONEL ve EN FAZLA ÜÇ. Anı formundaki `IzPhotoStrip`in aynısı —
/// aynı kare, aynı çarpı, aynı kesikli "+" kutusu. Günlük hızlı yazılan bir
/// şey (rapor 7.3); fotoğraf zorunlu olsaydı yazma eşiği yükselirdi.
///
/// ⚠️ KAYIT HATTI YOK. `JournalDao` yazılmadı; kayıt oturum belleğinde duruyor
/// (`createdJournalEntriesProvider`) ve Günlük sekmesinde görünüyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_add_menu.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/journal/domain/entities/journal_entry.dart';
import 'package:iz/features/journal/domain/journal_prompt.dart';
import 'package:iz/features/journal/presentation/journal_prompts.dart';
import 'package:iz/features/journal/presentation/view_models/created_journal_entries_view_model.dart';
import 'package:iz/features/journal/presentation/widgets/journal_greeting_card.dart';
import 'package:iz/features/journal/presentation/widgets/journal_mood_slider.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/shared/widgets/iz_bottom_nav.dart';
import 'package:iz/shared/widgets/iz_labeled_field.dart';
import 'package:iz/shared/widgets/iz_photo_strip.dart';

class JournalEditorView extends ConsumerStatefulWidget {
  const JournalEditorView({super.key});

  /// Başlık kısa olmalı: listede tek satırda görünüyor.
  static const int kTitleMaxLength = 120;

  /// Referanstaki sayaç 2000'di ve doğru: günlük uzun yazılabilmeli.
  static const int kNotesMaxLength = 2000;

  /// FR-031 — günlüğe en fazla üç fotoğraf.
  ///
  /// Anı formundaki gibi PLANA bağlı bir kota değil (orada Free 3 / İZ+ 30):
  /// günlük hızlı bir kayıt ve üç kare "bugünden bir kare" sözünü tutuyor.
  static const int kPhotoLimit = 3;

  /// Not kutusunun satır sayısı — kullanıcı "daha büyük olsun" dedi.
  static const int kNotesMinLines = 8;

  @override
  ConsumerState<JournalEditorView> createState() => _JournalEditorViewState();
}

class _JournalEditorViewState extends ConsumerState<JournalEditorView> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  /// ⚠️ GEÇİCİ [MediaItem]'lar: medya hattı kurulmadı, elimizde dosya yolu var.
  final List<MediaItem> _photos = [];

  int? _moodScore;

  /// Not boşken "Oluştur"a basılırsa görünüyor. Önceden gösterilmiyor:
  /// kullanıcı henüz yazmaya başlamadan onu suçlamak olurdu.
  String? _notesError;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Bugünün davet cümlesinin sırası.
  ///
  /// `build` içinde hesaplanmıyor: aynı gün içinde ekran her yeniden
  /// çizildiğinde aynı sonucu verir ama saati okumak bir YAN ETKİ ve onu
  /// tek bir yerde, ekran kurulurken yapmak daha dürüst.
  late final int promptIndex = journalPromptIndexFor(
    ref.read(clockProvider).now(),
    count: journalPrompts(context.l10n).length,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      // ÜÇ NOKTA YOK: bu ekranda silinecek bir şey henüz yok.
      appBar: AppBar(centerTitle: true, title: Text(l10n.journalNewTitle)),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          JournalGreetingCard(prompt: journalPrompts(l10n)[promptIndex]),
          const SizedBox(height: AppSpacing.lg),

          JournalMoodSlider(
            value: _moodScore,
            onChanged: (score) => setState(() => _moodScore = score),
          ),
          const SizedBox(height: AppSpacing.lg),

          IzLabeledField(
            label: l10n.journalFieldTitle,
            // Başlık OPSİYONEL: günlük serbest yazılıyor, başlık zorunlu
            // olsaydı yazma eşiği yükselirdi.
            isOptional: true,
            child: IzFieldInput(
              controller: _titleController,
              hintText: l10n.journalFieldTitleHint,
              maxLength: JournalEditorView.kTitleMaxLength,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          IzLabeledField(
            label: l10n.journalFieldNotes,
            child: IzFieldInput(
              controller: _notesController,
              hintText: l10n.journalFieldNotesHint,
              maxLength: JournalEditorView.kNotesMaxLength,
              // BÜYÜK KUTU (kullanıcının isteği): sekiz satırlık bir alan
              // "buraya uzun yazabilirsin" diyor. Küçük bir kutu insanı tek
              // cümleye mahkûm ediyordu.
              minLines: JournalEditorView.kNotesMinLines,
              maxLines: JournalEditorView.kNotesMinLines + 4,
              errorText: _notesError,
              onChanged: (_) {
                if (_notesError != null) setState(() => _notesError = null);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            l10n.journalPhotosLabel,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            // Sınırı ÖNCEDEN söylüyoruz: "+" kutusu kaybolduğunda kullanıcı
            // "nereye gitti?" diye kalmasın (anı formunda bunu sonradan
            // öğrenmiştik).
            l10n.journalPhotosHint(JournalEditorView.kPhotoLimit),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          IzPhotoStrip(
            photos: _photos,
            limit: JournalEditorView.kPhotoLimit,
            onRemove: (photo) => setState(() => _photos.remove(photo)),
            onAdd: _pickPhotos,
            removeLabel: l10n.memoryPhotoRemove,
            addLabel: l10n.memoryPhotoAdd,
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton.icon(
            onPressed: _create,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(AppIcons.celebrate, size: AppIconSize.md),
            label: Text(l10n.journalCreateAction),
          ),
        ],
      ),

      // ALT ÇUBUK — kullanıcının isteği ve referansta da var.
      //
      // Öteki formlarda (anı, koleksiyon, seri) çubuk YOK: onlar üste açılan,
      // ✕ ile kapanan görevler. Günlük ise uygulamanın bir SEKMESİ gibi
      // yaşıyor — her gün girilip yazılan bir yer — ve buradan çıkış yolu
      // kapalı kalmamalı.
      bottomNavigationBar: IzBottomNav(
        destinations: IzBottomNav.appTabs(l10n),
        // Hiçbir sekmede değil: yazarken birini vurgulamak yanlış olurdu.
        currentIndex: IzBottomNav.noSelection,
        onSelect: (index) => context.go(AppRoute.tabs[index].path),
        addIcon: AppIcons.add,
        addLabel: l10n.navAdd,
        // Günlük yazarken "+" en çok yeni bir anı demek.
        onAdd: () => showAppAddMenu(context),
      ),
    );
  }

  /// Galeriden fotoğraf — kalan kota kadar.
  Future<void> _pickPhotos() async {
    final remaining = JournalEditorView.kPhotoLimit - _photos.length;
    if (remaining <= 0) return;

    final result = await ref
        .read(mediaPickerProvider)
        .pickImages(limit: remaining);

    // Seçici uygulamanın DIŞINDA çalışıyor; dönüşte ekran hâlâ ayakta mı?
    if (!mounted) return;

    result.fold(
      onOk: (images) {
        if (images.isEmpty) return; // vazgeçti — bir hata değil, bir karar
        setState(() {
          _photos.addAll([
            for (final image in images)
              MediaItem(
                // `picked:` öneki kodun kendisine "bu henüz kalıcı değil"
                // dedirtiyor (anı ve kişi formlarında da aynı).
                id: 'picked:${image.path}',
                type: MediaType.photo,
                originalStatus: MediaOriginalStatus.available,
                localPreviewPath: image.path,
              ),
          ]);
        });
      },
      onErr: (failure) =>
          context.showSnack(failure.localizedMessage(context.l10n)),
    );
  }

  /// Doğrular, kaydeder, kapatır.
  void _create() {
    final l10n = context.l10n;
    final notes = _notesController.text.trim();

    // FR-030 — metin zorunlu. Başlık, ruh hâli ve fotoğraf değil: günlüğün
    // olmazsa olmazı yazının kendisi.
    if (notes.isEmpty) {
      setState(() => _notesError = l10n.journalNotesRequired);
      return;
    }

    final title = _titleController.text.trim();

    // ⚠️ BURADA KAYIT YOK; oturum belleğine gidiyor. Hat kurulduğunda burası
    // `ref.read(saveJournalEntryProvider)(...)` olacak, formun geri kalanı
    // aynı kalacak.
    ref.read(createdJournalEntriesProvider.notifier).add((
      entry: JournalEntry(
        // Kimlik ZAMANDAN üretiliyor çünkü repository yok; gerçek kimliği
        // veritabanı verecek.
        id: 'journal-${DateTime.now().microsecondsSinceEpoch}',
        // GÜN, saat DEĞİL: günlük gün bazlı gruplanıyor (FR-033).
        entryDate: ref.read(clockProvider).now().dateOnly,
        text: notes,
        title: title.isEmpty ? null : title,
        // FR-032 — hangi davete cevap verildi. Metin değil SIRA kimliği:
        // çeviri değişse de bağ kopmuyor.
        promptId: journalPromptId(promptIndex),
        moodScore: _moodScore,
        // FR-035 — varsayılan gizlilik: senkronize edilebilir.
        privacyMode: JournalPrivacyMode.standard,
      ),
      photos: [..._photos],
    ));

    context
      ..pop()
      ..showSnack(l10n.journalCreated);
  }
}

extension on DateTime {
  /// Saat bileşenini atar — `JournalEntry.entryDate` gün taşıyor.
  DateTime get dateOnly => DateTime(year, month, day);
}
