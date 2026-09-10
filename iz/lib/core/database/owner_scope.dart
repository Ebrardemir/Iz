/// AKTİF HESAP — yerel veritabanındaki her okumanın kapsamı.
///
/// NEDEN VAR?
/// Yerel veritabanı uzun süre "bu cihaz = tek kişi" varsayımıyla yazıldı.
/// `ownerId` sütunu her sahipli tabloda duruyordu ama HİÇBİR okuma sorgusu
/// ona bakmıyordu; hesap diye bir şey olmadığı için fark edilmiyordu.
///
/// Hesaplar çalışmaya başlayınca varsayım kırıldı: aynı cihazda ikinci bir
/// hesapla giriş yapan kullanıcı, birincinin anılarını, kişilerini ve
/// günlüklerini ekranda gördü. Görmesi tek başına yeterince kötüydü; asıl
/// tehlike, gördüğü bir kaydı DÜZENLEMESİ hâlinde o kaydın kuyruğa girip
/// KENDİ hesabına yüklenmesiydi — o noktada sızıntı buluta da çıkardı.
///
/// Buradaki kimlik, o sorgulara eklenen `where owner_id = ...` süzgecinin
/// beslendiği yer.
///
/// NEDEN VERİ SİLMİYORUZ?
/// Silmek daha kolay olurdu ama geri dönüşü yok: kullanıcının henüz buluta
/// çıkmamış kayıtları uyarısız yok olurdu. Süzgeç ise hiçbir şeye
/// dokunmuyor — ilk hesap tekrar giriş yaptığında verisi olduğu gibi
/// karşısına çıkıyor.
library;

/// Hesabı olmayan kullanıcının sahip kimliği.
///
/// `OwnedTable.ownerId`nin varsayılanı ve `Users` tablosunda tohumlanan
/// satırın kimliği ile AYNI değer olmak zorunda; yoksa yabancı anahtar
/// hiçbir şeye işaret etmez.
const kLocalOwnerId = 'local';

/// Şu an hangi hesabın verisine bakıyoruz?
///
/// NEDEN DEĞİŞTİRİLEBİLİR BİR ALAN?
/// Sorgu kurulurken kimliğin ELDE olması gerekiyor; `SecureStore`u okumak
/// `Future` döndürüyor ve her `select` çağrısını asenkron yapmak, kuyruk ile
/// yazmanın aynı transaction'da kalmasını imkânsız kılardı. Oturum kimliği
/// zaten süreç ömrü boyunca tek bir değer: doğru şekli bu.
///
/// Kimlik BİLİNMİYORSA [kLocalOwnerId] geçerli. Bu güvenli yön: hesabı
/// olmayan kullanıcının kendi verisi görünür, hesaplı kullanıcının verisi
/// görünmez. Ters varsayım (bilinmiyorsa hepsini göster) tam da düzeltmeye
/// çalıştığımız sızıntı olurdu.
final class OwnerScope {
  OwnerScope();

  String _current = kLocalOwnerId;

  /// Sorgulara giren sahip kimliği.
  String get current => _current;

  /// Hesap açıldı / oturum geri yüklendi.
  ///
  /// Boş ya da `null` kimlik ANLAMSIZ: öyle bir değerle damgalanmış satır
  /// hiçbir zaman geri okunamaz. Sessizce hesapsız kapsama düşüyoruz.
  void enter(String? ownerId) {
    _current = (ownerId == null || ownerId.isEmpty) ? kLocalOwnerId : ownerId;
  }

  /// Çıkış yapıldı. Veri SİLİNMİYOR, yalnız görünmez oluyor.
  void leave() => _current = kLocalOwnerId;

  /// Hesapsız kullanım mı?
  bool get isLocal => _current == kLocalOwnerId;
}
