/// Anı oluşturma/düzenleme ViewModel'i.
///
/// FORM STATE'İ NEDEN ViewModel'DE?
/// `TextEditingController`ları widget'ta tutmak normaldir, ama "hangi
/// kişiler seçili", "hangi fotoğraflar eklendi", "kaydediliyor mu",
/// "hangi alanda hata var" gibi bilgiler **iş state'idir** ve widget
/// yeniden kurulduğunda (rotasyon, tema değişimi) kaybolmamalıdır.
///
/// Bu ViewModel `MemoryDraft`ı tutar; kaydetme sırasında [SaveMemory]
/// use case'ini çağırır ve iş kuralı hatalarını alan bazında forma yansıtır.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/result/result.dart';
import 'package:iz/core/utils/clock.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/memories/data/repositories/memory_repository_impl.dart';
import 'package:iz/features/memories/domain/entities/memory.dart';
import 'package:iz/features/memories/presentation/providers/memory_providers.dart';

/// Editör ekranının tüm görünür durumu tek nesnede.
///
/// Ayrı ayrı `isSaving`, `error`, `draft` provider'ları yerine tek state:
/// View tek `watch` ile her şeyi alır ve tutarsız ara durum oluşmaz.
/// Formda seçilmiş bir kayıt (kişi, kategori, koleksiyon, seri).
///
/// ⚠️ NEDEN AYRI BİR TİP, NEDEN `MemoryDraft`IN ID ALANLARI DEĞİL?
///
/// Taslakta `personIds`, `categoryId`, `collectionIds`, `ritualId` alanları
/// ZATEN VAR ve doğru yer orası. Ama o kimlikleri şu an dolduramıyoruz:
/// veritabanında karşılık gelen kayıtlar yok (`PersonDao`, `CollectionDao`,
/// `RitualDao` yazılmadı) ve `PRAGMA foreign_keys = ON` olduğu için var
/// olmayan bir `personId` ile kaydetmek yabancı anahtar ihlaliyle
/// BAŞARISIZ olurdu — kullanıcı her seçim yaptıktan sonra kaydedemezdi.
///
/// Bu yüzden seçimler şimdilik yalnızca EKRANDA yaşıyor: kullanıcı seçtiğini
/// görüyor, ama kayıt bu alanları taşımıyor.
///
/// DAO'lar geldiğinde yapılacak tek şey: burada tutulan kimlikleri
/// `_update` içinde taslağa da yazmak. Ekranın tek satırı değişmeyecek.
typedef MemoryFormSelection = ({String id, String label});

final class MemoryEditorState {
  const MemoryEditorState({
    required this.draft,
    this.isLoading = false,
    this.isSaving = false,
    this.validationError,
    this.generalError,
    this.savedId,
    this.locationLabel,
    this.dateError,
    this.people = const [],
    this.category,
    this.collections = const [],
    this.series,
    this.photos = const [],
  });

  final MemoryDraft draft;
  final bool isLoading;
  final bool isSaving;

  /// Kullanıcının elle yazdığı konum.
  ///
  /// Taslakta `locationId` var (Locations tablosuna referans); serbest metni
  /// bir konum KAYDINA çevirmek repository'nin işi ve o hat henüz yok.
  /// Yukarıdaki [MemoryFormSelection] notuyla aynı gerekçe.
  final String? locationLabel;

  /// Elle yazılan tarih ayrıştırılamadığında gösterilecek metin.
  ///
  /// [validationError] DEĞİL: o iş kuralı hatası (domainden gelir), bu ise
  /// bir GİRDİ BİÇİMİ hatası ve yalnızca bu ekranı ilgilendiriyor.
  final String? dateError;

  final List<MemoryFormSelection> people;
  final MemoryFormSelection? category;
  final List<MemoryFormSelection> collections;
  final MemoryFormSelection? series;

  /// Şeritte görünen fotoğraflar.
  ///
  /// NEDEN TEK LİSTE? Şerit iki farklı yerden besleniyor:
  ///   • YENİ anıda kullanıcının galeriden seçtiği DOSYA YOLLARI
  ///   • DÜZENLEMEDE anıya bağlı kayıtlı [MediaItem]lar
  /// Şeride iki ayrı liste verseydik silme, ekleme ve sıra mantığını iki kez
  /// yazmak gerekirdi. Seçilen yollar için geçici bir [MediaItem] üretiyoruz
  /// (bkz. [MemoryEditorViewModel.pickedMedia]); şerit tek tip görüyor.
  final List<MediaItem> photos;

