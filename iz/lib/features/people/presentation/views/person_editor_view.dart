/// Kişi formu — FR-060, FR-061, FR-063.
///
/// TEK EKRAN, İKİ KİP. [personId] null ise "Yeni Kişi", doluysa "Kişiyi
/// Düzenle". Ayrı bir düzenleme ekranı yazmak aynı dört alanı, aynı
/// doğrulamayı ve aynı fotoğraf seçimini ikinci kez yazmak olurdu; ikisi
/// zamanla birbirinden ayrılırdı.
///
/// YERLEŞİM — DÜZENLEME (referans tasarım):
///   ┌──────────────────────────────┐
///   │ ✕     Kişiyi Düzenle     ✓  │
///   │ ┌────┐ ┌╌╌╌╌┐                │
///   │ │ ⊗  │ │ +  │                │  fotoğraf + kesikli değiştirme kutusu
///   │ └────┘ └╌╌╌╌┘                │
///   │ Ad                           │
///   │ [ Annem                  ]   │  DOLU gelir, kullanıcı düzeltir
///   │ İlişkiniz                    │
///   │ [ Annem                  ]   │
///   │ Doğum Tarihi (Opsiyonel)     │
///   │ [ 18 Nisan 1968       📅 ]   │
///   │ Kısa Not (Opsiyonel)         │
///   │ [ En büyük destekçim...   ]   │
///   │ [  Değişiklikleri Kaydet  ]  │
///   │        🗑 Kişiyi Sil          │
///   └──────────────────────────────┘
///
/// FOTOĞRAF ŞERİDİ, YUVARLAK SEÇİCİ DEĞİL (yalnızca düzenlemede).
/// Referansta kare bir fotoğraf, üstünde çarpı, yanında kesikli "+" kutusu var
/// — anı formundaki şeridin aynısı (`IzPhotoStrip`). Kişinin tek fotoğrafı
/// olduğu için "+" burada EKLEMEK değil DEĞİŞTİRMEK demek; kullanıcı önce
/// silmek zorunda kalmıyor.
///
/// İLİŞKİ SERBEST METİN, açılır liste DEĞİL.
/// Referansta chevron'lu bir açılır liste var; kullanıcı onun yerine kendi
/// yazmayı istedi ve haklı — "Annem" ile "Anne / Baba" aynı şey değil, ilki
/// kendi sesi. Filtreleme ve doğum günü önerileri (FR-064) için gereken tür
/// yazılandan türetiliyor (bkz. `guessRelationType`).
///
/// İKİ KAYDET YOLU (AppBar'daki ✓ ve alttaki düğme) BİLİNÇLİ.
/// Referansta ikisi de var: uzun bir formda kullanıcı ya sona iner ya da
/// bitirdiğini düşündüğü an üstteki tikle kapatır. İkisi de aynı işi yapıyor.
///
/// KAYIT VE SİLME GERÇEK: form `PersonRepository`ye yazıyor, düzenlenecek
/// kişi oradan okunuyor.
///
/// FOTOĞRAF HÂLÂ KAYDEDİLMİYOR — medya hattı (dosyayı uygulama alanına
/// kopyalama, önizleme üretme) kurulmadı. Seçilen fotoğraf ekranda görünüyor
/// ama `avatarMediaId` boş kalıyor; M4 ile bağlanacak.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';
import 'package:iz/features/people/presentation/person_l10n.dart';
import 'package:iz/features/people/presentation/widgets/person_photo_picker.dart';
import 'package:iz/shared/widgets/iz_labeled_field.dart';
import 'package:iz/shared/widgets/iz_photo_strip.dart';

class PersonEditorView extends ConsumerStatefulWidget {
  const PersonEditorView({this.personId, super.key});

  /// null → yeni kişi; dolu → o kişiyi düzenle.
  final String? personId;

  /// FR-061 — ad uzunluğu (`People.name` kolonu 1..120).
  static const int kNameMaxLength = 120;

  /// İlişki etiketi kısa olmalı: satırda tek satırda görünüyor.
  static const int kRelationMaxLength = 40;

  /// Kısa not — "kısa" olduğu adında yazıyor.
  static const int kNoteMaxLength = 280;

