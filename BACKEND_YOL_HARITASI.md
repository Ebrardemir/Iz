# İZ — Backend Yol Haritası

> Kapsam: **kimlik + senkronizasyon + entitlement + medya yedekleme.**
> Yani İZ 1.5'in tamamı. Kararlar 26 Ağustos 2026'da alındı; ADR tablosu bağlayıcıdır.

Bu doküman `iz/ARCHITECTURE.md`'nin backend karşılığıdır. Gereksinim numaraları
(FR-xxx / NFR-xxx) `IZ_Gereksinim_Analizi_Raporu.docx` dosyasına atıftır.

---

## 0. Alınan kararlar (ADR özeti)

| # | Karar | Seçim | Gerekçe |
|---|---|---|---|
| ADR-B01 | Backend stack | **ASP.NET Core 9 + PostgreSQL + EF Core** | Rapor 13.2'nin önerisi. Identity, BackgroundService, ProblemDetails yerleşik. Veri TR bölgesinde tutulabilir (KVKK). |
| ADR-B02 | Repo | **Aynı repo** — `iz/` (Flutter) yanına `api/` (ASP.NET). | *Karar 26 Ağustos 2026'da ayrı repodan çevrildi.* Kök dizin zaten dile bağlı değil, sıfır yeniden yapılandırma. Asıl kazanç ADR-B03'te: sözleşme ve onu kullanan istemci kodu **aynı commit'te** değişiyor, arada tutarsızlık penceresi kalmıyor. Ayrılmak kolay (`git filter-repo`), birleşmek zor — belirsizlikte daha az bağlayıcı seçim. **Kararı çevirecek tek koşul:** mobil koda erişmemesi gereken dış geliştiriciyle çalışmak. |
| ADR-B03 | Sözleşme | **OpenAPI, sunucu koddan üretilir; istemci client'ı ondan üretilir** | Rapor 22.1. Sözleşme kırılırsa istemci derlemesi kırılır — sessiz uyumsuzluk imkânsız. Monorepo sayesinde üretim ve tüketim tek CI koşusunda doğrulanır. |
| ADR-B04 | Sync protokolü | **Delta / change-log tabanlı, cursor'lı pull + batch push** | Rapor ADR-004. Idempotency zorunlu. |
| ADR-B05 | Çakışma politikası | **Alan bazlı LWW + uzun metinde kayıpsız çatallama** | Rapor 12.2: "günlük/anı metninde veri kaybetmeyen yaklaşım tercih edilmelidir". Detay §4.4. |
| ADR-B06 | ~~Kimlik~~ | ~~ASP.NET Core Identity + JWT~~ → **ADR-B15 ile değiştirildi.** | Kendi Identity katmanımızı yazmak 2–3 hafta ve kimlik doğrulamayı yanlış yapmak geç fark edilen bir güvenlik olayıdır. |
| ADR-B07 | Medya | **Tam kalitede yedeklenir — yalnız İZ+.** Object storage + resumable upload + CDN. | Ürünün asıl vaadi bu. Free zaten senkronize olmadığı için (ADR-B09) depolama maliyeti yalnız ödeyen kullanıcıda oluşur. Şemadaki `cloudObjectKey` nihayet dolar. |
| ADR-B08 | Entitlement | **Sunucu tarafı doğrulama tek gerçek kaynak** | İstemcide plan hesaplamak kırılabilir. Store webhook'ları sunucuyu günceller. |
| ADR-B09 | Kimler senkronize olur | **Yalnız İZ+ (ve Aile).** Free plan cihazda kalır. | Karar zaten verilmiş: `entitlement.dart` içinde `IzPlan.free` → `features: {}`; `cloudBackup` ve `multiDevice` yalnız `plus`/`family`'de (FR-047, FR-135). Ayrıca free'yi senkronlamak sattığımız şeyi bedava vermek olurdu. |
| ADR-B10 | `deviceOnly` günlük kayıtları | **Hiçbir koşulda sunucuya gitmez** ve metni **cihaza bağlı anahtarla şifrelenir.** | FR-035'in sözü yalnız sunucuya karşı değil, telefonun kendi iCloud/Drive yedeğine karşı da tutulmalı. Detay §7.5. |
| ADR-B11 | Sunucu bölgesi | **Türkiye.** | KVKK'da yurt dışına aktarım rejimini hiç devreye sokmaz. İlk pazar Türkiye. |
| ADR-B12 | Hesap zorunluluğu | **Uygulama hesap dayatmaz.** Bulutu açmak isteyen kişi o anda hesap açar. | Local-first duruşun devamı. Yan etkisi: İZ+'ı yalnız foto limiti için alan kişi hesapsız kalabilir, anonim geri yükleme sorunu doğmaz. |
| ADR-B13 | Abonelik bitince | Buluttaki **orijinaller 90 gün saklanır**, sonra silinir. **Metadata ve anılar asla silinmez.** | FR-134'ün sınırı burada çizilir. Local-first olduğu için orijinaller zaten kullanıcının galerisinde: buluttan silinen ikinci kopyadır. |
| ADR-B15 | Kimlik sağlayıcısı | **Firebase Authentication** (Spark planı, kartsız). API'miz Firebase ID token'ını Google'ın açık anahtarlarıyla **doğrular**, kendi token'ını üretmez. | E-posta/Apple/Google girişi 50.000 aylık aktif kullanıcıya kadar ücretsiz — bizde hesap yalnız bulut isteyende açıldığı için bu tavan fazlasıyla geniş. Şifre sıfırlama, e-posta doğrulama, token yenileme, Apple uyumluluğu hazır gelir. Karşılığı: e-posta ABD'ye aktarılır → ADR-B17. |
| ADR-B16 | Abonelik doğrulama | **RevenueCat** (ücretsiz katman: aylık $2.500 takip edilen gelire kadar, sonrası %1). | Makbuz doğrulamanın kenar durumları — ödemesiz süre, ödeme yeniden denemesi, iade, aile paylaşımı, yükseltme/düşürme, orantılama — yılların birikimi. Kendi doğrulayıcımıza ilk günden güvenmek için erken. **Geri dönüş bilinçli olarak açık tutuluyor** (§6 Faz 4, TR-M12-16..20). |
| ADR-B17 | Yurt dışı aktarımın dayanağı | **Açık rıza.** Hesap açma adımında ayrı, anlaşılır ve reddedilebilir bir onay. | ABD için KVKK yeterlilik kararı yok; Firebase de RevenueCat de KVKK'nın standart sözleşme metnini imzalamaz. Rıza burada gerçekten özgür iradeyle veriliyor: hesap ve abonelik isteğe bağlı, ürünün tamamı hesapsız çalışıyor. Local-first duruşunun hukuki getirisi. |
| ADR-B14 | Dışa aktarma | **ZIP**: fotoğraflar + anı başına okunabilir HTML/metin + makine için JSON. | FR-160/161 taşınabilirlik. Kullanıcı 20 yıl sonra İZ olmasa da açıp okuyabilmeli. |

