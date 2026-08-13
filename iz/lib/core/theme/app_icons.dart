/// KULLANIM:
/// ```dart
/// Icon(AppIcons.favorite)                    // boyut temadan gelir (28)
/// Icon(AppIcons.location, size: AppIconSize.sm)  // istisna gerekiyorsa
/// ```

library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

abstract final class AppIcons {
  // --- Ana gezinme (alt çubuk) ---------------------------------------------
  // Lucide'da dolu/boş ikon çifti yok; seçili sekmeyi RENK belirtiyor
  // (bkz. shared/widgets/iz_bottom_nav.dart).
  static const IconData navHome = LucideIcons.house;
  static const IconData navMyLife = LucideIcons.users;
  static const IconData navStore = LucideIcons.shoppingCart;
  static const IconData navProfile = LucideIcons.user;

  /// Henüz alt çubukta olmayan ama ekranları duran bölümler.
  static const IconData navJournal = LucideIcons.notebookPen;

  // --- Eylemler -------------------------------------------------------------
  static const IconData add = LucideIcons.plus;
  static const IconData addPhoto = LucideIcons.imagePlus;
  static const IconData edit = LucideIcons.squarePen;
  static const IconData delete = LucideIcons.trash2;
  static const IconData share = LucideIcons.share2;

  /// FR-046 kolaj — referanstaki 2×2 kare.
  ///
  /// `layoutGrid` (3 hücreli asimetrik düzen) DEĞİL: kolaj eşit karelerden
  /// oluşuyor ve simge de bunu söylemeli.
  static const IconData collage = LucideIcons.grid2x2;
  static const IconData search = LucideIcons.search;

  /// Liste filtresi — referanstaki ortalanmış, kısalan üç çizgi.
  /// (Lucide `filter` bir huni; tasarımdaki şekil bu değil.)
  static const IconData filter = LucideIcons.listFilter;
  static const IconData clear = LucideIcons.x;
  static const IconData retry = LucideIcons.refreshCw;

  // --- Yön ------------------------------------------------------------------
  static const IconData forward = LucideIcons.chevronRight;
  static const IconData back = LucideIcons.chevronLeft;

  /// Katlanır bölümlerin durumu: aşağı = kapalı, yukarı = açık.
  /// (Koleksiyon kartları bunu kullanıyor.)
  static const IconData expand = LucideIcons.chevronDown;
  static const IconData collapse = LucideIcons.chevronUp;

  /// "Daha fazla" — bir satırın kendi eylemlerini açar.
  /// Üç NOKTA, üç çizgi değil: çizgi menü/filtre demek, nokta eylem demek.
  static const IconData more = LucideIcons.ellipsis;

  /// Seçim işaretleri.
  ///
  /// ÇOK seçimde onay kutusu, TEK seçimde tik kullanıyoruz: kutu
  /// "birkaç tane işaretleyebilirsin" der, tik "şu an bu seçili" der.
  /// Kipi kullanıcıya işaretin biçimiyle anlatıyoruz
  /// (bkz. iz_selection_dialog.dart).
  static const IconData check = LucideIcons.check;
  static const IconData checkboxOn = LucideIcons.squareCheckBig;
  static const IconData checkboxOff = LucideIcons.square;

  /// "Şuna git" — eylem listelerinde detaya gitmeyi anlatır.
  ///
  /// [forward] (chevron-right) BURADA KULLANILMAZ: chevron bir liste satırının
  /// "devamı var" işaretidir, bir EYLEM ikonu değil. Eylem sayfasında baştaki
  /// ikon olarak konduğunda satır tıklanabilir bir liste öğesi gibi okunuyor,
  /// oysa orada zaten her satır bir eylem.
  static const IconData goTo = LucideIcons.arrowUpRight;

  // --- İçerik ---------------------------------------------------------------
  static const IconData memory = LucideIcons.sparkles;
  static const IconData favorite = LucideIcons.heart;

  /// Günlük yazılarını işaretleme.
  ///
  /// [favorite] (kalp) ANILARA ait; yıldız günlüğe. İkisi ayrı çünkü
  /// kullanıcı "beğendiğim anı" ile "sık döndüğüm yazı"yı aynı kovada
  /// istemiyor — ve kullanıcı bu ekran için açıkça "yıldızla" dedi.
  ///
  /// Lucide bir ÇİZGİ seti: dolu yıldız yok. Doluluk kalpteki gibi üç
  /// sinyalle veriliyor — dolu zemin, renk ve ekran okuyucu etiketi.
  static const IconData star = LucideIcons.star;
  static const IconData photo = LucideIcons.image;
  static const IconData photoLibrary = LucideIcons.images;
  static const IconData video = LucideIcons.video;
  static const IconData audio = LucideIcons.mic;
  static const IconData play = LucideIcons.circlePlay;
  static const IconData location = LucideIcons.mapPin;
  static const IconData person = LucideIcons.user;
  static const IconData people = LucideIcons.users;

  /// Referans tasarımda koleksiyon simgesi AÇIK KİTAP. Önce `library`
  /// (kitaplık rafı) kullanılıyordu; kavramı tek bir simgeyle anlatmak için
  /// ana sayfadaki sayaçla anı detayındaki etiketi aynı ikona bağladık.
  static const IconData collection = LucideIcons.bookOpen;

