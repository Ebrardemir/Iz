/// Rota adları ve yolları — TEK KAYNAK.
///
/// NEDEN SABİT?
/// `context.pushNamed('memory-detail')` yazarken bir harf hatası yaparsan
/// derleyici seni uyarmaz, uygulama çalışma zamanında patlar.
/// `AppRoute.memoryDetail.name` ise yazım hatasına izin vermez.
///
/// YENİ EKRAN EKLERKEN:
///   1. Buraya bir enum girdisi ekle
///   2. app_router.dart'ta karşılığını tanımla
library;

enum AppRoute {
  onboarding('onboarding', '/onboarding'),

  // --- Kimlik doğrulama ---
  signIn('sign-in', '/sign-in'),
  signUp('sign-up', '/sign-up'),

  // --- Alt çubuktaki sekmeler (shell içinde) ---
  home('home', '/home'),
  myLife('my-life', '/my-life'),
  store('store', '/store'),
  profile('profile', '/profile'),

  // --- Alt çubukta OLMAYAN ama ekranı duran bölümler ---
  //
  // Tasarım yenilenirken alt çubuk 5 sekmeden 4 sekme + eyleme indi.
  // Bu ekranlar silinmedi; ileride ana sayfadan (arama) veya profilden
  // (ayarlar) açılacaklar. Rotaları duruyor ki iş kaybolmasın.
  journal('journal', '/journal'),
  people('people', '/people'),
  search('search', '/search'),
  settings('settings', '/settings'),

  // --- Anı ---
  //
  // Ana sayfadaki "Tümünü Gör" bağlantısı buraya gidecek; ana sayfa artık
  // listenin kendisi değil, özetidir.
  memories('memories', '/memories'),

  // --- Yeni anı akışı ---
  //
  // İKİ ADIM: önce fotoğraf seçimi, sonra detaylar (başlık, not, tarih).
  // Ürünün tezi bu sırayı belirliyor — kullanıcı önce "hangi kareler" diye
  // düşünüyor, form sonra geliyor.
  //
  // ⚠️ İKİ ADIM HENÜZ BAĞLI DEĞİL: galeri erişimi bir platform paketi
  // gerektiriyor ve o karar ertelendi. `memoryNewDetails`e şimdilik yalnızca
  // rotayla gidilebiliyor (testler öyle yapıyor).
  memoryNew('memory-new', '/memory/new'),
  memoryNewDetails('memory-new-details', '/memory/new/details'),

  // DİKKAT: `/memory/picker` rotası `/memory/:id`den ÖNCE gelmeli, yoksa
  // "picker" bir anı kimliği sanılıp detay ekranı açılıyor — golden çekerken
  // tam bunu yaşadık (`/person/new` ile aynı tuzak).
  //
  // Anı seçme ekranını hem seri hem koleksiyon formu açıyor; o yüzden yol bir
  // feature'ın altında değil.
  memoryPicker('memory-picker', '/memory/picker'),
  memoryDetail('memory-detail', '/memory/:id'),
  memoryEdit('memory-edit', '/memory/:id/edit'),

  // --- Diğer detaylar ---
  // DİKKAT: `/person/new` rotası `/person/:id`den ÖNCE gelmeli, yoksa
  // "new" bir kimlik olarak eşleşir (anı tarafında da aynı kural var).
  personNew('person-new', '/person/new'),
  personDetail('person-detail', '/person/:id'),
  personEdit('person-edit', '/person/:id/edit'),

  // Ritüel oluşturma ve ona anı bağlama.
  //
  // Anı seçme ekranı formun ALT ROTASI DEĞİL, kardeşi: form onu `pushNamed`
  // ile açıp seçilen kimlikleri `pop` ile geri alıyor.
  ritualNew('ritual-new', '/ritual/new'),
  collectionNew('collection-new', '/collection/new'),
  journalNew('journal-new', '/journal/new'),
  journalAll('journal-all', '/journal/all'),
  ritualDetail('ritual-detail', '/ritual/:id'),
  collectionDetail('collection-detail', '/collection/:id'),

  // --- Ayarlar alt sayfaları ---
  backupStatus('backup-status', '/settings/backup'),
  subscription('subscription', '/settings/subscription');

  const AppRoute(this.name, this.path);

  /// `context.goNamed(AppRoute.timeline.name)` için.
  final String name;

  /// Tam yol — deep link ve doğrudan `context.go()` için.
  final String path;

  /// ALT ÇUBUKTAKİ SEKMELER, SIRASIYLA.
  ///
  /// TEK KAYNAK. Sıra üç yerde birden geçerli olmak zorunda:
  ///   • `app_router.dart`taki `branches` listesi
  ///   • `app_shell.dart`taki `IzBottomNav.destinations`
  ///   • alt çubuğu kabuk dışında gösteren ekranlar (anı detayı)
  /// Elle üç kez yazıldığında biri kaydığında derleyici SUSAR: uygulama
  /// açılır, sadece "Hayatım"a dokunan kullanıcı Mağaza'yı görür. Bu liste
  /// o üç yerin ortak referansı.
  static const List<AppRoute> tabs = [home, myLife, store, profile];
}
