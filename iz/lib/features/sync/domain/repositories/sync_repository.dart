/// Senkronizasyonun domain sözleşmesi.
///
/// NEDEN ARAYÜZ VAR — tek bir uygulaması olacakken?
/// ARCHITECTURE.md §2: presentation katmanı `data/`ye bakamaz. Yedekleme
/// Sağlığı ekranı ve "şimdi eşitle" düğmesi bu sözleşmeyi görecek; arkasında
/// `SyncEngine` mi başka bir şey mi olduğunu bilmeyecek.
///
/// İkinci fayda testte: ekranı sınarken gerçek bir motor kurmak, sahte bir
/// sunucu ve gerçek bir veritabanı kurmak demekti.
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/sync/domain/entities/sync_outcome.dart';

abstract interface class SyncRepository {
  /// Bir tur eşitleme yapar: kuyruğu boşaltır, sonra yenileri indirir.
  ///
  /// SIRA ÖNEMLİ VE DEĞİŞMEZ — önce push, sonra pull. Tersi olsaydı, bu
  /// cihazda bekleyen bir değişiklik varken inen sunucu sürümü onu ezerdi ve
  /// kullanıcı henüz göndermediği yazısını kaybederdi.
  ///
  /// Exception FIRLATMAZ (TR-C-02): ağ hatası beklenen bir durum ve
  /// `try/catch` zorunluluğunu çağırana yıkmıyoruz.
  Future<Result<SyncOutcome>> syncNow();
}
