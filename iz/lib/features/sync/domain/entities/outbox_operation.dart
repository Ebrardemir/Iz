/// Bir kaydın sunucuya bildirilecek DEĞİŞİM TÜRÜ.
///
/// Metin değil enum: `payloadJson` içine gömülü bir dize olsaydı yazım
/// hatası çalışma anında, üstelik kuyruk boşaltılırken ortaya çıkardı.
library;

enum OutboxOperation {
  /// Yeni kayıt.
  create,

  /// Var olan kaydın alanları değişti.
  update,

  /// Tombstone — kayıt silindi.
  ///
  /// `delete` de bir DEĞİŞİKLİKTİR, yokluk değil: sunucuya "bu kaydı sil"
  /// diye gitmezse ikinci cihaz silmeyi hiç öğrenmez.
  delete,
}
