# İZ — Mimari Rehberi

> Bu doküman projenin **nasıl çalıştığını** ve **nasıl büyütüleceğini** anlatır.
> Yeni bir özelliğe başlamadan önce "Yeni feature ekleme reçetesi" bölümünü oku.

---

## 1. Neden bu mimari?

Gereksinim raporu ürünü 5 faza yayıyor: MVP → V1.5 (bulut) → V2 (ortak koleksiyon)
→ V2.5 (Atölye/e-ticaret) → V3 (AI, sesli İZ). Yani kod **sürekli büyüyecek** ve
bugün yazdığın bir ekran, iki faz sonra tamamen farklı bir veri kaynağından
beslenecek.

Bu yüzden tek bir kurala takıntılıyız:

> **Bir katman, kendisinden daha somut olan hiçbir şeyi bilmez.**

Bunun somut getirisi: V1.5'te Drift'in yanına bulut senkronizasyonu eklediğimizde
`MemoryRepository` arayüzünün arkasını değiştireceğiz ve **hiçbir ViewModel, hiçbir
widget değişmeyecek.**

---

## 2. Katmanlar ve bağımlılık yönü

```
┌──────────────────────────────────────────────────────────────┐
│  app/          Composition root — HER ŞEYİ bilir             │
│                (router, AppDatabase, bootstrap)              │
└───────────────────────────┬──────────────────────────────────┘
                            │ bilir
┌───────────────────────────▼──────────────────────────────────┐
│  features/<x>/presentation   View + ViewModel                │
│                              (Flutter'ı bilir, SQL'i bilmez) │
└───────────────────────────┬──────────────────────────────────┘
                            │ bilir
┌───────────────────────────▼──────────────────────────────────┐
│  features/<x>/domain      Entity + Repository sözleşmesi     │
│                           + UseCase                          │
│                           (SAF DART — Flutter yok, SQL yok)  │
└───────────────────────────▲──────────────────────────────────┘
                            │ uygular (implements)
┌───────────────────────────┴──────────────────────────────────┐
│  features/<x>/data        Tablo + DAO + Mapper + Repo impl   │
│                           (Drift'i bilir)                    │
└──────────────────────────────────────────────────────────────┘

  shared/   Feature'lar arası ortak UI       → sadece core'u bilir
  core/     Altyapı (Result, tema, l10n…)    → HİÇBİR feature'ı bilmez
```

**Dikkat:** `data` katmanı `domain`'e bağımlıdır, tersi değil. Domain arayüzü
tanımlar, data onu uygular. Buna *bağımlılığın tersine çevrilmesi* denir ve
tüm mimarinin can damarıdır.

### Feature'lar arası kural

Bir feature başka bir feature'ın **sadece `domain/` klasörünü** import edebilir.

```dart
// ✅ İZİN VAR — memories, person entity'sini kullanabilir
import 'package:iz/features/people/domain/entities/person.dart';

// ❌ YASAK — başka feature'ın DAO'suna dokunma
import 'package:iz/features/people/data/daos/person_dao.dart';

// ❌ YASAK — başka feature'ın ekranını doğrudan çağırma
import 'package:iz/features/people/presentation/views/people_view.dart';
```

Başka bir feature'ın ekranına gitmen gerekiyorsa **rota adıyla** git:

```dart
context.pushNamed(AppRoute.personDetail.name, pathParameters: {'id': id});
```

#### Tek istisna: l10n köprüleri

`<feature>/presentation/<x>_l10n.dart` dosyaları başka feature'lardan
import edilebilir (`category_l10n.dart`, `ritual_l10n.dart`). Bunlar bir
domain entity'sini kullanıcı metnine çeviren **saf fonksiyonlar** — widget
yok, state yok, `Navigator` yok. Yasağın koruduğu şey (bir ekranın başka bir
ekranın iç yapısına bağlanması) burada oluşmuyor.

Örnek: "Hayatım" ekranının SERİLERİM sekmesi `Ritual` entity'sini
gösteriyor ve "Her yıl 3 Mart'ta" metnini `ritual_l10n.dart`tan alıyor.
Aynı köprüyü kopyalamak, Türkçe ek kurallarının iki yerde ayrışması
demekti.

---

## 3. Veri akışı — bir anıya favori demek

