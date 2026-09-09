/// "Bu cihazda kim oturum açmış?" — motorun tek kimlik sorusu.
///
/// NEDEN AYRI BİR SÖZLEŞME?
/// Motor önce doğrudan hesap ucunu (`/v1/me`) çağırıyordu ve bu iki şeyi
/// birden bozuyordu:
///
///   1. MİMARİ SINIR. `sync/presentation` katmanı `auth/data`ya bakmak
///      zorunda kalıyordu; ARCHITECTURE.md §2 buna izin vermiyor ve CI'daki
///      TR-C-03 denetimi bunu yakaladı.
///
///   2. SORUMLULUK. Motorun işi eşitlemek; kullanıcı kimliğinin nereden
///      geldiği (önbellek mi, ağ mı, ileride başka bir kaynak mı) onu
///      ilgilendirmiyor. Sözleşme daraldıkça motor da sadeleşiyor.
///
/// Uygulaması `data/sources/remote_sync_identity.dart` — orada `auth/data`ya
/// bakmak serbest (`data` → `data` geçişi zaten `memory_dao.dart`ta da var).
library;

abstract interface class SyncIdentity {
  /// Sunucudaki `users.id` — BİZİM UUID'miz, Firebase uid'si değil.
  ///
  /// Oturum yoksa ya da kimlik çözülemiyorsa `null`. Motor bu durumda hiçbir
  /// şey göndermiyor: sahipsiz veri sunucuya çıkmamalı.
  Future<String?> ownerId();
}
