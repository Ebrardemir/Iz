# Görsel varlıklar — kaynak, lisans ve değiştirme rehberi

Bu dosya `assets/images/` altındaki görsellerin NEREDEN geldiğini ve
değiştirirken nelere dikkat edilmesi gerektiğini anlatır.

Dosyanın kendisi bilerek `assets/` DIŞINDA duruyor: `pubspec.yaml`'da asset
klasörlerinin tamamı paketlendiği için, oraya konan her dosya — okunmayacak
bir belge bile — uygulamanın içine gömülürdü.

---

## Giriş / kayıt ekranı — `assets/images/auth/`

> ⚠️ **Bunlar GEÇİCİ yer tutucudur.** Kendi görsellerinle değiştirebilirsin —
> dosya adlarını koru, kod değişmez.

| Dosya | Kullanıldığı yer | Kaynak | Fotoğrafçı |
|---|---|---|---|
| `hero_light.jpg` | Açık tema | Unsplash | sarandy westfall |
| `hero_dark.jpg` | Koyu tema | Unsplash | Annie Spratt |

**Lisans:** Unsplash License — ticari/ticari olmayan kullanım serbest,
atıf zorunlu değil, izin gerekmez. <https://unsplash.com/license>

### Değiştirirken nelere dikkat et

Görsel `BoxFit.cover` ile ekranın üst şeridine sığdırılır ve **altına kart
biner**. Bu yüzden:

- **Yatay (landscape) oran** iyi durur; ~3:2 civarı ideal.
- Görselin **alt üçte biri kartın altında kalır** — ana özneyi oraya koyma.
- **Açık tema** görseli aydınlık, **koyu tema** görseli karanlık olmalı.
  Tek görsel iki temada da kullanılırsa biri mutlaka zeminden kopuyor —
  ilk denemede tam olarak bu oldu.

---

## Ana sayfa — `assets/images/home/`

> ⚠️ **GEÇİCİ yer tutucu.** Gerçekte burada kullanıcının "Bugünün İzi"
> anısının kapak fotoğrafı görünecek; bu dosya yalnızca tasarım aşaması için.

| Dosya | Kaynak | Fotoğrafçı |
|---|---|---|
| `hero_today.jpg` | [Unsplash](https://unsplash.com/photos/K0J25JjBd8U) | [Kevin Charit](https://unsplash.com/@kevin_charit) |
| `memory_coffee.jpg` | Proje sahibi tarafından verildi | — |

`memory_coffee.jpg`, "SON ANILAR" listesindeki örnek kartın kapağı.
Orijinal 2136×3200; fincanı merkeze alan kare kırpma sonrası **256×256**
olarak eklendi (~11 KB). Küçük resim ekranda 64 pt, yani 3× yoğunlukta 192
px yeter. ⚠️ Kaynağı proje sahibi verdi; kullanım hakkı onun sorumluluğunda.

Listedeki öteki iki kart YER TUTUCU: `hero_today.jpg` ve
`auth/hero_light.jpg` ödünç kullanılıyor. Gerçek görseller geldiğinde
`HomeView._sampleMemories` içindeki yolları değiştirmek yeterli.

**Lisans:** Unsplash License — ticari kullanım serbest, atıf zorunlu değil.

Orijinal 1600×2400; depoya **1200×1800**, kalite 88, progressive JPEG olarak
girdi (~247 KB). 390 pt genişlikteki alan için 3× yoğunlukta bile fazlasıyla
yeterli, orijinali koymanın anlamı yok.

### Değiştirirken nelere dikkat et

- **Dikey (portrait) görsel sorun değil.** Hero şeridi `BoxFit.cover` ile
  ortadan yatay bir bant kırpar; dikey bir karede öznenin dikey ortada
  olması yeter. Bu dosyada tam öyle: silüet ve tekne kırpılan bantta kalıyor.
- Görselin **alt kısmı kavisli panelin altında kalır** — ana özneyi oraya
  koyma. Kavis SİMETRİK DEĞİL: sağ tarafta daha çok yer kapatır
  (bkz. `lib/shared/widgets/curved_top_panel.dart`).
- Sol alt bölge, üzerine gelecek yazıların (BUGÜNÜN İZİ / başlık / tarih)
  yeri — orayı sakin bırak.

---

## Yeni bir görsel klasörü eklerken

1. Dosyaları `assets/images/<klasör>/` altına koy.
2. `pubspec.yaml` → `flutter: assets:` listesine klasörü ekle.
3. Kaynak/lisans bilgisini **buraya** yaz, klasörün içine değil.
4. `flutter run`'ı TAMAMEN kapatıp yeniden başlat — yeni asset klasörleri
   hot reload/hot restart ile paketlenmez.