---

## 1. Başlangıç durumu (2026-08-26 itibarıyla)

**İstemci:** 173 Dart dosyası, ~34k satır, `flutter analyze` temiz, 55 test dosyası.
Drift `schemaVersion: 5`, 13 tablo + FTS5 sanal tablosu. Backend'e dair **tek satır ağ kodu yok**.
Tablolardan yalnız `Memories` için DAO ve repository yazılmış — kalan 12 tablonun
veri katmanı henüz yok (TRD → Ek D / TR-D-02).

Lehimize olan hazırlıklar (bunlar bize haftalar kazandırıyor):

- `core/database/table_mixins.dart` → `SyncableTable` zaten `id`(UUID) + `createdAt` + `updatedAt` + `deletedAt`(tombstone) + `version` veriyor. Rapor 12.2'nin istediği tam olarak bu.
- `OwnedTable` → `ownerId` var (şu an sabit `'local'`).
- `MediaItems` zaten `cloudObjectKey`, `galleryAssetId`, `originalStatus` taşıyor.
- `core/config/app_config.dart` → `apiBaseUrl` + `IZ_ENV` dart-define hazır.
- `core/config/feature_flags.dart` → `cloudSync` bayrağı **ve** `FeatureFlags.fromMap` (remote config, NFR-061).
- `core/storage/secure_store.dart` → token için Keychain/Keystore yeri hazır.
- `Result<T>` / `Failure` → ağ hatalarının oturacağı tip hiyerarşisi hazır.
- `features/journal/domain/entities/journal_entry.dart` → `syncable` getter'ı (`privacyMode != deviceOnly`) **zaten yazılmış**. Sync katmanının uyması gereken kural kodda duruyor.
- `core/entitlement/entitlement.dart` → plan matrisi hazır; `cloudBackup`/`multiDevice` yalnız İZ+'ta. Sync'in kime açılacağı sorusu çoktan cevaplanmış.
- `features/auth/` → domain sözleşmesi (`AuthRepository`), use-case'ler, ViewModel'ler, ekranlar **hazır ve test edilmiş**. Yalnız implementasyon sahte.

Kapatılacak boşluklar:

1. Ağ katmanı yok (`http`/`dio` bağımlılığı bile yok).
2. `StubAuthRepository` — token yok, refresh yok, oturum kalıcılığı yok (`_session` bellekte).
3. `Users` tablosu yok; `ownerId` sabit `'local'`.
4. Outbox / event kuyruğu yok (rapor 12.2 istiyor).
5. Sync durumu yok — cursor, `lastSyncAt`, `pendingCount`, `BackupState` yok.
6. `currentPlanProvider` sabit `IzPlan.free`; IAP yok.
7. Analitik yok (rapor 23 olay sözlüğü).

### 1.1 Kritik teknik borç — join tabloları

`MemoryPeople`, `MemoryCollections`, `MemoryRituals`, `MemoryMedia` **`SyncableTable` kullanmıyor**:
düz `Table`, composite primary key, `updatedAt`/`deletedAt`/`version` yok.

**Sonucu:** delta sync'te *"bu kişiyi anıdan çıkardım"* olayı temsil edilemez.
Satır fiziksel silindiği için değişiklik günlüğüne yazılacak bir şey kalmaz; diğer cihaz
ilişkiyi hâlâ görür ve bir sonraki push'ta geri yazar. **Silinen ilişki geri gelir.**

Bunu Faz 2'de şema v5 ile kapatıyoruz. Ne kadar erken, o kadar ucuz: kullanıcı tabanı
büyüdükçe migration riski artar.

---

## 2. Hedef mimari

```
[Firebase Auth]        [RevenueCat]
   │ ID token            │ webhook (abonelik durumu)
   ▼                     ▼
[Flutter Client] ────────┴──── HTTPS (TLS 1.2+) ────┐
   │                                                 │
   │  Kimlik DOĞRULAMASI Google'da,                  │
   │  kimlik KARARI ve tüm içerik bizde.             │
   ▼                                                 ▼
[api/ — ASP.NET Core · Türkiye]
   ├─ Auth        → Firebase ID token doğrulama (Google açık anahtarları)
   ├─ Sync        → /sync/push, /sync/pull (change-log)
   ├─ Entitlement → plan durumu, store webhook'ları
   ├─ Account     → profil, hesap silme (KVKK)
   └─ Config      → remote feature flags (FeatureFlags.fromMap'i besler)
        │
   [PostgreSQL]  +  [Redis: idempotency + rate limit]  +  [Hosted background jobs]
        │
   (Faz 6+: Object Storage + CDN — bu haritanın dışında)
```

**Depo yapısı** — tek repo, iki uygulama:

```
Iz/
├── .github/workflows/        → tek CI; işler yol filtresiyle ayrışır
├── iz/                       → Flutter istemcisi (mevcut)
│   └── lib/core/network/     → üretilen API istemcisi buraya iner
├── api/                      → ASP.NET Core sunucusu (yeni)
│   ├── src/
│   │   ├── Iz.Api/              Minimal API endpoint'leri, DI, middleware
│   │   ├── Iz.Domain/           Entity'ler, çakışma kuralları (bağımlılıksız)
│   │   ├── Iz.Application/      Use-case'ler (SyncPushHandler, PullChangesHandler…)
│   │   └── Iz.Infrastructure/   EF Core (migration'lar dahil), Redis,
│   │                             Firebase token doğrulama, RevenueCat
│   ├── tests/
│   │   ├── Iz.UnitTests/        çakışma çözümü, versiyonlama — saf mantık
│   │   └── Iz.IntegrationTests/ Testcontainers ile gerçek Postgres
│   ├── docker-compose.yml       Postgres + Redis (yerel geliştirme)
│   └── Iz.sln
├── contracts/
│   └── openapi.v1.yaml       → api CI'ında üretilir, PR diff'inde görünür
├── BACKEND_YOL_HARITASI.md
└── TEKNIK_GEREKSINIM_DOKUMANI.md
```