Somut bir örnekle tüm zinciri izleyelim:

```
[1] Kullanıcı kalp ikonuna dokunur
     MemoryCard(onFavoriteToggle: …)                   ← saf widget, sadece haber verir

[2] View komutu ViewModel'e iletir
     ref.read(memoryListProvider.notifier).toggleFavorite(memory)

[3] ViewModel repository'yi çağırır
     repository.setFavorite(id, isFavorite: !memory.isFavorite)
     → Future<Result<Unit>>  (exception fırlatmaz!)

[4] Repository DAO'yu çağırır, exception'ı Failure'a çevirir
     guard(() => _dao.setFavorite(...), onError: DatabaseFailure.new)

[5] DAO SQL çalıştırır (transaction içinde, version + 1)
     UPDATE memories SET is_favorite = ?, version = version + 1 …

[6] ⚡ Drift, memories tablosunun değiştiğini görür ve
     watchMemories() stream'ini KENDİLİĞİNDEN yeniden yayınlar

[7] ViewModel'in build()'i o stream'e bağlı olduğu için
     AsyncValue<List<Memory>> güncellenir

[8] ref.watch yapan View yeniden çizilir — kalp dolu görünür
```

**Kritik nokta:** 6–8 arası adımları sen yazmıyorsun. `setState` yok, manuel
`refresh()` yok, "listeyi güncelle" çağrısı yok. Drift'in reaktif sorguları +
Riverpod bunu üstleniyor. Bu, veri ile ekranın **asla tutarsız kalmamasını**
garanti eder.

---

## 4. Her katmanın kuralları

### `core/` — altyapı

Feature bilmez. Buraya bir şey koymadan önce sor: *"Bu, İZ'e özgü bir iş kuralı mı,
yoksa herhangi bir uygulamada olabilecek bir altyapı parçası mı?"* İş kuralıysa
`features/`e gider.

| Dosya | Ne işe yarar |
|---|---|
| `result/result.dart` | `Result<T>` = başarı **veya** hata. Repository'ler bunu döner. |
| `error/failure.dart` | Domain'in tanıdığı sonlu hata kümesi (`sealed`) + `ValidationCode`. |
| `l10n/failure_l10n.dart` | Hata → kullanıcı metni köprüsü. Çeviri seçimi BURADA yapılır. |
| `l10n/app_languages.dart` | Desteklenen diller. Yeni dil eklerken tek dokunulacak yer. |
| `entitlement/entitlement.dart` | FR-130 özellik matrisi. Free/İZ+ farkları **tek dosyada**. |
| `config/feature_flags.dart` | NFR-061 faz bayrakları. Yarım özelliği kapatarak main'de tut. |
| `theme/` | Tasarım tokenları. Widget'ta `fontSize: 18` yazma, temadan oku. |
| `utils/clock.dart` | `DateTime.now()` yerine bunu kullan — yoksa zaman bağımlı kod test edilemez. |
| `utils/id_generator.dart` | UUID v7. Sync geldiğinde id çakışması olmasın diye. |

### `domain/` — saf iş mantığı

**Bu klasörde `import 'package:flutter/...'` GÖRÜRSEN bir şey yanlıştır.**
Domain'in Flutter'ı bilmemesi, iş kurallarını widget kurmadan, milisaniyelerde
test edebilmeni sağlar.

- `entities/` — değişmez (immutable) veri sınıfları + türetilmiş kurallar
  (`memory.hasContent`, `mediaItem.isPrintable`)
- `repositories/` — **sadece arayüz**, implementasyon yok
- `usecases/` — aşağıdaki 4 durumdan biri varsa yaz, yoksa yazma:
  1. İş kuralı var (FR-012: boş anı kaydedilemez)
  2. Birden fazla repository'yi birleştiriyorsun (FR-034: günlükten anıya)
  3. Entitlement kapısı var (FR-048: video sadece İZ+)
  4. Aynı mantık iki ViewModel'de tekrar ediyor

  Bunların hiçbiri yoksa ViewModel doğrudan repository'yi çağırsın. Gereksiz
  UseCase katmanı sadece dosya sayısını artırır.

