import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Uygulama adı
  ///
  /// In tr, this message translates to:
  /// **'İZ'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In tr, this message translates to:
  /// **'Hayatında iz bırakanları seç, biriktir ve yaşat'**
  String get appTagline;

  /// No description provided for @commonCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get commonEdit;

  /// No description provided for @commonRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get commonClose;

  /// No description provided for @commonDone.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get commonDone;

  /// No description provided for @commonShare.
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get commonShare;

  /// No description provided for @commonSearch.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get commonSearch;

  /// No description provided for @commonSeeAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü Gör'**
  String get commonSeeAll;

  /// No description provided for @commonAdd.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get commonAdd;

  /// No description provided for @commonNext.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get commonNext;

  /// No description provided for @commonSkip.
  ///
  /// In tr, this message translates to:
  /// **'Atla'**
  String get commonSkip;

  /// NFR-032: yükleme göstergesinin ekran okuyucu etiketi
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor'**
  String get commonLoading;

  /// Giriş ekranı ana başlığı
  ///
  /// In tr, this message translates to:
  /// **'Tekrar hoş geldin'**
  String get authWelcomeBack;

  /// No description provided for @authWelcomeSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Değerli anılarına kaldığın yerden devam et.'**
  String get authWelcomeSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get authPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifremi unuttum'**
  String get authForgotPassword;

  /// No description provided for @authSignIn.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get authSignIn;

  /// No description provided for @authCreateAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Oluştur'**
  String get authCreateAccount;

  /// No description provided for @authOr.
  ///
  /// In tr, this message translates to:
  /// **'veya'**
  String get authOr;

  /// No description provided for @authSignInWithApple.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile Giriş Yap'**
  String get authSignInWithApple;

  /// No description provided for @authSignInWithGoogle.
  ///
  /// In tr, this message translates to:
  /// **'Google ile Giriş Yap'**
  String get authSignInWithGoogle;

  /// R-002 gizlilik endişesinin azaltımı — giriş ekranı alt notu
  ///
  /// In tr, this message translates to:
  /// **'Verilerin güvende. Gizliliğine saygı duyuyoruz.'**
  String get authPrivacyNote;

  /// No description provided for @authShowPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi göster'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi gizle'**
  String get authHidePassword;

  /// NFR-032 — dekoratif görselin ekran okuyucu açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Anılardan oluşan bir fotoğraf kolajı'**
  String get authHeroSemantics;

  /// No description provided for @authResetLinkSent.
  ///
  /// In tr, this message translates to:
  /// **'Şifre sıfırlama bağlantısı gönderildi.'**
  String get authResetLinkSent;

  /// No description provided for @authResetNeedsEmail.
  ///
  /// In tr, this message translates to:
  /// **'Önce e-posta adresini gir.'**
  String get authResetNeedsEmail;

  /// No description provided for @authFullName.
  ///
  /// In tr, this message translates to:
  /// **'Ad Soyad'**
  String get authFullName;

  /// No description provided for @authPasswordAgain.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi tekrar gir'**
  String get authPasswordAgain;

  /// No description provided for @authSignUp.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt Ol'**
  String get authSignUp;

  /// No description provided for @authContinueWithApple.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile Devam Et'**
  String get authContinueWithApple;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In tr, this message translates to:
  /// **'Google ile Devam Et'**
  String get authContinueWithGoogle;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabın var mı?'**
  String get authAlreadyHaveAccount;

  /// No description provided for @navHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get navHome;

  /// No description provided for @navMyLife.
  ///
  /// In tr, this message translates to:
  /// **'Hayatım'**
  String get navMyLife;

  /// Alt çubuğun ortasındaki yükseltilmiş eylem — yeni anı
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get navAdd;

  /// No description provided for @navStore.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza'**
  String get navStore;

  /// No description provided for @navProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profilim'**
  String get navProfile;

  /// No description provided for @myLifePreviousMonth.
  ///
  /// In tr, this message translates to:
  /// **'Önceki ay'**
  String get myLifePreviousMonth;

  /// No description provided for @myLifeNextMonth.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki ay'**
  String get myLifeNextMonth;

  /// Hayatim ekraninin sekmeleri. BUYUK HARFLE yazili: Dart toUpperCase() dile duyarsizdir, Turkce i harfini I yapar.
  ///
  /// In tr, this message translates to:
  /// **'TAKVİM'**
  String get myLifeTabCalendar;

  /// No description provided for @myLifeTabCollections.
  ///
  /// In tr, this message translates to:
  /// **'KOLEKSİYONLAR'**
  String get myLifeTabCollections;

  /// No description provided for @myLifeTabSeries.
  ///
  /// In tr, this message translates to:
  /// **'SERİLERİM'**
  String get myLifeTabSeries;

  /// Hayatim ekraninin basligi. BUYUK HARFLE yazili: Dart toUpperCase() dile duyarsizdir.
  ///
  /// In tr, this message translates to:
  /// **'HAYATIM'**
  String get myLifeTitle;

  /// Takvimde anısı olmayan bir gün seçildiğinde. NFR-035: boş durum kullanıcıya ne yapacağını anlatmalı
  ///
  /// In tr, this message translates to:
  /// **'Bu güne henüz iz düşmedi'**
  String get myLifeDayEmptyTitle;

  /// Boş günün eylemi — yeni anı ekranını açar
  ///
  /// In tr, this message translates to:
  /// **'Bu güne bir iz bırak'**
  String get myLifeDayEmptyAction;

  /// KOLEKSİYONLAR sekmesi boşken. NFR-035
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir koleksiyon yok'**
  String get collectionsEmptyTitle;

  /// No description provided for @collectionsEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bir seyahati, bir dönemi ya da bir kişiyi anlatan anıları tek bir koleksiyonda topla.'**
  String get collectionsEmptyMessage;

  /// Kapalı koleksiyon kartının ekran okuyucu etiketi
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyonu aç'**
  String get collectionExpand;

  /// Koleksiyon oluşturma ekranının başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Koleksiyon'**
  String get collectionNewTitle;

  /// No description provided for @collectionFieldName.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyon Adı'**
  String get collectionFieldName;

  /// No description provided for @collectionFieldNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyon adı gir'**
  String get collectionFieldNameHint;

  /// No description provided for @collectionFieldDescription.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get collectionFieldDescription;

  /// No description provided for @collectionFieldDescriptionHint.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyonunu kısaca açıkla'**
  String get collectionFieldDescriptionHint;

  /// No description provided for @collectionFieldDateRange.
  ///
  /// In tr, this message translates to:
  /// **'Tarih Aralığı'**
  String get collectionFieldDateRange;

  /// No description provided for @collectionFieldDateRangeHint.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç – Bitiş'**
  String get collectionFieldDateRangeHint;

  /// No description provided for @collectionFieldPeople.
  ///
  /// In tr, this message translates to:
  /// **'İlgili Kişiler'**
  String get collectionFieldPeople;

  /// No description provided for @collectionFieldPeopleHint.
  ///
  /// In tr, this message translates to:
  /// **'Kişi ekle'**
  String get collectionFieldPeopleHint;

  /// No description provided for @collectionFieldCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get collectionFieldCategory;

  /// No description provided for @collectionFieldCategoryHint.
  ///
  /// In tr, this message translates to:
  /// **'Kategori seç'**
  String get collectionFieldCategoryHint;

  /// No description provided for @collectionFieldMemories.
  ///
  /// In tr, this message translates to:
  /// **'İlk Anıları Ekle'**
  String get collectionFieldMemories;

  /// No description provided for @collectionFieldMemoriesHint.
  ///
  /// In tr, this message translates to:
  /// **'Anı seçerek başla'**
  String get collectionFieldMemoriesHint;

  /// Koleksiyon formunda seçilen anı sayısı.
  ///
  /// In tr, this message translates to:
  /// **'{count} anı seçildi'**
  String collectionSelectedMemories(int count);

  /// No description provided for @collectionCreateAction.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyonu Oluştur'**
  String get collectionCreateAction;

  /// FR-074 — koleksiyon adı zorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Bir isim yazmadan oluşturamayız.'**
  String get collectionNameRequired;

  /// No description provided for @collectionCreated.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyonun oluştu, Hayatım’da seni bekliyor.'**
  String get collectionCreated;

  /// No description provided for @collectionCollapse.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyonu kapat'**
  String get collectionCollapse;

  /// Koleksiyon başlığının altındaki sayı. `memoryCount` ile aynı metin ama AYRI anahtar: koleksiyon satırında ileride 'anı' yerine 'öğe' demek gerekebilir ve o gün ötekini bozmadan değiştirilebilsin.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =0{Anı yok} =1{1 anı} other{{count} anı}}'**
  String collectionMemoryCount(int count);

  /// Alt çubuktaki Ekle düğmesinin açtığı halka menünün ekran okuyucu başlığı. Ekranda YAZILI DEĞİL — tasarımda başlık yok, seçenekler kendini anlatıyor.
  ///
  /// In tr, this message translates to:
  /// **'Ne eklemek istersin?'**
  String get addMenuTitle;

  /// No description provided for @addMenuMemory.
  ///
  /// In tr, this message translates to:
  /// **'Anı'**
  String get addMenuMemory;

  /// Tekrarlanan olay (domain'de Ritual). ARAYÜZDE HER YERDE 'seri' DENİR — SERİLERİM sekmesiyle aynı kelime. Entity adı ile arayüz kelimesinin ayrı olması bilinçli: kod 'ritual', kullanıcı 'seri' görüyor.
  ///
  /// In tr, this message translates to:
  /// **'Seri'**
  String get addMenuSeries;

  /// No description provided for @addMenuJournal.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Kaydı'**
  String get addMenuJournal;

  /// No description provided for @addMenuCollection.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyon'**
  String get addMenuCollection;

  /// No description provided for @addMenuPerson.
  ///
  /// In tr, this message translates to:
  /// **'Kişi'**
  String get addMenuPerson;

  /// SERİLERİM sekmesi boşken. NFR-035
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir seri yok'**
  String get seriesEmptyTitle;

  /// No description provided for @seriesEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Her yıl tekrarlanan şeyleri bir seriye bağla; yılları yan yana görürsün.'**
  String get seriesEmptyMessage;

  /// NEDEN 12 DAL VAR? Türkçede bulunma hâli eki aya göre değişiyor: Mart'TA, Nisan'DA, Eylül'DE. Ünlü ve ünsüz uyumuna bağlı olduğu için tek bir kalıpla ('Her yıl {day} {ay}'ta') üretilemez — bir DİL kuralı, bu yüzden yeri çeviri dosyası. SADELEŞTİRME: bir dilin böyle bir kuralı yoksa yalnızca `other` dalını yazmak yeterli.
  ///
  /// In tr, this message translates to:
  /// **'{month, select, 1{Her yıl {day} Ocak\'ta} 2{Her yıl {day} Şubat\'ta} 3{Her yıl {day} Mart\'ta} 4{Her yıl {day} Nisan\'da} 5{Her yıl {day} Mayıs\'ta} 6{Her yıl {day} Haziran\'da} 7{Her yıl {day} Temmuz\'da} 8{Her yıl {day} Ağustos\'ta} 9{Her yıl {day} Eylül\'de} 10{Her yıl {day} Ekim\'de} 11{Her yıl {day} Kasım\'da} 12{Her yıl {day} Aralık\'ta} other{Her yıl}}'**
  String ritualEveryYearOn(String month, int day);

  /// Tarihi kayan ritüeller (yaz tatili, kamp). Mevsim, ritüelin anchorMonth'undan türetiliyor.
  ///
  /// In tr, this message translates to:
  /// **'{season, select, spring{Her yıl ilkbaharda} summer{Her yıl yaz aylarında} autumn{Her yıl sonbaharda} winter{Her yıl kış aylarında} other{Her yıl}}'**
  String ritualEveryYearInSeason(String season);

  /// Kullanıcının elle bağladığı ritüeller (RecurrenceType.custom)
  ///
  /// In tr, this message translates to:
  /// **'Belirli bir tarihi yok'**
  String get ritualCustomSchedule;

  /// No description provided for @ritualEveryMonth.
  ///
  /// In tr, this message translates to:
  /// **'Her ay'**
  String get ritualEveryMonth;

  /// No description provided for @ritualEveryWeek.
  ///
  /// In tr, this message translates to:
  /// **'Her hafta'**
  String get ritualEveryWeek;

  /// Seri oluşturma ekranının başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Seri'**
  String get ritualNewTitle;

  /// No description provided for @coverAdd.
  ///
  /// In tr, this message translates to:
  /// **'Kapak Görseli Ekle'**
  String get coverAdd;

  /// No description provided for @coverChange.
  ///
  /// In tr, this message translates to:
  /// **'Kapak Görselini Değiştir'**
  String get coverChange;

  /// NFR-032 — kapak alanındaki çizimin ekran okuyucu açıklaması.
  ///
  /// In tr, this message translates to:
  /// **'Dağlar, güneş ve bir zeytin dalı çizimi'**
  String get coverIllustrationSemantics;

  /// No description provided for @ritualFieldName.
  ///
  /// In tr, this message translates to:
  /// **'Seri Adı'**
  String get ritualFieldName;

  /// No description provided for @ritualFieldNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Serine bir isim ver'**
  String get ritualFieldNameHint;

  /// No description provided for @ritualFieldDescription.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get ritualFieldDescription;

  /// No description provided for @ritualFieldDescriptionHint.
  ///
  /// In tr, this message translates to:
  /// **'Bu seriyle ilgili kısa bir açıklama yaz'**
  String get ritualFieldDescriptionHint;

  /// No description provided for @ritualFieldRecurrence.
  ///
  /// In tr, this message translates to:
  /// **'Tekrarlama'**
  String get ritualFieldRecurrence;

  /// No description provided for @ritualFieldPeople.
  ///
  /// In tr, this message translates to:
  /// **'İlgili Kişiler'**
  String get ritualFieldPeople;

  /// No description provided for @ritualFieldPeopleHint.
  ///
  /// In tr, this message translates to:
  /// **'Kişi ekle'**
  String get ritualFieldPeopleHint;

  /// No description provided for @ritualFieldCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get ritualFieldCategory;

  /// No description provided for @ritualFieldCategoryHint.
  ///
  /// In tr, this message translates to:
  /// **'Kategori seç'**
  String get ritualFieldCategoryHint;

  /// No description provided for @ritualFieldMemories.
  ///
  /// In tr, this message translates to:
  /// **'Bu Yıla Anı Ekle'**
  String get ritualFieldMemories;

  /// No description provided for @ritualFieldMemoriesHint.
  ///
  /// In tr, this message translates to:
  /// **'Seriye anı bağla'**
  String get ritualFieldMemoriesHint;

  /// Seri formunda seçilen anı sayısı.
  ///
  /// In tr, this message translates to:
  /// **'{count} anı seçildi'**
  String ritualSelectedMemories(int count);

  /// Seçilen anılardan TÜRETİLEN tarih aralığı; kullanıcı tarih girmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Tarih aralığı: {range}'**
  String ritualDateRange(String range);

  /// No description provided for @ritualCreateAction.
  ///
  /// In tr, this message translates to:
  /// **'Seriyi Oluştur'**
  String get ritualCreateAction;

  /// FR-075 — seri adı zorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Bir isim yazmadan oluşturamayız.'**
  String get ritualNameRequired;

  /// No description provided for @ritualCreated.
  ///
  /// In tr, this message translates to:
  /// **'Serin oluştu, Serilerim’de seni bekliyor.'**
  String get ritualCreated;

  /// No description provided for @memoryPickerTitle.
  ///
  /// In tr, this message translates to:
  /// **'Anı Seç'**
  String get memoryPickerTitle;

  /// BR — bir anı tek seriye bağlanır; liste yalnızca bağsız anıları gösterir.
  ///
  /// In tr, this message translates to:
  /// **'Bağlanabilecek anı kalmamış. Bir anı yalnızca tek bir seriye bağlanabilir.'**
  String get memoryPickerEmpty;

  /// No description provided for @memoryPickerDone.
  ///
  /// In tr, this message translates to:
  /// **'Bitti'**
  String get memoryPickerDone;

  /// Seri detayındaki ilk kutu.
  ///
  /// In tr, this message translates to:
  /// **'{count} yıl'**
  String ritualStatYears(int count);

  /// No description provided for @ritualStatYearsLabel.
  ///
  /// In tr, this message translates to:
  /// **'Birlikte'**
  String get ritualStatYearsLabel;

  /// No description provided for @ritualStatMemories.
  ///
  /// In tr, this message translates to:
  /// **'{count} anı'**
  String ritualStatMemories(int count);

  /// No description provided for @ritualStatMemoriesLabel.
  ///
  /// In tr, this message translates to:
  /// **'Toplam'**
  String get ritualStatMemoriesLabel;

  /// No description provided for @ritualStatCities.
  ///
  /// In tr, this message translates to:
  /// **'{count} şehir'**
  String ritualStatCities(int count);

  /// No description provided for @ritualStatCitiesLabel.
  ///
  /// In tr, this message translates to:
  /// **'Keşfedildi'**
  String get ritualStatCitiesLabel;

  /// No description provided for @ritualDetailMemories.
  ///
  /// In tr, this message translates to:
  /// **'Bu Serideki Anılar'**
  String get ritualDetailMemories;

  /// No description provided for @ritualDetailShowAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü Gör'**
  String get ritualDetailShowAll;

  /// No description provided for @ritualDetailShowLess.
  ///
  /// In tr, this message translates to:
  /// **'Daha Az Göster'**
  String get ritualDetailShowLess;

  /// No description provided for @ritualDetailNoMemories.
  ///
  /// In tr, this message translates to:
  /// **'Bu seriye henüz anı bağlamadın. Bağladığın her anı burada yıl yıl birikecek.'**
  String get ritualDetailNoMemories;

  /// AppBar'daki üç noktanın ekran okuyucu etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Seri işlemleri'**
  String get ritualDetailActions;

  /// No description provided for @ritualEditAction.
  ///
  /// In tr, this message translates to:
  /// **'Seriyi Düzenle'**
  String get ritualEditAction;

  /// No description provided for @ritualDeleteAction.
  ///
  /// In tr, this message translates to:
  /// **'Seriyi Sil'**
  String get ritualDeleteAction;

  /// No description provided for @ritualDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Seri silinsin mi?'**
  String get ritualDeleteTitle;

  /// Kişi silmedeki söz veriyle aynı: bir kabı silmek içindekini silmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Bu seri silinecek. İçindeki anılar silinmez, yalnızca serideki bağlantıları kopar.'**
  String get ritualDeleteMessage;

  /// No description provided for @ritualRecurrenceSectionSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Tekrarlama seçenekleri'**
  String get ritualRecurrenceSectionSemantics;

  /// Seri kartının ekran okuyucu özeti — kaç yılın anısı var
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =0{Yıl yok} =1{1 yıl} other{{count} yıl}}'**
  String ritualYearCount(int count);

  /// Anı satırındaki üç nokta düğmesinin ipucu
  ///
  /// In tr, this message translates to:
  /// **'Anı işlemleri'**
  String get memoryMoreActions;

  /// No description provided for @memoryOpenDetail.
  ///
  /// In tr, this message translates to:
  /// **'Anıya git'**
  String get memoryOpenDetail;

  /// No description provided for @commonFilter.
  ///
  /// In tr, this message translates to:
  /// **'Filtrele'**
  String get commonFilter;

  /// Fotograf uzerindeki kucuk ust baslik. BUYUK HARFLE YAZILI: Dart'in toUpperCase() metodu dile duyarsizdir ve Turkce 'i' harfini 'I' yapar ('BUGUNUN IZI'). Dogru buyuk harf cevirmenin sorumlulugunda.
  ///
  /// In tr, this message translates to:
  /// **'BUGÜNÜN İZİ'**
  String get homeHeroTodayEyebrow;

  /// No description provided for @homeHeroViewMemory.
  ///
  /// In tr, this message translates to:
  /// **'Anıyı Gör'**
  String get homeHeroViewMemory;

  /// No description provided for @homeHeroEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'İlk İzini Bırak'**
  String get homeHeroEmptyTitle;

  /// No description provided for @homeHeroEmptySubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlamak isteyeceğin bir anı seç ve sakla.'**
  String get homeHeroEmptySubtitle;

  /// No description provided for @homeHeroAddMemory.
  ///
  /// In tr, this message translates to:
  /// **'Anı Ekle'**
  String get homeHeroAddMemory;

  /// Bolum basligi. BUYUK HARFLE yazili: Dart toUpperCase() dile duyarsizdir ve Turkce i harfini I yapar.
  ///
  /// In tr, this message translates to:
  /// **'SON ANILAR'**
  String get homeRecentTitle;

  /// No description provided for @homeRecentEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Burada henüz bir iz yok.'**
  String get homeRecentEmptyTitle;

  /// No description provided for @homeRecentEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'İlk anını eklediğinde burada görünmeye başlayacak.'**
  String get homeRecentEmptyMessage;

  /// No description provided for @homeStatJournal.
  ///
  /// In tr, this message translates to:
  /// **'GÜNLÜK'**
  String get homeStatJournal;

  /// Sayacin altindaki birim. Turkcede sayidan sonra cogul eki gelmez, Ingilizcede gelir; bu yuzden cogul yapisi kullaniliyor.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, other{kayıt}}'**
  String homeStatJournalUnit(int count);

  /// No description provided for @homeStatPeople.
  ///
  /// In tr, this message translates to:
  /// **'KİŞİLER'**
  String get homeStatPeople;

  /// Sayacin altindaki birim.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, other{kişi}}'**
  String homeStatPeopleUnit(int count);

  /// No description provided for @homeStatSeries.
  ///
  /// In tr, this message translates to:
  /// **'SERİLER'**
  String get homeStatSeries;

  /// Sayacin altindaki birim.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, other{seri}}'**
  String homeStatSeriesUnit(int count);

  /// No description provided for @homeStatCollections.
  ///
  /// In tr, this message translates to:
  /// **'KOLEKSİYONLAR'**
  String get homeStatCollections;

  /// Sayacin altindaki birim.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, other{koleksiyon}}'**
  String homeStatCollectionsUnit(int count);

  /// No description provided for @homeNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get homeNotifications;

  /// Henüz tasarlanmamış sekmelerin yer tutucu başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bu ekran yakında'**
  String get screenComingSoon;

  /// No description provided for @screenComingSoonMessage.
  ///
  /// In tr, this message translates to:
  /// **'Tasarımı hazırlanıyor. Çok yakında burada olacak.'**
  String get screenComingSoonMessage;

  /// No description provided for @navJournal.
  ///
  /// In tr, this message translates to:
  /// **'Günlük'**
  String get navJournal;

  /// No description provided for @navPeople.
  ///
  /// In tr, this message translates to:
  /// **'Kişiler'**
  String get navPeople;

  /// No description provided for @navSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get navSettings;

  /// No description provided for @memoriesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Anılarım'**
  String get memoriesTitle;

  /// No description provided for @memoryNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Anı'**
  String get memoryNew;

  /// No description provided for @memoryEdit.
  ///
  /// In tr, this message translates to:
  /// **'Anıyı Düzenle'**
  String get memoryEdit;

  /// No description provided for @memoryFavorite.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere ekle'**
  String get memoryFavorite;

  /// No description provided for @memoryUnfavorite.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerden çıkar'**
  String get memoryUnfavorite;

  /// Anı listesindeki favori filtresi KAPALIYKEN düğmenin ipucu — dokununca ne olacağını söyler
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca favorileri göster'**
  String get memoryFilterFavoritesOff;

  /// Filtre AÇIKKEN ipucu. NFR-031: durumu renkten başka bir kanalla da bildirmek için metin değişiyor
  ///
  /// In tr, this message translates to:
  /// **'Favori filtresini kaldır'**
  String get memoryFilterFavoritesOn;

  /// NFR-035: boş durum ekranı kullanıcıya ne yapacağını anlatmalı
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir iz yok'**
  String get memoryEmptyTitle;

  /// No description provided for @memoryEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Tüm galerini değil, saklamaya değer anlarını biriktir. İlk izini bırakarak başla.'**
  String get memoryEmptyMessage;

  /// No description provided for @memoryEmptyAction.
  ///
  /// In tr, this message translates to:
  /// **'İlk izini bırak'**
  String get memoryEmptyAction;

  /// No description provided for @memoryDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Anı silinsin mi?'**
  String get memoryDeleteTitle;

  /// No description provided for @memoryDeleteMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu anı çöp kutusuna taşınacak. 30 gün içinde geri alabilirsin.'**
  String get memoryDeleteMessage;

  /// No description provided for @memoryDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get memoryDeleteConfirm;

  /// No description provided for @memoryDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Anı çöp kutusuna taşındı'**
  String get memoryDeleted;

  /// No description provided for @memoryRestore.
  ///
  /// In tr, this message translates to:
  /// **'Geri al'**
  String get memoryRestore;

  /// Koleksiyon/kişi kartlarında anı sayısı
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =0{Anı yok} =1{1 anı} other{{count} anı}}'**
  String memoryCount(int count);

  /// FR-080 Bugünün İzi kartı başlığı
  ///
  /// In tr, this message translates to:
  /// **'{years, plural, =0{Bugün} =1{Geçen yıl bugün} other{{years} yıl önce bugün}}'**
  String memoryYearsAgo(int years);

  /// Anı editörü — başlık alanının etiketi
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get memoryFieldTitle;

  /// No description provided for @memoryFieldTitleHint.
  ///
  /// In tr, this message translates to:
  /// **'Bu anı neydi?'**
  String get memoryFieldTitleHint;

  /// No description provided for @memoryFieldNote.
  ///
  /// In tr, this message translates to:
  /// **'Not'**
  String get memoryFieldNote;

  /// No description provided for @memoryFieldNoteHint.
  ///
  /// In tr, this message translates to:
  /// **'Neyi hatırlamak istersin?'**
  String get memoryFieldNoteHint;

  /// No description provided for @memoryFieldDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get memoryFieldDate;

  /// No description provided for @memoryFieldCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get memoryFieldCategory;

  /// No description provided for @memoryFieldCollection.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyon'**
  String get memoryFieldCollection;

  /// Domainde `Ritual`, arayüzde 'seri' — SERİLERİM sekmesiyle aynı kelime.
  ///
  /// In tr, this message translates to:
  /// **'Seri'**
  String get memoryFieldSeries;

  /// No description provided for @memoryFieldLocationHint.
  ///
  /// In tr, this message translates to:
  /// **'Neredeydi?'**
  String get memoryFieldLocationHint;

  /// Henüz seçim yapılmamış satırlarda değerin yerine görünen yer tutucu
  ///
  /// In tr, this message translates to:
  /// **'Seç'**
  String get memoryFieldEmpty;

  /// Yeni anı akışının İKİNCİ adımı. Düzenleme modunda `memoryEdit` kullanılıyor.
  ///
  /// In tr, this message translates to:
  /// **'Detayları Gir'**
  String get memoryDetailsTitle;

  /// Elle yazılan tarih ayrıştırılamadığında. Örnek biçim cihazın diline göre üretiliyor, çeviriye gömülü DEĞİL.
  ///
  /// In tr, this message translates to:
  /// **'Tarihi anlayamadım. Örnek: {example}'**
  String memoryDateInvalid(String example);

  /// FR-013 — geçmişe izin var, geleceğe yok
  ///
  /// In tr, this message translates to:
  /// **'Gelecek bir tarih seçemezsin.'**
  String get memoryDateFuture;

  /// Seçim diyaloğunun en altındaki + satırı
  ///
  /// In tr, this message translates to:
  /// **'Yeni ekle'**
  String get pickerAddNew;

  /// Seçilecek hiçbir kayıt yokken. NFR-035: boş durum ne yapacağını söylemeli
  ///
  /// In tr, this message translates to:
  /// **'Henüz hiç yok. Aşağıdan ekleyebilirsin.'**
  String get pickerEmpty;

  /// No description provided for @memoryPhotos.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraflar'**
  String get memoryPhotos;

  /// No description provided for @memoryNoPhotos.
  ///
  /// In tr, this message translates to:
  /// **'Henüz fotoğraf eklenmedi.'**
  String get memoryNoPhotos;

  /// Anı detay ekranının AppBar başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Anı Detay'**
  String get memoryDetailTitle;

  /// Anı detayındaki eylem: seçili fotoğraflardan kolaj üretir.
  ///
  /// In tr, this message translates to:
  /// **'Kolaj Oluştur'**
  String get memoryActionCollage;

  /// Kapalı nottaki aç/kapa okunun ekran okuyucu etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Notun tamamını göster'**
  String get memoryNoteExpand;

  /// No description provided for @memoryNoteCollapse.
  ///
  /// In tr, this message translates to:
  /// **'Notu kısalt'**
  String get memoryNoteCollapse;

  /// Yeni anı akışının İLK adımındaki başlık. Serif (Cormorant) — markanın duygusal sesi. 'Kare' fotoğraf demek; 'geriye kalmak' ürünün tezini taşıyor (her şeyi değil, kalmaya değeni sakla).
  ///
  /// In tr, this message translates to:
  /// **'Bu anıdan geriye hangi kareler kalsın?'**
  String get memoryPhotosPrompt;

  /// No description provided for @memoryPickFromGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden Fotoğraf Seç'**
  String get memoryPickFromGallery;

  /// FR-041 limiti. SAYI SABİT DEĞİL: kullanıcının planına göre entitlement matrisinden geliyor (Free 3, İZ+ 30). Ücretsiz planda 3 yazacak.
  ///
  /// In tr, this message translates to:
  /// **'En fazla {limit} fotoğraf seçebilirsin.'**
  String memoryPhotoLimitHint(int limit);

  /// NFR-032 — dekoratif illüstrasyonun ekran okuyucu açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf çerçeveleri ve bir dal çizimi'**
  String get memoryPhotosIllustrationSemantics;

  /// Düzenleme ekranlarının kaydet düğmesi (anı ve kişi); yeni kayıtta "Kaydet" yazıyor.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklikleri Kaydet'**
  String get commonSaveChanges;

  /// No description provided for @memoryPhotoRemove.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı kaldır'**
  String get memoryPhotoRemove;

  /// No description provided for @memoryPhotoAdd.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf ekle'**
  String get memoryPhotoAdd;

  /// FR-020 anı detayı — ilişkili kayıt bölüm başlıkları
  ///
  /// In tr, this message translates to:
  /// **'Kişiler'**
  String get relationPeople;

  /// No description provided for @relationCollections.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyonlar'**
  String get relationCollections;

  /// No description provided for @relationRitual.
  ///
  /// In tr, this message translates to:
  /// **'Seri'**
  String get relationRitual;

  /// No description provided for @relationLocation.
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get relationLocation;

  /// FR-041 medya limiti
  ///
  /// In tr, this message translates to:
  /// **'Ücretsiz planda bir anıya en fazla {limit} fotoğraf ekleyebilirsin.'**
  String photoLimitReached(int limit);

  /// No description provided for @todaysTraceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün İzi'**
  String get todaysTraceTitle;

  /// No description provided for @todaysTraceSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş yıllarda bugün yaşadıklarını hatırlat'**
  String get todaysTraceSubtitle;

  /// No description provided for @thenAndNowTitle.
  ///
  /// In tr, this message translates to:
  /// **'O Zaman / Şimdi'**
  String get thenAndNowTitle;

  /// FR-001 onboarding 1/3 — ürünün yedekleme uygulaması olmadığını anlatır
  ///
  /// In tr, this message translates to:
  /// **'Tüm galerini değil,\nizini bırakanları biriktir'**
  String get onboardingCurateTitle;

  /// No description provided for @onboardingCurateBody.
  ///
  /// In tr, this message translates to:
  /// **'İZ bir yedekleme uygulaması değil. Senin için gerçekten anlamlı olan anları seçip anlamlandırdığın bir kişisel hafıza.'**
  String get onboardingCurateBody;

  /// No description provided for @onboardingContextTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bir anı,\nbirçok bağlam'**
  String get onboardingContextTitle;

  /// No description provided for @onboardingContextBody.
  ///
  /// In tr, this message translates to:
  /// **'Aynı anıyı kişilerle, kategorilerle, koleksiyonlarla ve serilerle ilişkilendir. Klasörlerde kaybolmadan yıllar sonra saniyeler içinde bul.'**
  String get onboardingContextBody;

  /// Rapor 20.2: local-only yaklaşımı ve veri kaybı riski dürüstçe anlatılmalı
  ///
  /// In tr, this message translates to:
  /// **'Verilerin\nşimdilik bu cihazda'**
  String get onboardingLocalTitle;

  /// No description provided for @onboardingLocalBody.
  ///
  /// In tr, this message translates to:
  /// **'Anıların telefonunda saklanıyor; kimseyle paylaşılmıyor. Ama telefonunu kaybedersen anıların da kaybolur — bu yüzden düzenli olarak dışa aktarmanı hatırlatacağız.'**
  String get onboardingLocalBody;

  /// No description provided for @onboardingStart.
  ///
  /// In tr, this message translates to:
  /// **'İlk izini bırak'**
  String get onboardingStart;

  /// No description provided for @journalEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bugün neyin izini bırakmak istersin?'**
  String get journalEmptyTitle;

  /// No description provided for @journalEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Kısa bir not yeter. İstersen sonradan kalıcı bir anıya dönüştürürsün.'**
  String get journalEmptyMessage;

  /// Günlük oluşturma ekranının başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Günlük'**
  String get journalNewTitle;

  /// No description provided for @journalGreeting.
  ///
  /// In tr, this message translates to:
  /// **'Merhaba'**
  String get journalGreeting;

  /// FR-032 — günlük davet cümleleri (güne göre değişiyor).
  ///
  /// In tr, this message translates to:
  /// **'Bugün seni ne yordu, ne güldürdü? Birkaç satır bırak; yarın sana iyi gelecek.'**
  String get journalPrompt1;

  /// No description provided for @journalPrompt2.
  ///
  /// In tr, this message translates to:
  /// **'Unutma diye değil, hatırlamak istediğinde bulasın diye yaz.'**
  String get journalPrompt2;

  /// No description provided for @journalPrompt3.
  ///
  /// In tr, this message translates to:
  /// **'Küçük şeyler de yazılır: bir kahve, bir söz, bir bakış. Hepsi bugünün izi.'**
  String get journalPrompt3;

  /// No description provided for @journalPrompt4.
  ///
  /// In tr, this message translates to:
  /// **'Kelimelerin düzgün olmak zorunda değil. Sen anlatsan yeter.'**
  String get journalPrompt4;

  /// No description provided for @journalPrompt5.
  ///
  /// In tr, this message translates to:
  /// **'Bugünden geriye ne kalsın istersin? Onu yaz, gerisini zamana bırak.'**
  String get journalPrompt5;

  /// Ruh hâli ölçeğinin sol ucu — sayı değil, duygu.
  ///
  /// In tr, this message translates to:
  /// **'Zorlu bir gündü'**
  String get journalMoodLow;

  /// No description provided for @journalMoodHigh.
  ///
  /// In tr, this message translates to:
  /// **'Güzel bir gündü'**
  String get journalMoodHigh;

  /// NFR-032 — dekoratif çizimin ekran okuyucu açıklaması.
  ///
  /// In tr, this message translates to:
  /// **'Açık bir defter ve zeytin dalı çizimi'**
  String get journalIllustrationSemantics;

  /// No description provided for @journalMoodQuestion.
  ///
  /// In tr, this message translates to:
  /// **'Bugün kendini nasıl hissediyorsun?'**
  String get journalMoodQuestion;

  /// Kaydırıcının ekran okuyucu etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Bugünkü ruh hâlin: {value}'**
  String journalMoodSemantics(int value);

  /// No description provided for @journalFieldTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get journalFieldTitle;

  /// No description provided for @journalFieldTitleHint.
  ///
  /// In tr, this message translates to:
  /// **'Bugüne bir ad ver'**
  String get journalFieldTitleHint;

  /// No description provided for @journalFieldNotes.
  ///
  /// In tr, this message translates to:
  /// **'Notlarım'**
  String get journalFieldNotes;

  /// No description provided for @journalFieldNotesHint.
  ///
  /// In tr, this message translates to:
  /// **'İçinden geçenleri özgürce yaz…'**
  String get journalFieldNotesHint;

  /// No description provided for @journalPhotosLabel.
  ///
  /// In tr, this message translates to:
  /// **'Bugünden bir kare'**
  String get journalPhotosLabel;

  /// Fotoğraf opsiyonel; sınırı önceden söylüyoruz.
  ///
  /// In tr, this message translates to:
  /// **'İstersen en fazla {count} fotoğraf ekle.'**
  String journalPhotosHint(int count);

  /// No description provided for @journalCreateAction.
  ///
  /// In tr, this message translates to:
  /// **'Kaydı Oluştur'**
  String get journalCreateAction;

  /// FR-030 — günlük metni zorunlu, başlık değil.
  ///
  /// In tr, this message translates to:
  /// **'Birkaç kelime yazmadan kaydedemeyiz.'**
  String get journalNotesRequired;

  /// No description provided for @journalCreated.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün izi kaydedildi.'**
  String get journalCreated;

  /// Günlük ana sayfasındaki karşılama.
  ///
  /// In tr, this message translates to:
  /// **'Hoş geldin'**
  String get journalHeroGreeting;

  /// Profil adı bilindiğinde kullanılan hâli.
  ///
  /// In tr, this message translates to:
  /// **'Hoş geldin, {name}'**
  String journalHeroGreetingNamed(String name);

  /// No description provided for @journalHeroBody.
  ///
  /// In tr, this message translates to:
  /// **'Kendine birkaç satır da olsa bugün eşlik et.'**
  String get journalHeroBody;

  /// No description provided for @journalHeroAction.
  ///
  /// In tr, this message translates to:
  /// **'Yazmaya Başla'**
  String get journalHeroAction;

  /// NFR-032 — kapak fotoğrafının ekran okuyucu açıklaması.
  ///
  /// In tr, this message translates to:
  /// **'Bir masada açık defter, kalem ve kahve çizimi'**
  String get journalHeroSemantics;

  /// No description provided for @journalRecentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Son Yazılarım'**
  String get journalRecentTitle;

  /// No description provided for @journalRecentEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Burası senin sessiz köşen'**
  String get journalRecentEmptyTitle;

  /// No description provided for @journalRecentEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Yazdığın her satır, bir gün dönüp bulacağın bir iz olacak.'**
  String get journalRecentEmptyBody;

  /// NFR-032 — boş durum çiziminin ekran okuyucu açıklaması.
  ///
  /// In tr, this message translates to:
  /// **'Boş bir sayfa, kalem ve filiz çizimi'**
  String get journalEmptyIllustrationSemantics;

  /// No description provided for @journalAllTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm Günlükler'**
  String get journalAllTitle;

  /// No description provided for @journalFilterAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get journalFilterAll;

  /// No description provided for @journalFilterThisWeek.
  ///
  /// In tr, this message translates to:
  /// **'Bu Hafta'**
  String get journalFilterThisWeek;

  /// No description provided for @journalFilterThisMonth.
  ///
  /// In tr, this message translates to:
  /// **'Bu Ay'**
  String get journalFilterThisMonth;

  /// No description provided for @journalFilterFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get journalFilterFavorites;

  /// Süzgece göre değişen boş durum: her biri neyin eksik olduğunu söylüyor.
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta henüz yazmadın. Hafta bitmeden bir satır bırakabilirsin.'**
  String get journalAllEmptyWeek;

  /// No description provided for @journalAllEmptyMonth.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay hiç yazmamışsın. Ay kapanmadan bir gün seç ve yaz.'**
  String get journalAllEmptyMonth;

  /// No description provided for @journalAllEmptyFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Henüz hiçbir yazını yıldızlamadın. Dönüp dönüp okuduğun bir gün varsa onu işaretle.'**
  String get journalAllEmptyFavorites;

  /// No description provided for @journalFavoriteAdd.
  ///
  /// In tr, this message translates to:
  /// **'Yıldızla'**
  String get journalFavoriteAdd;

  /// No description provided for @journalFavoriteRemove.
  ///
  /// In tr, this message translates to:
  /// **'Yıldızı kaldır'**
  String get journalFavoriteRemove;

  /// No description provided for @peopleEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Burası onlarla dolacak.'**
  String get peopleEmptyTitle;

  /// No description provided for @peopleEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Annen, en yakın arkadaşın, belki kedin… Kimi eklersen, onunla yaşadıklarınız tek bir çizgide birikmeye başlar.'**
  String get peopleEmptyMessage;

  /// Kişiler ekranının başlığı; alt çubuktaki kısa ad "Kişiler" (navPeople).
  ///
  /// In tr, this message translates to:
  /// **'Kişilerim'**
  String get peopleTitle;

  /// No description provided for @peopleSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hayatına iz bırakanlar burada yaşar.'**
  String get peopleSubtitle;

  /// No description provided for @peopleEmptyAction.
  ///
  /// In tr, this message translates to:
  /// **'İlk Kişini Ekle'**
  String get peopleEmptyAction;

  /// No description provided for @peopleIllustrationSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Bir kubbenin altında duran üç kişi çizimi'**
  String get peopleIllustrationSemantics;

  /// FR-061 ilişki türlerinin ekranda görünen adları.
  ///
  /// In tr, this message translates to:
  /// **'Kendim'**
  String get relationTypeSelf;

  /// No description provided for @relationTypePartner.
  ///
  /// In tr, this message translates to:
  /// **'Eşim'**
  String get relationTypePartner;

  /// No description provided for @relationTypeParent.
  ///
  /// In tr, this message translates to:
  /// **'Anne / Baba'**
  String get relationTypeParent;

  /// No description provided for @relationTypeChild.
  ///
  /// In tr, this message translates to:
  /// **'Çocuğum'**
  String get relationTypeChild;

  /// No description provided for @relationTypeSibling.
  ///
  /// In tr, this message translates to:
  /// **'Kardeşim'**
  String get relationTypeSibling;

  /// No description provided for @relationTypeGrandparent.
  ///
  /// In tr, this message translates to:
  /// **'Anneanne / Dede'**
  String get relationTypeGrandparent;

  /// No description provided for @relationTypeGrandchild.
  ///
  /// In tr, this message translates to:
  /// **'Torunum'**
  String get relationTypeGrandchild;

  /// No description provided for @relationTypeRelative.
  ///
  /// In tr, this message translates to:
  /// **'Akrabam'**
  String get relationTypeRelative;

  /// No description provided for @relationTypeFriend.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşım'**
  String get relationTypeFriend;

  /// No description provided for @relationTypeColleague.
  ///
  /// In tr, this message translates to:
  /// **'İş arkadaşım'**
  String get relationTypeColleague;

  /// Evcil hayvan. "Hayvanım" değil: uygulama onları da aileden sayıyor.
  ///
  /// In tr, this message translates to:
  /// **'Dostum'**
  String get relationTypePet;

  /// No description provided for @relationTypeOther.
  ///
  /// In tr, this message translates to:
  /// **'Yakınım'**
  String get relationTypeOther;

  /// No description provided for @peopleAddAction.
  ///
  /// In tr, this message translates to:
  /// **'Kişi Ekle'**
  String get peopleAddAction;

  /// No description provided for @peopleSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Kişilerde ara'**
  String get peopleSearchHint;

  /// No description provided for @peopleSearchClear.
  ///
  /// In tr, this message translates to:
  /// **'Aramayı temizle'**
  String get peopleSearchClear;

  /// No description provided for @personNewTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Kişi'**
  String get personNewTitle;

  /// No description provided for @personPhotoAdd.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf Ekle'**
  String get personPhotoAdd;

  /// No description provided for @personPhotoChange.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı değiştir'**
  String get personPhotoChange;

  /// No description provided for @personPhotoRemove.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı kaldır'**
  String get personPhotoRemove;

  /// No description provided for @personFieldName.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get personFieldName;

  /// No description provided for @personFieldNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Elif'**
  String get personFieldNameHint;

  /// No description provided for @personFieldRelation.
  ///
  /// In tr, this message translates to:
  /// **'İlişkiniz'**
  String get personFieldRelation;

  /// Kullanıcı ilişkiyi kendi kelimeleriyle yazıyor; listeden seçmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Annem'**
  String get personFieldRelationHint;

  /// No description provided for @personFieldBirthDate.
  ///
  /// In tr, this message translates to:
  /// **'Doğum Tarihi'**
  String get personFieldBirthDate;

  /// No description provided for @personFieldBirthDateHint.
  ///
  /// In tr, this message translates to:
  /// **'Tarih seç'**
  String get personFieldBirthDateHint;

  /// No description provided for @personFieldNote.
  ///
  /// In tr, this message translates to:
  /// **'Kısa Not'**
  String get personFieldNote;

  /// No description provided for @personFieldNoteHint.
  ///
  /// In tr, this message translates to:
  /// **'Bu kişi hakkında bir not ekle…'**
  String get personFieldNoteHint;

  /// No description provided for @personSaveAction.
  ///
  /// In tr, this message translates to:
  /// **'Kişiyi Kaydet'**
  String get personSaveAction;

  /// No description provided for @personNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Bir ad yazmadan kaydedemeyiz.'**
  String get personNameRequired;

  /// No description provided for @personBirthDateFuture.
  ///
  /// In tr, this message translates to:
  /// **'Doğum tarihi gelecekte olamaz.'**
  String get personBirthDateFuture;

  /// Zorunlu olmayan alan etiketlerinin yanına eklenir.
  ///
  /// In tr, this message translates to:
  /// **'(Opsiyonel)'**
  String get formOptional;

  /// No description provided for @personDetailCollections.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyonlarımız'**
  String get personDetailCollections;

  /// No description provided for @personDetailRituals.
  ///
  /// In tr, this message translates to:
  /// **'Serilerimiz'**
  String get personDetailRituals;

  /// No description provided for @personDetailNoCollections.
  ///
  /// In tr, this message translates to:
  /// **'Onunla paylaştığın bir koleksiyon henüz yok.'**
  String get personDetailNoCollections;

  /// No description provided for @personDetailNoRituals.
  ///
  /// In tr, this message translates to:
  /// **'Birlikte tekrarladığın bir seri henüz yok.'**
  String get personDetailNoRituals;

  /// No description provided for @personEditAction.
  ///
  /// In tr, this message translates to:
  /// **'Kişiyi Düzenle'**
  String get personEditAction;

  /// No description provided for @personDeleteAction.
  ///
  /// In tr, this message translates to:
  /// **'Kişiyi Sil'**
  String get personDeleteAction;

  /// AppBar'daki üç noktanın ekran okuyucu etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Kişi işlemleri'**
  String get personActions;

  /// No description provided for @personDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kişi silinsin mi?'**
  String get personDeleteTitle;

  /// FR-063 — kişi silmek anıları silmiyor; kullanıcıya bunu açıkça söylemek gerekiyor.
  ///
  /// In tr, this message translates to:
  /// **'Bu kişi silinecek. Onunla yaşadığın anılar silinmez, yalnızca bağlantısı kopar.'**
  String get personDeleteMessage;

  /// Kişi düzenleme ekranının başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Kişiyi Düzenle'**
  String get personEditTitle;

  /// Ritüelin kaç yıldır sürdüğü.
  ///
  /// In tr, this message translates to:
  /// **'{count} yıl'**
  String ritualDurationYears(int count);

  /// Koleksiyonlar bir kişiye süzüldüğünde gösterilen çip.
  ///
  /// In tr, this message translates to:
  /// **'{name} ile'**
  String myLifeFilteredByPerson(String name);

  /// No description provided for @myLifeClearFilter.
  ///
  /// In tr, this message translates to:
  /// **'Süzmeyi kaldır'**
  String get myLifeClearFilter;

  /// No description provided for @peopleSearchEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Aradığın kişiyi bulamadım'**
  String get peopleSearchEmptyTitle;

  /// No description provided for @peopleSearchEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'\"{query}\" ile eşleşen bir kişi yok. Başka bir ad ya da ilişki dene.'**
  String peopleSearchEmptyMessage(String query);

  /// Satır sonundaki okun ekran okuyucu etiketi.
  ///
  /// In tr, this message translates to:
  /// **'{name} sayfasını aç'**
  String peopleOpenDetail(String name);

  /// No description provided for @searchPromptTitle.
  ///
  /// In tr, this message translates to:
  /// **'Anılarında ara'**
  String get searchPromptTitle;

  /// No description provided for @searchPromptMessage.
  ///
  /// In tr, this message translates to:
  /// **'Başlık ve notlarda arama yapabilirsin. Arama internet olmadan da çalışır.'**
  String get searchPromptMessage;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsMessage.
  ///
  /// In tr, this message translates to:
  /// **'Farklı bir kelime deneyebilir veya filtreleri temizleyebilirsin.'**
  String get searchNoResultsMessage;

  /// FR-162 / R-001 yedekleme durumu uyarısı
  ///
  /// In tr, this message translates to:
  /// **'Yalnız bu cihazda'**
  String get backupLocalOnly;

  /// No description provided for @backupLocalOnlyDetail.
  ///
  /// In tr, this message translates to:
  /// **'Verilerin sadece bu telefonda tutuluyor. Telefonunu kaybedersen anıların da kaybolur.'**
  String get backupLocalOnlyDetail;

  /// No description provided for @backupExportNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi dışa aktar'**
  String get backupExportNow;

  /// No description provided for @backupLastExport.
  ///
  /// In tr, this message translates to:
  /// **'Son dışa aktarma: {date}'**
  String backupLastExport(String date);

  /// No description provided for @backupNeverExported.
  ///
  /// In tr, this message translates to:
  /// **'Henüz hiç dışa aktarmadın'**
  String get backupNeverExported;

  /// BR-007 / FR-044 kaynak eksik durumu
  ///
  /// In tr, this message translates to:
  /// **'Orijinal fotoğraf bulunamadı'**
  String get mediaMissingTitle;

  /// No description provided for @mediaMissingMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu fotoğraf galerinden silinmiş görünüyor. İZ\'de sakladığımız önizleme gösteriliyor.'**
  String get mediaMissingMessage;

  /// No description provided for @paywallTitle.
  ///
  /// In tr, this message translates to:
  /// **'İZ+ ile aç'**
  String get paywallTitle;

  /// No description provided for @paywallFeatureLocked.
  ///
  /// In tr, this message translates to:
  /// **'Bu özellik {plan} planında kullanılabilir.'**
  String paywallFeatureLocked(String plan);

  /// No description provided for @errorGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti. Lütfen tekrar dene.'**
  String get errorGeneric;

  /// No description provided for @errorDatabase.
  ///
  /// In tr, this message translates to:
  /// **'Verilerine şu anda ulaşılamıyor.'**
  String get errorDatabase;

  /// No description provided for @errorNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Aradığın kayıt bulunamadı.'**
  String get errorNotFound;

  /// No description provided for @errorPermission.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için izin vermen gerekiyor.'**
  String get errorPermission;

  /// No description provided for @errorPermissionSettings.
  ///
  /// In tr, this message translates to:
  /// **'İzni Ayarlar\'dan açabilirsin.'**
  String get errorPermissionSettings;

  /// No description provided for @errorNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı kurulamadı.'**
  String get errorNetwork;

  /// No description provided for @errorOffline.
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantın yok gibi görünüyor.'**
  String get errorOffline;

  /// FR-012 iş kuralı — ValidationCode.emptyMemory karşılığı
  ///
  /// In tr, this message translates to:
  /// **'Bir anı en az bir not veya bir fotoğraf içermeli.'**
  String get errorValidationEmptyMemory;

  /// FR-013 iş kuralı — ValidationCode.futureDate karşılığı
  ///
  /// In tr, this message translates to:
  /// **'Anı tarihi gelecekte olamaz.'**
  String get errorValidationFutureDate;

  /// No description provided for @errorValidationEmailRequired.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresini gir.'**
  String get errorValidationEmailRequired;

  /// No description provided for @errorValidationEmailInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi gir.'**
  String get errorValidationEmailInvalid;

  /// No description provided for @errorValidationPasswordRequired.
  ///
  /// In tr, this message translates to:
  /// **'Şifreni gir.'**
  String get errorValidationPasswordRequired;

  /// No description provided for @errorValidationPasswordTooShort.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az {min} karakter olmalı.'**
  String errorValidationPasswordTooShort(int min);

  /// No description provided for @errorSignInFailed.
  ///
  /// In tr, this message translates to:
  /// **'E-posta veya şifre hatalı.'**
  String get errorSignInFailed;

  /// No description provided for @errorValidationNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Adını ve soyadını gir.'**
  String get errorValidationNameRequired;

  /// No description provided for @errorValidationPasswordsDoNotMatch.
  ///
  /// In tr, this message translates to:
  /// **'Şifreler eşleşmiyor.'**
  String get errorValidationPasswordsDoNotMatch;

  /// No description provided for @routeNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa bulunamadı'**
  String get routeNotFound;

  /// No description provided for @routeNotImplemented.
  ///
  /// In tr, this message translates to:
  /// **'Bu ekran henüz hazır değil.'**
  String get routeNotImplemented;

  /// No description provided for @routeGoHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana sayfaya dön'**
  String get routeGoHome;

  /// FR-070 varsayılan sistem kategorileri. Veritabanında ad değil anahtar saklanır; gösterim burada çevrilir.
  ///
  /// In tr, this message translates to:
  /// **'Seyahat'**
  String get categoryTravel;

  /// No description provided for @categoryFamily.
  ///
  /// In tr, this message translates to:
  /// **'Aile'**
  String get categoryFamily;

  /// No description provided for @categoryRelationships.
  ///
  /// In tr, this message translates to:
  /// **'İlişkiler'**
  String get categoryRelationships;

  /// No description provided for @categoryCelebrations.
  ///
  /// In tr, this message translates to:
  /// **'Kutlamalar'**
  String get categoryCelebrations;

  /// No description provided for @categoryEducation.
  ///
  /// In tr, this message translates to:
  /// **'Eğitim'**
  String get categoryEducation;

  /// No description provided for @categoryCareer.
  ///
  /// In tr, this message translates to:
  /// **'Kariyer'**
  String get categoryCareer;

  /// No description provided for @categoryHome.
  ///
  /// In tr, this message translates to:
  /// **'Ev'**
  String get categoryHome;

  /// No description provided for @categoryDaily.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Yaşam'**
  String get categoryDaily;

  /// No description provided for @settingsAppearance.
  ///
  /// In tr, this message translates to:
  /// **'Görünüm'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem dili'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik ve Güvenlik'**
  String get settingsPrivacy;

  /// No description provided for @settingsBackup.
  ///
  /// In tr, this message translates to:
  /// **'Yedekleme Durumu'**
  String get settingsBackup;

  /// No description provided for @settingsStorage.
  ///
  /// In tr, this message translates to:
  /// **'Depolama Kullanımı'**
  String get settingsStorage;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'tr':
      return AppL10nTr();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