  /// İş kuralı hatası. Hangi alanın altında görüneceğini `code.field` söyler.
  ///
  /// NOT: Burada hazır METİN tutmuyoruz. Metin dile bağlıdır; ViewModel ise
  /// dil bilmez. View, [errorFor] ile hatayı alır ve `localizedMessage`
  /// çağırarak çevirir.
  final ValidationFailure? validationError;

  /// Alanla eşleşmeyen hata (SnackBar'da gösterilir).
  final Failure? generalError;

  /// Kaydetme başarılı olduğunda dolar → View bunu görüp ekranı kapatır.
  final String? savedId;

  bool get canSave => draft.hasContent && !isSaving;

  /// Verilen form alanı için hata varsa döner, yoksa null.
  /// Kullanım: `errorText: state.errorFor(MemoryFormField.note)?.localizedMessage(l10n)`
  ValidationFailure? errorFor(String field) =>
      validationError?.code.field == field ? validationError : null;

  MemoryEditorState copyWith({
    MemoryDraft? draft,
    bool? isLoading,
    bool? isSaving,
    ValidationFailure? validationError,
    Failure? generalError,
    String? savedId,
    String? locationLabel,
    String? dateError,
    List<MemoryFormSelection>? people,
    MemoryFormSelection? category,
    List<MemoryFormSelection>? collections,
    MemoryFormSelection? series,
    List<MediaItem>? photos,
    bool clearErrors = false,
    bool clearSavedId = false,
    bool clearDateError = false,
    // Tek seçimli alanlar TEMİZLENEBİLİR olmalı: kullanıcı seçtiği
    // kategoriyi geri alabilir. `copyWith(category: null)` bunu ifade
    // edemediği için ayrı bayrak (aynı desen `clearErrors`ta da var).
    bool clearCategory = false,
    bool clearSeries = false,
  }) => MemoryEditorState(
    draft: draft ?? this.draft,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    validationError: clearErrors
        ? null
        : (validationError ?? this.validationError),
    generalError: clearErrors ? null : (generalError ?? this.generalError),
    savedId: clearSavedId ? null : (savedId ?? this.savedId),
    locationLabel: locationLabel ?? this.locationLabel,
    dateError: clearDateError ? null : (dateError ?? this.dateError),
    people: people ?? this.people,
    category: clearCategory ? null : (category ?? this.category),
    collections: collections ?? this.collections,
    series: clearSeries ? null : (series ?? this.series),
    photos: photos ?? this.photos,
  );
}

class MemoryEditorViewModel extends Notifier<MemoryEditorState> {
  MemoryEditorViewModel(this.memoryId);

  /// null → yeni anı, dolu → düzenleme. Family argümanı.
  final String? memoryId;

  @override
  MemoryEditorState build() {
    final now = ref.read(clockProvider).now();

    if (memoryId == null) {
      return MemoryEditorState(draft: MemoryDraft(occurredAt: now));
    }

    // Düzenleme: mevcut anıyı yükle. build() senkron olmak zorunda
    // olduğu için yüklemeyi arka planda başlatıyoruz.
    unawaited(_loadExisting(memoryId!));
    return MemoryEditorState(
      draft: MemoryDraft(occurredAt: now),
      isLoading: true,
    );
  }

  Future<void> _loadExisting(String id) async {
    final result = await ref.read(memoryRepositoryProvider).findDetail(id);

    state = result.fold(
      onOk: (detail) {
        if (detail == null) {
          return state.copyWith(
            isLoading: false,
            generalError: NotFoundFailure(entity: 'Memory', id: id),
          );
        }
        // ALANLAR DOLU AÇILIYOR.
        //
        // Taslak kimlikleri taşıyor ama ekranda ADLAR görünüyor; ikisi ayrı
        // şeyler (bkz. [MemoryFormSelection]). Adlar burada, kaydın kendisinden
        // geliyor — başka bir sorgu gerekmiyor.
        //
        // KATEGORİ BURADA YOK: `MemoryDetail` kategori nesnesi taşımıyor,
        // yalnızca kimliğini. Sistem kategorilerinin adı DİLE bağlı ve bu sınıf
        // dil bilmiyor; adı View çözüyor (`_categoryLabelOf`).
        return state.copyWith(
          isLoading: false,
          draft: _toDraft(detail),
          locationLabel: detail.location?.label ?? detail.memory.locationLabel,
          people: [
            for (final person in detail.people)
              (id: person.id, label: person.name),
          ],
          collections: [
            for (final collection in detail.collections)
              (id: collection.id, label: collection.title),
          ],
          series: detail.ritual == null
              ? null
              : (id: detail.ritual!.id, label: detail.ritual!.title),
          photos: detail.media,
        );
      },
      onErr: (failure) =>
          state.copyWith(isLoading: false, generalError: failure),
    );
  }