> **UseCase'in provider'ı `domain/` içinde DURMAZ.** Bir provider tanımlamak
> `flutter_riverpod`ı, onu kurmak da somut repository'yi (yani `data/`
> katmanını) import etmeyi gerektirir — ikisi de yukarıdaki kuralı bozar.
> Sınıf domain'de saf Dart olarak kalır, kurulumu
> `presentation/providers/<feature>_providers.dart` içinde yapılır.
>
> Getirisi somut: `SaveMemory` testi Riverpod kurmuyor, sınıfı doğrudan
> `new`liyor (bkz. `test/unit/save_memory_test.dart`).

### `data/` — dış dünya

- `tables/` — Drift tablo tanımları
- `daos/` — **sadece SQL.** İş kuralı yok, `Result` yok, domain tipi yok.
- `mappers/` — satır ↔ entity çevirisi
- `repositories/` — DAO'yu kullanır, exception'ı `Failure`a çevirir, `Result` döner

> **Kural:** `data` katmanının exception'ları (`LocalDatabaseException` vb.)
> bu klasörün dışına ÇIKMAZ. Repository onları `Failure`a çevirir.

### `presentation/` — ekran

- `view_models/` — `Notifier` / `StreamNotifier`. **BuildContext tutmaz,
  Navigator çağırmaz, widget bilmez.** Saf Dart testi yazılabilmeli.
- `views/` — `ConsumerWidget`. `ref.watch` ile state okur, `ref.read(...)` ile
  komut gönderir, navigasyonu **View** yapar. Başka ekrana giderken **her zaman
  `AppRoute` enum'u** kullan; `pushNamed('memory-detail')` gibi ham string
  yazma — yazım hatasını derleyici yakalamaz, uygulama çalışma zamanında
  "sayfa bulunamadı"ya düşer.
- `widgets/` — mümkün olduğunca Riverpod'suz, saf widget'lar. Böylece hem
  yeniden kullanılabilir hem de `ProviderScope` kurmadan test edilebilir olurlar.
- `providers/` — UseCase'lerin DI bağlantıları (bkz. yukarıdaki `domain/`
  notu). Yalnızca kurulum; iş mantığı buraya yazılmaz.

### Çok dillilik (l10n) — bütün katmanları ilgilendirir

İZ çok dilli bir uygulama. Bu yüzden tek bir kural var:

> **Kullanıcının okuyacağı hiçbir metin `.dart` dosyasında yazılı olmaz.**

Metin `lib/core/l10n/arb/` altında yaşar, `context.l10n.<anahtar>` ile okunur.
Kural `flutter test` ile **mekanik olarak** denetlenir (`test/unit/l10n_test.dart`),
yani unutulduğunda yazıldığı gün yakalanır.

Bu kuralın **üç bilinçli istisnası** var:

| İstisna | Neden | Nerede |
|---|---|---|
| `Failure.message` | Loga gider, kullanıcı görmez. İngilizce ve teknik yazılır. | `core/error/failure.dart` |
| Dil adları ("Türkçe") | Bir dil kendi adıyla yazılır; çevrilirse kullanıcı kendi dilini bulamaz. | `core/l10n/app_languages.dart` |
| Kullanıcı verisi | Kişi adı, anı notu, kullanıcının açtığı kategori — bunlar veri, arayüz metni değil. | veritabanı |

**Domain katmanı metin taşımaz, KOD taşır.** Bir iş kuralı ihlalinde
`ValidationFailure(code: ValidationCode.emptyMemory)` dönersin; hangi cümlenin
gösterileceğine `core/l10n/failure_l10n.dart` karar verir:

```
SaveMemory            →  ValidationCode.emptyMemory      (domain: dil bilmez)
failure_l10n.dart     →  l10n.errorValidationEmptyMemory (UI: dili bilir)
```

Aynı desen kategori adlarında da geçerli: sistem kategorilerinin veritabanındaki
`name` sütununda **ad değil anahtar** durur (`travel`), gösterim
`category_l10n.dart` içinde çözülür.

Yeni bir dil eklemek için `core/l10n/app_languages.dart` başındaki reçeteyi izle.

---

## 5. Yeni feature ekleme reçetesi

Örnek: **Günlük (Journal)** feature'ını tamamlayalım. Domain modeli ve tablosu
zaten hazır (`journal/domain/entities/journal_entry.dart`,
`journal/data/tables/journal_tables.dart`).

### Adım 1 — Domain sözleşmesi

