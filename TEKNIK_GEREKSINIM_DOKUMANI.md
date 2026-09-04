# İZ — Teknik Gereksinim Dokümanı

**Kapsam:** İZ 1.0 · 1.1 · 1.5
**Sürüm:** 1.0 — 26 Ağustos 2026
**Kaynaklar:** `IZ_Gereksinim_Analizi_Raporu.docx` (FR/NFR), `iz/ARCHITECTURE.md` (katman kuralları),
`BACKEND_YOL_HARITASI.md` (sunucu tarafı), İZ Özellik Matrisi (Free/İZ+ dağılımı)

---

## 0. Bu doküman nasıl okunur

Gereksinim analizi raporu **ne** yapılacağını söyler. Bu doküman **nasıl** yapılacağını söyler:
hangi tablo, hangi arayüz, hangi kural, hangi hata, hangi kabul testi.

**Notasyon**

| | |
|---|---|
| `TR-M2-04` | Teknik gereksinim · Modül 2 · 4. madde. Kod incelemesinde ve test adlarında bu kimlik kullanılır. |
| `FR-012` | Kaynak rapordaki fonksiyonel gereksinim. Her teknik gereksinim en az bir FR'ye dayanır. |
| **[1.0]** `[1.1]` `[1.5]` | Hangi sürümde teslim edilecek. |
| 🔒 | İZ+ kapısı var. `entitlements.require(...)` ile korunur. |
| ☁ | Senkronizasyona konu. §1.4'teki sözleşmeye uyar. |

**Zorunluluk dili:** “**Zorunlu**” maddesi olmadan sürüm çıkmaz. “Önerilir” maddesi
gerekçelendirilerek atlanabilir; atlama kararı bu dosyaya not düşülür.

**Bu doküman kapsamı dışı:** 2.0 ortak koleksiyon, 2.5 İZ Atölye, 3.0 ileri özellikler.
Bunlar kendi TRD'lerinde ele alınacak; burada yalnız veri modelinin onlara kapı bırakması aranır.

---

## 1. Ortak zemin

Tüm modülleri bağlayan kurallar. Bir modül bölümünde aksi yazmıyorsa burası geçerlidir.

### 1.1 Katman sözleşmesi

`iz/ARCHITECTURE.md` §2'deki bağımlılık yönü **bağlayıcıdır**:

```
presentation → domain ← data
                 ↑
               core (hiçbir feature'ı bilmez)
```

- **TR-C-01 [1.0] Zorunlu.** `domain/` katmanı Flutter, Drift veya HTTP tiplerini import edemez.
  Saf Dart + `core/`. Bu kuralı bir CI adımı denetler (import grafiği taraması).
- **TR-C-02 [1.0] Zorunlu.** Repository ve UseCase katmanları `Result<T>` döner, **exception fırlatmaz**.
  Exception yalnız data source içinde yaşar ve orada `guard()` ile `Result`'a çevrilir.
  Sözleşme: [`core/result/result.dart`](iz/lib/core/result/result.dart).