  static MemoryDraft _toDraft(MemoryDetail detail) => MemoryDraft(
    id: detail.id,
    occurredAt: detail.memory.occurredAt,
    title: detail.memory.title,
    note: detail.memory.note,
    categoryId: detail.memory.categoryId,
    personIds: detail.people.map((p) => p.id).toList(),
    collectionIds: detail.collections.map((c) => c.id).toList(),
    mediaIds: detail.media.map((m) => m.id).toList(),
    coverMediaId: detail.memory.coverMedia?.id,
    ritualId: detail.ritual?.id,
    ritualYear: detail.ritualYear,
    locationId: detail.location?.id,
    isFavorite: detail.memory.isFavorite,
  );

  // --- Form komutları -----------------------------------------------------

  void setTitle(String? value) => _update((d) => d.copyWith(title: value));

  void setNote(String? value) => _update((d) => d.copyWith(note: value));

  void setOccurredAt(DateTime value) {
    state = state.copyWith(
      draft: state.draft.copyWith(occurredAt: value),
      clearErrors: true,
      clearDateError: true,
    );
  }

  /// Kullanıcının ELLE yazdığı tarihi ayrıştırır.
  ///
  /// Takvimden seçmek her zaman geçerli bir tarih verir; yazmak vermez.
  /// İki hata durumu var ve ikisi de AYNI yere (`dateError`) yazılıyor
  /// çünkü ikisi de kullanıcının bu alandaki girdisiyle ilgili:
  ///   • ayrıştırılamayan metin  → "Tarihi anlayamadım…"
  ///   • gelecekteki tarih       → FR-013
  ///
  /// [parse] ve hata metinleri DIŞARIDAN geliyor: ViewModel dili bilmez ve
  /// `intl`in cihaz diline bağlı biçimleyicisini burada kurmak, sınıfı
  /// Flutter'a bağlardı.
  void setOccurredAtFromText(
    String text, {
    required DateTime? Function(String) parse,
    required String invalidMessage,
    required String futureMessage,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(clearDateError: true);
      return;
    }

    final parsed = parse(trimmed);
    if (parsed == null) {
      state = state.copyWith(dateError: invalidMessage);
      return;
    }

    // FR-013 — geçmişe izin var, geleceğe yok. Kural asıl olarak
    // `SaveMemory`de duruyor; burada kullanıcıyı kaydete basmadan uyarıyoruz.
    if (parsed.isAfter(ref.read(clockProvider).now())) {
      state = state.copyWith(dateError: futureMessage);
      return;
    }

    setOccurredAt(parsed);
  }

  void setLocation(String? value) {
    final trimmed = value?.trim();
    state = state.copyWith(
      locationLabel: (trimmed == null || trimmed.isEmpty) ? '' : trimmed,
      clearErrors: true,
    );
  }

  // --- Seçim alanları -------------------------------------------------------
  //
  // Dördü de aynı deseni izliyor: seçim EKRAN durumunda tutuluyor, taslağın
  // id alanlarına yazılmıyor (gerekçe: [MemoryFormSelection]).

  void setPeople(List<MemoryFormSelection> people) =>
      state = state.copyWith(people: people, clearErrors: true);

  /// Kategori — TASLAĞA DA YAZILAN tek seçim.
  ///
  /// Öteki üçü yalnızca ekranda yaşıyor çünkü karşılık gelen veritabanı
  /// satırları yok. Kategori FARKLI: sistem kategorileri (`SystemCategory`)
  /// ilk açılışta veritabanına tohumlanıyor, yani `cat_travel` GERÇEK bir
  /// satır. Taslağa yazmak yabancı anahtar ihlali değil — ve yazmasak
  /// kullanıcının seçtiği kategori kaydedilmezdi.
  void setCategory(MemoryFormSelection? category) => state = state.copyWith(
    draft: state.draft.copyWith(categoryId: category?.id),
    category: category,
    clearCategory: category == null,
    clearErrors: true,
  );

  void setCollections(List<MemoryFormSelection> collections) =>
      state = state.copyWith(collections: collections, clearErrors: true);

  void setSeries(MemoryFormSelection? series) => state = state.copyWith(
    series: series,
    clearSeries: series == null,
    clearErrors: true,
  );

