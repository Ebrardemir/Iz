# İZ

> Hayatında iz bırakanları seç, biriktir ve yaşat.

İZ bir galeri yedekleme uygulaması değil; kullanıcının *"bu an benim için önemli"*
dediği anıları kişi, tarih, konum ve bağlamla birlikte sakladığı **kişisel hafıza**
uygulamasıdır.

---

## Depo yapısı

```
Iz/
├── iz/                            Flutter istemcisi
├── api/                           ASP.NET Core 9 sunucusu
├── contracts/                     OpenAPI sözleşmesi (api CI'ında üretilecek)
├── .github/workflows/ci.yml       tek CI, yol filtresiyle ayrışır
│
├── BACKEND_YOL_HARITASI.md        sunucu kararları, sync protokolü, fazlar
├── TEKNIK_GEREKSINIM_DOKUMANI.md  14 modül, 190+ numaralı gereksinim
└── iz/ARCHITECTURE.md             istemci katman kuralları
```

Backend ayrı repoda değil (ADR-B02). Gerekçe: OpenAPI sözleşmesi ve onu tüketen
istemci kodu **aynı commit'te** değişebiliyor.

## Çalıştırma

**İlk kurulumda bir kez** — fvm yoksa istemci derlenmez:

```bash
dart pub global activate fvm
cd iz && fvm install        # .fvmrc'deki sürümü indirir (3.47.1)
```

```bash
# İstemci
cd iz && fvm flutter pub get && fvm flutter run

# Sunucu
cd api && docker compose up --build
curl http://localhost:8080/health
```

Flutter sürümü `iz/.fvmrc` ile **3.47.1**'e sabit. CI aynı sürümü kullanıyor;
değiştirirsen ikisini birden güncelle.

> ⚠️ **`fvm` önekini atlama.** Düz `flutter pub get` makinendeki genel sürümle
> koşar ve o sürüm 3.47.1 değilse bağımlılıklar **çözülmez.** Aldığın hata
> yanıltıcıdır: `pub`, sorunu paketlerde sanıp `drift_dev`'i düşürmeni önerir.
> Gerçek sebep Flutter'ın `test_api`'yi çivilediği sürümdür — 3.44 onu 0.7.11'e,
> 3.47 ise 0.7.12'ye çiviler; `drift_dev 2.34.5`'in ihtiyaç duyduğu
> analyzer 13 yalnız ikincisinde çözülebiliyor. Paketleri düşürmek sorunu
> çözmez, yerelini CI'dan ayırır.
>
> VS Code için `iz/.vscode/settings.json` aynı sürümü editöre de gösteriyor.

## Hangi belge ne için

| Belge | Sorusu |
|---|---|
| `IZ_Gereksinim_Analizi_Raporu.docx` | **Ne** yapılacak (FR/NFR, ürün stratejisi) |
| `TEKNIK_GEREKSINIM_DOKUMANI.md` | **Nasıl** yapılacak (modül modül, kabul kriterleriyle) |
| `BACKEND_YOL_HARITASI.md` | Sunucu tarafı: kararlar, protokol, fazlar |
| `iz/ARCHITECTURE.md` | İstemci katman kuralları ve yeni feature reçetesi |

---

## Durum — 26 Ağustos 2026

### İstemci (`iz/`)

| | |
|---|---|
| Kod | ~34k satır, `flutter analyze` **temiz** |
| Test | **912 test**, hepsi geçiyor |
| Veritabanı | Drift, **şema v5**, 8 indeks, migration testi var |

**Uyarı — en önemli devir notu:** 20 ekranın yalnız **4'ü** gerçek veritabanına
bağlı. Geri kalanı `lib/` içindeki **1.250 satır önizleme verisiyle** çalışıyor ve
`app_router.dart` bile buna bağımlı. Veri katmanını yazmak, önizleme verisini
sökmekle başlıyor. Ayrıntı: TRD → **Ek D / TR-D-02**.

### Sunucu (`api/`)

Faz 0 tamamlandı: solution iskeleti, Docker, sağlık uçları, ProblemDetails,
OpenAPI, 5 entegrasyon testi. Henüz iş mantığı yok.

⚠️ **Docker imajı hiç derlenmedi** (geliştirme makinesinde daemon kapalıydı).
İlk `docker compose up --build` gözle doğrulanmalı.

### CI

Yazıldı ama **hiç koşmadı** — workflow yalnız PR'da ve `tasarim`/`main`'e push'ta
tetikleniyor. İlk PR'da gerçekten yeşil yandığı görülmeli.

---

## Sıradaki işler

1. **PR aç, CI'ı doğrula.** Workflow hiç koşmadı; ilk çalışmasını görmeden
   üzerine iş yığmayalım.
2. **Docker imajını doğrula** — `cd api && docker compose up --build`.
3. **TR-D-01 · `store` sekmesi** — 🔴 yayın engeli. `ComingSoonView` yer tutucusu
   App Store Guideline 2.1'e takılır. Önerilen: sekmeyi İZ+ tanıtım ekranına
   dönüştürmek.
4. **TR-D-02 · önizleme verisini gerçek veriyle değiştir** — router'dan başla,
   yükü en çok taşıyan yer orası.
5. **Faz 1 · Kimlik** — Firebase ID token doğrulama, `users` tablosu, EF Core.

Tam liste ve öncelikler: TRD → **Ek D — Teknik borç kaydı**.

## Karara bağlanmamışlar

**Barındırma sağlayıcısı.** Sunucu Türkiye'de olacak (ADR-B11) ama nerede belli
değil. Dikkat: **GCP'nin Türkiye bölgesi 2028-2029'da** açılacak, AWS'in
İstanbul'da yalnız bir *Local Zone*'u var. GCP'ye deploy etmek ADR-B11'i ihlal
eder. Kod barındırmadan bağımsız yazıldı — yapılandırma tamamen ortam
değişkeninden, uygulama durumsuz.

**Altı ürün kararı** — TRD → **Ek C**: fotoğraf limiti A/B'si, sesli anı
tadımlığı, İZ+ fiyatı, ritüel arayüzü, kategori/koleksiyon anlatımı, ilk pazar.

---

## Değişmeyen kararlar

Bunlar bir sürüme ait değil, ürünün duruşu:

- **Anı çekirdektir**, fotoğraf yalnızca medyadır
- **Yerel veri doğruluk kaynağıdır**, bulut bir aynadır
- **Tüm galeriye erişim izni istenmez** — sistem seçicisi kullanılır
- **Arama cihazdan çıkmaz** — sorgunun kendisi hassas veridir
- **Kategori sayısı paywall değildir** — ücret maliyet üretene bağlanır
- **Free planda bulut ve paylaşım yoktur**, her şey cihazda kalır
- **Herkese açık sosyal ağ yapılmaz**
- **Abonelik bitince anılar silinmez**
- **Analitiğe kullanıcı içeriği gönderilmez**