**Sözleşme akışı monorepo'da:** `api/` derlenince `contracts/openapi.v1.yaml` yeniden üretilir.
Aynı CI koşusu bu dosyadan Dart istemcisini üretir ve `iz/`nin derlendiğini doğrular.
Bir alan adı değiştiğinde **aynı PR** hem sunucuyu hem istemciyi kırar — ayrı repolarda
kaçınılmaz olan "yayınla, sonra karşı tarafta güncelle" penceresi hiç oluşmaz.

**CI ayrımı:** işler yol filtresiyle çalışır — `iz/**` değişince Flutter işleri,
`api/**` değişince .NET işleri, `contracts/**` değişince ikisi birden.
Deseni `uretilen-kod` işinde zaten kurduk.

**Neden istemci mimarisini aynalıyoruz:** `Iz.Domain` hiçbir şeyi bilmez, `Iz.Application`
yalnız domain'i bilir. Flutter tarafındaki domain/data/presentation ayrımıyla aynı kural.
İki tarafta aynı zihinsel model = geliştirici bağlam değiştirdiğinde hata yapmaz.

---

## 3. Sunucu veri modeli

Rapor 12'deki kavramsal model **birebir** korunur — MVP local DB ile bulut DB aynı modeli
paylaşmalı (rapor 12, satır 907).

```
users               (id, email, display_name, locale, created_at, deleted_at, plan_cache)
devices             (id, user_id, platform, last_seen_at, push_token)
memories            (id, owner_id, title, note, occurred_at, occurred_y/m/d,
                     category_id, location_id, cover_media_id, is_favorite, is_archived,
                     source_journal_entry_id, created_at, updated_at, deleted_at, version)
journal_entries     (…, entry_date, text, title, mood_score, is_starred, converted_memory_id)
people              (…, name, relation_type, birth_date, avatar_media_id)
categories          (…, name, icon, sort_order, is_system)
collections         (…, title, description, cover_media_id, visibility)
rituals             (…, title, recurrence_type, related_person_id)
locations           (…, label, latitude, longitude, city, country)
media_items         (…, type, gallery_asset_id, cloud_object_key(NULL), mime, w, h,
                     duration_ms, size_bytes, original_status)
memory_people       (memory_id, person_id, role,        updated_at, deleted_at, version)
memory_collections  (memory_id, collection_id, sort_order, updated_at, deleted_at, version)
memory_rituals      (memory_id, ritual_id, occurrence_year, updated_at, deleted_at, version)
memory_media        (memory_id, media_id, sort_order,   updated_at, deleted_at, version)
journal_media       (journal_entry_id, media_id, sort_order, updated_at, deleted_at, version)

change_log          (seq BIGSERIAL, user_id, entity_type, entity_id, op, version,
                     changed_at, device_id)          ← sync'in kalbi
idempotency_keys    (key, user_id, request_hash, response_body, created_at)
subscriptions       (user_id, provider, plan, status, expires_at, original_transaction_ref)
```

### 3.1 change_log — neden ayrı tablo

Pull'da "şu cursor'dan sonrasını ver" sorgusunu tablo tablo `updated_at > x` tarayarak
yapmak iki sorun doğurur: (a) her entity için ayrı indeks taraması, (b) **sıralama garantisi yok**
— iki tablodaki aynı milisaniyeli değişikliğin hangi sırayla uygulanacağı belirsiz kalır.

`change_log.seq` kullanıcı başına monoton artan tek bir sıra verir. Cursor = son görülen `seq`.
Sıra deterministik, sorgu tek indeks, sayfalama trivial.

**Kural:** `change_log`'a yazma, entity yazmasıyla **aynı transaction** içinde olur.
Aksi hâlde bir değişiklik kalıcı olur ama günlüğe düşmez → o kayıt hiçbir cihaza gitmez, sessizce kaybolur.

---

## 4. Sync protokolü

### 4.1 Push

```http
POST /v1/sync/push
Authorization: Bearer <access_token>
Idempotency-Key: <uuid, istemci üretir, retry'da AYNI kalır>

{
  "deviceId": "0192f...",
  "changes": [
    { "entityType": "memory",
      "entityId": "0192f8a1-...",
      "op": "upsert",              // upsert | delete
      "baseVersion": 3,            // istemcinin bildiği son sunucu sürümü; yeni kayıtta 0
      "payload": { "title": "...", "occurredAt": "2026-03-02T10:00:00Z", ... } }
  ]
}
```

Yanıt:

```json
{
  "results": [
    { "entityId": "0192f8a1-...", "status": "applied",  "version": 4, "seq": 1187 },
    { "entityId": "0192f8b2-...", "status": "conflict", "server": { "version": 7, "payload": {...} } },
    { "entityId": "0192f8c3-...", "status": "rejected", "reason": "entitlement_limit" }
  ],
  "cursor": 1187
}
```

**Kurallar:**

- `baseVersion` sunucudaki `version` ile eşleşmiyorsa → `conflict`. Sunucu **kendiliğinden ezmez**.
- Tüm batch tek transaction'da işlenir; kısmi başarı yok (ya hepsi ya hiçbiri). Çakışan öğeler
  "işlenmedi" sayılır, geri kalanı uygulanır — bu tek istisna, çünkü aksi hâlde bir çakışma
  tüm kuyruğu kilitler.
- `Idempotency-Key` Redis'te 24 saat tutulur. Aynı anahtarla gelen ikinci istek **işlenmez**,
  ilk yanıt aynen döner (NFR: "aynı event tekrar işlendiğinde duplicate anı üretmemelidir", rapor satır 820).
- Batch üst sınırı 200 değişiklik / 1 MB.

### 4.2 Pull

```http
GET /v1/sync/pull?cursor=1140&limit=200
```

```json
{
  "changes": [
    { "seq": 1141, "entityType": "memory", "entityId": "...", "op": "upsert",
      "version": 4, "payload": {...} },
    { "seq": 1142, "entityType": "memory_person", "entityId": "0192..:0192..",
      "op": "delete", "version": 2 }
  ],
  "nextCursor": 1187,
  "hasMore": false
}
```