  /// Galeriden seçilen dosya yollarını şeride ekler.
  ///
  /// ⚠️ HENÜZ KALICI DEĞİL. Medya hattı (dosyayı uygulama alanına kopyalama,
  /// önizleme üretme, `MediaItems` tablosuna yazma) kurulmadı; ürettiğimiz
  /// [MediaItem]ların kimliği geçici ve `mediaIds`e YAZILMIYOR — var olmayan
  /// bir medya kimliğiyle kaydetmek yabancı anahtar ihlali olurdu.
  ///
  /// Hat kurulduğunda burası dosyaları kaydedip gerçek kimlikleri
  /// [addMedia]ya geçecek; şeridin tek satırı değişmeyecek.
  void addPickedPhotos(List<String> paths) {
    final next = [...state.photos];
    for (final path in paths) {
      if (next.any((m) => m.localPreviewPath == path)) continue;
      next.add(pickedMedia(path));
    }
    state = state.copyWith(photos: next, clearErrors: true);
  }

  /// Şeritten bir fotoğrafı kaldırır.
  ///
  /// Kayıtlı bir medyaysa taslaktan da düşüyor ([removeMedia]); yeni
  /// seçilmiş geçici bir kareyse taslakta hiç yoktu ve orada bir şey
  /// değişmiyor.
  void removePhoto(String mediaId) {
    state = state.copyWith(
      photos: state.photos.where((m) => m.id != mediaId).toList(),
      clearErrors: true,
    );
    if (state.draft.mediaIds.contains(mediaId)) removeMedia(mediaId);
  }

  /// Galeriden seçilmiş, henüz kaydedilmemiş bir kare.
  ///
  /// Kimlik ÖNEKLİ (`picked:`) çünkü gerçek bir medya kimliği değil: taslağa
  /// yazılmaması gerektiğini kodun kendisi söylüyor.
  static MediaItem pickedMedia(String path) => MediaItem(
    id: 'picked:$path',
    type: MediaType.photo,
    originalStatus: MediaOriginalStatus.available,
    localPreviewPath: path,
  );

  void addMedia(List<String> mediaIds) => _update((d) {
    final next = [...d.mediaIds];
    for (final id in mediaIds) {
      if (!next.contains(id)) next.add(id);
    }
    // İlk fotoğraf otomatik kapak olur (FR-018).
    return d.copyWith(
      mediaIds: next,
      coverMediaId: d.coverMediaId ?? next.firstOrNull,
    );
  });

  void removeMedia(String mediaId) => _update((d) {
    final next = [...d.mediaIds]..remove(mediaId);
    return d.copyWith(
      mediaIds: next,
      coverMediaId: d.coverMediaId == mediaId
          ? next.firstOrNull
          : d.coverMediaId,
    );
  });

  /// FR-018 — kapak görselini değiştir.
  void setCover(String mediaId) =>
      _update((d) => d.copyWith(coverMediaId: mediaId));

  void toggleFavorite() =>
      _update((d) => d.copyWith(isFavorite: !d.isFavorite));

  /// Kaydeder. Başarılıysa `state.savedId` dolar → View ekranı kapatır.
  Future<void> save() async {
    if (state.isSaving) return; // çift dokunmaya karşı koruma

    state = state.copyWith(isSaving: true, clearErrors: true);

    final result = await ref.read(saveMemoryProvider)(state.draft);

    state = result.fold(
      onOk: (id) => state.copyWith(isSaving: false, savedId: id),
      // İş kuralı hatası → forma yansır. Diğer her şey → SnackBar.
      onErr: (failure) => state.copyWith(
        isSaving: false,
        validationError: failure is ValidationFailure ? failure : null,
        generalError: failure is ValidationFailure ? null : failure,
      ),
    );
  }

  /// FR-014/FR-015 — anıyı çöp kutusuna taşır (geri alınabilir).
  ///
  /// Yalnızca DÜZENLEME modunda anlamlı; yeni anıda silinecek bir kayıt yok.
  /// Onayı ve "geri al" bildirimini View yönetiyor (NFR-034).
  Future<Result<Unit>> moveToTrash() async {
    final id = memoryId;
    if (id == null) return okUnit;
    return ref.read(memoryRepositoryProvider).moveToTrash(id);
  }

  /// View, hatayı gösterdikten sonra çağırır — aynı hata iki kez
  /// SnackBar açmasın.
  void consumeError() => state = state.copyWith(clearErrors: true);

  void _update(MemoryDraft Function(MemoryDraft draft) transform) {
    state = state.copyWith(draft: transform(state.draft), clearErrors: true);
  }
}

final memoryEditorProvider =
    NotifierProvider.family<MemoryEditorViewModel, MemoryEditorState, String?>(
      MemoryEditorViewModel.new,
      isAutoDispose: true,
    );
