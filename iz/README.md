# İZ

> Hayatında iz bırakanları seç, biriktir ve yaşat.

İZ bir galeri yedekleme uygulaması değil; kullanıcının *"bu an benim için
önemli"* dediği anıları kişi, tarih, konum ve bağlamla birlikte sakladığı
**kişisel hafıza** uygulamasıdır.

Bu depo, `IZ_Gereksinim_Analizi_Raporu.docx` dokümanındaki gereksinimleri
karşılayan Flutter istemcisini içerir.

---

## Hızlı başlangıç

```bash
flutter pub get
dart run build_runner build     # Drift/JSON kodunu üretir
flutter run
```

Mimariyi ve yeni özellik ekleme adımlarını öğrenmek için
**[ARCHITECTURE.md](ARCHITECTURE.md)** dosyasını oku — projeyi anlamanın
en hızlı yolu orasıdır.

---

## Teknoloji seçimleri

| Alan | Seçim | Neden |
|---|---|---|
| Mimari | MVVM + katmanlı (domain/data/presentation) | Rapor 5 faza yayılıyor; katman sınırları değişimi soğuruyor |
| State & DI | **Riverpod 3** (`Notifier` / `StreamNotifier`) | ViewModel'ler test edilebilir; ayrı DI kütüphanesi gerekmiyor |
| Yerel veritabanı | **Drift** (SQLite) | 4 adet N-N ilişki, FTS5 offline arama, versiyonlu migration |
| Navigasyon | **go_router** (`StatefulShellRoute`) | Sekme geçmişleri korunur, deep link hazır |
| Çeviri | `flutter_localizations` + ARB | Türkçe (varsayılan) + İngilizce |

> **freezed kullanılmıyor:** Drift zaten immutable data class + `copyWith`
> üretiyor, domain tarafında Dart 3'ün `sealed class` + pattern matching'i
> yeterli. Bir bağımlılık ve bir codegen adımı eksik.

---

## Şu an çalışan özellikler

- ✅ Onboarding (FR-001/004) — local-first yaklaşımı dürüstçe anlatan 3 adım
- ✅ Anı oluşturma / düzenleme / favori / arşiv / çöp kutusu (FR-010..020)
- ✅ Aylara gruplanmış timeline
- ✅ Offline tam metin arama — FTS5, Türkçe aksan duyarsız (FR-090/092)
- ✅ Filtreleme: kişi, kategori, koleksiyon, ritüel, tarih, favori (FR-091)
- ✅ Bugünün İzi sorgusu (FR-080)
- ✅ Free/İZ+ entitlement matrisi ve foto limiti (FR-130, FR-041)
- ✅ Ayarlar: tema, dil, bildirim tercihi + yedekleme durumu uyarısı (R-001)
- ✅ Açık/koyu tema, dinamik yazı boyutu, erişilebilirlik etiketleri

İskeleti hazır, içi doldurulacak alanlar için ARCHITECTURE.md → Bölüm 10.

---

## Proje yapısı

```
lib/
├── main.dart                 → bootstrap'ı çağırır, başka bir şey yapmaz
├── app/                      → composition root (her şeyi bilir)
│   ├── bootstrap.dart           başlatma zinciri
│   ├── app.dart                 MaterialApp.router
│   ├── database/                AppDatabase — tüm tabloları toplar
│   └── router/                  GoRouter + alt sekme kabuğu
│
├── core/                     → altyapı (HİÇBİR feature'ı bilmez)
│   ├── result/                  Result<T> — başarı veya hata
│   ├── error/                   Failure hiyerarşisi
│   ├── entitlement/             Free/İZ+ özellik matrisi
│   ├── config/                  ortam + faz bayrakları
│   ├── database/                paylaşılan tablo mixin'leri
│   ├── theme/  l10n/  logging/  storage/  extensions/  utils/
│
├── shared/widgets/           → feature'lar arası ortak UI
│
└── features/<feature>/
    ├── data/          tables · daos · mappers · repositories
    ├── domain/        entities · repositories (arayüz) · usecases
    └── presentation/  view_models · views · widgets
```

---

## Testler

```bash
flutter test          # 42 test
flutter analyze       # temiz olmalı
```

| Katman | Dosya | Yaklaşım |
|---|---|---|
| İş kuralları | `test/unit/save_memory_test.dart` | Saf Dart + mocktail |
| SQL / şema | `test/unit/memory_repository_test.dart` | **Gerçek** bellek içi SQLite |
| ViewModel | `test/unit/memory_list_view_model_test.dart` | `ProviderContainer` + override |
| Widget | `test/widget/memory_card_test.dart` | `wrapWidget` yardımcısı |
| Uçtan uca | `test/widget/app_smoke_test.dart` | Uygulamayı gerçekten açar ve gezinir |

Testler gereksinim kimliklerine göre adlandırılmıştır (`FR-012`, `BR-001` …),
böylece bir gereksinimin karşılandığını doğrudan aratabilirsin.

---

## Ortamlar

```bash
flutter run --dart-define=IZ_ENV=dev      # varsayılan
flutter run --dart-define=IZ_ENV=prod --dart-define=IZ_API=https://api.iz.app
```

Prod'da ayrıntılı log kapanır (NFR-014).

### Emülatörden yerel API'ye bağlanmak

```bash
# 1) API'yi ayağa kaldır (repo kökünde)
docker compose -f api/docker-compose.yml up -d
dotnet run --project api/src/Iz.Api --urls http://0.0.0.0:5163

# 2) Uygulamayı emülatörün gördüğü adrese yönlendir
flutter run --dart-define=IZ_API=http://10.0.2.2:5163
```

`10.0.2.2`, Android emülatöründen ana makinenin (host) `localhost`'una
karşılık gelen özel adrestir; `localhost` yazarsan emülatörün KENDİSİNİ
kastetmiş olursun.

Şifresiz (`http://`) trafik Android 9'dan beri varsayılan olarak engelli.
`android/app/src/debug/res/xml/network_security_config.xml` bu üç yerel
adrese izin verir; dosya `src/debug/` altında olduğu için release
derlemesine girmez, yani mağaza sürümünde şifresiz trafik kapalı kalır.