- İstemci `nextCursor`'ı **ancak tüm değişiklikleri yerel transaction'a yazdıktan sonra** kaydeder.
  Yarıda kesilirse aynı sayfa tekrar gelir — uygulama idempotent olduğu için sorun olmaz.
- Kendi `deviceId`'sinden gelen değişiklikler yanıtta işaretlenir; istemci onları atlar (echo önleme).

### 4.3 İlk senkronizasyon (bootstrap)

Yeni cihazda `cursor = 0` ile pull → tüm veri sayfa sayfa gelir. Ayrı bir "full snapshot"
uç noktası **yazmıyoruz**: aynı kod yolu hem ilk yüklemeyi hem delta'yı çözer, dolayısıyla
ilk yükleme yolu her gün test edilmiş olur.

### 4.4 Çakışma politikası

Rapor 12.2 açık: *"son-yazma-kazanır olmadan önce test edilmelidir; günlük/anı metninde
veri kaybetmeyen bir yaklaşım tercih edilmelidir."* Üç sınıf tanımlıyoruz:

| Alan sınıfı | Örnek | Politika |
|---|---|---|
| **Skaler / idempotent** | `isFavorite`, `isArchived`, `categoryId`, `occurredAt`, `sortOrder` | Alan bazlı **son yazma kazanır** (`updatedAt` karşılaştırması). Kayıp önemsiz. |
| **Uzun metin** | `memory.note`, `journal.text`, `memory.title` | **Kayıpsız çatallama**: sunucu sürümü kazanır, istemcinin sürümü yerel `SyncConflicts` tablosuna yazılır ve kullanıcıya *"Bu anının bu cihazda farklı bir sürümü var"* diye gösterilir. Hiçbir cümle sessizce silinmez. |
| **N-N ilişki** | `memory_people` vs. | Satır bazlı: `deletedAt` dolu olan **kazanır** (silme kasıtlıdır). Ekleme/çıkarma ayrı satırlar olduğu için birleşme doğal olarak set union + tombstone. |

**Neden metin için otomatik merge yok:** üç yönlü metin birleştirme (diff3) kullanıcıya
anlamadığı çakışma işaretleri gösterir. Bir anı notu kod değil; kullanıcı "hangisi benim yazdığım"
sorusuna cevap verebilmeli. İki sürümü yan yana göstermek dürüst ve basit.

### 4.5 Silme

Fiziksel silme yok. `deletedAt` dolar, `version` artar, `change_log`'a `op: delete` düşer.
Kalıcı silme yalnız iki yerde:

- Çöp kutusu 30 günü dolduğunda (FR-015) — hem istemci hem sunucu tarafında zamanlanmış iş.
- Hesap silme talebinde (KVKK) — §7.3.

### 4.6 Senkronizasyon dışı bırakılanlar

Sync'in neyi **taşımadığı**, neyi taşıdığı kadar bağlayıcı. Dördü de bilinçli:

| Ne | Neden dışarıda |
|---|---|
| **`privacyMode == deviceOnly` günlük kayıtları** | FR-035'te kullanıcıya verilmiş açık söz. Bu kayıt outbox'a bile girmez. |
| **FTS5 arama indeksi** | Yerelde yeniden üretilebilir türev veri; taşımak hem gereksiz hem yavaş. Ayrıca arama sorgusunun kendisi hassastır — sunucuya hiç uğramaz (NFR-003 zaten offline arama istiyor). |
| **`localPreviewPath`, `galleryAssetId`** | Cihaza özgü yollar. Başka cihazda anlamsız, hatta yanıltıcı. Sync'te atlanır. |
| **Medya binary'si** | ADR-B07 — bu haritanın kapsamı dışı. `cloudObjectKey` şemada durur, hep `null`. |

**Süzgeç nerede uygulanır:** `deviceOnly` filtresi **repository'nin outbox'a yazdığı noktada**,
ekranda değil. Ekranda filtrelemek, ileride başka bir yazma yolu eklendiğinde kaydın sessizce
sızması demektir.

Buna karşılık **tek bir test** yazılır ve o test bu haritanın en önemli testidir:

> *"`deviceOnly` işaretli bir günlük kaydı oluşturulduğunda `OutboxEntries` tablosu boş kalır."*

Bu test kırmızıya dönerse yayın durur. Kullanıcıya "bu cihazdan çıkmayacak" dediğimiz bir metnin
sunucuya gitmesi, bu üründe düzeltilebilir bir hata değildir.

### 4.7 `locked` kayıtlar

FR-035'in ikinci yarısı: kilitli günlük kaydı. Bunlar **senkronize olur** (kullanıcı yedeğini ister)
ama uygulama açılışında biyometri/PIN ister (FR-005). Sunucu için farkları yok — düz metin durur.
İstemci tarafı şifreleme yalnız bu kayıtlar için anlamlı; §7.5'te ele alınıyor, bu fazın dışında.

---

## 5. API yüzeyi (v1)

Rapor 22'deki taslak sınırların bu fazda gerçekleşen alt kümesi:

> **Kimlik uçları yok — bilinçli.** ADR-B06 (kendi Identity katmanımız) ADR-B15 ile
> düştüğü için `register` / `login` / `refresh` / `logout` / `password-reset` /
> `social` uçlarının hiçbiri yazılmıyor. Bu altı işi Firebase yapıyor. İstemci
> Firebase'den ID token alır ve her isteğe `Authorization: Bearer <ID token>`
> koyar; bizim tarafımızda yalnız **doğrulama middleware'i** vardır (TR-M1-05).
> Token yenilemeyi de Firebase SDK'sı yönetir — elle refresh mantığı yazılmaz (TR-M1-02).

```
POST   /v1/devices                    cihaz kaydı (platform, push token)

GET    /v1/me                         profil + plan özeti
                                      (ilk çağrıda users kaydını token'daki uid ile açar)
PATCH  /v1/me
POST   /v1/me/delete-request          KVKK — 30 gün geri alınabilir
DELETE /v1/me/delete-request          geri alma

POST   /v1/sync/push
GET    /v1/sync/pull?cursor=&limit=
GET    /v1/sync/state                 lastSyncAt, serverCursor (yedekleme sağlığı ekranı)

GET    /v1/entitlements               plan, expiry, features[] — planın TEK kaynağı
POST   /v1/entitlements/refresh       satın alma sonrası planı hemen tazele
                                      (webhook'u beklemeden; doğrulama yine sunucuda)
POST   /v1/webhooks/revenuecat        abonelik durumu değişimi — imza doğrulanır (ADR-B16)

GET    /v1/config/flags               FeatureFlags.fromMap'i besler (NFR-061)
```