  /// Ana sayfadaki "SERİLER" sayacı — referanstaki dört yapraklı şekil.
  static const IconData series = LucideIcons.clover;

  /// Anı listesi boşken gösterilen simge.
  ///
  /// Ayak izleri: uygulamanın adı "İZ" ve boş liste "henüz iz yok" demek.
  /// Genel bir "kutu boş" simgesi yerine markanın kendi metaforunu
  /// kullanıyoruz.
  static const IconData emptyTrace = LucideIcons.footprints;

  /// Markanın yaprağı — filiz motifinin ikon hâli.
  ///
  /// Uygulamanın çizimlerinde (`iz_wordmark`, boş durum illüstrasyonları) bir
  /// zeytin dalı var; ikon gerektiğinde onun yerine bu geçiyor.
  static const IconData leaf = LucideIcons.leaf;

  static const IconData ritual = LucideIcons.calendarHeart;

  /// Ritüel formundaki satır ikonları (referans tasarım).
  ///
  /// "T" HARFİ bir metin alanını anlatıyor: satırın işi bir isim yazmak.
  /// `edit` (kalem) burada yanlış olurdu — kalem "var olanı değiştir" der.
  static const IconData textField = LucideIcons.type;

  /// Açıklama alanı — kısalan üç çizgi, yani bir paragraf.
  /// `filter` de üç çizgi ama ORTALANMIŞ; ikisi karışmasın.
  static const IconData description = LucideIcons.alignLeft;

  /// Tekrarlama — döngü oku.
  /// `retry` (refreshCw) ile aynı fikir ama farklı iş: biri "yeniden dene",
  /// bu "her yıl yine".
  static const IconData recurrence = LucideIcons.repeat;

  /// Bir şeyi KURAN düğmelerin parıltısı ("Ritüeli Oluştur").
  ///
  /// TEKİL `sparkle`, [memory]'nin çoğul `sparkles`ı DEĞİL: bu uygulamada
  /// çoğul parıltı "anı" demek ve bir eylem düğmesinde onu kullanmak ikonu
  /// iki anlama bölerdi.
  static const IconData celebrate = LucideIcons.sparkle;
  static const IconData date = LucideIcons.calendar;

  // --- Durumlar -------------------------------------------------------------
  /// Boş arama sonucu.
  static const IconData searchEmpty = LucideIcons.searchX;

  /// Genel hata ekranı.
  static const IconData error = LucideIcons.circleAlert;

  /// Uyarı (R-001 "yalnız bu cihazda" gibi).
  static const IconData warning = LucideIcons.triangleAlert;

  /// BR-007 — galerideki orijinal medya kayıp.
  static const IconData mediaMissing = LucideIcons.imageOff;

  /// Rota bulunamadı.
  static const IconData routeNotFound = LucideIcons.compass;

  // --- Kimlik doğrulama -----------------------------------------------------
  static const IconData email = LucideIcons.mail;
  static const IconData password = LucideIcons.lockKeyhole;

  /// Şifre görünürlüğü: `eye` = "göster", `eyeOff` = "gizle".
  static const IconData passwordShow = LucideIcons.eye;
  static const IconData passwordHide = LucideIcons.eyeOff;

  /// Gizlilik güvencesi (giriş ekranı alt notu).
  static const IconData secure = LucideIcons.lock;

  // --- Ana sayfa ------------------------------------------------------------
  /// Ana sayfanın üst şeridindeki bildirim zili.
  static const IconData notifications = LucideIcons.bell;

  // --- Ayarlar ve sistem ----------------------------------------------------
  static const IconData device = LucideIcons.smartphone;
  static const IconData privacy = LucideIcons.shieldCheck;
  static const IconData storage = LucideIcons.hardDrive;
  static const IconData cloud = LucideIcons.cloud;

  // --- Onboarding -----------------------------------------------------------
  static const IconData onboardingContext = LucideIcons.workflow;

  /// Kategori ve ritüel ikonları veritabanında **anahtar** olarak saklanır
  /// (`iconKey`), çünkü ikon seti değişse bile kullanıcının verisi bozulmamalı.
  /// Anahtarı çizime bu tablo çevirir.
  ///
  /// Bilinmeyen anahtar gelirse [fallbackCategory] döner — eski bir sürümden
  /// gelen veri uygulamayı çökertmesin.
  static const Map<String, IconData> byKey = {
    // FR-070 varsayılan kategoriler
    'travel': LucideIcons.plane,
    'family': LucideIcons.usersRound,
    'heart': LucideIcons.heart,
    'celebration': LucideIcons.partyPopper,
    'school': LucideIcons.graduationCap,
    'work': LucideIcons.briefcase,
    'home': LucideIcons.house,
    'daily': LucideIcons.sunrise,
    // Ritüeller
    'ritual': LucideIcons.calendarHeart,
    'birthday': LucideIcons.cake,
    'anniversary': LucideIcons.heart,
    // Tarihi kayan (seasonal) ritüeller: yaz tatili, kamp.
    'summer': LucideIcons.sun,
    'winter': LucideIcons.snowflake,
  };

  static const IconData fallbackCategory = LucideIcons.tag;

  /// `iconKey` → ikon. Bilinmeyen anahtarda çökmez.
  static IconData forKey(String? key) => byKey[key] ?? fallbackCategory;
}