`lib/features/journal/domain/repositories/journal_repository.dart`

```dart
abstract interface class JournalRepository {
  Stream<Result<List<JournalEntry>>> watchEntries({DateTime? month});
  Future<Result<String>> saveEntry(JournalEntry entry);
  Future<Result<Unit>> deleteEntry(String id);
}
```

### Adım 2 — DAO

`lib/features/journal/data/daos/journal_dao.dart`

```dart
part 'journal_dao.g.dart';

@DriftAccessor(tables: [JournalEntries, JournalMedia, MediaItems])
class JournalDao extends DatabaseAccessor<AppDatabase>
    with _$JournalDaoMixin {
  JournalDao(super.db);

  Stream<List<JournalEntryRow>> watchEntries() =>
      (select(journalEntries)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.entryDate)]))
          .watch();
}
```

### Adım 3 — DAO'yu veritabanına tanıt

`lib/app/database/app_database.dart` içinde `daos:` listesine ekle:

```dart
@DriftDatabase(
  tables: [ … ],
  daos: [MemoryDao, JournalDao],   // ← eklendi
  include: {'package:iz/features/search/data/search.drift'},
)
```

> Yeni bir **tablo** eklediysen `tables:` listesine de ekle, `schemaVersion`i
> +1 yap ve `onUpgrade` içine migration adımını yaz.

### Adım 4 — Codegen

```bash
dart run build_runner build
```

### Adım 5 — Repository implementasyonu

`lib/features/journal/data/repositories/journal_repository_impl.dart`

`MemoryRepositoryImpl`i şablon olarak kullan: `guard(...)` ile exception'ları
`Failure`a çevir, mapper ile domain'e dönüştür, sonda provider'ı tanımla:

```dart
final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  );
});
```

### Adım 6 — ViewModel

`lib/features/journal/presentation/view_models/journal_list_view_model.dart`

```dart
class JournalListViewModel extends StreamNotifier<List<JournalEntry>> {
  @override
  Stream<List<JournalEntry>> build() =>
      ref.watch(journalRepositoryProvider).watchEntries().unwrap();

  Future<Result<Unit>> delete(String id) =>
      ref.read(journalRepositoryProvider).deleteEntry(id);
}

final journalListProvider =
    StreamNotifierProvider<JournalListViewModel, List<JournalEntry>>(
      JournalListViewModel.new,
    );
```

### Adım 7 — View'ı bağla

`journal_view.dart` içindeki placeholder'ı değiştir:

```dart
final state = ref.watch(journalListProvider);

return AsyncValueView<List<JournalEntry>>(
  value: state,
  onRetry: () => ref.invalidate(journalListProvider),
  emptyBuilder: () => const AppEmptyState(
    icon: Icons.edit_note_outlined,
    title: 'Bugün neyin izini bırakmak istersin?',
    actionLabel: 'Yaz',
  ),
  data: (entries) => ListView.builder( … ),
);
```

### Adım 8 — Rota ekle (yeni ekran varsa)

`app_routes.dart`'a enum girdisi, `app_router.dart`'a `GoRoute` ekle.

### Adım 9 — Test yaz

| Ne test edilir | Nerede | Nasıl |
|---|---|---|
| İş kuralı | `test/unit/…_test.dart` | Saf Dart, mock repository |
| SQL / şema | `test/unit/…_repository_test.dart` | `createTestDatabase()` — gerçek SQLite |
| ViewModel | `test/unit/…_view_model_test.dart` | `ProviderContainer` + override |
| Widget | `test/widget/…_test.dart` | `wrapWidget(...)` |
| Uçtan uca akış | `test/widget/…_test.dart` | `pumpApp(...)` — bkz. `test/helpers/app_harness.dart` |

> **Zamana bağlı bir kural mı test ediyorsun?** `DateTime.now()` yazma;
> `Clock` enjekte et ve testte `FixedClock` ver. Aksi hâlde test
> çalıştırıldığı güne göre sonuç değiştirir — `SaveMemory`nin FR-013 kuralı
> tam bu yüzden düzeltildi (bkz. `core/utils/clock.dart`).

---

## 6. Sık yapılan hatalar ve tuzaklar

Bu liste, bu projeyi kurarken **gerçekten karşılaşılan** sorunlardan çıktı.

### `Value(null)` ile `Value.absent()` farkı