**Store webhook'ları neden yok:** App Store Server Notifications ve Play RTDN
doğrudan RevenueCat'e gidiyor, RevenueCat bize tek bir normalize edilmiş webhook
atıyor. ADR-B16'dan geri dönülürse (kendi doğrulayıcımızı yazarsak)
`/v1/webhooks/appstore` ve `/v1/webhooks/googleplay` o gün eklenir — bu yüzden
Apple `originalTransactionId` ve Google `purchaseToken` bugünden bizim
veritabanımızda tutuluyor (TR-M12-17).

**Standartlar (rapor 22.1):**

- Hata gövdesi **her zaman** RFC 9457 ProblemDetails. Özel alan: `errorCode` (istemci `Failure`'a bununla map'ler).
- `Idempotency-Key` push ve entitlement doğrulamada zorunlu.
- Rate limit: auth uçlarında IP+hesap bazlı, sync'te kullanıcı bazlı (Redis sliding window).
- **Loglar içerik metni taşımaz.** `memory.note`, `journal.text`, kişi adı, e-posta → asla log'a girmez.
  İstemcideki `redact()` (NFR-013/014) yaklaşımının sunucu karşılığı bir `IzLogRedactor` middleware'i.

---

## 6. Fazlar

> Süreler **1 backend + 1 Flutter geliştirici** varsayımıyla. Fazlar sıralı yazıldı ama
> Faz 2 istemci tarafında Faz 1 ile paralel yürütülebilir.

### Faz 0 — Temel atma (1–2 hafta)

**Sunucu** — ✅ *tamamlandı (26 Ağustos 2026)*
- ✅ `api/` klasörü, .NET 9 solution: `Iz.Domain` → `Iz.Application` → `Iz.Infrastructure` → `Iz.Api`
      (tek yönlü bağımlılık zinciri, Flutter tarafındaki katman ayrımının aynası)
- ✅ `docker-compose` (Postgres 17 + Redis 7), sağlık koşuluyla başlatma sırası
- ✅ Çok aşamalı `Dockerfile`, root olmayan kullanıcı. **Yapılandırma tamamen ortam
      değişkeninden ve uygulama durumsuz** — aynı imaj VPS'te de yönetilen konteyner
      servisinde de çalışır, barındırma kararı ertelenebilir kalıyor
- ✅ `/health/live`, `/health/ready`, `/health` (ortam bildirimi)
- ✅ ProblemDetails middleware: her hata `errorCode` ve `traceId` taşıyor
- ✅ JSON konsol logu (ayrı log kütüphanesi eklenmedi — henüz gerek yok)
- ✅ `/openapi/v1.json` yayınlanıyor
- ✅ CI: `dotnet format` + derleme + test, **yol filtresiyle** (`api/**` veya `contracts/**`)
- ✅ 5 entegrasyon testi: sağlık uçları, ProblemDetails biçimi, OpenAPI yayını

**Not:** `Iz.Migrations` ayrı proje olarak açılmadı — EF migration'ları `Iz.Infrastructure`
içinde yaşayacak. Bir proje az, aynı iş.

**✅ Doğrulandı (3 Eylül 2026):** `docker compose up --build` çalıştırıldı. İmaj derlendi,
üç konteyner de sağlıklı, `/health` gerçek yanıt verdi (`{"status":"ok","environment":"dev"}`),
`/health/live`, `/health/ready` ve `/openapi/v1.json` 200 döndü.

**İstemci**
- `dio` + `core/network/`: `ApiClient`, auth interceptor, retry/backoff, `ProblemDetails → Failure` map'i
- `AppConfig.apiBaseUrl` gerçekten kullanılmaya başlar

**Çıkış kriteri:** Flutter uygulamasından `/health` çağrılıyor, hata gövdesi `Failure`'a dönüyor, testte mock'lanabiliyor.

---

### Faz 1 — Kimlik (1 hafta)

> Süre 2–3 haftadan 1 haftaya indi: kimlik doğrulamayı Firebase yapıyor (ADR-B15).
> Bize kalan iş **token doğrulamak ve kullanıcıyı kendi veritabanımıza yazmak**.

**Sunucu** — *3 Eylül 2026: ilk geçiş yazıldı, 24 entegrasyon testi yeşil.*
- ✅ Firebase ID token doğrulaması: `JwtBearer` + `Authority` ile Google'ın anahtarları
      indirilip önbelleğe alınıyor; `iss`/`aud`/`exp` ve imza doğrulanıyor. `ClockSkew`
      varsayılan 5 dakikadan 30 saniyeye çekildi.
- ✅ EF Core + PostgreSQL: `users` ve `devices` tabloları, snake_case, ilk migration.
- ✅ **`users` Firebase `uid` ile anahtarlanmıyor, kendi UUID v7'miz birincil anahtar;
      `firebase_uid` benzersiz sütun.** Karar Faz 1'de netleşti: `uid`'yi birincil anahtar
      yapmak her satırın sahipliğini bir kimlik sağlayıcısının iç kimliğine bağlardı ve
      ADR-B15'ten çıkmayı imkânsızlaştırırdı. Maliyeti bir sütun.
- ✅ E-posta bizde de tutuluyor ve her istekte token'dakiyle tazeleniyor (TR-M1-06).
- ✅ `GET /v1/me`, `PATCH /v1/me`, `POST /v1/devices`
- ✅ IDOR'a karşı iki hat: repository'ler `userId` ile sorguluyor **ve** EF global sorgu
      süzgeci sahipli kayıtları kullanıcıya bağlıyor (§7.2). Entegrasyon testinde
      "saldırgan kurbanın cihaz kimliğiyle istek atar" senaryosu var.
- ✅ Cihaz kimliğini **sunucu üretir** — istemci üretseydi başka cihazın kimliğini iddia
      edip sync'teki echo kuralını kurbanın değişikliklerini gizlemek için kullanabilirdi.
- ✅ CI'a migration kayması kontrolü eklendi (`has-pending-model-changes`).
- ⏳ Kalan: rate limit (auth uçları), `/health/ready`'ye veritabanı kontrolü,
      `POST /v1/me/delete-request` (sütunlar hazır: `deletion_requested_at`).

