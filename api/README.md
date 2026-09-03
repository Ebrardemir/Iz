# İZ API

İZ'in sunucu tarafı. Kararlar ve fazlar için depo kökündeki
[BACKEND_YOL_HARITASI.md](../BACKEND_YOL_HARITASI.md), gereksinimler için
[TEKNIK_GEREKSINIM_DOKUMANI.md](../TEKNIK_GEREKSINIM_DOKUMANI.md).

## Hızlı başlangıç

```bash
docker compose up --build
curl http://localhost:8080/health
```

Docker olmadan:

```bash
dotnet tool restore                     # dotnet-ef sürümü depoda sabit
dotnet run --project src/Iz.Api         # IZ_Iz__DatabaseConnection ŞART
dotnet test
```

> **Docker gerekiyor.** Entegrasyon testleri Testcontainers ile gerçek bir
> PostgreSQL kaldırıyor (yol haritası §8). Bellek içi sağlayıcı kullanmıyoruz:
> benzersizlik kısıtı, yabancı anahtar ve migration'ın gerçekten çalışması
> orada test edilemez — orada yeşil yanan test üretimde kırmızıya döner.

## Veritabanı

Şema EF Core migration'larıyla yönetilir; migration'lar `Iz.Infrastructure`
içinde yaşar (ayrı bir `Iz.Migrations` projesi açılmadı — bir proje az, aynı iş).

```bash
# Yeni migration üret
dotnet ef migrations add Adi \
  --project src/Iz.Infrastructure --startup-project src/Iz.Infrastructure \
  --output-dir Persistence/Migrations

# Yereldeki veritabanına uygula
dotnet ef database update \
  --project src/Iz.Infrastructure --startup-project src/Iz.Infrastructure
```

Entity'yi değiştirip migration üretmeyi unutmak CI'da yakalanır
(`migrations has-pending-model-changes`). Bu tür bir kaymanın ilk fark
edileceği yer aksi hâlde üretim veritabanı olurdu.

## Yapı

```
src/
├── Iz.Domain/          Entity'ler ve iş kuralları. HİÇBİR ŞEYE bağımlı değil.
├── Iz.Application/     Use-case'ler. Yalnız Domain'i bilir.
├── Iz.Infrastructure/  EF Core, Redis, Firebase, RevenueCat. Application'ı bilir.
└── Iz.Api/             Endpoint'ler, DI, middleware. Hepsini bilir.
```

Bağımlılık yönü tek taraflı: `Api → Infrastructure → Application → Domain`.
Flutter tarafındaki `domain/data/presentation` ayrımıyla aynı kural — iki
tarafta aynı zihinsel model olsun ki geliştirici bağlam değiştirince hata
yapmasın.

## Yapılandırma

Sırlar **yalnız ortam değişkeninden** gelir, `appsettings.json`'a yazılmaz
(TR-M14). Önek `IZ_`, bölüm ayracı `__`:

| Değişken | Ne |
|---|---|
| `IZ_Iz__Environment` | `dev` \| `staging` \| `prod` |
| `IZ_Iz__DatabaseConnection` | PostgreSQL bağlantı dizesi |
| `IZ_Iz__RedisConnection` | Redis bağlantı dizesi |
| `IZ_Iz__FirebaseProjectId` | ID token doğrulaması için (Faz 1) |

`IZ_Iz__DatabaseConnection` **olmadan uygulama açılmaz** — eksik yapılandırmayı
ilk gerçek kullanıcının isteğinde değil, açılışta öğrenmek istiyoruz.

`IZ_Iz__FirebaseProjectId` boşsa uygulama yine açılır (sağlık uçları ve OpenAPI
çalışır) ama kimlik isteyen her uç **401** döner. "Yapılandırılmadı" hiçbir
koşulda "herkese açık"a dönüşmez.

## Kimlik (Faz 1)

Kendi token'ımızı üretmiyoruz (ADR-B15). İstemci Firebase'den bir **ID token**
alır, her isteğe `Authorization: Bearer <ID token>` koyar; biz Google'ın açık
anahtarlarıyla **imza · `iss` · `aud` · `exp`** doğrularız (TR-M1-05).

`register`/`login`/`refresh`/`logout`/`password-reset` uçları **yoktur** —
bu altı işi Firebase yapıyor. İlk geçerli token geldiğinde kullanıcı kaydı
kendiliğinden açılır; ayrı bir "kayıt ol" adımı yok.

| Uç | Ne |
|---|---|
| `GET /v1/me` | Profil + plan özeti. İlk çağrıda `users` kaydını açar. |
| `PATCH /v1/me` | `displayName`, `locale`. Boş bırakılan alan değişmez. |
| `POST /v1/devices` | Cihazı kaydeder veya son görülmesini tazeler. |

Cihaz kimliğini **sunucu üretir**. İstemci üretseydi başka bir cihazın
kimliğini iddia edebilir, sync'teki "kendi değişikliğini atla" kuralını
kurbanın değişikliklerini gizlemek için kullanabilirdi.

## Sağlık uçları

| Uç | Soru |
|---|---|
| `/health/live` | Süreç ayakta mı? Yeniden başlatılmalı mı? |
| `/health/ready` | İstek alabilir mi? Trafiğe açılmalı mı? |
| `/health` | Hangi ortamda çalışıyor? (dağıtım doğrulaması) |

İmajda `HEALTHCHECK` **yok**: `curl`/`wget` kurmak imajı ve saldırı yüzeyini
büyütür. Yoklamayı platform HTTP üzerinden yapar.

## Sözleşme

`/openapi/v1.json` çalışma zamanında yayınlanır. ADR-B03 gereği istemci
client'ı bu belgeden üretilecek; monorepo olduğumuz için üretim ve tüketim
aynı CI koşusunda doğrulanıyor.