```dart
MemoriesCompanion(deletedAt: const Value(null))    // sütunu NULL yap
MemoriesCompanion(deletedAt: const Value.absent()) // sütuna DOKUNMA
```
Karıştırırsan güncelleme sessizce yanlış çalışır.

### Drift enum'ları ve `app_database.dart` import'ları

Tabloda `textEnum<X>()` kullandıysan, `X`'i **`app_database.dart` içine de**
import etmelisin. Üretilen `app_database.g.dart` o dosyanın `part`'ıdır ve
onun import'larını kullanır.

⚠️ `flutter analyze` bunu **yakalamaz** (`*.g.dart` hariç tutulur). Hata ancak
`flutter test` / `flutter run` sırasında görünür. Bu yüzden codegen sonrası
mutlaka testleri çalıştır.

### Tarih ve zaman dilimi

Drift, `DateTime`'ı **UTC** ISO-8601 metni olarak saklar. Türkiye'de 26 Temmuz
00:30'da yaşanan anı UTC'de 25 Temmuz olur. Bu yüzden `memories` tablosunda
`occurredYear/Month/Day` sütunlarını **yerel** tarihle ayrıca tutuyoruz;
"Bugünün İzi" ve ritüel karşılaştırmaları bunları kullanır.

### `pumpAndSettle` sonsuza kadar bekler

Ekranda `CircularProgressIndicator` varsa animasyon hiç bitmez ve test 10 dakika
sonra timeout'a düşer. `test/widget/app_smoke_test.dart` içindeki `settle()`
yardımcısını kullan.

### Widget testinde gerçek veritabanı kullanma

Bekleyen timer'lar `!timersPending` hatası verir. Widget testlerinde
`FakeMemoryRepository` kullan; SQL doğruluğu zaten repository testlerinde
gerçek SQLite ile doğrulanıyor.

### `ref.read(provider.future)` tek başına abone olmaz

Testte önce `container.listen(...)` ile provider'ı canlı tut, yoksa
"disposed during loading state" hatası alırsın.

### `await` sonrası `context` kullanımı

```dart
final result = await viewModel.save();
if (!context.mounted) return;   // ← BU SATIR ŞART
context.showSnack(...);
```

Ekran kapandıktan sonra bir şey yapman gerekiyorsa (SnackBar'ın "Geri al"
butonu gibi), `ref` yerine pop'tan **önce** yakaladığın
`ProviderScope.containerOf(context)`i kullan.

### `DateFormat` uygulamanın dilini kendiliğinden BİLMEZ

`intl` paketi Flutter'ın dil sisteminden bağımsızdır; kendi global
`Intl.defaultLocale` değişkenine bakar. Ayarlamazsan kullanıcı arayüzü
İngilizce yapsa bile tarihler cihazın dilinde kalır. Bu yüzden `app.dart`
içindeki `builder:` her çizimde şunu yapıyor:

```dart
Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
```

`Localizations.localeOf` kullanıyoruz çünkü kullanıcının seçimi `null`
(sistem dili) olabilir — bize gereken **gerçekte gösterilen** dil.

### Veritabanına çevrilmiş metin yazma

Sistem kategorileri ilk açılışta bir kez tohumlanır. Oraya `'Seyahat'`
yazsaydık İngilizce arayüzde de Türkçe görünürdü ve düzeltmek — kayıtlar
kullanıcının cihazında olduğu için — bir **migration** gerektirirdi.
Bu yüzden `name` sütununa anahtar (`travel`) yazılır.

**Genel kural:** veritabanına yazdığın bir metnin dili varsa, dur ve düşün.

### `shared_preferences` testte `flutter.` öneki ister

```dart
SharedPreferences.setMockInitialValues({'flutter.onboarding_completed': true});
```

---

## 7. Komut referansı

```bash
# Bağımlılıklar
flutter pub get

# Kod üretimi (Drift/JSON) — tablo veya DAO değiştirdiğinde şart
dart run build_runner build

# Üretilen dosyalar bozulduysa
dart run build_runner build --delete-conflicting-outputs

# Sürekli izleme modunda üret
dart run build_runner watch

# Çeviri sınıflarını üret (.arb dosyalarını değiştirdiğinde)
flutter gen-l10n

# Statik analiz — commit öncesi temiz olmalı
flutter analyze

# Testler
flutter test
flutter test test/unit/save_memory_test.dart
flutter test --plain-name "FR-012"

# Çalıştır
flutter run
flutter run --dart-define=IZ_ENV=prod
```