**İstemci**
- `FirebaseAuthRepository` yazılır; [stub_auth_repository.dart](iz/lib/features/auth/data/repositories/stub_auth_repository.dart) yerine geçer.
  **Değişen tek satır** `authRepositoryProvider` — View, ViewModel, UseCase hiç dokunulmaz.
  (Mimarinin bu vaadi burada sınanacak; tutmazsa sorun mimaridedir, acele etmeyelim.)
- Token'lar `SecureStore`'a; uygulama açılışında oturum geri yükleme; `go_router` redirect'i
- `Users` tablosu (Drift) + oturum açan kullanıcının `ownerId`'si

**⚠️ Anonim → hesap yükseltme akışı.** Mevcut kullanıcılar hesapsız kullanıyor,
tüm kayıtlar `ownerId = 'local'`. Hesap açıldığında:
1. Tüm yerel kayıtların `ownerId`'si gerçek `userId` ile güncellenir (tek transaction),
2. Her kayıt için outbox'a `upsert` yazılır (`baseVersion: 0`),
3. İlk push bu kuyruğu boşaltır.

Bu akış atlanırsa mevcut kullanıcıların verisi **hiçbir zaman buluta çıkmaz.** Faz 1'in en riskli parçası budur; testi ilk yazılacak testtir.

**Çıkış kriteri:** Gerçek hesapla giriş/çıkış, uygulama kapanıp açılınca oturum korunuyor, access token süresi dolunca sessizce yenileniyor, hesapsız kullanıcı hesap açınca verisi `ownerId` alıyor.

---

### Faz 2 — Şema hazırlığı (1–2 hafta, Faz 1 ile paralel)

Görünür hiçbir özellik üretmez; Faz 3'ün ön koşuludur.

**Drift `schemaVersion` → v7** (şema kütüğünün tek kaynağı: TRD **Ek A**):

> ⚠️ *Bu bölüm 26 Ağustos'ta "v4 → v5" diye yazılmıştı; o sırada v5 zaten alınmıştı.*
> Bugünkü doğru numara **v7**'dir: v5 ters yön indeksleriyle (✅ alındı), v6 ise
> `journal_search` FTS tablosuyla (1.1) dolu. Sync tabloları 1.5'e ait olduğu için
> sıradaki boş numara v7. Sürüm numarasını bu dokümandan değil **her zaman Ek A'dan**
> oku — iki yerde tutulan numara bir gün ayrışır.

- Join tablolarına (`MemoryPeople`, `MemoryCollections`, `MemoryRituals`, `MemoryMedia`, `JournalMedia`)
  `updatedAt`, `deletedAt`, `version` sütunları. Composite PK korunur — kimlik `(memoryId, personId)`
  çifti zaten deterministik, ayrı UUID gerekmez.
- Yeni tablolar:
  - `OutboxEntries` — `id, entityType, entityId, op, payloadJson, baseVersion, createdAt, attemptCount, lastError`
  - `SyncState` — `cursor, lastSyncAt, lastError, pendingCount` (rapor 12'deki `BackupState`)
  - `SyncConflicts` — `entityType, entityId, field, localValue, serverValue, detectedAt, resolvedAt`
- **Tüm mevcut sorgulara `deletedAt IS NULL` filtresi.** Join tabloları soft-delete'e geçtiği için
  bu atlanırsa silinmiş ilişkiler ekranda görünmeye başlar. Bu, fazın en sinsi kısmı —
  `memory_dao.dart` ve tüm feature DAO'ları tek tek gözden geçirilecek.
- Repository yazma yolları outbox'a kayıt düşürür (henüz kimse okumuyor).

**Çıkış kriteri:** v5 → v7 migration testi yeşil; mevcut test paketi hâlâ yeşil; outbox doluyor.

---

### Faz 3 — Metadata senkronizasyonu (4–6 hafta) — **haritanın kalbi**

**Sunucu**
- Tüm entity'ler + `change_log` (aynı transaction kuralı)
- `/v1/sync/push` — versiyon kontrolü, çakışma tespiti, idempotency
- `/v1/sync/pull` — cursor'lı sayfalama
- `/v1/sync/state`
- Entitlement kontrolü push'ta (free plan limitleri sunucuda da doğrulanır — istemciye güvenilmez)

**İstemci**
- `SyncEngine`: outbox drain → push → sonuç işleme → pull → yerel uygulama
- Tetikleyiciler: uygulama öne geldiğinde, yazma sonrası debounce (30 sn), manuel "şimdi eşitle"
- Ağ hatasında üstel backoff + jitter; çevrimdışında kuyruk büyür, veri kaybolmaz
  (FR: "düşük bağlantıda kaldığı yerden devam, retry ve kuyruklama", rapor satır 323)
- Çakışma UI'ı: anı detayında "bu anının başka bir sürümü var" şeridi, iki sürüm yan yana
- Ayarlar → **Yedekleme Sağlığı** ekranı gerçekleşir: son eşitleme, bekleyen öğe, son hata (FR-614)
- Hepsi `featureFlagsProvider.cloudSync` bayrağının arkasında — bayrak kapalıyken tek satır çalışmaz

**Çıkış kriteri (kabul senaryoları):**
1. İki cihaz, aynı hesap: A'da oluşturulan anı B'de görünür.
2. A çevrimdışıyken 20 değişiklik → çevrimiçi olunca hepsi tek batch'te gider, tekrar yok.
3. Aynı push iki kez gönderilir (retry) → sunucuda tek kayıt (idempotency).
4. A ve B aynı notu farklı düzenler → **hiçbir metin kaybolmaz**, kullanıcıya iki sürüm gösterilir.
5. A'da anıdan kişi çıkarılır → B'de de çıkar, bir sonraki eşitlemede geri gelmez. *(§1.1 borcunun testi)*
6. Yeni cihazda sıfırdan bootstrap → tüm veri iner.
7. Pull yarıda kesilir → tekrar denendiğinde duplicate oluşmaz.
8. **`deviceOnly` günlük kaydı oluşturulur → outbox boş, sunucuda iz yok, ikinci cihazda görünmez.** *(§4.6)*
9. Free plandaki hesap push denerse `403 entitlement_required` alır; yerel veri bozulmaz.

---

### Faz 4 — Entitlement ve abonelik (2–3 hafta) — **Faz 3'ün yayın ön koşulu**

> **Sıralama uyarısı:** ADR-B09 gereği sync yalnız İZ+ kullanıcıya açık. Yani Faz 3 teknik olarak
> bitse bile, satılamayan bir özelliği yayınlayamayız. Bu faz Faz 3 ile **paralel** yürütülür ve
> `cloudSync` bayrağını açmanın koşuludur. Sunucu tarafında `/v1/sync/push` free kullanıcıya
> `403 + errorCode: entitlement_required` döner; istemci bunu paywall'a çevirir.


**Sunucu**
- `/v1/entitlements` — **uygulamanın tek plan kaynağı.** İstemci RevenueCat SDK'sından plan okumaz.
- `POST /v1/webhooks/revenuecat` — abonelik durumu değişimi buradan gelir; imza doğrulanır.
- `subscriptions` tablosu. **Apple `originalTransactionId` ve Google `purchaseToken` KENDİ
  veritabanımıza yazılır** — bunlar geçiş anahtarıdır: sağlayıcı değişse bile Apple/Google'a
  doğrudan yeniden doğrulatabiliriz.
- Plan `users.plan_cache`'e denormalize edilir (sync push'ta hızlı limit kontrolü için).
- `ISubscriptionVerifier` arayüzü; tek implementasyon `RevenueCatVerifier`.
  Kendi altyapımıza geçiş = ikinci bir implementasyon yazmak, çağrı yerlerine dokunmamak.

