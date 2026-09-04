// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppL10nTr extends AppL10n {
  AppL10nTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'İZ';

  @override
  String get appTagline => 'Hayatında iz bırakanları seç, biriktir ve yaşat';

  @override
  String get commonCancel => 'Vazgeç';

  @override
  String get commonSave => 'Kaydet';

  @override
  String get commonDelete => 'Sil';

  @override
  String get commonEdit => 'Düzenle';

  @override
  String get commonRetry => 'Tekrar dene';

  @override
  String get commonClose => 'Kapat';

  @override
  String get commonDone => 'Tamam';

  @override
  String get commonShare => 'Paylaş';

  @override
  String get commonSearch => 'Ara';

  @override
  String get commonSeeAll => 'Tümünü Gör';

  @override
  String get commonAdd => 'Ekle';

  @override
  String get commonNext => 'Devam';

  @override
  String get commonSkip => 'Atla';

  @override
  String get commonLoading => 'Yükleniyor';

  @override
  String get authWelcomeBack => 'Tekrar hoş geldin';

  @override
  String get authWelcomeSubtitle =>
      'Değerli anılarına kaldığın yerden devam et.';

  @override
  String get authEmail => 'E-posta';

  @override
  String get authPassword => 'Şifre';

  @override
  String get authForgotPassword => 'Şifremi unuttum';

  @override
  String get authSignIn => 'Giriş Yap';

  @override
  String get authCreateAccount => 'Hesap Oluştur';

  @override
  String get authOr => 'veya';

  @override
  String get authSignInWithApple => 'Apple ile Giriş Yap';

  @override
  String get authSignInWithGoogle => 'Google ile Giriş Yap';

  @override
  String get authPrivacyNote =>
      'Verilerin güvende. Gizliliğine saygı duyuyoruz.';

  @override
  String get authShowPassword => 'Şifreyi göster';

  @override
  String get authHidePassword => 'Şifreyi gizle';

  @override
  String get authHeroSemantics => 'Anılardan oluşan bir fotoğraf kolajı';

  @override
  String get authResetLinkSent => 'Şifre sıfırlama bağlantısı gönderildi.';

  @override
  String get authResetNeedsEmail => 'Önce e-posta adresini gir.';

  @override
  String get authFullName => 'Ad Soyad';

  @override
  String get authPasswordAgain => 'Şifreyi tekrar gir';

  @override
  String get authSignUp => 'Kayıt Ol';

  @override
  String get authContinueWithApple => 'Apple ile Devam Et';

  @override
  String get authContinueWithGoogle => 'Google ile Devam Et';

  @override
  String get authAlreadyHaveAccount => 'Zaten hesabın var mı?';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navMyLife => 'Hayatım';

  @override
  String get navAdd => 'Ekle';

  @override
  String get navStore => 'Mağaza';

  @override
  String get navProfile => 'Profilim';

  @override
  String get myLifePreviousMonth => 'Önceki ay';

  @override
  String get myLifeNextMonth => 'Sonraki ay';

  @override
  String get myLifeTabCalendar => 'TAKVİM';

  @override
  String get myLifeTabCollections => 'KOLEKSİYONLAR';

  @override
  String get myLifeTabSeries => 'SERİLERİM';

  @override
  String get myLifeTitle => 'HAYATIM';

  @override
  String get myLifeDayEmptyTitle => 'Bu güne henüz iz düşmedi';

  @override
  String get myLifeDayEmptyAction => 'Bu güne bir iz bırak';

  @override
  String get collectionsEmptyTitle => 'Henüz bir koleksiyon yok';

  @override
  String get collectionsEmptyMessage =>
      'Bir seyahati, bir dönemi ya da bir kişiyi anlatan anıları tek bir koleksiyonda topla.';

  @override
  String get collectionExpand => 'Koleksiyonu aç';

  @override
  String get collectionNewTitle => 'Yeni Koleksiyon';

  @override
  String get collectionFieldName => 'Koleksiyon Adı';

  @override
  String get collectionFieldNameHint => 'Koleksiyon adı gir';

  @override
  String get collectionFieldDescription => 'Açıklama';

  @override
  String get collectionFieldDescriptionHint => 'Koleksiyonunu kısaca açıkla';

  @override
  String get collectionFieldDateRange => 'Tarih Aralığı';

  @override
  String get collectionFieldDateRangeHint => 'Başlangıç – Bitiş';

  @override
  String get collectionFieldPeople => 'İlgili Kişiler';

  @override
  String get collectionFieldPeopleHint => 'Kişi ekle';

  @override
  String get collectionFieldCategory => 'Kategori';

  @override
  String get collectionFieldCategoryHint => 'Kategori seç';

  @override
  String get collectionFieldMemories => 'İlk Anıları Ekle';

  @override
  String get collectionFieldMemoriesHint => 'Anı seçerek başla';

  @override
  String collectionSelectedMemories(int count) {
    return '$count anı seçildi';
  }

  @override
  String get collectionCreateAction => 'Koleksiyonu Oluştur';

  @override
  String get collectionNameRequired => 'Bir isim yazmadan oluşturamayız.';

  @override
  String get collectionCreated =>
      'Koleksiyonun oluştu, Hayatım’da seni bekliyor.';

  @override
  String get collectionCollapse => 'Koleksiyonu kapat';

  @override
  String collectionMemoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anı',
      one: '1 anı',
      zero: 'Anı yok',
    );
    return '$_temp0';
  }

  @override
  String get addMenuTitle => 'Ne eklemek istersin?';

  @override
  String get addMenuMemory => 'Anı';

  @override
  String get addMenuSeries => 'Seri';

  @override
  String get addMenuJournal => 'Günlük Kaydı';

  @override
  String get addMenuCollection => 'Koleksiyon';

  @override
  String get addMenuPerson => 'Kişi';

  @override
  String get seriesEmptyTitle => 'Henüz bir seri yok';

  @override
  String get seriesEmptyMessage =>
      'Her yıl tekrarlanan şeyleri bir seriye bağla; yılları yan yana görürsün.';

  @override
  String ritualEveryYearOn(String month, int day) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Her yıl $day Ocak\'ta',
      '2': 'Her yıl $day Şubat\'ta',
      '3': 'Her yıl $day Mart\'ta',
      '4': 'Her yıl $day Nisan\'da',
      '5': 'Her yıl $day Mayıs\'ta',
      '6': 'Her yıl $day Haziran\'da',
      '7': 'Her yıl $day Temmuz\'da',
      '8': 'Her yıl $day Ağustos\'ta',
      '9': 'Her yıl $day Eylül\'de',
      '10': 'Her yıl $day Ekim\'de',
      '11': 'Her yıl $day Kasım\'da',
      '12': 'Her yıl $day Aralık\'ta',
      'other': 'Her yıl',
    });
    return '$_temp0';
  }

  @override
  String ritualEveryYearInSeason(String season) {
    String _temp0 = intl.Intl.selectLogic(season, {
      'spring': 'Her yıl ilkbaharda',
      'summer': 'Her yıl yaz aylarında',
      'autumn': 'Her yıl sonbaharda',
      'winter': 'Her yıl kış aylarında',
      'other': 'Her yıl',
    });
    return '$_temp0';
  }

  @override
  String get ritualCustomSchedule => 'Belirli bir tarihi yok';

  @override
  String get ritualEveryMonth => 'Her ay';

  @override
  String get ritualEveryWeek => 'Her hafta';

  @override
  String get ritualNewTitle => 'Yeni Seri';

  @override
  String get coverAdd => 'Kapak Görseli Ekle';

  @override
  String get coverChange => 'Kapak Görselini Değiştir';

  @override
  String get coverIllustrationSemantics =>
      'Dağlar, güneş ve bir zeytin dalı çizimi';

  @override
  String get ritualFieldName => 'Seri Adı';

  @override
  String get ritualFieldNameHint => 'Serine bir isim ver';

  @override
  String get ritualFieldDescription => 'Açıklama';

  @override
  String get ritualFieldDescriptionHint =>
      'Bu seriyle ilgili kısa bir açıklama yaz';

  @override
  String get ritualFieldRecurrence => 'Tekrarlama';

  @override
  String get ritualFieldPeople => 'İlgili Kişiler';

  @override
  String get ritualFieldPeopleHint => 'Kişi ekle';

  @override
  String get ritualFieldCategory => 'Kategori';

  @override
  String get ritualFieldCategoryHint => 'Kategori seç';

  @override
  String get ritualFieldMemories => 'Bu Yıla Anı Ekle';

  @override
  String get ritualFieldMemoriesHint => 'Seriye anı bağla';

  @override
  String ritualSelectedMemories(int count) {
    return '$count anı seçildi';
  }

  @override
  String ritualDateRange(String range) {
    return 'Tarih aralığı: $range';
  }

  @override
  String get ritualCreateAction => 'Seriyi Oluştur';

  @override
  String get ritualNameRequired => 'Bir isim yazmadan oluşturamayız.';

  @override
  String get ritualCreated => 'Serin oluştu, Serilerim’de seni bekliyor.';

  @override
  String get memoryPickerTitle => 'Anı Seç';

  @override
  String get memoryPickerEmpty =>
      'Bağlanabilecek anı kalmamış. Bir anı yalnızca tek bir seriye bağlanabilir.';

  @override
  String get memoryPickerDone => 'Bitti';

  @override
  String ritualStatYears(int count) {
    return '$count yıl';
  }

  @override
  String get ritualStatYearsLabel => 'Birlikte';

  @override
  String ritualStatMemories(int count) {
    return '$count anı';
  }

  @override
  String get ritualStatMemoriesLabel => 'Toplam';

  @override
  String ritualStatCities(int count) {
    return '$count şehir';
  }

  @override
  String get ritualStatCitiesLabel => 'Keşfedildi';

  @override
  String get ritualDetailMemories => 'Bu Serideki Anılar';

  @override
  String get ritualDetailShowAll => 'Tümünü Gör';

  @override
  String get ritualDetailShowLess => 'Daha Az Göster';

  @override
  String get ritualDetailNoMemories =>
      'Bu seriye henüz anı bağlamadın. Bağladığın her anı burada yıl yıl birikecek.';

  @override
  String get ritualDetailActions => 'Seri işlemleri';

  @override
  String get ritualEditAction => 'Seriyi Düzenle';

  @override
  String get ritualDeleteAction => 'Seriyi Sil';

  @override
  String get ritualDeleteTitle => 'Seri silinsin mi?';

  @override
  String get ritualDeleteMessage =>
      'Bu seri silinecek. İçindeki anılar silinmez, yalnızca serideki bağlantıları kopar.';

  @override
  String get ritualRecurrenceSectionSemantics => 'Tekrarlama seçenekleri';

  @override
  String ritualYearCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yıl',
      one: '1 yıl',
      zero: 'Yıl yok',
    );
    return '$_temp0';
  }

  @override
  String get memoryMoreActions => 'Anı işlemleri';

  @override
  String get memoryOpenDetail => 'Anıya git';

  @override
  String get commonFilter => 'Filtrele';

  @override
  String get homeHeroTodayEyebrow => 'BUGÜNÜN İZİ';

  @override
  String get homeHeroViewMemory => 'Anıyı Gör';

  @override
  String get homeHeroEmptyTitle => 'İlk İzini Bırak';

  @override
  String get homeHeroEmptySubtitle =>
      'Hatırlamak isteyeceğin bir anı seç ve sakla.';

  @override
  String get homeHeroAddMemory => 'Anı Ekle';

  @override
  String get homeRecentTitle => 'SON ANILAR';

  @override
  String get homeRecentEmptyTitle => 'Burada henüz bir iz yok.';

  @override
  String get homeRecentEmptyMessage =>
      'İlk anını eklediğinde burada görünmeye başlayacak.';

  @override
  String get homeStatJournal => 'GÜNLÜK';

  @override
  String homeStatJournalUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kayıt',
    );
    return '$_temp0';
  }

  @override
  String get homeStatPeople => 'KİŞİLER';

  @override
  String homeStatPeopleUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kişi',
    );
    return '$_temp0';
  }

  @override
  String get homeStatSeries => 'SERİLER';

  @override
  String homeStatSeriesUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seri',
    );
    return '$_temp0';
  }

  @override
  String get homeStatCollections => 'KOLEKSİYONLAR';

  @override
  String homeStatCollectionsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'koleksiyon',
    );
    return '$_temp0';
  }

  @override
  String get homeNotifications => 'Bildirimler';

  @override
  String get screenComingSoon => 'Bu ekran yakında';

  @override
  String get screenComingSoonMessage =>
      'Tasarımı hazırlanıyor. Çok yakında burada olacak.';

  @override
  String get navJournal => 'Günlük';

  @override
  String get navPeople => 'Kişiler';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get memoriesTitle => 'Anılarım';

  @override
  String get memoryNew => 'Yeni Anı';

  @override
  String get memoryEdit => 'Anıyı Düzenle';

  @override
  String get memoryFavorite => 'Favorilere ekle';

  @override
  String get memoryUnfavorite => 'Favorilerden çıkar';

  @override
  String get memoryFilterFavoritesOff => 'Yalnızca favorileri göster';

  @override
  String get memoryFilterFavoritesOn => 'Favori filtresini kaldır';

  @override
  String get memoryEmptyTitle => 'Henüz bir iz yok';

  @override
  String get memoryEmptyMessage =>
      'Tüm galerini değil, saklamaya değer anlarını biriktir. İlk izini bırakarak başla.';

  @override
  String get memoryEmptyAction => 'İlk izini bırak';

  @override
  String get memoryDeleteTitle => 'Anı silinsin mi?';

  @override
  String get memoryDeleteMessage =>
      'Bu anı çöp kutusuna taşınacak. 30 gün içinde geri alabilirsin.';

  @override
  String get memoryDeleteConfirm => 'Sil';

  @override
  String get memoryDeleted => 'Anı çöp kutusuna taşındı';

  @override
  String get memoryRestore => 'Geri al';

  @override
  String memoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anı',
      one: '1 anı',
      zero: 'Anı yok',
    );
    return '$_temp0';
  }

  @override
  String memoryYearsAgo(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years yıl önce bugün',
      one: 'Geçen yıl bugün',
      zero: 'Bugün',
    );
    return '$_temp0';
  }

  @override
  String get memoryFieldTitle => 'Başlık';

  @override
  String get memoryFieldTitleHint => 'Bu anı neydi?';

  @override
  String get memoryFieldNote => 'Not';

  @override
  String get memoryFieldNoteHint => 'Neyi hatırlamak istersin?';

  @override
  String get memoryFieldDate => 'Tarih';

  @override
  String get memoryFieldCategory => 'Kategori';

  @override
  String get memoryFieldCollection => 'Koleksiyon';

  @override
  String get memoryFieldSeries => 'Seri';

  @override
  String get memoryFieldLocationHint => 'Neredeydi?';

  @override
  String get memoryFieldEmpty => 'Seç';

  @override
  String get memoryDetailsTitle => 'Detayları Gir';

  @override
  String memoryDateInvalid(String example) {
    return 'Tarihi anlayamadım. Örnek: $example';
  }

  @override
  String get memoryDateFuture => 'Gelecek bir tarih seçemezsin.';

  @override
  String get pickerAddNew => 'Yeni ekle';

  @override
  String get pickerEmpty => 'Henüz hiç yok. Aşağıdan ekleyebilirsin.';

  @override
  String get memoryPhotos => 'Fotoğraflar';

  @override
  String get memoryNoPhotos => 'Henüz fotoğraf eklenmedi.';

  @override
  String get memoryDetailTitle => 'Anı Detay';

  @override
  String get memoryActionCollage => 'Kolaj Oluştur';

  @override
  String get memoryNoteExpand => 'Notun tamamını göster';

  @override
  String get memoryNoteCollapse => 'Notu kısalt';

  @override
  String get memoryPhotosPrompt => 'Bu anıdan geriye hangi kareler kalsın?';

  @override
  String get memoryPickFromGallery => 'Galeriden Fotoğraf Seç';

  @override
  String memoryPhotoLimitHint(int limit) {
    return 'En fazla $limit fotoğraf seçebilirsin.';
  }

  @override
  String get memoryPhotosIllustrationSemantics =>
      'Fotoğraf çerçeveleri ve bir dal çizimi';

  @override
  String get commonSaveChanges => 'Değişiklikleri Kaydet';

  @override
  String get memoryPhotoRemove => 'Fotoğrafı kaldır';

  @override
  String get memoryPhotoAdd => 'Fotoğraf ekle';

  @override
  String get relationPeople => 'Kişiler';

  @override
  String get relationCollections => 'Koleksiyonlar';

  @override
  String get relationRitual => 'Seri';

  @override
  String get relationLocation => 'Konum';

  @override
  String photoLimitReached(int limit) {
    return 'Ücretsiz planda bir anıya en fazla $limit fotoğraf ekleyebilirsin.';
  }

  @override
  String get todaysTraceTitle => 'Bugünün İzi';

  @override
  String get todaysTraceSubtitle =>
      'Geçmiş yıllarda bugün yaşadıklarını hatırlat';

  @override
  String get thenAndNowTitle => 'O Zaman / Şimdi';

  @override
  String get onboardingCurateTitle =>
      'Tüm galerini değil,\nizini bırakanları biriktir';

  @override
  String get onboardingCurateBody =>
      'İZ bir yedekleme uygulaması değil. Senin için gerçekten anlamlı olan anları seçip anlamlandırdığın bir kişisel hafıza.';

  @override
  String get onboardingContextTitle => 'Bir anı,\nbirçok bağlam';

  @override
  String get onboardingContextBody =>
      'Aynı anıyı kişilerle, kategorilerle, koleksiyonlarla ve serilerle ilişkilendir. Klasörlerde kaybolmadan yıllar sonra saniyeler içinde bul.';

  @override
  String get onboardingLocalTitle => 'Verilerin\nşimdilik bu cihazda';

  @override
  String get onboardingLocalBody =>
      'Anıların telefonunda saklanıyor; kimseyle paylaşılmıyor. Ama telefonunu kaybedersen anıların da kaybolur — bu yüzden düzenli olarak dışa aktarmanı hatırlatacağız.';

  @override
  String get onboardingStart => 'İlk izini bırak';

  @override
  String get journalEmptyTitle => 'Bugün neyin izini bırakmak istersin?';

  @override
  String get journalEmptyMessage =>
      'Kısa bir not yeter. İstersen sonradan kalıcı bir anıya dönüştürürsün.';

  @override
  String get journalNewTitle => 'Yeni Günlük';

  @override
  String get journalGreeting => 'Merhaba';

  @override
  String get journalPrompt1 =>
      'Bugün seni ne yordu, ne güldürdü? Birkaç satır bırak; yarın sana iyi gelecek.';

  @override
  String get journalPrompt2 =>
      'Unutma diye değil, hatırlamak istediğinde bulasın diye yaz.';

  @override
  String get journalPrompt3 =>
      'Küçük şeyler de yazılır: bir kahve, bir söz, bir bakış. Hepsi bugünün izi.';

  @override
  String get journalPrompt4 =>
      'Kelimelerin düzgün olmak zorunda değil. Sen anlatsan yeter.';

  @override
  String get journalPrompt5 =>
      'Bugünden geriye ne kalsın istersin? Onu yaz, gerisini zamana bırak.';

  @override
  String get journalMoodLow => 'Zorlu bir gündü';

  @override
  String get journalMoodHigh => 'Güzel bir gündü';

  @override
  String get journalIllustrationSemantics =>
      'Açık bir defter ve zeytin dalı çizimi';

  @override
  String get journalMoodQuestion => 'Bugün kendini nasıl hissediyorsun?';

  @override
  String journalMoodSemantics(int value) {
    return 'Bugünkü ruh hâlin: $value';
  }

  @override
  String get journalFieldTitle => 'Başlık';

  @override
  String get journalFieldTitleHint => 'Bugüne bir ad ver';

  @override
  String get journalFieldNotes => 'Notlarım';

  @override
  String get journalFieldNotesHint => 'İçinden geçenleri özgürce yaz…';

  @override
  String get journalPhotosLabel => 'Bugünden bir kare';

  @override
  String journalPhotosHint(int count) {
    return 'İstersen en fazla $count fotoğraf ekle.';
  }

  @override
  String get journalCreateAction => 'Kaydı Oluştur';

  @override
  String get journalNotesRequired => 'Birkaç kelime yazmadan kaydedemeyiz.';

  @override
  String get journalCreated => 'Bugünün izi kaydedildi.';

  @override
  String get journalHeroGreeting => 'Hoş geldin';

  @override
  String journalHeroGreetingNamed(String name) {
    return 'Hoş geldin, $name';
  }

  @override
  String get journalHeroBody => 'Kendine birkaç satır da olsa bugün eşlik et.';

  @override
  String get journalHeroAction => 'Yazmaya Başla';

  @override
  String get journalHeroSemantics =>
      'Bir masada açık defter, kalem ve kahve çizimi';

  @override
  String get journalRecentTitle => 'Son Yazılarım';

  @override
  String get journalRecentEmptyTitle => 'Burası senin sessiz köşen';

  @override
  String get journalRecentEmptyBody =>
      'Yazdığın her satır, bir gün dönüp bulacağın bir iz olacak.';

  @override
  String get journalEmptyIllustrationSemantics =>
      'Boş bir sayfa, kalem ve filiz çizimi';

  @override
  String get journalAllTitle => 'Tüm Günlükler';

  @override
  String get journalFilterAll => 'Tümü';

  @override
  String get journalFilterThisWeek => 'Bu Hafta';

  @override
  String get journalFilterThisMonth => 'Bu Ay';

  @override
  String get journalFilterFavorites => 'Favoriler';

  @override
  String get journalAllEmptyWeek =>
      'Bu hafta henüz yazmadın. Hafta bitmeden bir satır bırakabilirsin.';

  @override
  String get journalAllEmptyMonth =>
      'Bu ay hiç yazmamışsın. Ay kapanmadan bir gün seç ve yaz.';

  @override
  String get journalAllEmptyFavorites =>
      'Henüz hiçbir yazını yıldızlamadın. Dönüp dönüp okuduğun bir gün varsa onu işaretle.';

  @override
  String get journalFavoriteAdd => 'Yıldızla';

  @override
  String get journalFavoriteRemove => 'Yıldızı kaldır';

  @override
  String get peopleEmptyTitle => 'Burası onlarla dolacak.';

  @override
  String get peopleEmptyMessage =>
      'Annen, en yakın arkadaşın, belki kedin… Kimi eklersen, onunla yaşadıklarınız tek bir çizgide birikmeye başlar.';

  @override
  String get peopleTitle => 'Kişilerim';

  @override
  String get peopleSubtitle => 'Hayatına iz bırakanlar burada yaşar.';

  @override
  String get peopleEmptyAction => 'İlk Kişini Ekle';

  @override
  String get peopleIllustrationSemantics =>
      'Bir kubbenin altında duran üç kişi çizimi';

  @override
  String get relationTypeSelf => 'Kendim';

  @override
  String get relationTypePartner => 'Eşim';

  @override
  String get relationTypeParent => 'Anne / Baba';

  @override
  String get relationTypeChild => 'Çocuğum';

  @override
  String get relationTypeSibling => 'Kardeşim';

  @override
  String get relationTypeGrandparent => 'Anneanne / Dede';

  @override
  String get relationTypeGrandchild => 'Torunum';

  @override
  String get relationTypeRelative => 'Akrabam';

  @override
  String get relationTypeFriend => 'Arkadaşım';

  @override
  String get relationTypeColleague => 'İş arkadaşım';

  @override
  String get relationTypePet => 'Dostum';

  @override
  String get relationTypeOther => 'Yakınım';

  @override
  String get peopleAddAction => 'Kişi Ekle';

  @override
  String get peopleSearchHint => 'Kişilerde ara';

  @override
  String get peopleSearchClear => 'Aramayı temizle';

  @override
  String get personNewTitle => 'Yeni Kişi';

  @override
  String get personPhotoAdd => 'Fotoğraf Ekle';

  @override
  String get personPhotoChange => 'Fotoğrafı değiştir';

  @override
  String get personPhotoRemove => 'Fotoğrafı kaldır';

  @override
  String get personFieldName => 'Ad';

  @override
  String get personFieldNameHint => 'Örn. Elif';

  @override
  String get personFieldRelation => 'İlişkiniz';

  @override
  String get personFieldRelationHint => 'Örn. Annem';

  @override
  String get personFieldBirthDate => 'Doğum Tarihi';

  @override
  String get personFieldBirthDateHint => 'Tarih seç';

  @override
  String get personFieldNote => 'Kısa Not';

  @override
  String get personFieldNoteHint => 'Bu kişi hakkında bir not ekle…';

  @override
  String get personSaveAction => 'Kişiyi Kaydet';

  @override
  String get personNameRequired => 'Bir ad yazmadan kaydedemeyiz.';

  @override
  String get personBirthDateFuture => 'Doğum tarihi gelecekte olamaz.';

  @override
  String get formOptional => '(Opsiyonel)';

  @override
  String get personDetailCollections => 'Koleksiyonlarımız';

  @override
  String get personDetailRituals => 'Serilerimiz';

  @override
  String get personDetailNoCollections =>
      'Onunla paylaştığın bir koleksiyon henüz yok.';

  @override
  String get personDetailNoRituals =>
      'Birlikte tekrarladığın bir seri henüz yok.';

  @override
  String get personEditAction => 'Kişiyi Düzenle';

  @override
  String get personDeleteAction => 'Kişiyi Sil';

  @override
  String get personActions => 'Kişi işlemleri';

  @override
  String get personDeleteTitle => 'Kişi silinsin mi?';

  @override
  String get personDeleteMessage =>
      'Bu kişi silinecek. Onunla yaşadığın anılar silinmez, yalnızca bağlantısı kopar.';

  @override
  String get personEditTitle => 'Kişiyi Düzenle';

  @override
  String ritualDurationYears(int count) {
    return '$count yıl';
  }

  @override
  String myLifeFilteredByPerson(String name) {
    return '$name ile';
  }

  @override
  String get myLifeClearFilter => 'Süzmeyi kaldır';

  @override
  String get peopleSearchEmptyTitle => 'Aradığın kişiyi bulamadım';

  @override
  String peopleSearchEmptyMessage(String query) {
    return '\"$query\" ile eşleşen bir kişi yok. Başka bir ad ya da ilişki dene.';
  }

  @override
  String peopleOpenDetail(String name) {
    return '$name sayfasını aç';
  }

  @override
  String get searchPromptTitle => 'Anılarında ara';

  @override
  String get searchPromptMessage =>
      'Başlık ve notlarda arama yapabilirsin. Arama internet olmadan da çalışır.';

  @override
  String get searchNoResultsTitle => 'Sonuç bulunamadı';

  @override
  String get searchNoResultsMessage =>
      'Farklı bir kelime deneyebilir veya filtreleri temizleyebilirsin.';

  @override
  String get backupLocalOnly => 'Yalnız bu cihazda';

  @override
  String get backupLocalOnlyDetail =>
      'Verilerin sadece bu telefonda tutuluyor. Telefonunu kaybedersen anıların da kaybolur.';

  @override
  String get backupExportNow => 'Şimdi dışa aktar';

  @override
  String backupLastExport(String date) {
    return 'Son dışa aktarma: $date';
  }

  @override
  String get backupNeverExported => 'Henüz hiç dışa aktarmadın';

  @override
  String get mediaMissingTitle => 'Orijinal fotoğraf bulunamadı';

  @override
  String get mediaMissingMessage =>
      'Bu fotoğraf galerinden silinmiş görünüyor. İZ\'de sakladığımız önizleme gösteriliyor.';

  @override
  String get paywallTitle => 'İZ+ ile aç';

  @override
  String paywallFeatureLocked(String plan) {
    return 'Bu özellik $plan planında kullanılabilir.';
  }

  @override
  String get errorGeneric => 'Bir şeyler ters gitti. Lütfen tekrar dene.';

  @override
  String get errorDatabase => 'Verilerine şu anda ulaşılamıyor.';

  @override
  String get errorNotFound => 'Aradığın kayıt bulunamadı.';

  @override
  String get errorPermission => 'Devam etmek için izin vermen gerekiyor.';

  @override
  String get errorPermissionSettings => 'İzni Ayarlar\'dan açabilirsin.';

  @override
  String get errorNetwork => 'Bağlantı kurulamadı.';

  @override
  String get errorOffline => 'İnternet bağlantın yok gibi görünüyor.';

  @override
  String get errorValidationEmptyMemory =>
      'Bir anı en az bir not veya bir fotoğraf içermeli.';

  @override
  String get errorValidationFutureDate => 'Anı tarihi gelecekte olamaz.';

  @override
  String get errorValidationEmailRequired => 'E-posta adresini gir.';

  @override
  String get errorValidationEmailInvalid => 'Geçerli bir e-posta adresi gir.';

  @override
  String get errorValidationPasswordRequired => 'Şifreni gir.';

  @override
  String errorValidationPasswordTooShort(int min) {
    return 'Şifre en az $min karakter olmalı.';
  }

  @override
  String get errorSignInFailed => 'E-posta veya şifre hatalı.';

  @override
  String get errorSignInTooManyAttempts =>
      'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.';

  @override
  String get errorSignInAccountDisabled => 'Bu hesap kullanıma kapatılmış.';

  @override
  String get errorSessionExpired => 'Oturumun sona erdi. Tekrar giriş yap.';

  @override
  String get errorSignInProviderUnavailable =>
      'Bu giriş yöntemi henüz kullanılamıyor.';

  @override
  String get errorValidationEmailInUse =>
      'Bu e-postayla bir hesap zaten var. Giriş yapmayı dene.';

  @override
  String get errorValidationNameRequired => 'Adını ve soyadını gir.';

  @override
  String get errorValidationPasswordsDoNotMatch => 'Şifreler eşleşmiyor.';

  @override
  String get routeNotFound => 'Sayfa bulunamadı';

  @override
  String get routeNotImplemented => 'Bu ekran henüz hazır değil.';

  @override
  String get routeGoHome => 'Ana sayfaya dön';

  @override
  String get categoryTravel => 'Seyahat';

  @override
  String get categoryFamily => 'Aile';

  @override
  String get categoryRelationships => 'İlişkiler';

  @override
  String get categoryCelebrations => 'Kutlamalar';

  @override
  String get categoryEducation => 'Eğitim';

  @override
  String get categoryCareer => 'Kariyer';

  @override
  String get categoryHome => 'Ev';

  @override
  String get categoryDaily => 'Günlük Yaşam';

  @override
  String get settingsAppearance => 'Görünüm';

  @override
  String get settingsThemeSystem => 'Sistem';

  @override
  String get settingsThemeLight => 'Açık';

  @override
  String get settingsThemeDark => 'Koyu';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsLanguageSystem => 'Sistem dili';

  @override
  String get settingsNotifications => 'Bildirimler';

  @override
  String get settingsPrivacy => 'Gizlilik ve Güvenlik';

  @override
  String get settingsBackup => 'Yedekleme Durumu';

  @override
  String get settingsStorage => 'Depolama Kullanımı';
}