---

## 8. Faz bayrakları — V1.5'e geçiş

Rapor 16. bölümdeki faz geçişini kodda tek satırla yapıyoruz.
`lib/app/bootstrap.dart` içinde:

```dart
final container = ProviderContainer(
  overrides: [
    appPreferencesProvider.overrideWithValue(AppPreferences(preferences)),
    featureFlagsProvider.overrideWithValue(const FeatureFlags.v15()), // ← faz
  ],
);
```

Ekranlarda:

```dart
if (ref.watch(featureFlagsProvider).cloudSync) {
  // bulut yedekleme kartını göster
}
```

Böylece yarım kalmış V1.5 kodu `main` dalında durabilir ama kullanıcıya
görünmez (R-004: aşırı özellik yükü riskinin azaltımı).

---

## 9. Gereksinim → kod haritası

Bir gereksinimi ararken nereye bakacağını gösteren tablo:

| Gereksinim | Kodda nerede |
|---|---|
| FR-001/004 onboarding | `features/onboarding/`, `app_router.dart` redirect |
| FR-010..020 anı yönetimi | `features/memories/` (tam örnek) |
| FR-012 boş anı engeli | `domain/usecases/save_memory.dart` |
| FR-013 geçmiş tarih | `memory_editor_view.dart` → `firstDate: DateTime(1900)` |
| FR-015 çöp kutusu | `memory_dao.dart` → `softDelete` / `purgeExpiredTrash` |
| FR-016/074 N-N ilişkiler | `memory_tables.dart` join tabloları |
| FR-030..035 günlük | `features/journal/` (model + tablo hazır) |
| FR-041 foto limiti | `core/entitlement/entitlement.dart` → `IzLimit.photosPerMemory` |
| FR-042/043/044 medya durumu | `features/media/domain/entities/media_item.dart` |
| FR-070 varsayılan kategoriler | `memory_category.dart` → `DefaultCategories.seed` |
| FR-080 Bugünün İzi | `memory_dao.dart` → `findOnThisDay` |
| FR-090/092 offline arama | `features/search/data/search.drift` (FTS5) |
| FR-130 entitlement matrisi | `core/entitlement/entitlement.dart` |
| BR-007 kaynak eksik | `MediaOriginalStatus`, `media_thumbnail.dart` |
| BR-011 günlük ≠ anı | `journal_entry.dart` → `convertedMemoryId` |
| BR-012 ritüel yapısı | `memory_tables.dart` → `MemoryRituals.occurrenceYear` |
| NFR-004/020 transaction | `memory_dao.dart` → `upsertMemory` |
| NFR-010/011 güvenli depolama | `core/storage/secure_store.dart` |
| NFR-013/014 log redaksiyonu | `core/logging/app_logger.dart` → `redact()` |
| NFR-032/033 erişilebilirlik | `app_theme.dart`, `app.dart` → `textScaler.clamp` |
| NFR-035 boş durumlar | `shared/widgets/app_empty_state.dart` |
| NFR-061 feature flag | `core/config/feature_flags.dart` |
| Rapor 12.2 sync hazırlığı | `core/database/table_mixins.dart` |

---

## 10. Henüz yapılmayanlar

Yapı hazır ama içi doldurulmayı bekleyen alanlar:

- **Galeri erişimi (FR-040/042)** — `photo_manager` benzeri bir paketle
  `MediaSource` adaptörü. `media_thumbnail.dart` ve `memory_editor_view.dart`
  bunu bekliyor.
- **Günlük, Kişiler, Koleksiyonlar, Ritüeller** — domain modelleri ve tabloları
  hazır; DAO + repository + ViewModel yazılacak (Bölüm 5'teki reçete).
- **Dışa aktarma (FR-160/161)** — `backup` feature'ı.
- **Abonelik (FR-131..134)** — IAP entegrasyonu; `currentPlanProvider` bunu
  bekliyor (şu an sabit `IzPlan.free` dönüyor).
- **İZ Studio (FR-100..104)**, **Atölye (V2.5)**, **AI (V3)** — faz bayrakları
  hazır.