  /// Kişinin TEK fotoğrafı var.
  ///
  /// Anı formundaki gibi plana bağlı bir kota değil, kavramsal bir sınır: bir
  /// kişinin bir avatarı olur.
  static const int kPhotoLimit = 1;

  @override
  ConsumerState<PersonEditorView> createState() => _PersonEditorViewState();
}

class _PersonEditorViewState extends ConsumerState<PersonEditorView> {
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _noteController = TextEditingController();

  /// Seçilen fotoğraf.
  ///
  /// ⚠️ GEÇİCİ [MediaItem]: medya hattı (dosyayı uygulama alanına kopyalama,
  /// önizleme üretme) kurulmadı, elimizde yalnızca dosya yolu var. Aynı
  /// yaklaşım anı formunda da kullanılıyor.
  MediaItem? _photo;

  DateTime? _birthDate;

  /// Alan bazlı hatalar. Kaydete basılmadan gösterilmiyor: kullanıcı henüz
  /// yazmaya başlamadan "ad zorunlu" demek onu suçlamak olur.
  String? _nameError;

  /// Alanlar bir kez dolduruldu mu?
  ///
  /// Doldurma [didChangeDependencies] içinde yapılıyor çünkü tarihi biçimlemek
  /// için dil gerekiyor ve `initState` içinde `context` henüz güvenli değil. O
  /// yöntem birden çok kez çağrılabildiği için bu bayrak lazım: aksi hâlde tema
  /// ya da klavye değişimi kullanıcının yazdıklarının üstüne yazardı.
  bool _loaded = false;

  bool get _isEditing => widget.personId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    final personId = widget.personId;
    if (personId == null) return;