- **TR-C-03 [1.0] Zorunlu.** ✅ *CI'da denetleniyor.* Bir feature başka bir feature'ın
  `presentation/` katmanına bağlanamaz; `domain/` ve `presentation/` katmanları başka bir
  feature'ın `data/`sını import edemez. Başka ekrana geçiş **rota adıyla** yapılır.
  **İki meşru istisna** (ARCHITECTURE.md §2):
  `data/ → data/` tablo referansı (yabancı anahtar ve join için zorunlu) ve
  `*_l10n.dart` köprüleri (entity'yi metne çeviren saf fonksiyonlar).
- **TR-C-04 [1.0] Zorunlu.** ViewModel'ler `Notifier`/`StreamNotifier` olarak yazılır; `BuildContext`
  tutmazlar. Ekran-dışı bağımlılık yalnız provider üzerinden gelir.

### 1.2 Hata modeli

Uygulamanın hata sözlüğü [`core/error/failure.dart`](iz/lib/core/error/failure.dart) içindeki
`sealed class Failure`'dır. Yeni bir hata tipi eklemek `switch` bacaklarını derleme zamanında kırar —
bu bilinçlidir.

| Tip | Ne zaman | UI davranışı |
|---|---|---|
| `DatabaseFailure` | Drift/SQLite hatası | Genel hata + yeniden dene |
| `NotFoundFailure` | Kayıt silinmiş/yok | Boş durum ekranı, geri dön |
| `ValidationFailure` | İş kuralı ihlali (`ValidationCode`) | **Form alanının altında** — kod `field` taşıyorsa |
| `AuthFailure` | Kimlik reddi, oturum süresi | Giriş ekranına yönlendir |
| `PermissionFailure` | Galeri/konum/bildirim izni | İzin açıklaması + ayarlara yönlendirme |
| `MediaUnavailableFailure` | Orijinal galeri öğesi yok | Önizleme + “kaynak eksik” rozeti (asla çökme) |
| `EntitlementFailure` | Plan yetmiyor | **Hata değil, paywall.** `requiredPlan` ile satış ekranı |
| `NetworkFailure` | 1.5 ağ katmanı | Çevrimdışı rozeti + kuyruğa alındı bildirimi |
| `UnexpectedFailure` | Sınıflandırılamayan | Genel hata; buraya çok düşüyorsa yeni tip gerekir |

- **TR-C-10 [1.0] Zorunlu.** Kullanıcıya `Failure.message` **gösterilmez**. Gösterilecek metin
  `core/l10n/failure_l10n.dart` üzerinden seçilir. `message` yalnız log içindir.
- **TR-C-11 [1.0] Zorunlu.** `ValidationCode` yeni bir değer aldığında çevirisi de eklenir;
  `l10n_test.dart` eksik çeviriyi yakalar.
- **TR-C-12 [1.0] Zorunlu.** `EntitlementFailure` yakalayan hiçbir ekran bunu kırmızı hata olarak
  göstermez. Paywall açılır, kullanıcının girdiği veri **korunur**.

### 1.3 Entitlement kapıları

Merkezî matris: [`core/entitlement/entitlement.dart`](iz/lib/core/entitlement/entitlement.dart).

- **TR-C-20 [1.0] Zorunlu.** Kodun hiçbir yerinde `if (plan == IzPlan.plus)` yazılmaz.
  Her zaman `entitlements.can(IzFeature.x)` veya `entitlements.limit(IzLimit.y)` sorulur.
  Bir CI grep adımı `IzPlan.plus` karşılaştırmasını yasaklar.
- **TR-C-21 [1.0] Zorunlu.** Kapı **UseCase katmanında** uygulanır, UI'da değil. UI yalnız kapının
  sonucunu gösterir. Örnek: [`save_memory.dart:66`](iz/lib/features/memories/domain/usecases/save_memory.dart#L66).
- **TR-C-22 [1.0] Zorunlu.** UI ayrıca **önden** bilgilendirir: limit dolmadan önce kalan hak
  gösterilir (“3 fotoğraftan 2'si seçildi”). Kullanıcı duvara çarparak öğrenmemeli.
- **TR-C-23 [1.5] Zorunlu.** Sunucu aynı kapıyı **bağımsız olarak** uygular. İstemciden gelen plan
  bilgisine güvenilmez; `/v1/sync/push` free kullanıcıya `403 entitlement_required` döner.
- **TR-C-24 [1.0] Önerilir.** `EntitlementMatrix.defaults()` yalnız çevrimdışı varsayılandır;
  gerçek değerler `/v1/config/flags` ve `/v1/entitlements` üzerinden gelir (NFR-043).

### 1.4 Senkronizasyon sözleşmesi ☁ [1.5]

Ayrıntı `BACKEND_YOL_HARITASI.md` §4'te. Modüllerin uyması gereken özet:

- **TR-C-30 Zorunlu.** Senkronize olan her tablo `SyncableTable` kullanır: `id` (UUID v7),
  `createdAt`, `updatedAt`, `deletedAt`, `version`.
- **TR-C-31 Zorunlu.** Her yazma işlemi `updatedAt`'i tazeler ve `version`'ı **+1** artırır.
  Referans uygulama: [`memory_dao.dart:440`](iz/lib/features/memories/data/daos/memory_dao.dart#L440).
- **TR-C-32 Zorunlu.** Silme **fiziksel değildir**; `deletedAt` doldurulur (tombstone).
  Fiziksel silme yalnız çöp kutusu süresi dolduğunda ve **sunucu silmeyi onayladıktan sonra**.
- **TR-C-33 Zorunlu.** Her yazma, aynı transaction içinde `OutboxEntries` tablosuna bir kayıt düşürür.
- **TR-C-34 Zorunlu.** Çakışmada: skaler alanlar son-yazma-kazanır; **uzun metin alanları
  (`memory.note`, `journal.text`, `memory.title`) kayıpsız çatallanır** — sunucu sürümü kazanır,
  yerel sürüm `SyncConflicts` tablosuna yazılır ve kullanıcıya gösterilir.
- **TR-C-35 Zorunlu.** Free plandaki kullanıcı için senkronizasyon motoru **hiç çalışmaz**;
  outbox birikmez. Plan İZ+'a geçtiğinde ilk bootstrap tetiklenir.
- **TR-C-36 Zorunlu.** `privacyMode == deviceOnly` günlük kayıtları outbox'a **hiç girmez** (§M3).

### 1.5 Kimlik, zaman, dil

- **TR-C-40 [1.0] Zorunlu.** Tüm birincil anahtarlar **UUID v7** (`core/utils/id_generator.dart`).
  Otomatik artan tamsayı kullanılmaz — cihazlar arası çakışırdı.
- **TR-C-41 [1.0] Zorunlu.** `DateTime.now()` doğrudan çağrılmaz; `Clock` soyutlaması
  ([`core/utils/clock.dart`](iz/lib/core/utils/clock.dart)) enjekte edilir. “Bugünün İzi” testlenebilir olmalı.
- **TR-C-42 [1.0] Zorunlu.** Tarihler Drift'te `storeDateTimeAsText: true` ile ISO-8601 metin olarak
  saklanır. Kullanıcının gördüğü tarih **yerel saat**, karşılaştırma **UTC** üzerinden yapılır.
- **TR-C-43 [1.0] Zorunlu.** Veritabanına çevrilmiş metin yazılmaz. Sistem kategorileri gibi sabitler
  `iconKey`/`SystemCategory` gibi **anahtar** olarak saklanır, çevirisi UI'da seçilir.
- **TR-C-44 [1.0] Zorunlu.** `DateFormat` her zaman aktif dil ile kurulur; varsayılan locale'e güvenilmez.

### 1.6 Analitik ve loglama

- **TR-C-50 [1.0] Zorunlu.** Analitik olayları rapor §23'teki sözlükle sınırlıdır. **Kullanıcı içeriği
  parametre olarak gönderilmez**: anı başlığı, günlük metni, kişi adı, dosya adı, arama sorgusu.
- **TR-C-51 [1.0] Zorunlu.** Crash raporlarında `redact()` uygulanır (NFR-013/014).
- **TR-C-52 [1.0] Zorunlu.** Sayısal değerler **kova** olarak gönderilir (`media_count_bucket`),
  ham sayı olarak değil.

### 1.7 Erişilebilirlik ve tema

- **TR-C-60 [1.0] Zorunlu.** Tüm dokunulabilir hedefler ≥ 44×44 dp.
- **TR-C-61 [1.0] Zorunlu.** Metin ölçeği `textScaler.clamp` ile sınırlanır ama **kısıtlanmaz**;
  1.3× ölçekte hiçbir ekran taşmaz. `theme_contrast_test.dart` kontrastı denetler.
- **TR-C-62 [1.0] Zorunlu.** Açık ve koyu tema eşit özenle çalışır; renk yalnız `AppColors`
  belirteçlerinden okunur.

---

## M1 — Hesap, profil, onboarding

**Gereksinimler:** FR-001..007 · **Sürüm:** 1.0 (onboarding, profil), 1.1 (uygulama kilidi), 1.5 (hesap)

### M1.1 Kapsam ve duruş

Free kullanıcı **hesapsız** çalışır ve hesaba ihtiyaç duymaz — verisi zaten yalnız cihazındadır.
Hesap bulutla birlikte gelir. Uygulama hiçbir noktada kapıda kayıt istemez (ADR-B12).

### M1.2 Veri modeli

| Tablo | Sürüm | Alanlar |
|---|---|---|
| `Users` **(yeni)** | 1.5 | `SyncableTable` + `email`, `displayName`, `locale`, `avatarMediaId` |
| — profil tercihleri | 1.0 | `shared_preferences`: `onboarding_seen`, `theme_mode`, `locale`, bildirim tercihleri |
| — oturum | 1.5 | `flutter_secure_storage`: `access_token`, `refresh_token`, `user_id` |

- **TR-M1-01 [1.5] Zorunlu.** `Users` tablosu eklendiğinde tüm `OwnedTable.ownerId` değerleri
  `'local'` sabitinden gerçek `userId`'ye taşınır. Bu **tek transaction** içinde yapılır.
- **TR-M1-02 [1.5] Zorunlu.** Token'lar `shared_preferences`'a **asla** yazılmaz (NFR-011).
  Firebase SDK'sı token yenilemeyi kendi yönetir; elle refresh mantığı yazılmaz.
- **TR-M1-05 [1.5] Zorunlu.** Sunucu, istemciden gelen Firebase ID token'ını Google'ın açık
  anahtarlarıyla doğrular: imza, `aud`, `iss`, `exp`. **İstemcinin ilettiği `uid`'ye güvenilmez** —
  `uid` yalnız doğrulanmış token'ın içinden okunur.
- **TR-M1-06 [1.5] Zorunlu.** E-posta bizim `users` tablomuzda da tutulur (hesap silme ve destek
  için gerekir), ama **tek gerçek kaynak Firebase'dir**.

### M1.3 Domain sözleşmesi

Mevcut ve **değişmeyecek**: [`AuthRepository`](iz/lib/features/auth/domain/repositories/auth_repository.dart)
— `signInWithEmail`, `signUpWithEmail`, `signInWithProvider`, `sendPasswordReset`, `signOut`, `currentSession`.

- **TR-M1-03 [1.5] Zorunlu.** `StubAuthRepository` yerine `FirebaseAuthRepository` konur (ADR-B15).
  **Yalnız `authRepositoryProvider` satırı değişir**; View, ViewModel ve UseCase'lere dokunulmaz.
  Bu, mimarinin sınavıdır: dokunmak gerekiyorsa sorun mimaridedir.

### M1.4 İş kuralları

- **TR-M1-10 [1.0] Zorunlu.** Onboarding en fazla 3 adımdır ve **atlanabilir**. Son adım kullanıcıyı
  boş ana ekrana değil, “İlk İzin ne?” akışına bırakır (FR-004).
- **TR-M1-11 [1.0] Zorunlu.** Onboarding local-first yaklaşımını **dürüstçe** anlatır: verinin cihazda
  olduğu ve yedeklenmediği açıkça söylenir (R-001 riskinin azaltımı).
- **TR-M1-12 [1.1] Zorunlu.** Uygulama kilidi açıldığında kilit **uygulama öne geldiğinde** sorulur,
  yalnız soğuk açılışta değil. Biyometri başarısızsa PIN'e düşer.
- **TR-M1-13 [1.1] Zorunlu.** Kilit açıkken uygulama görev değiştiricide (app switcher) içerik
  göstermez — ekran görüntüsü perdesi konur.
- **TR-M1-14 [1.5] Zorunlu.** Anonim → hesap yükseltmede kullanıcı **hiçbir veri kaybetmez**.
  Yükseltme sonrası tüm yerel kayıtlar outbox'a `baseVersion: 0` ile yazılır.
- **TR-M1-15 [1.5] Zorunlu.** Hesap silme talebi **30 gün geri alınabilir**. Yerel kopyaların
  durumu kullanıcıya açıkça anlatılır (FR-007).

### M1.5 Ekranlar ve durumlar

| Ekran | Rota | Durumlar |
|---|---|---|
| Onboarding | `/onboarding` | 3 adım · atla |
| Giriş | `/sign-in` | boş · yükleniyor · alan hatası · kimlik reddi · ağ hatası |
| Kayıt | `/sign-up` | + şifre eşleşmiyor · e-posta kullanımda |
| Profil | `/profile` | hesapsız (varsayılan) · hesaplı · İZ+ rozeti |

### M1.6 Kabul kriterleri

1. Uygulama ilk kurulumda hesap istemeden ilk anı kaydedilebilir.
2. Hesap açan kullanıcının mevcut tüm verisi `ownerId` alır ve senkronizasyona girer.
3. Uygulama kapanıp açıldığında oturum korunur; ID token süresi dolunca Firebase SDK'sı
   sessizce yeniler — uygulama kodunda elle refresh yolu **bulunmaz** (TR-M1-02).
4. Süresi geçmiş, imzası bozuk veya başka bir Firebase projesine ait bir token sunucuda
   `401` alır; istemci oturumu düşürüp giriş ekranına döner.
5. Uygulama kilidi açıkken görev değiştiricide anı içeriği görünmez.

---

## M2 — Anı yönetimi

**Gereksinimler:** FR-010..020 · **Sürüm:** 1.0 · ☁ 1.5

Ürünün çekirdeği ve mimarinin referans uygulaması. Yeni bir modül yazan geliştirici önce buraya bakar.

### M2.1 Veri modeli

`Memories` — [`memory_tables.dart`](iz/lib/features/memories/data/tables/memory_tables.dart),
`SyncableTable` + `OwnedTable`.

| Alan | Tip | Not |
|---|---|---|
| `title` | text? (≤200) | |
| `note` | text? | çakışmada kayıpsız çatallanır |
| `occurredAt` | dateTime | |
| `occurredYear/Month/Day` | int | **denormalize** — “Bugünün İzi” indeksi için |
| `categoryId` | text? → `Categories` | |
| `locationId` | text? → `Locations` | |
| `coverMediaId` | text? → `MediaItems` | |
| `isFavorite`, `isArchived` | bool | |
| `sourceJournalEntryId` | text? | BR-011 izlenebilirlik |

İlişkiler: `MemoryPeople`, `MemoryCollections`, `MemoryRituals`, `MemoryMedia`.

- **TR-M2-01 [1.5] Zorunlu.** Dört join tablosuna `updatedAt`, `deletedAt`, `version` eklenir
  (şema v5). Composite PK korunur — `(memoryId, personId)` zaten benzersizdir.
  **Bu yapılmazsa silinen ilişki diğer cihazda geri gelir.**
- **TR-M2-02 [1.5] Zorunlu.** Join tabloları soft-delete'e geçtiğinde **tüm okuma sorgularına**
  `deletedAt IS NULL` filtresi eklenir. Eksik bırakılan bir sorgu silinmiş ilişkiyi ekranda gösterir.
- **TR-M2-03 [1.0] Zorunlu.** `occurredYear/Month/Day` yazma anında `occurredAt`'ten türetilir;
  ikisi asla ayrışamaz. Tek yazma yolu: `upsertMemory`.

### M2.2 Domain sözleşmesi

`MemoryRepository` + use-case'ler. DAO yüzeyi (mevcut):
`watchMemories`, `watchDetail`, `findDetail`, `findOnThisDay`, `watchByPerson`, `watchByRitual`,
`upsertMemory`, `setFavorite`, `setArchived`, `softDelete`, `restore`, `purgeExpiredTrash`, `countAll`.

- **TR-M2-04 [1.0] Zorunlu.** `upsertMemory` anı ve tüm ilişkilerini **tek transaction**'da yazar
  (NFR-004/020). Kısmi yazma oluşamaz.
- **TR-M2-05 [1.0] Zorunlu.** Liste ekranları `Stream` ile beslenir; yazma sonrası elle yenileme yapılmaz.

### M2.3 İş kuralları

- **TR-M2-10 [1.0] Zorunlu.** Boş anı kaydedilemez: en az bir not **veya** en az bir medya
  (FR-012 → `ValidationCode.emptyMemory`).
- **TR-M2-11 [1.0] Zorunlu.** Geçmiş tarihe izin verilir (`firstDate: 1900`), **geleceğe verilmez**
  (`ValidationCode.futureDate`).
- **TR-M2-12 [1.0] Zorunlu.** 🔒 Fotoğraf limiti plandan okunur (`IzLimit.photosPerMemory`).
  Limit aşımı `ValidationFailure(photoLimitExceeded, limit: n)` üretir → **paywall**, hata değil.
- **TR-M2-13 [1.0] Zorunlu.** Silinen anı çöp kutusuna gider ve **30 gün** saklanır (FR-015).
- **TR-M2-14 [1.5] Zorunlu.** Çöp kutusu temizliği yalnız **sunucu silmeyi onayladıysa** fiziksel
  silme yapar. Aksi hâlde uzun süre çevrimdışı kalan cihaz kaydı geri diriltir.
- **TR-M2-15 [1.0] Zorunlu.** Arşivlenen anı timeline'da görünmez ama aramada ve kişi/koleksiyon
  detayında görünür. Arşiv ≠ silme.
- **TR-M2-16 [1.0] Zorunlu.** Kapak görseli seçilmemişse ilk medya kapak sayılır; medya yoksa
  kategori ikonu kullanılır — anı kartı **asla boş görünmez**.

### M2.4 Ekranlar ve durumlar

| Ekran | Rota | Durumlar |
|---|---|---|
| Timeline | `/memories` | boş · yükleniyor · aylara gruplu liste |
| Anı detayı | `/memory/:id` | normal · arşivli · çöpte · medya kaynağı eksik · **çakışma uyarısı [1.5]** |
| Yeni anı — fotoğraf | `/memory/new` | seçim · limit uyarısı · izin reddi |
| Yeni anı — detaylar | `/memory/new/details` | form · alan hataları · paywall |

- **TR-M2-20 [1.0] Zorunlu.** Boş durumlar `AppEmptyState` bileşenini kullanır ve **eylem içerir**
  (NFR-035): “İlk anını ekle”.
- **TR-M2-21 [1.5] Zorunlu.** Çakışma varsa detay ekranında bir şerit gösterilir:
  “Bu anının bu cihazda farklı bir sürümü var” + iki sürümü yan yana gösteren ekran.
- **TR-M2-25 [1.0] Zorunlu.** Timeline **sayfalanır**: 10.000 anıda ilk ekran < 500 ms'de
  çizilir (NFR-002). `watchMemories` tüm tabloyu stream etmez; ay bazlı yükleme veya
  sonsuz kaydırma kullanılır. Açık iş: **Ek D / TR-D-04**.
  *(Bu kimlik Ek D'den referans veriliyordu ama tanımı yoktu; buraya yazıldı.)*

### M2.5 Kabul kriterleri

1. Yalnız notla, yalnız fotoğrafla anı kaydedilir; ikisi de boşken kaydedilemez.
2. Free planda 4. fotoğraf seçilince paywall açılır ve **girilen form verisi korunur**.
3. Anı silinip 29. günde geri getirilebilir; 31. günde listede yoktur.
4. Kişi bağlantısı kaldırılan anı, ikinci cihazda da kaldırılmış görünür ve geri gelmez. **[1.5]**
5. 10.000 anıda timeline ilk ekranı < 500 ms'de çizilir (NFR-002).

---

## M3 — Günlük

**Gereksinimler:** FR-030..036 · **Sürüm:** 1.0 · ☁ 1.5 (kısmi)

Günlük ayrı bir modüldür; anıya **tek yönlü** dönüşür. Ürünün en hassas verisi burada.

### M3.1 Veri modeli

`JournalEntries` — `SyncableTable`. Alanlar: `entryDate`, `text`, `title?`, `promptId?`,
`moodKey?`, `moodScore?`, `privacyMode`, `isFavorite`, `convertedMemoryId?`.
İlişki: `JournalMedia`.

`JournalPrivacyMode`: `standard` · `locked` · `deviceOnly`.

### M3.2 Gizlilik — modülün en kritik kuralı

- **TR-M3-01 [1.0] Zorunlu.** `deviceOnly` kaydın `text` alanı, **cihaza bağlı bir anahtarla
  şifrelenerek** saklanır. Anahtar `flutter_secure_storage`'da “yalnız bu cihaz” erişilebilirliğiyle
  tutulur ve platform yedeğine (iCloud / Google Drive) **taşınmaz**.
  *Gerekçe:* FR-035'in sözü yalnız sunucuya karşı değil, telefonun kendi yedeğine karşı da geçerlidir.
- **TR-M3-02 [1.5] Zorunlu.** `deviceOnly` kayıt outbox'a **hiç girmez**. Süzgeç repository'nin
  outbox'a yazdığı noktada uygulanır — ekranda değil. Sözleşme kodda hazır:
  [`JournalEntry.syncable`](iz/lib/features/journal/domain/entities/journal_entry.dart#L99).
- **TR-M3-03 [1.0] Zorunlu.** Şifreli olduğu için `deviceOnly` kayıt **FTS indeksine girmez** ve
  aramada çıkmaz. Bu davranış kullanıcıya açıkça söylenir.
- **TR-M3-04 [1.1] Zorunlu.** `locked` kayıt indekslenir ve aramada çıkar, ama **açılırken kilit sorar**.
- **TR-M3-05 [1.0] Zorunlu.** Anahtar kaybolursa (cihaz değişimi) `deviceOnly` kayıt açılamaz.
  Uygulama bunu **çökmeden** ele alır ve kullanıcıya durumu açıklar.

### M3.3 İş kuralları

- **TR-M3-10 [1.0] Zorunlu.** Bir günlük kaydı yalnız **bir kez** anıya dönüşür; `convertedMemoryId`
  dolduktan sonra dönüştürme eylemi kapanır ve ilgili anıya bağlantı gösterilir (BR-011).
- **TR-M3-11 [1.0] Zorunlu.** Dönüştürmede tarih ve içerik otomatik taşınır; kullanıcı onaylamadan
  kayıt oluşmaz.
- **TR-M3-12 [1.0] Zorunlu.** Dönüştürme **silme değildir**: günlük kaydı yerinde kalır.
- **TR-M3-13 [1.0] Zorunlu.** Günlük fotoğraf limiti anı limitiyle **aynı** kaynaktan okunur
  (`IzLimit.photosPerMemory`). Ayrı bir limit tanımlanmaz.
- **TR-M3-14 [1.0] Zorunlu.** Aynı güne birden çok kayıt yazılabilir; `entryDate` benzersiz değildir.
- **TR-M3-15 [1.0] Önerilir.** Promptlar tamamen kapatılabilir (FR-032); kapalıyken hiçbir yerde önerilmez.

### M3.4 Ekranlar ve durumlar

| Ekran | Rota | Durumlar |
|---|---|---|
| Günlük ana | `/journal` | takvim · liste · boş |
| Kayıt düzenleyici | `/journal/:id` | yeni · düzenleme · kilitli (kilit sorulur) · dönüştürüldü |
| Tüm kayıtlar | `/journal/all` | filtre: ay, ruh hâli, yıldız |

### M3.5 Kabul kriterleri

1. `deviceOnly` işaretli kayıt oluşturulduğunda `OutboxEntries` **boş kalır**. *(Bu testin kırmızıya
   dönmesi yayını durdurur.)*
2. `deviceOnly` kaydın metni veritabanı dosyasında **düz metin olarak bulunmaz**.
3. `deviceOnly` kayıt arama sonuçlarında görünmez.
4. Anıya dönüştürülen kayıt ikinci kez dönüştürülemez; anıya bağlantı gösterilir.
5. Kilitli kayıt, kilit açılmadan içeriğini göstermez.

---

## M4 — Medya ve saklama

**Gereksinimler:** FR-040..051 · **Sürüm:** 1.0 · 🔒☁ 1.5

Paketlemenin ağırlık merkezi: depolama ve bant genişliği maliyeti üreten her şey burada.

### M4.1 Veri modeli

`MediaItems` — [`media_tables.dart`](iz/lib/features/media/data/tables/media_tables.dart), `SyncableTable`:
`type`, `galleryAssetId?`, `localPreviewPath?`, `cloudObjectKey?`, `originalStatus`,
`mimeType?`, `width?`, `height?`, `durationMs?`, `sizeBytes?`, `lastVerifiedAt?`.

`MediaOriginalStatus`: `available` · `missing` · `cloudOnly` · `unknown`.

- **TR-M4-01 [1.0] Zorunlu.** Medya binary'si veritabanına **gömülmez** (rapor §12.2).
  DB metadata tutar; dosya sandbox'ta veya galeride durur.
- **TR-M4-02 [1.5] Zorunlu.** `galleryAssetId` ve `localPreviewPath` **senkronize edilmez** —
  cihaza özgüdürler, başka cihazda yanıltıcı olurlar.

### M4.2 Galeri erişimi

- **TR-M4-10 [1.0] Zorunlu.** **Sistem fotoğraf seçicisi** kullanılır (Android Photo Picker /
  iOS PHPicker). Tüm galeriye erişim izni **istenmez** (NFR-051). Kendi galeri arayüzünü çizen
  paketler bu yüzden reddedilmiştir.
- **TR-M4-11 [1.0] Zorunlu.** Seçilen her öğe için uygulama alanında **optimize edilmiş önizleme**
  üretilir (FR-043). Önizleme, orijinal silinse bile kartın anlaşılır kalmasını sağlar.
- **TR-M4-12 [1.0] Zorunlu.** Orijinalin varlığı **tembel** doğrulanır (`lastVerifiedAt`);
  her açılışta tüm galeri taranmaz.
- **TR-M4-13 [1.0] Zorunlu.** Orijinal bulunamazsa `originalStatus = missing` yazılır, kullanıcıya
  rozet gösterilir ve uygulama **çökmez** (FR-044, NFR-021).

### M4.3 Bulut yedeği 🔒 [1.5]

Karar: İZ+ kullanıcısının orijinalleri **tam kalitede** yedeklenir (ADR-B07).

- **TR-M4-20 Zorunlu.** Yükleme **parçalı ve devam edebilir** olmalıdır; ağ kesintisinden sonra
  baştan başlamaz (NFR-005 / FR-050).
- **TR-M4-21 Zorunlu.** Küçük önizleme **cihazda** üretilir ve orijinalle birlikte yüklenir.
- **TR-M4-22 Zorunlu.** Kullanıcı yalnız Wi-Fi'da yükleme tercihini seçebilir; varsayılan **açıktır**.
- **TR-M4-23 Zorunlu.** Medya bazında “yalnız cihazda / bulutta yedekli” durumu gösterilir (FR-051).
  Free planda bu gösterge her zaman “yalnız cihazda” der.
- **TR-M4-24 Zorunlu.** Abonelik bittiğinde buluttaki orijinaller **90 gün** saklanır, sonra silinir.
  Metadata ve anılar **asla** silinmez (ADR-B13, FR-134). Kullanıcı silme öncesi uyarılır ve
  indirme imkânı verilir.
- **TR-M4-25 Zorunlu.** İkinci cihazda orijinali henüz inmemiş medya `cloudOnly` durumundadır ve
  `missing` ile **karıştırılmaz** — kullanıcıya “galeriden silinmiş” denmez.

### M4.4 Kabul kriterleri

1. Fotoğraf seçimi tüm galeri izni istemez; yalnız seçilen öğelere erişilir.
2. Galeriden silinen fotoğrafın anısı açıldığında uygulama çökmez, önizleme + rozet gösterir.
3. Yükleme uçak modunda kesilir, ağ dönünce **kaldığı yerden** devam eder.
4. Free kullanıcının hiçbir medyası sunucuya çıkmaz.
5. Abonelik bitiminden 91 gün sonra orijinaller sunucuda yoktur; anı metadatası yerindedir.

---

## M5 — Kişiler

**Gereksinimler:** FR-060..065 · **Sürüm:** 1.0 (çekirdek), 1.5 (istatistikler) · ☁ 1.5

### M5.1 Veri modeli

`People` — `SyncableTable` + `OwnedTable`. Alanlar: `name`, `kind`, `relationType`,
`birthDate?`, `avatarMediaId?`, `note?`.

- `PersonKind`: `human` · `pet` · `other`
- `RelationType`: `self` · `partner` · `parent` · `child` · `sibling` · `grandparent` ·
  `grandchild` · `relative` · `friend` · `colleague` · `pet` · `other`

- **TR-M5-01 [1.0] Zorunlu.** `relationType` veritabanına **anahtar** olarak yazılır
  (`textEnum`), çevrilmiş metin olarak değil (TR-C-43).
- **TR-M5-02 [1.0] Zorunlu.** Kişi sayısında sınır yoktur — hiçbir planda.

### M5.2 İş kuralları

- **TR-M5-10 [1.0] Zorunlu.** Evcil hayvan ve insan olmayan özneler aynı modelle desteklenir;
  **UI dili buna göre uyarlanır** (FR-062): `pet` için “ilişki” yerine “tür/ad” dili kullanılır.
- **TR-M5-11 [1.0] Zorunlu.** `self` ilişki türü **en fazla bir** kişiye atanabilir.
- **TR-M5-12 [1.0] Zorunlu.** Kişi silindiğinde ilişkili anılar **silinmez**; yalnız bağ kopar
  (`MemoryPeople` satırı tombstone alır).
- **TR-M5-13 [1.0] Zorunlu.** Kişi yaşam çizgisi kronolojiktir ve arşivli anıları da içerir;
  yalnız çöptekiler hariçtir.
- **TR-M5-14 [1.0] Zorunlu.** `birthDate` girilmişse yaklaşan doğum günü ritüel olarak
  hatırlatılabilir (FR-064 → M10).
- **TR-M5-15 [1.5] Önerilir.** Kişi istatistikleri (birlikte gidilen yerler, en eski anı, bu yıl)
  yerel sorgudan üretilir; sunucu gerektirmez.

### M5.3 Ekranlar

| Ekran | Rota | Durumlar |
|---|---|---|
| Kişiler | `/people` | boş · liste · arama |
| Kişi detayı | `/person/:id` | yaşam çizgisi · ritüeller · istatistik [1.5] |
| Kişi düzenleyici | `/person/new`, `/person/:id/edit` | form · alan hataları |

> ⚠️ Rota sırası: `/person/new` mutlaka `/person/:id`'den **önce** tanımlanır, yoksa “new”
> bir kimlik sanılır. Aynı tuzak `/memory/picker` için de geçerlidir.

### M5.4 Kabul kriterleri

1. Evcil hayvan profilinde “ilişki türü” alanı insan diliyle sorulmaz.
2. Kişi silindiğinde o kişiyle etiketli anılar listede kalır.
3. İkinci kez `self` atanmak istendiğinde uygulama engeller ve nedenini söyler.

---

## M6 — Kategori, koleksiyon, ritüel

**Gereksinimler:** FR-070..077 · **Sürüm:** 1.0 (çekirdek), 1.5 (etiketler) · ☁ 1.5

**Bilinçli karar: hiçbiri paywall değildir; üç planda da sınırsızdır** (FR-072/138, rapor §14.2).
`IzLimit.maxCategories` üç planda da `kUnlimited`.

### M6.1 Veri modeli

| Tablo | Alanlar |
|---|---|
| `Categories` | `name`, `iconKey`, `sortOrder`, `isSystem` |
| `Collections` | `title`, `description?`, `coverMediaId?`, `visibility`, `startDate?`, `endDate?` |
| `Rituals` | `title`, `recurrenceType`, `relatedPersonId?`, `anchorMonth?`, `anchorDay?`, `iconKey` |

`CollectionVisibility`: `private` · `shared` (shared 2.0'a hazırlık, 1.x'te kullanılmaz)
`RecurrenceType`: `yearly` · `monthly` · `weekly` · `seasonal` · `custom`

- **TR-M6-01 [1.0] Zorunlu.** Varsayılan kategoriler `onCreate` sırasında tohumlanır
  (`SystemCategory` → `DefaultCategories.seed`). `isSystem = true` olanlar **silinemez**,
  yalnız yeniden adlandırılabilir ve sıralanabilir.
- **TR-M6-02 [1.0] Zorunlu.** Kategori adı veritabanına kullanıcının yazdığı hâliyle yazılır;
  **sistem kategorilerinin adı `iconKey`/anahtar üzerinden çevrilir** — veritabanına Türkçe metin
  gömülmez (TR-C-43).
- **TR-M6-03 [1.0] Zorunlu.** Bir anının **bir** kategorisi, **çok** koleksiyonu, **isteğe bağlı bir**
  ritüel bağlantısı olur (FR-017).
- **TR-M6-04 [1.0] Zorunlu.** `MemoryRituals.occurrenceYear` zorunludur — ritüelin hangi yılına ait
  olduğu bilinmeden yıl karşılaştırması yapılamaz (BR-012).

### M6.2 İş kuralları

- **TR-M6-10 [1.0] Zorunlu.** Kategori silindiğinde anılar silinmez; `categoryId` null'a düşer.
- **TR-M6-11 [1.0] Zorunlu.** Koleksiyon silindiğinde anılar silinmez; yalnız bağ kopar.
- **TR-M6-12 [1.0] Zorunlu.** Aynı ritüelin aynı yılına **en fazla bir** anı bağlanır
  (`(memoryId, ritualId)` PK + `occurrenceYear` mantıksal kısıtı). Kullanıcı ikinciyi eklemek
  isterse mevcut bağın değiştirilmesi önerilir.
- **TR-M6-13 [1.0] Zorunlu.** Ritüel görünümü yılları karşılaştırmaya uygun olmalıdır: eksik yıllar
  **boşluk olarak görünür** (“2024 — anı yok, eklemek ister misin?”). Bu, M10'daki hatırlatmanın
  görsel karşılığıdır.
- **TR-M6-14 [1.0] Zorunlu.** Kategori ile koleksiyon farkı onboarding'de veya ilk kullanımda
  bir kez anlatılır (rapor §24.2 açık sorusu — ürün kararı: ilk koleksiyon oluşturulurken).

### M6.3 Kabul kriterleri

1. Free planda 50 kategori oluşturulabilir; hiçbir paywall görünmez.
2. Sistem kategorisi silinemez, yeniden adlandırılabilir.
3. Kategori silindiğinde ona bağlı anılar timeline'da kalır.
4. Ritüel detayında anısı olmayan yıl boşluk olarak görünür.

---

## M7 — Yeniden keşfetme

**Gereksinimler:** FR-080..086 · **Sürüm:** 1.0 (Bugünün İzi, O Zaman/Şimdi), 1.5 (yıllık özet)

Ürünün duygusal getirisi burada üretilir. Hepsi cihazdaki veriden hesaplanır — sunucu gerekmez,
bu yüzden **hepsi ücretsizdir**.

### M7.1 Bugünün İzi

- **TR-M7-01 [1.0] Zorunlu.** Sorgu `occurredMonth` + `occurredDay` üzerinden çalışır ve
  `idxMemoriesOnThisDay` indeksini kullanır. Tam tarih karşılaştırması yapılmaz.
  Referans: `memory_dao.dart` → `findOnThisDay`.
- **TR-M7-02 [1.0] Zorunlu.** “Bugün” tanımı `Clock` üzerinden gelir ve **yerel saat** kullanır.
  Gece yarısı geçişinde kart kendiliğinden değişir.
- **TR-M7-03 [1.0] Zorunlu.** Aynı güne ait birden çok yıl varsa hepsi gösterilir, en yeniden eskiye.
- **TR-M7-04 [1.0] Zorunlu.** Bugün için anı yoksa kart **gösterilmez** — boş bir “anın yok” kartı
  kullanıcıyı suçlar gibi durur.

### M7.2 O Zaman / Şimdi

- **TR-M7-10 [1.0] Zorunlu.** İki veya daha fazla farklı tarihteki anı yan yana sunulur (FR-082).
- **TR-M7-11 [1.0] Zorunlu.** Karşılaştırma çıktısı İZ Studio'ya (M9) devredilebilir.

### M7.3 Yıllık özet [1.5]

- **TR-M7-20 Zorunlu.** Özet **yalnız kullanıcının kendi verisinden** türetilir: anı sayısı,
  şehir/yer sayısı, seçilmiş kişiler, önemli ritüeller (FR-085). Dış veri karıştırılmaz.
- **TR-M7-21 Zorunlu.** Kullanıcı paylaşmadan önce özeti **düzenleyebilir** (FR-086) — hangi
  kişilerin ve hangi ölçümlerin görüneceğini seçer.
- **TR-M7-22 Zorunlu.** Özet hesaplaması ana thread'i kilitlemez; ağır sorgu Drift isolate'inde çalışır.

### M7.4 Kabul kriterleri

1. Bugünün İzi kartı 1 Ocak'ta, artık yıl 29 Şubat'ta doğru çalışır.
2. Cihaz saat dilimi değişince kart aynı gün içinde yanlış tarihe kaymaz.
3. Yıllık özet 10.000 anıda < 2 sn'de üretilir ve arayüz donmaz.

---

## M8 — Arama, filtre, harita

**Gereksinimler:** FR-090..094 · **Sürüm:** 1.0 (arama, filtre), 1.1 (günlük araması), 1.5 (harita)

**Kural: arama cihazdan hiç çıkmaz.** Arama sorgusunun kendisi hassas veridir; hiçbir sürümde
sunucuya gönderilmez, analitiğe yazılmaz (TR-C-50).

### M8.1 İndeks

Mevcut: [`search.drift`](iz/lib/features/search/data/search.drift) — FTS5 sanal tablosu
`memory_search`, `tokenize = 'unicode61 remove_diacritics 2'`.

- **TR-M8-01 [1.0] Zorunlu.** Türkçe aksan duyarsızlığı zorunludur: “sarı” → “sari”, “İzmir” → “izmir”.
- **TR-M8-02 [1.0] Zorunlu.** İndeks **trigger'larla** güncellenir, repository'de elle değil.
  Böylece yeni bir yazma yolu eklendiğinde indeksi güncellemeyi unutmak imkânsızdır.
- **TR-M8-03 [1.0] Zorunlu.** Soft-delete edilen anı indeksten düşer (mevcut `after_update` trigger'ı).
- **TR-M8-04 [1.1] Zorunlu.** `journal_search` FTS tablosu ve trigger'ları eklenir.
  **`privacyMode = 'deviceOnly'` kayıtlar indekslenmez** (metni şifreli; TR-M3-03).
- **TR-M8-05 [1.5] Zorunlu.** Senkronizasyondan gelen kayıtlar da trigger'lar sayesinde otomatik
  indekslenir; ayrı bir yeniden inşa adımı gerekmez. Migration sonrası onarım için
  `rebuildMemorySearchIndex` kullanılır.

### M8.2 Sonuçlar ve filtreler

- **TR-M8-10 [1.1] Zorunlu.** Sonuçlar **iki ayrı sekmede** sunulur: “Anılar” ve “Günlük”.
  Tek listede karıştırılmaz — ürünün iki kavramı ayırma duruşu aramada da korunur.
- **TR-M8-11 [1.0] Zorunlu.** Filtreler: kişi, kategori, koleksiyon, ritüel, tarih aralığı, favori
  (FR-091). Filtreler **birleşik** çalışır (AND).
- **TR-M8-12 [1.0] Zorunlu.** Arama tamamen çevrimdışı çalışır (FR-092).
- **TR-M8-13 [1.0] Zorunlu.** Boş sorgu tüm sonuçları döndürmez; filtre uygulanmışsa filtre sonucu,
  uygulanmamışsa arama önerileri gösterilir.

### M8.3 Anı haritası [1.5]

- **TR-M8-20 Zorunlu.** Konumlu anılar kümelenmiş gösterilir (FR-093). Kümeleme **yerelde** hesaplanır.
- **TR-M8-21 Zorunlu.** Konum verisi anıdan bağımsız bir tabloda (`Locations`) durur ve
  birden çok anı aynı konumu paylaşabilir.
- **TR-M8-22 Zorunlu.** Harita sağlayıcısına kullanıcı içeriği (başlık, not) **gönderilmez**;
  yalnız koordinat sorgulanır.

### M8.4 Kabul kriterleri

1. “sari” araması “Sarı Ev” anısını bulur.
2. 10.000 anıda arama < 500 ms (NFR-002).
3. `deviceOnly` günlük kaydı hiçbir sorguda görünmez.
4. Çöpteki anı arama sonuçlarında çıkmaz; arşivli anı çıkar.
5. Uçak modunda arama tam çalışır.

---

## M9 — İZ Studio

**Gereksinimler:** FR-100..105 · **Sürüm:** 1.0 (temel), 🔒 1.5 (premium)

Ürünün **tek organik büyüme mekanizması**. Bu yüzden temel şablonlar ve paylaşım ücretsizdir —
paylaşılmayan bir kart kimseyi getirmez.

### M9.1 Kapsam

- **TR-M9-01 [1.0] Zorunlu.** MVP şablonları en az dört tip: “O Zaman/Şimdi”, “Yılın İzleri”,
  “Birlikte X Yıl”, “Ritüel Yılları” (FR-101).
- **TR-M9-02 [1.0] Zorunlu.** Çıktı Instagram Story oranında (9:16) ve genel paylaşım için
  kare (1:1) üretilebilir (FR-102).
- **TR-M9-03 [1.0] Zorunlu.** Render **cihazda** yapılır; sunucuya görsel gönderilmez.
- **TR-M9-04 [1.0] Zorunlu.** Paylaşım platformun kendi paylaşım sayfası üzerinden yapılır.
  İZ içinde kullanıcıdan kullanıcıya paylaşım **yoktur** (o, 2.0 ortak koleksiyonun işidir).

### M9.2 Ücretsiz / premium ayrımı

- **TR-M9-10 [1.0] Zorunlu.** Ücretsiz çıktıda küçük “İZ ile oluşturuldu” ibaresi bulunur (FR-103).
  İbare **tasarımı bozmayacak** ölçüde ve konumda olur; kullanıcıyı utandıran bir filigran değildir.
- **TR-M9-11 [1.5] Zorunlu.** 🔒 `IzFeature.removeWatermark` — ibare kaldırılır.
- **TR-M9-12 [1.5] Zorunlu.** 🔒 `IzFeature.hdExport` — yüksek çözünürlüklü çıktı.
- **TR-M9-13 [1.5] Zorunlu.** 🔒 `IzFeature.premiumStudioTemplates` — premium şablonlar ve
  harita/tarih şeridi/kişi bazlı otomatik kolajlar (FR-105).
- **TR-M9-14 [1.0] Zorunlu.** Premium şablon ücretsiz kullanıcıya **görünür ama kilitlidir**;
  önizlemesi gösterilir. Gizlenen özellik satılamaz.

### M9.3 Kabul kriterleri

1. Ücretsiz kullanıcı dört temel şablondan kart üretip Instagram'a gönderebilir.
2. Üretilen görsel hiçbir sunucuya yüklenmez.
3. Premium şablona dokunan ücretsiz kullanıcı paywall görür, hata görmez.
4. Kaynak fotoğraf galeriden silinmişse Studio önizlemeyi kullanır ve düşük çözünürlük uyarısı verir.

---

## M10 — Bildirimler

**Gereksinimler:** FR-150..153 · **Sürüm:** 1.0

**Tamamı yereldir; sunucu gerektirmez.** Tarih cihazda bilinir, veri cihazdan çıkmaz.
Push altyapısı (FCM/APNs) 1.x'te **kurulmaz** — ilk ihtiyaç 2.0 ortak koleksiyon davetlerinde doğar.

### M10.1 Kapsam

- **TR-M10-01 [1.0] Zorunlu.** Ayrı ayrı açılıp kapatılabilen dört kanal (FR-150):
  Bugünün İzi · ritüel/yıldönümü · günlük promptu · sistem uyarıları.
  Tek bir “bildirimler” anahtarı yeterli değildir.
- **TR-M10-02 [1.0] Zorunlu.** Ritüel tarihi yaklaşınca hatırlatma üretilir:
  “Bu yılın anısını eklemek ister misin?” (FR-152). Tetik, `Rituals.anchorMonth/anchorDay` ve
  `MemoryRituals.occurrenceYear` boşluğundan hesaplanır — **o yıl için anı yoksa** hatırlatılır.
- **TR-M10-03 [1.0] Zorunlu.** Doğum günleri `People.birthDate`'ten türer (FR-064).
- **TR-M10-04 [1.5] Zorunlu.** Boşluk uyarıları (“bu yıl henüz yaz tatili anısı eklenmedi”)
  **opt-in**'dir, varsayılan kapalıdır (FR-153).

### M10.2 Sıklık ve saygı

- **TR-M10-10 [1.0] Zorunlu.** Toplam bildirim **haftada 3'ü** aşmaz (FR-151). Sayaç yereldir.
- **TR-M10-11 [1.0] Zorunlu.** Sessiz saatler: 22:00–09:00 arasında bildirim planlanmaz.
- **TR-M10-12 [1.0] Zorunlu.** Bildirim metninde **anı içeriği geçmez** — başlık, not, kişi adı yok.
  “3 yıl önce bugün bir iz bıraktın” meşrudur; “Ayşe ile Kapadokya” değildir.
- **TR-M10-13 [1.0] Zorunlu.** Bildirim izni **ilk açılışta istenmez**; kullanıcı bir hatırlatma
  kanalını açtığında istenir. Bağlamsız izin isteği reddedilme oranını yükseltir.
- **TR-M10-14 [1.0] Zorunlu.** İzin reddedilirse uygulama çalışmaya devam eder; ayarlarda durum
  gösterilir ve sistem ayarlarına bağlantı verilir.

### M10.3 Kabul kriterleri

1. Dört kanal ayrı ayrı kapatılabilir; biri kapalıyken diğeri çalışır.
2. Bir haftada dördüncü bildirim planlanmaz.
3. Bildirim metni hiçbir koşulda kullanıcı içeriği taşımaz.
4. Bildirim izni verilmemişken uygulama hatasız çalışır.

---

## M11 — Dışa aktarma ve yedekleme sağlığı

**Gereksinimler:** FR-160..166 · **Sürüm:** 1.0 (yerel), 🔒 1.5 (bulut durumu)

“Verin senindir” sözünün teknik karşılığı. Bu yüzden **ücretsizdir**.

### M11.1 Dışa aktarma biçimi

Karar (ADR-B14): çıktı bir **ZIP** paketidir.

```
iz-disa-aktarma-2026-08-26.zip
├── anilar/
│   ├── 2026-03-02-kapadokya/
│   │   ├── ani.html          ← okunabilir: başlık, tarih, not, kişiler, konum
│   │   ├── foto-1.jpg
│   │   └── foto-2.jpg
│   └── ...
├── gunluk/
│   └── 2026-03-02.html
├── veri.json                 ← makine okunabilir tam metadata
└── OKUBENI.html              ← paketin nasıl okunacağı
```

- **TR-M11-01 [1.0] Zorunlu.** `veri.json` **tüm** anı ve günlük metadatasını, ilişkileriyle
  birlikte içerir (FR-160). Şema sürümü dosyada yazılıdır.
- **TR-M11-02 [1.0] Zorunlu.** HTML dosyaları harici bağımlılık içermez; 20 yıl sonra çevrimdışı
  açılabilir olmalıdır. Stil gömülüdür, font sistem fontudur.
- **TR-M11-03 [1.0] Zorunlu.** Fotoğraflar **orijinal** çözünürlükte dahil edilir; orijinal
  bulunamıyorsa önizleme konur ve `OKUBENI.html` bunu açıkça belirtir.
- **TR-M11-04 [1.5] Zorunlu.** 🔒 `IzFeature.advancedExport` — seçili koleksiyon/kişi bazlı kısmi
  dışa aktarma ve yüksek çözünürlük seçeneği (FR-161).
- **TR-M11-05 [1.0] Zorunlu.** `deviceOnly` günlük kayıtları **kullanıcı açıkça onaylamadıkça**
  pakete girmez; onaylarsa şifresi çözülerek yazılır ve paketin şifresiz olduğu hatırlatılır.
- **TR-M11-06 [1.0] Zorunlu.** Dışa aktarma arka planda çalışır, ilerleme gösterilir ve iptal edilebilir.

### M11.2 Yedekleme sağlığı ekranı

- **TR-M11-10 [1.0] Zorunlu.** Ekran şunları gösterir (FR-162): mod (**yalnız cihazda** / bulut),
  son dışa aktarma tarihi, risk uyarısı.
- **TR-M11-11 [1.0] Zorunlu.** Free kullanıcıya risk **dürüstçe** anlatılır: “Anıların yalnızca bu
  telefonda. Telefonu kaybedersen kaybolurlar.” Korkutma değil, bilgilendirme dili (R-001).
- **TR-M11-12 [1.0] Zorunlu.** Belirli aralıklarla yedek hatırlatması açılabilir (FR-163).
- **TR-M11-13 [1.5] Zorunlu.** 🔒 İZ+ kullanıcıya gösterilir: son başarılı senkronizasyon zamanı,
  bekleyen öğe sayısı, son hata (FR-164). Kaynak: `SyncState` tablosu.
- **TR-M11-14 [1.5] Zorunlu.** 🔒 Yeni cihaz kurulumunda buluttan geri yükleme akışı (FR-165).

### M11.3 Kabul kriterleri

1. Dışa aktarılan ZIP, internetsiz bir bilgisayarda açılıp okunabilir.
2. `veri.json` yeniden içe aktarıldığında tüm ilişkiler korunur (gelecekteki içe aktarma için).
3. Free kullanıcı yedekleme ekranında “yalnız cihazda” uyarısını görür.
4. `deviceOnly` kayıt, onay verilmedikçe pakette bulunmaz.

---

## M12 — Abonelik ve entitlement

**Gereksinimler:** FR-130..135 · **Sürüm:** 1.0 (matris altyapısı), 1.5 (satın alma)

### M12.1 Matris

Tek gerçek kaynak: [`entitlement.dart`](iz/lib/core/entitlement/entitlement.dart).

| | Free | İZ+ | Family |
|---|---|---|---|
| `photosPerMemory` | 3 | 30 | 50 |
| `videoDurationSeconds` | 0 | 300 | 600 |
| `maxCategories` | ∞ | ∞ | ∞ |
| Özellikler | *(hiçbiri)* | 9 özellik | 9 özellik + ortak kota |

Dokuz kapılanabilir özellik: `videoMemory` · `audioMemory` · `cloudBackup` · `multiDevice` ·
`premiumStudioTemplates` · `hdExport` · `removeWatermark` · `sharedCollectionOwner` · `advancedExport`.

- **TR-M12-01 [1.0] Zorunlu.** Gömülü matris yalnız **çevrimdışı varsayılandır**. Gerçek değerler
  uzaktan gelir (NFR-043).
- **TR-M12-02 [1.5] Zorunlu.** `currentPlanProvider` sabit `IzPlan.free` olmaktan çıkar ve
  `/v1/entitlements` yanıtından beslenir. Yanıt **önbelleğe alınır**; çevrimdışıyken son bilinen
  plan geçerlidir.
- **TR-M12-03 [1.5] Zorunlu.** Plan bilgisi `flutter_secure_storage`'da imzalı olarak tutulur;
  düz `shared_preferences` değeri düzenlenerek premium açılamamalıdır.

### M12.2 Abonelik doğrulama — RevenueCat [1.5]

Karar (ADR-B16): makbuz doğrulaması **RevenueCat** üzerinden yapılır. Gerekçe, kenar durumların
ağırlığı: ödemesiz süre, ödeme yeniden denemesi, iade, aile paylaşımı, plan yükseltme/düşürme,
orantılama ve mağazaların sandbox tuhaflıkları. Bunlar yılların birikimidir; ilk sürümde kendi
doğrulayıcımıza güvenmek gereksiz bir risk.

**Karar geri döndürülebilir tutulur.** Aşağıdaki dört madde bunun teknik garantisidir:

- **TR-M12-16 [1.5] Zorunlu.** RevenueCat bir **doğrulayıcıdır, gerçek kaynak değildir.**
  Uygulamanın plan bilgisi **yalnız** `/v1/entitlements`'tan okunur. İstemci RevenueCat SDK'sından
  plan **okumaz** — ADR-B08 ("entitlement kararının tek kaynağı bizim sunucumuz") korunur.
- **TR-M12-17 [1.5] Zorunlu.** Apple `originalTransactionId` ve Google `purchaseToken`
  **kendi veritabanımıza** yazılır. Geçiş anahtarı budur: sağlayıcı değişse bile Apple ve
  Google'a doğrudan yeniden doğrulatabiliriz. Bu alanlar olmadan geçiş imkânsızlaşır.
- **TR-M12-18 [1.5] Zorunlu.** Sunucuda `ISubscriptionVerifier` arayüzü tanımlanır; tek
  implementasyon `RevenueCatVerifier`. Hiçbir çağrı yeri RevenueCat tipini doğrudan görmez.
  Geçiş = ikinci implementasyon yazmak.
- **TR-M12-19 [1.5] Zorunlu.** RevenueCat'e **opak bir kullanıcı kimliği** gönderilir.
  E-posta, ad ve Firebase `uid` doğrudan gönderilmez (veri minimizasyonu, ADR-B17).
  Kullanılmayan RevenueCat entegrasyonları (attribution, üçüncü taraf analitik ortakları)
  kapalı tutulur — her ek entegrasyon yeni bir alt işleyici demektir.
- **TR-M12-20 [1.5] Zorunlu.** `POST /v1/webhooks/revenuecat` imza doğrulaması yapar.
  Doğrulanmamış webhook hiçbir plan değişikliğine yol açmaz.

### M12.3 Satın alma [1.5]

- **TR-M12-10 Zorunlu.** Dijital abonelik yalnız App Store IAP / Google Play Billing üzerinden
  satılır (FR-131). Fiziksel ürün (2.5) **ayrı** ödeme akışıdır.
- **TR-M12-11 Zorunlu.** Abonelik ekranı ücreti, yenileme periyodunu ve **açılan özellikleri**
  açıkça gösterir (FR-132).
- **TR-M12-12 Zorunlu.** Satın alma **geri yüklenebilir** (FR-133). Hesapsız kullanıcı için mağaza
  makbuzu yeterlidir; bulut kullanılacaksa hesap o anda açılır.
- **TR-M12-13 Zorunlu.** Makbuz doğrulaması **sunucu tarafında** yapılır (RevenueCat üzerinden).
  İstemcinin “ben İZ+'ım” demesi hiçbir sunucu kararında kabul edilmez (ADR-B08).
- **TR-M12-14 Zorunlu.** Abonelik durum değişimi **webhook ile** sunucuya taşınır; istemcinin
  uygulamayı açması beklenmez. İptal, iade ve süre dolumu böyle yakalanır.
- **TR-M12-15 Zorunlu.** Abonelik bitince: yeni premium **işlem** kapanır, mevcut veri **açık kalır**
  (FR-134). Buluttaki orijinaller 90 gün sonra silinir (TR-M4-24).

### M12.4 Paywall davranışı

> *Numaralandırma notu:* bu blok **TR-M12-20/21/22** iken **TR-M12-30/31/32**'ye taşındı —
> `TR-M12-20` kimliği M12.2'deki webhook imza doğrulamasında da kullanılıyordu. Aynı kimlik
> iki gereksinimde durursa test adları ve kod incelemesi hangisini kastettiğini söyleyemez.

- **TR-M12-30 [1.0] Zorunlu.** Paywall her zaman **tetikleyen özelliği** söyler
  (`EntitlementFailure.featureKey` → “Video eklemek İZ+ ile gelir”). Genel bir satış ekranı açılmaz.
- **TR-M12-31 [1.0] Zorunlu.** Paywall açıldığında kullanıcının girdiği veri kaybolmaz;
  kapatınca aynı forma döner.
- **TR-M12-32 [1.0] Zorunlu.** Paywall'a düşen her tetikleyici analitikte `trigger_feature` ile
  ölçülür (içerik gönderilmez).

### M12.5 Kabul kriterleri

1. `IzPlan.plus` ile doğrudan karşılaştırma yapan kod CI'da reddedilir.
2. İstemci kodunda RevenueCat SDK'sından plan **okuyan** tek bir satır bulunmaz (TR-M12-16).
3. `originalTransactionId` / `purchaseToken` her abonelikte kendi veritabanımızda kayıtlıdır.
4. Satın alma sonrası plan sunucudan gelir; uygulama yeniden kurulduğunda geri yüklenir.
5. Abonelik iptalinde webhook ile plan düşer; kullanıcının anıları erişilebilir kalır.
6. Cihaz depolamasındaki plan değeri elle düzenlenerek premium açılamaz.
7. İmzası doğrulanmamış bir webhook isteği plan değiştirmez.

---

## M13 — Senkronizasyon ☁ 🔒

**Gereksinimler:** FR-050, FR-164..166 · **Sürüm:** 1.5 · **Yalnız İZ+**

Kendi başına bir modül: diğer modüllerin hepsine dokunur. Protokol ayrıntısı
`BACKEND_YOL_HARITASI.md` §4'te; burada **istemci tarafı** gereksinimler.

### M13.1 Yeni tablolar (şema v7 — bkz. Ek A)

| Tablo | Alanlar |
|---|---|
| `OutboxEntries` | `id`, `entityType`, `entityId`, `op`, `payloadJson`, `baseVersion`, `createdAt`, `attemptCount`, `lastError?` |
| `SyncState` | `cursor`, `lastSyncAt?`, `lastError?`, `pendingCount` |
| `SyncConflicts` | `entityType`, `entityId`, `field`, `localValue`, `serverValue`, `detectedAt`, `resolvedAt?` |
| `Users` | M1.2 |

### M13.2 Motor

- **TR-M13-01 Zorunlu.** Döngü: outbox boşalt → push → sonuçları uygula → pull → yerele yaz →
  cursor'ı **en son** kaydet. Yarıda kesilirse aynı sayfa tekrar gelir; uygulama idempotenttir.
- **TR-M13-02 Zorunlu.** Tetikleyiciler: uygulama öne geldiğinde · yazma sonrası 30 sn debounce ·
  kullanıcının “şimdi eşitle” eylemi. Sürekli yoklama yapılmaz.
- **TR-M13-03 Zorunlu.** Ağ hatasında **üstel geri çekilme + jitter**. Çevrimdışıyken kuyruk büyür,
  veri kaybolmaz.
- **TR-M13-04 Zorunlu.** Her push isteği bir `Idempotency-Key` taşır; yeniden denemede **aynı**
  anahtar kullanılır.
- **TR-M13-05 Zorunlu.** Motor `featureFlagsProvider.cloudSync` bayrağının arkasındadır.
  Bayrak kapalıyken **tek satır çalışmaz**.
- **TR-M13-06 Zorunlu.** Free plandaki kullanıcıda motor hiç başlamaz; outbox yazılmaz.
- **TR-M13-07 Zorunlu.** Sunucudan `403 entitlement_required` gelirse kuyruk **korunur**, silinmez;
  kullanıcıya paywall gösterilir.

### M13.3 Çakışma arayüzü

- **TR-M13-10 [1.5] Zorunlu.** Metin çakışmasında **hiçbir sürüm silinmez**: sunucu sürümü
  kaydın üzerine yazılır, yerel sürüm `SyncConflicts` tablosuna **kurtarılan sürüm** olarak
  saklanır ve kullanıcıya bildirilir. Otomatik birleştirme yapılmaz.
- **TR-M13-10b [1.6] Önerilir.** İki sürümü yan yana gösteren karşılaştırma ekranı.
  *1.5'ten bilinçli olarak çıkarıldı:* nadir bir olay için tam bir arayüz, Faz 3'e bir hafta
  ekliyordu. Asıl garanti — veri kaybetmemek — TR-M13-10 ile zaten sağlanıyor; kullanıcı
  kurtarılan sürümü görebiliyor, sadece yan yana kıyaslayamıyor.
- **TR-M13-11 Zorunlu.** Kullanıcı seçmeden önce **hiçbir sürüm silinmez**.
- **TR-M13-12 Zorunlu.** Çözülmemiş çakışma sayısı yedekleme sağlığı ekranında görünür.

### M13.4 Sürüm uyumu

- **TR-M13-20 Zorunlu.** İstemci her istekte kendi şema ve uygulama sürümünü bildirir.
- **TR-M13-21 Zorunlu.** Sunucu **minimum desteklenen istemci sürümü** tanımlar; altındaki istemci
  senkronize olmaz ve kullanıcıya güncelleme akışı gösterilir.
- **TR-M13-22 Zorunlu.** İstemci **tanımadığı alanları korur** ve geri gönderir.
  *Gerekçe:* eski istemci yeni bir alanı düşürüp kaydı geri push ederse o alan kalıcı olarak silinir —
  sessiz veri kaybı.
- **TR-M13-23 Zorunlu.** Cursor sunucuda geçersizse (tombstone ömrü aşılmış) istemci **bootstrap**
  yapar: cursor sıfırlanır, tüm veri yeniden çekilir.

### M13.5 Kabul kriterleri

1. İki cihaz, aynı hesap: A'da oluşturulan anı B'de görünür.
2. A çevrimdışıyken 20 değişiklik yapılır; ağ gelince hepsi gider, tekrar oluşmaz.
3. Aynı push iki kez gönderilir → sunucuda tek kayıt.
4. A ve B aynı notu farklı düzenler → **hiçbir metin kaybolmaz**, kullanıcı seçer.
5. A'da anıdan kişi çıkarılır → B'de de çıkar, sonraki eşitlemede geri gelmez.
6. `deviceOnly` günlük kaydı hiçbir zaman sunucuya ulaşmaz.
7. Free hesap push denerse `403` alır, yerel veri bozulmaz.
8. Yeni cihazda sıfırdan bootstrap tüm veriyi indirir.

---

## M14 — Güvenlik, gizlilik, uyumluluk

**Gereksinimler:** NFR-010..017, FR-007 · **Sürüm:** 1.0 · 1.1 · 1.5

### M14.1 Cihazda

- **TR-M14-01 [1.0] Zorunlu.** Token, şifreleme anahtarı ve ödeme sırrı düz metin dosyada
  saklanmaz (NFR-011) — `flutter_secure_storage` (Keychain/Keystore).
- **TR-M14-02 [1.0] Zorunlu.** İçerik **varsayılan olarak özeldir** (NFR-012). Hiçbir şey
  kullanıcı istemeden paylaşılmaz.
- **TR-M14-03 [1.0] Zorunlu.** `deviceOnly` günlük metni cihaza bağlı anahtarla şifrelenir (TR-M3-01).
- **TR-M14-04 [1.1] Önerilir.** Yerel veritabanı şifrelemesi (SQLCipher). Uygulama kilidi (FR-005)
  ancak bununla gerçek bir kilit olur; şifresiz `.db` dosyası okunabilir kalır.

### M14.2 Platform yedeği

- **TR-M14-10 [1.0] Zorunlu.** ✅ **Kapatıldı.** `AndroidManifest.xml` artık `allowBackup="true"`,
  `fullBackupContent="@xml/backup_rules"` ve `dataExtractionRules="@xml/data_extraction_rules"`
  taşıyor. Kurallar: veritabanı **yedeklenir** (kullanıcının 1.5'e kadar tek güvenlik ağı),
  `FlutterSecureStorage.xml` **hem bulut yedeğinden hem cihaz transferinden hariç** —
  şifreleme anahtarı ve oturum token'ları yeni cihaza taşınmaz. Önbellek dışarıda.
- **TR-M14-11 [1.0] Zorunlu.** iOS tarafında veritabanının iCloud yedeğine dahil olma durumu bilinçli
  bir karar olarak yazılır. Karar: **yedek açık kalır** (kullanıcının güvenlik ağı), `deviceOnly`
  kayıtlar şifreleme sayesinde korunur.

### M14.3 Ağ ve sunucu [1.5]

- **TR-M14-20 Zorunlu.** Tüm trafik TLS 1.2+ (NFR-015).
- **TR-M14-21 Zorunlu.** Sunucuda encryption-at-rest.
- **TR-M14-22 Zorunlu.** Her sorgu `owner_id = currentUserId` filtresiyle çalışır;
  istemciden gelen `ownerId` **asla** kabul edilmez. IDOR senaryosu entegrasyon testinde denenir.
- **TR-M14-23 Önerilir.** Cihaz doğrulaması (Play Integrity / App Attest) — zorunlu kılınmadan önce ölçülür.
- **TR-M14-24 Zorunlu.** Sunucu bölgesi **Türkiye** (ADR-B11).

### M14.4 Yurt dışına veri aktarımı

İki dış sağlayıcı kullanıyoruz ve ikisi de ABD'de: **Firebase Authentication** (ADR-B15) ve
**RevenueCat** (ADR-B16). ABD için KVKK'nın verilmiş bir yeterlilik kararı **yok**.

| Sağlayıcı | Aktarılan veri | Nerede |
|---|---|---|
| Firebase Auth | e-posta, kullanıcı kimliği, giriş meta verisi | Google, ABD |
| RevenueCat | opak kullanıcı kimliği, satın alma kaydı, IP | AWS + Snowflake, ABD (13 alt işleyici) |

**Aktarılmayan:** anı içeriği, günlük metni, fotoğraf, kişi adları, konum, arama sorguları.
Bunların tamamı Türkiye'deki sunucumuzda ve kullanıcının cihazında kalır.

- **TR-M14-25 [1.5] Zorunlu.** Aktarımın hukuki dayanağı **açık rızadır** (ADR-B17).
  Rıza, hesap açma adımında **ayrı bir onay** olarak alınır — kullanım koşullarının içine
  gömülmez, önceden işaretli gelmez ve **reddedilebilir**.
- **TR-M14-26 [1.5] Zorunlu.** Rıza reddedilirse kullanıcı **uygulamayı kullanmaya devam eder**;
  yalnız bulut ve abonelik kapalı kalır. Bu, rızanın "özgür iradeyle verilmiş" sayılmasının
  koşuludur — hizmetin önkoşulu yapılan rıza KVKK'da geçersizdir.
- **TR-M14-27 [1.5] Zorunlu.** Aydınlatma metni hangi verinin **hangi sağlayıcıya** ve **hangi
  ülkeye** gittiğini isim vererek yazar. "Üçüncü taraf hizmet sağlayıcılar" gibi kapalı ifade yeterli değildir.
- **TR-M14-28 [1.5] Zorunlu.** Rıza kaydı (tarih, sürüm, metin) saklanır ve kullanıcı **geri alabilir**.
  Geri alındığında bulut kapatılır, sunucudaki veri §M14.5'teki silme akışına girer.
- **TR-M14-29 [1.5] Önerilir.** Standart sözleşme yolu (7499 sayılı değişiklik, 1 Haziran 2024)
  yeniden değerlendirilir: sağlayıcılar KVKK'nın metnini imzalamaya yanaşırsa açık rızaya
  bağımlılık azalır.

### M14.5 KVKK / GDPR

- **TR-M14-30 [1.0] Zorunlu.** Gizlilik metni ve veri işleme envanteri hazırlanır; **profesyonel
  hukuk incelemesi** 1.5 yayınından önce tamamlanır (rapor NFR-036).
- **TR-M14-31 [1.5] Zorunlu.** Hesap silme talebi 30 gün geri alınabilir, sonra kalıcıdır (FR-007).
  Yerel kopyaların durumu kullanıcıya açıkça anlatılır.
- **TR-M14-32 [1.5] Zorunlu.** VERBİS kaydı ve aydınlatma metni yayından önce yerinde olur.
- **TR-M14-33 [1.0] Zorunlu.** Uçtan uca şifreleme 1.x kapsamında **yoktur**; içerik metni sunucuda
  düz durur. Bu, gizlilik metninde **dürüstçe** yazılır — sessiz geçilmez.

### M14.6 Yayın engelleri

Bu maddeler tamamlanmadan mağazaya yükleme yapılamaz:

- **TR-M14-40 [1.0] Zorunlu.** ✅ **Kapatıldı.** `ios/Runner/PrivacyInfo.xcprivacy` oluşturuldu ve
  Xcode projesinin **Resources** derleme fazına kaydedildi (yoksa pakete girmez).
  Bildirilen API gerekçeleri: `FileTimestamp` (C617.1, 3B52.1), `UserDefaults` (CA92.1),
  `DiskSpace` (85F4.1). `NSPrivacyTracking = false`, toplanan veri tipi **yok**.
  ⚠️ Çökme raporlama, analitik, hesap ve bulut yedeği eklendiğinde bu dosya güncellenmeli —
  dosyanın başındaki yorumda liste duruyor.
- **TR-M14-41 [1.0] Zorunlu.** App Store / Play veri güvenliği formları doldurulur ve
  bu dokümandaki veri sınıflarıyla **tutarlı** olur.
- **TR-M14-42 [1.0] Zorunlu.** Tüm izin açıklama metinleri (`NSPhotoLibraryUsageDescription` vb.)
  neden istendiğini somut olarak söyler.

---

## Ek A — Şema sürümleri

| Sürüm | İçerik | Durum |
|---|---|---|
| v1 | Çekirdek tablolar | ✅ |
| v2 | Anı indeksleri (`idxMemoriesOccurredAt`, `idxMemoriesOnThisDay`) | ✅ |
| v3 | Günlük başlık + ruh hâli puanı | ✅ |
| v4 | Günlük yıldızı | ✅ |
| **v5** | **Ters yön indeksleri**: `memory_people.personId`, `memory_collections.collectionId`, `memory_rituals.ritualId`, `memory_media.mediaId`, `journal_media.mediaId`, `memories.categoryId` | ✅ |
| **v6** | `people.relation_label` — kullanıcının kendi yazdığı ilişki adı ("Annem") | ✅ |
| **v7** | `journal_search` FTS tablosu ve trigger'ları | ⏳ 1.1 |
| **v8** | Join tablolarına `updatedAt/deletedAt/version` · `Users` · `OutboxEntries` · `SyncState` · `SyncConflicts` | ⏳ 1.5 |

> **v6 neden plana girmemişti?** `Person.relationLabel` entity'de ve arayüzde
> baştan beri vardı, eksik olan yalnız sütundu — yani editörde yazılan "Annem"
> kayıt sırasında sessizce düşüyordu. Kişiler modülünün veri katmanı yazılırken
> fark edildi. Sonraki iki sürüm bir sıra kaydı; içerikleri değişmedi.

- **TR-A-01 Zorunlu.** Her şema değişikliğinde `schemaVersion` artırılır ve **eski migration adımları
  asla değiştirilmez** — kullanıcı v1'den v6'ya atlayabilir.
- **TR-A-02 Zorunlu.** ✅ **Kapatıldı.** `drift_schemas/drift_schema_v4.json` alındı,
  `test/generated_migrations/` yardımcıları üretildi ve `test/unit/migration_test.dart` yazıldı.
  Test iki şeyi denetler: canlı şema v4 anlık görüntüsüyle birebir aynı mı, ve `schemaVersion`
  anlık görüntüyle uyumlu mu. **Not:** v1–v3 geriye dönük üretilemedi (depoda tek commit var);
  v4 temel alındı — mevcut ve gelecek tüm kullanıcılar v4 veya üzerinde.
  *Bu adım `drift_dev`'in 2.34.0 → 2.34.5'e yükseltilmesini gerektirdi; 2.34.0 drift 2.34.3 ile
  şema dökümü yapamıyordu.*

---

## Ek B — Test matrisi

| Katman | Kapsam | Araç |
|---|---|---|
| Birim | UseCase iş kuralları, çakışma çözümü, entitlement kapıları | `flutter_test`, `mocktail` |
| Veritabanı | Migration v1→v6, DAO sorguları, FTS | Bellek içi Drift |
| Widget | Ekran durumları, boş/hata/yükleniyor, erişilebilirlik | `flutter_test` |
| Çeviri | Eksik anahtar, eksik `ValidationCode` çevirisi | `l10n_test.dart` |
| Sözleşme | OpenAPI değişimi → istemci derleme hatası | CI |
| Entegrasyon [1.5] | İki cihaz simülasyonu, çevrimdışı kuyruk, idempotency, IDOR | Testcontainers + sahte sunucu |
| Güvenlik [1.5] | Yetki, token süresi, log redaksiyonu | Manuel + otomatik |

- **TR-B-01 Zorunlu.** Aşağıdaki testler **yayın durdurucudur**; kırmızıysa sürüm çıkmaz:
  - `deviceOnly` kayıt outbox'a girmiyor (TR-M3-02)
  - `deviceOnly` metni veritabanında düz durmuyor (TR-M3-01)
  - Free kullanıcının hiçbir verisi sunucuya çıkmıyor (TR-C-35)
  - Silinen ilişki ikinci cihazda geri gelmiyor (TR-M2-01)
  - Anonim → hesap yükseltmede veri kaybolmuyor (TR-M1-14)
- **TR-B-02 Zorunlu.** ✅ **Kapatıldı.** `.github/workflows/ci.yml` üç iş koşuyor:
  **(1) Analiz ve testler** — `dart format` denetimi, `flutter analyze`, tüm test paketi.
  **(2) Mimari kuralları** — TR-C-20 (plan karşılaştırması yasak), TR-C-01 (domain saflığı),
  TR-C-03 (feature sınırları), TR-C-41 (`DateTime.now()` uyarısı). Flutter kurmadan koşar, hızlıdır.
  **(3) Üretilen kod güncel mi** — `build_runner` koşup `git diff` ile fark arar; tabloyu değiştirip
  kod üretmeyi unutmayı yakalar.
  Flutter sürümü `.fvmrc` ile aynı (3.47.1) olmak zorunda — ayrışırsa “yerelde geçiyor” durumu doğar.

---

## Ek C — Bu dokümanın açık bıraktıkları

Karara bağlanmadan ilgili modül **başlanamaz**:

| # | Soru | Bloke ettiği |
|---|---|---|
| 1 | Anı başına fotoğraf limiti 3 mü, 3–5 A/B mi? | M12 fiyatlandırma testi |
| 2 | Sesli anıda Free'ye sınırlı deneme verilecek mi? | M4, M12 |
| 3 | İZ+ fiyatı ve ücretsiz deneme süresi | M12 |
| 4 | Ritüel görünümü: yıllar yan yana mı, dikey mi, hibrit mi? | M6 arayüz |
| 5 | Kategori/koleksiyon farkı kullanıcıya nerede anlatılacak? | M6, M1 onboarding |
| 6 | İlk pazar yalnız Türkiye mi? | M14 hukuk, dil kapsamı |

---

## Ek D — Teknik borç kaydı

26 Ağustos 2026 tarihli uçtan uca teknik incelemenin çıktısı. **Bu bölüm bir yol haritasıdır:**
öncelik sırasına dizilmiştir, her madde tek başına ele alınabilir.

### Kapatılanlar

| | Ne yapıldı |
|---|---|
| ✅ TR-M14-10 | Android `allowBackup` açıkça tanımlandı, yedek kuralları yazıldı, güvenli depolama yedekten çıkarıldı |
| ✅ TR-M14-40 | `PrivacyInfo.xcprivacy` oluşturuldu ve Xcode Resources fazına kaydedildi |
| ✅ TR-A-02 | `drift_schemas/` dökümü + `migration_test.dart` (v4→v5 yükseltmesi dahil) |
| ✅ TR-B-02 | CI kuruldu: analiz/test, mimari kuralları, üretilen kod tazeliği |
| ✅ TR-D-09 | `ErrorWidget.builder` → `AppCrashView`; prod'da kırmızı hata ekranı çıkmıyor |
| ✅ TR-D-10 | Şema v5: join tablolarına ters yön indeksleri + `memories.categoryId` |

### Açık maddeler

| # | Madde | Öncelik | Neden |
|---|---|---|---|
| TR-D-01 | `store` sekmesi kararı | **P0** | Yayın engeli |
| TR-D-02 | Önizleme verisini gerçek veriyle değiştir | **P1** | Tüm veri katmanı işinin önkoşulu |
| TR-D-03 | Görsel bellek yönetimi | **P1** | Gerçek fotoğraf gelince çökme riski |
| TR-D-04 | Timeline sayfalama | **P1** | NFR-002 hedefi tutmaz |
| TR-D-05 | Profil ekranı | **P1** | FR-003 karşılanmıyor |
| TR-D-06 | Piksel testlerini belirteçlere bağla | P2 | Tasarım değişimini pahalılaştırıyor |
| TR-D-07 | Kullanılmayan feature flag'ler | P3 | Yanıltıcı |
| TR-D-08 | Family planı | P3 | Erken |

---

- **TR-D-01 [1.0] Zorunlu — P0.** `store` sekmesindeki `ComingSoonView` kaldırılır.
  *Sorun:* App Store Guideline 2.1 "coming soon" yer tutucu ekranları **reddediyor**.
  İZ Atölye 2.5'te geliyor; o zamana kadar bu sekme boş bir vaat.
  *Seçenekler:* (a) sekmeyi alt çubuktan kaldır — alt çubuk 4'ten 3'e iner, tasarım kararı;
  (b) sekmeyi İZ+ tanıtım/abonelik ekranına dönüştür — hem yer tutucu olmaktan çıkar hem
  M12'nin ihtiyacı olan satış yüzeyini verir. **(b) öneriliyor.**
  Konum: [`app_router.dart:378`](iz/lib/app/router/app_router.dart#L378).

- **TR-D-02 [1.0] Zorunlu — P1.** `lib/` içindeki **1.250 satır önizleme verisi** kaldırılır ve
  ekranlar gerçek repository'lere bağlanır.
  *Mevcut durum:* 20 view'ün yalnız 4'ü veritabanına bağlı. 7 önizleme dosyası 11 dosyadan
  kullanılıyor ve **`app_router.dart` bunlara bağımlı** — rota çözümü
  `MyLifePreviewData.seriesCardOf()` üzerinden geçiyor.
  *Sonuçları:* (a) veri katmanı geldiğinde 11 dosya + router birlikte değişecek,
  (b) demo anılar prod derlemesine paketleniyor ve kullanıcıya görünebilir.
  *Sıra:* **router'dan başla** — yükü en çok taşıyan yer orası. Sonra modül modül
  (M5 Kişiler → M6 Organizasyon → M3 Günlük → M7 Yeniden keşif).
  *Bitiş ölçüsü:* `lib/` altında `*preview_data*.dart` kalmaz; `l10n_test.dart`'taki
  ilgili istisnalar da silinir.

- **TR-D-03 [1.0] Zorunlu — P1.** Liste ve ızgara görünümlerinde görseller
  **hedef boyutta decode edilir** (`cacheWidth`/`cacheHeight` veya `ResizeImage`).
  *Sorun:* kodda tek bir `cacheWidth` yok; hepsi `Image.asset` (demo görselleri).
  Gerçek fotoğraflar bağlandığında 12 MP bir kareyi tam çözünürlükte decode etmek,
  liste kaydırmasında bellek patlamasına yol açar. NFR-001/002'yi doğrudan tehdit eder.
  *Bitiş ölçüsü:* 200 fotoğraflı bir listede kaydırma sırasında bellek kullanımı düz kalır.

- **TR-D-04 [1.0] Zorunlu — P1.** Timeline **sayfalanır** (sonsuz kaydırma veya ay bazlı yükleme).
  *Mevcut durum:* `watchMemories` opsiyonel `limit` alıyor ama timeline hepsini stream ediyor.
  TR-M2-25'teki "10.000 anıda ilk ekran < 500 ms" hedefi sayfalama olmadan tutmaz.

- **TR-D-05 [1.0] Zorunlu — P1.** Profil ekranı yazılır (FR-003: ad, görsel, dil, bildirim ve
  gizlilik tercihleri). *Mevcut durum:* `profile` rotası geçici olarak `SettingsView` gösteriyor.

- **TR-D-06 [1.1] Önerilir — P2.** Widget testlerindeki **~124 sabit piksel iddiası**
  (`expect(height, 370)`, `expect(width, 350)`) tasarım belirteçlerinden okunur hâle getirilir.
  *Sorun:* tasarım henüz oturmamışken 912 testin ciddi bir kısmı onu donduruyor; her revizyon
  bu testleri kırıyor.
  *Yaklaşım:* değeri `AppSpacing`/tema belirtecinden oku — belirteç değişince test kendiliğinden
  uyar. Gerçekten sözleşme olan birkaçı (dokunma hedefi ≥ 44 dp, TR-C-60) sabit kalır.

- **TR-D-07 [1.1] Önerilir — P3.** `FeatureFlags`'teki **12 bayraktan 11'i hiç okunmuyor**
  (`cloudSync` dahil). Bayrak altyapısı ucuz ama şu an sıfır getiri sağlıyor ve "kullanılıyor"
  izlenimi veriyor. Ya kullanım yerleri yazılır ya da faz geldiğinde eklenmek üzere sadeleştirilir.

- **TR-D-08 [2.0] Önerilir — P3.** `IzPlan.family` matriste 1.0'dan beri duruyor ama plan 2.0'da.
  Her entitlement kararında üçüncü bir sütun düşünmek gerekiyor, karşılığı yok.
  2.0'a kadar matristen çıkarmak değerlendirilebilir.

---

*Bu doküman kodla birlikte versiyonlanır. Bir gereksinim değiştiğinde kimliği (`TR-…`) korunur,
içeriği güncellenir ve değişiklik bu satırın altına not düşülür.*