**Geçiş neden şimdiden düşünülüyor:** RevenueCat ücretsiz katmanı aylık $2.500 gelire kadar,
sonrası %1. Bu eşiğe gelmek iyi bir sorundur — ama o gün geldiğinde mimarinin hazır olması gerekir.
Yukarıdaki üç madde (kendi kimliklerimizi saklamak, tek plan kaynağı olmak, arayüz arkasına almak)
geçişi haftalar değil günler meselesi yapar.

**İstemci**
- `purchases_flutter` (RevenueCat SDK): satın alma akışı ve geri yükleme
- **RevenueCat'e opak bir kullanıcı kimliği gönderilir** — e-posta, ad veya Firebase `uid`
  doğrudan gönderilmez (veri minimizasyonu, ADR-B17)
- `currentPlanProvider` sabit `IzPlan.free` olmaktan çıkar; `/v1/entitlements`'tan beslenir
- `core/entitlement/entitlement.dart` matrisi zaten hazır — yalnız kaynağı değişir
- `/v1/config/flags` → `FeatureFlags.fromMap` (NFR-061 gerçekleşir)

**Çıkış kriteri:** Satın alma sonrası plan sunucudan gelir; abonelik iptalinde webhook ile düşer; uygulama silinip kurulunca restore çalışır.

---

### Faz 5 — Operasyon, güvenlik, uyumluluk (sürekli; Faz 3 ile paralel başlar)