    // FORMU DEPODAN DOLDURUYORUZ. Okuma asenkron olduğu için ayrı bir
    // metotta: ilk kare boş form, veri gelince alanlar doluyor.
    unawaited(_loadPerson(personId));
  }

  /// Düzenlenecek kişiyi okuyup alanları doldurur.
  ///
  /// Kayıt bulunamazsa form BOŞ KALIYOR ve ekran kapanmıyor: kullanıcı
  /// silinmiş bir kişinin bağlantısına tıklamış olabilir; onu boş bir
  /// forma bırakmak, hata ekranına atmaktan daha az can sıkıcı.
  Future<void> _loadPerson(String personId) async {
    final result = await ref
        .read(personRepositoryProvider)
        .findPerson(personId);
    if (!mounted) return;

    final person = switch (result) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (person == null) return;

    // ALANLAR DOLU GELİYOR: kullanıcı düzeltmek istediğini siler, olduğu gibi
    // bırakmak istediğine dokunmaz. Boş bir form ona her şeyi yeniden
    // yazdırırdı.
    _nameController.text = person.name;
    // İlişki metni: kullanıcının yazdığı varsa o, yoksa türün çevrilmiş adı.
    // İkincisi de düzenlenebilir bir başlangıç — kullanıcı üstüne kendi
    // kelimesini yazabilir.
    _relationController.text = relationDisplay(person, context.l10n);
    _noteController.text = person.note ?? '';

    final birthDate = person.birthDate;
    if (birthDate != null) {
      _birthDate = birthDate;
      _birthDateController.text = _formatBirthDate(birthDate);
    }

    // Denetleyicilere yazmak widget'ı kendiliğinden yeniden çizmiyor;
    // metin alanları dinliyor ama tarih alanı ve kaydet düğmesi çizilmiş
    // durumda kalırdı.
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _birthDateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_isEditing ? l10n.personEditTitle : l10n.personNewTitle),
        // GERİ OKU DEĞİL ÇARPI: bu bir akışın adımı değil, üste açılan tam
        // ekran bir görev. Çarpı "vazgeç ve kapat" demek.
        leading: IconButton(
          icon: const Icon(AppIcons.clear),
          tooltip: l10n.commonClose,
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(AppIcons.check),
            tooltip: l10n.personSaveAction,
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          if (_isEditing)
            // Şerit SOLA YASLI ve tek karelik: referanstaki yerleşim bu ve
            // ortalamak, yanındaki "+" kutusuyla birlikte ekranda gezinen bir
            // ikili üretiyordu.
            IzPhotoStrip(
              photos: [?_photo],
              limit: PersonEditorView.kPhotoLimit,
              // Fotoğraf varken de "+" duruyor: burada anlamı DEĞİŞTİRMEK.
              showAddWhenFull: true,
              onRemove: (_) => setState(() => _photo = null),
              onAdd: _pickPhoto,
              removeLabel: l10n.personPhotoRemove,
              addLabel: l10n.personPhotoChange,
            )
          else
            // Yeni kişide yuvarlak seçici: henüz hiçbir şey seçilmemişken
            // "Fotoğraf Ekle" yazan tek bir alan, kare bir şeritten daha açık
            // bir çağrı (kullanıcı bu ekranı böyle onayladı).
            Center(
              child: PersonPhotoPicker(
                photo: _photo,
                onPick: _pickPhoto,
                onRemove: () => setState(() => _photo = null),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          IzLabeledField(
            label: l10n.personFieldName,
            child: IzFieldInput(
              controller: _nameController,
              hintText: l10n.personFieldNameHint,
              maxLength: PersonEditorView.kNameMaxLength,
              textCapitalization: TextCapitalization.words,
              errorText: _nameError,
              // Yazmaya başlayınca hata kalksın: kullanıcı sorunu çözüyor,
              // uyarının orada kalması onu takip etmek olur.
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          IzLabeledField(
            label: l10n.personFieldRelation,
            child: IzFieldInput(
              controller: _relationController,
              // "Örn. Annem" — kullanıcıya kendi kelimesini yazabileceğini
              // söyleyen tek şey bu ipucu.
              hintText: l10n.personFieldRelationHint,
              maxLength: PersonEditorView.kRelationMaxLength,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          IzLabeledField(
            label: l10n.personFieldBirthDate,
            isOptional: true,
            child: IzFieldInput(
              controller: _birthDateController,
              hintText: l10n.personFieldBirthDateHint,
              // SALT OKUNUR ve dokunmak takvimi açıyor.
              //
              // Anı formunda tarih hem yazılıyor hem seçiliyor; orada bugüne
              // yakın bir tarih giriliyor ve yazmak hızlı. Doğum tarihi ise
              // yıllar öncesi: elle yazmak "1987" bulana kadar sekiz dokunuş,
              // takvimden yıl seçmek üç. Kullanıcı da "takvime tıklayınca
              // takvim açılsın" dedi.
              readOnly: true,
              onTap: _pickBirthDate,
              suffix: IconButton(
                onPressed: _pickBirthDate,
                icon: const Icon(AppIcons.date),
                iconSize: AppIconSize.md,
                color: context.colors.onSurfaceVariant,
                tooltip: l10n.personFieldBirthDate,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          IzLabeledField(
            label: l10n.personFieldNote,
            isOptional: true,
            child: IzFieldInput(
              controller: _noteController,
              hintText: l10n.personFieldNoteHint,
              maxLength: PersonEditorView.kNoteMaxLength,
              // Dört satırlık pencere: referanstaki kutu da bu yükseklikte ve
              // "kısa not" sözü tutuluyor — uzun yazan kullanıcıda içi kayıyor.
              maxLines: 4,
              minLines: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              // Düzenlemede "Kaydet" değil "Değişiklikleri Kaydet": kullanıcı
              // yeni bir şey yaratmıyor, var olanı düzeltiyor.
              _isEditing ? l10n.commonSaveChanges : l10n.personSaveAction,
            ),
          ),

          // SİL — yalnızca düzenlemede.
          //
          // Kaydet'in ALTINDA ve düğme değil metin: ikisi eşit ağırlıkta
          // görünmemeli (referansta da öyle). Anı formunda da aynı yerleşim.
          if (_isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              child: TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(AppIcons.delete, size: AppIconSize.md),
                label: Text(l10n.personDeleteAction),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Galeriden tek fotoğraf.
  Future<void> _pickPhoto() async {
    final result = await ref
        .read(mediaPickerProvider)
        .pickImages(limit: PersonEditorView.kPhotoLimit);

    // Seçici uygulamanın DIŞINDA çalışıyor; dönüşte bu ekran hâlâ ayakta mı
    // diye bakmak zorundayız (use_build_context_synchronously).
    if (!mounted) return;

    result.fold(
      onOk: (images) {
        final path = images.firstOrNull?.path;
        if (path == null) return; // vazgeçti — bir hata değil, bir karar
        setState(
          () => _photo = MediaItem(
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

  Future<void> _pickBirthDate() async {
    final now = ref.read(clockProvider).now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, now.month, now.day),
      // Doğum tarihi GEÇMİŞTE: üst sınır bugün.
      firstDate: DateTime(1900),
      lastDate: now,
      // Yıl seçimiyle AÇILIYOR: doğum tarihinde asıl iş yılı bulmak, gün
      // takvimi 30 yıl geriye sayfa sayfa gitmek demek olurdu.
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _birthDate = picked;
      _birthDateController.text = _formatBirthDate(picked);
    });
  }

  /// Alandaki tarih metni.
  ///
  /// YIL DA YAZIYOR ("18 Nisan 1968"): kişi detayındaki çipte yıl yok çünkü
  /// orada soru "ne zaman kutluyoruz", ama düzenlenebilir bir alanda yılı
  /// saklamak kullanıcıya doğru tarihi seçip seçmediğini gizlemek olurdu.
  String _formatBirthDate(DateTime date) =>
      DateFormat.yMMMMd(context.l10n.localeName).format(date);

  /// Doğrular, sonra kaydeder.
  void _save() {
    final l10n = context.l10n;
    final name = _nameController.text.trim();

    // FR-061 — ad zorunlu. Tek doğrulama bu: öteki üç alan opsiyonel ve
    // tarih zaten takvimden geliyor, yani geçersiz olamaz.
    if (name.isEmpty) {
      setState(() => _nameError = l10n.personNameRequired);
      return;
    }

    unawaited(_persist(name));
  }

  /// Kaydeder ve ekranı kapatır.
  ///
  /// BAŞARIDA BİLDİRİM YOK — bilinçli. Kullanıcı listeye dönüyor ve kişiyi
  /// orada görüyor; asıl onay bu. Üstüne bir de "kaydedildi" balonu
  /// göstermek, kullanıcının zaten gördüğü şeyi tekrar söylemek olurdu.
  ///
  /// HATADA ekran KAPANMIYOR: form dolu kalıyor ki kullanıcı yazdıklarını
  /// kaybetmesin (TR-C-12'nin paywall için söylediğinin aynısı).
  Future<void> _persist(String name) async {
    final result = await ref
        .read(personRepositoryProvider)
        .save(
          PersonDraft(
            id: widget.personId,
            name: name,
            // İlişki TÜRÜ burada hesaplanmıyor: bu bir veri yorumlama
            // kuralı ve `PersonMapper` içinde yaşıyor. Ekran yalnız
            // kullanıcının YAZDIĞINI taşıyor.
            relationLabel: _relationController.text,
            birthDate: _birthDate,
            note: _noteController.text,
          ),
        );

    if (!mounted) return;

    switch (result) {
      case Ok():
        context.pop();
      case Err(:final failure):
        context.showSnack(failure.localizedMessage(context.l10n));
    }
  }

  /// NFR-034: kritik silme işleminde açık onay.
  ///
  /// Kişi detayındaki üç nokta menüsündeki onayla AYNI metinler: kullanıcı
  /// aynı işi iki yerden yapabiliyor ve iki farklı uyarı görmek hangisinin
  /// doğru olduğunu sorgulatırdı.
  Future<void> _confirmDelete() async {
    final l10n = context.l10n;

    final confirmed = await context.confirm(
      title: l10n.personDeleteTitle,
      // FR-063 — kişiyi silmek ANILARI SİLMİYOR. Kullanıcı bunu onaydan önce
      // bilmeli; yoksa silmeye cesaret edemez ya da yanlış şeyi bekler.
      message: l10n.personDeleteMessage,
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final personId = widget.personId;
    if (personId == null) {
      // Henüz kaydedilmemiş bir kişi: silinecek bir şey yok, formdan çık.
      context.pop();
      return;
    }

    final result = await ref
        .read(personRepositoryProvider)
        .softDelete(personId);
    if (!mounted) return;

    switch (result) {
      case Ok():
        context.pop();
      case Err(:final failure):
        // Silinemedi: ekranda kalıyoruz ki kullanıcı tekrar deneyebilsin.
        context.showSnack(failure.localizedMessage(l10n));
    }
  }
}
