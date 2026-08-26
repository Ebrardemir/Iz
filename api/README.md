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
dotnet run --project src/Iz.Api
dotnet test
```

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