- **Gözlemlenebilirlik** (rapor satır 902): upload hata oranı, sync gecikmesi, API latency, storage büyümesi dashboard'u. OpenTelemetry + Grafana.
- **Yedekleme:** Postgres PITR; **geri yükleme tatbikatı** yapılmadan "yedeğimiz var" denmez.
- **Rate limit / abuse:** auth ve sync uçları.
- **Güvenlik testi** (rapor satır 1227): auth, erişim kontrolü, **IDOR** (başkasının `memoryId`'siyle istek), log redaksiyonu, token süresi.
- **KVKK/GDPR:** §7.
- **Analitik** (rapor 23): olay sözlüğü — kullanıcı içeriği asla parametre olmaz.

---

## 7. Güvenlik ve KVKK

### 7.1 Taşıma ve saklama
- TLS 1.2+ zorunlu, HSTS. Cert pinning Faz 5'te değerlendirilir (pinning yanlış yapılırsa uygulamayı kırar — acele edilmez).
- Postgres encryption-at-rest (NFR-015).
- E2EE **bu fazın kapsamında değil** (ADR-003 "teknik keşfe alınmalı" diyor). Ancak metadata sync'te
  içerik metni sunucuda düz durur — bunu gizlilik metninde **dürüstçe** yazacağız. Ürünün duruşu bunu gerektiriyor.

### 7.2 Yetkilendirme
Her sorgu `owner_id = currentUserId` filtresiyle. **İstemciden gelen `ownerId`'ye asla güvenilmez.**
EF Core global query filter + entegrasyon testinde IDOR senaryosu.

### 7.3 Hesap ve veri silme (FR, rapor satır 214)
- `POST /v1/me/delete-request` → 30 gün geri alınabilir pencere, sonra kalıcı silme job'ı.
- Kullanıcıya **yerel kopyaların durumu açıkça anlatılır** — rapor bunu özellikle şart koşuyor.
- Veri dışa aktarma (FR-160/161) bu fazda istemci tarafında; sunucu tarafı export sonraya.

### 7.4 Cihaz doğrulama, sırlar ve ortam ayrımı

- **Cihaz doğrulama.** Uç noktalarımız internete açık; geçerli bir token'ı ele geçiren biri
  uygulamanın dışından istek atabilir. Faz 5'te **Play Integrity (Android) + App Attest (iOS)**
  doğrulaması eklenir: istemci attestation token'ı gönderir, sunucu Google/Apple API'siyle doğrular.
  Zorunlu tutmadan önce ölçülür — yanlış yapılandırılmış attestation gerçek kullanıcıyı dışarıda bırakır.
- **Sırlar depoda durmaz.** Bağlantı dizeleri, imzalama anahtarları, store API anahtarları
  ortam değişkeni / secret manager'dan gelir. Repoya giren tek şey `.env.example`'dır.
- **Ortamlar fiziksel olarak ayrı.** `dev` / `staging` / `prod` **ayrı veritabanları**.
  Tek ortamla çalışmak, bir gün bir test script'inin prod verisini silmesi demektir —
  ve bu üründe silinen veri bir kullanıcının anısıdır.

### 7.5 İleri güvenlik (bu fazın dışında, ama şimdiden konumlanıyor)

- **Yerel veritabanı şifreleme (SQLCipher).** FR-005 uygulama kilidi, `.db` dosyası düz dururken
  yalnız bir perdedir; telefonu ele geçiren biri dosyayı okur. Gerçek kilit ancak şifreli DB ile olur.
- **İstemci tarafı şifreleme yalnız `locked` kayıtlar için.** Tüm uygulamaya E2EE uygulamak iki şeyi
  bitirir: sunucu tarafı kurtarma (anahtarını kaybeden kullanıcı verisini kaybeder) ve sunucu tarafı
  arama. Kullanıcının **bilerek kilitlediği** kayıt bu bedeli hak eder, tamamı etmez.

### 7.6 Yapılacak hukuki iş (rapor satır 886)
VERBİS kaydı, aydınlatma metni, açık rıza akışı, veri işleme envanteri, veri sorumlusu/işleyen sözleşmeleri.
**Sunucu TR bölgesinde tutulmazsa yurt dışına aktarım rejimi devreye girer** — hosting kararı bu yüzden
teknik değil hukuki bir karardır. Profesyonel hukuk incelemesi Faz 3 bitmeden başlatılmalı.

---

## 8. Test stratejisi

| Katman | Ne | Nerede |
|---|---|---|
| Birim | Çakışma çözümü, versiyon karşılaştırma, cursor mantığı | `Iz.UnitTests` |
| Entegrasyon | Gerçek Postgres (Testcontainers), push/pull uçtan uca, idempotency, IDOR | `Iz.IntegrationTests` |
| Sözleşme | OpenAPI değişirse istemci client'ı yeniden üretilir; kırılma derleme hatası | CI |
| İstemci birim | `SyncEngine` — fake `ApiClient` ile outbox drain, backoff, çakışma | `iz/test/unit/` |
| İstemci entegrasyon | Bellek içi Drift + fake sunucu ile iki cihaz simülasyonu | `iz/test/` |
| Kaos | Ağ kesintisi, yarım pull, çift push, saat kayması | Faz 3 çıkış kriteri |

**Saat kayması notu:** çakışma çözümü istemci `updatedAt`'ine bakıyor. Cihaz saati yanlışsa
karar bozulur. Bu yüzden sunucu, gelen `updatedAt`'i kendi saatiyle karşılaştırıp aşırı sapmayı
(> 24 saat) log'lar ve sıralamada `change_log.seq`'i otoriter kabul eder.

---

## 9. Riskler

| Risk | Etki | Azaltım |
|---|---|---|
| Join tablosu borcu geç kapatılır | Silinen ilişkiler geri gelir; kullanıcı güveni kırılır | Faz 2 sıraya alındı, Faz 3'ün ön koşulu |
| Anonim→hesap yükseltme atlanır | Mevcut kullanıcıların verisi buluta hiç çıkmaz | Faz 1 çıkış kriteri; ilk yazılan test |
| Çakışma politikası veri kaybettirir | Kullanıcının yazdığı not silinir — geri dönüşü yok | Uzun metinde kayıpsız çatallama (§4.4) |
| Sunucu bölgesi/KVKK geç ele alınır | Yayın engeli | Hukuk incelemesi Faz 3 bitmeden başlar |
| Kapsam medyaya kayar | Faz 3 hiç bitmez | ADR-B07: medya bu haritanın dışında, şema hazır |
| Sync bayrağı erken açılır | Yarım özellik kullanıcıya ulaşır | `cloudSync` bayrağı ancak 9 kabul senaryosu yeşilken açılır |
| **`deviceOnly` kayıt sunucuya sızar** | Kullanıcıya verilen açık sözün ihlali; onarılamaz güven kaybı | Süzgeç outbox yazma noktasında (§4.6); yayını durduran test |
| Entitlement geç gelir | Sync biter ama satılamaz, yayınlanamaz | Faz 4 Faz 3 ile paralel; ADR-B09 |
| Tek ortam / paylaşılan veritabanı | Test bir gün prod verisini siler | `dev`/`staging`/`prod` ayrı DB (§7.4) |
| Analitiğe içerik parametresi girer | NFR-013 ihlali | Olay sözlüğü (rapor 23) tek kaynak; kod incelemesinde kontrol |

---

## 10. Kapsam dışı (bilinçli)

Medya yükleme, object storage, CDN, resumable/chunked upload, thumbnail pipeline (rapor 7.4, NFR-032);
ortak koleksiyon/davet (V2, FR-110..116); İZ Atölye ticaret katmanı (rapor 13.3); yönetim paneli
(rapor 21 — "MVP local-only ise şart değildir"); AI (V3).

Hiçbiri için kapı kapatılmıyor: `cloudObjectKey` şemada duruyor, `Invitation`/`Membership`
kavramsal modelde yerini koruyor, `change_log` yeni entity tipleri eklemeye açık.

**Bildirimler backend işi değil — kimse push sunucusu kurmasın.** FR-150/151/152 (Bugünün İzi,
ritüel hatırlatması, günlük promptu) hepsi MVP gereksinimi ve hepsi **yerel bildirimle** çözülür:
tarih cihazda biliniyor, veri cihazdan çıkmıyor. Sunucudan tetiklenen push ancak V2'de
(ortak koleksiyon daveti) gerekecek. Bugün FCM/APNs entegrasyonu yapmak, çözülmemiş bir sorunu
çözmektir.

**Dışa aktarma (FR-135/160/161) da istemci tarafıdır** — veri zaten cihazda, sunucuya sorup
geri indirmenin anlamı yok.

---

## 11. Açık sorular (başlamadan cevaplanmalı)

1. **Hosting nerede?** TR bölgesi (KVKK'yı basitleştirir) mi, yoksa AB/global (maliyet, olgunluk) mü? → Hukuki karar.
2. ~~Bulut free kullanıcıya açılacak mı?~~ **Kapandı.** Rapor satır 1441 açık bırakmıştı ama
   `entitlement.dart` zaten karar vermiş: `IzPlan.free` → `features: {}`. Sync İZ+ özelliğidir (ADR-B09).
   Geriye kalan tek alt soru: free kullanıcıya **küçük bir güvenlik kotası** (ör. yalnız metin, medyasız,
   son 100 anı) verilecek mi? Bu bir ürün kararı — teknik olarak `/v1/entitlements` bunu taşıyabilir.
3. **Hesap MVP'de zorunlu mu?** Şu an opsiyonel. Sync açılınca zorunlu mu olacak, yoksa "yalnız cihazda" modu kalıcı mı? → Onboarding ve `ownerId` stratejisini etkiler.
4. **E2EE ne zaman?** Şimdi değil dedik; ama kullanıcıya ne söz vereceğimiz gizlilik metnini bugünden bağlar.
5. **Çakışma UI'ını kim tasarlayacak?** Faz 3'ün kullanıcıya değen tek parçası ve en kolay kötü yapılan yeri.
