/// Bir senkronizasyon turunun sonucu.
///
/// NEDEN SAYILAR, `bool başarılı` DEĞİL?
/// Bir tur "kısmen" başarılı olabiliyor ve bu normal: iki kayıt yazıldı,
/// biri çakıştı, biri reddedildi. Tek bir bayrak bu durumu ya "başarılı"
/// (çakışmayı gizler) ya "başarısız" (kullanıcıyı boşuna korkutur) diye
/// yalan söylerdi.
///
/// Yedekleme Sağlığı ekranı (FR-164) bu sayıları doğrudan gösteriyor.
library;

final class SyncOutcome {
  const SyncOutcome({
    this.pushed = 0,
    this.conflicted = 0,
    this.rejected = 0,
    this.pulled = 0,
    this.skipped = 0,
    this.pendingAfter = 0,
    this.cursor = 0,
  });

  /// Sunucuya yazılan değişiklik sayısı.
  final int pushed;

  /// Sunucudaki sürüm farklı çıktı; kullanıcıya sorulacak.
  final int conflicted;

  /// Sunucu işleyemedi (tanınmayan tür, bozuk gövde…).
  final int rejected;

  /// Sunucudan indirilip yerele uygulanan kayıt sayısı.
  final int pulled;

  /// İnen ama UYGULANAMAYAN kayıt sayısı.
  ///
  /// Sıfırdan büyük olması bir arıza işareti: normalde her satır
  /// uygulanabilir. Sayıyı gizlemek yerine yüzeye çıkarıyoruz — sessizce
  /// atlanan bir kayıt, kullanıcının ikinci cihazında hiç belirmeyen bir anı
  /// demek.
  final int skipped;

  /// Turdan SONRA kuyrukta kalan satır sayısı.
  ///
  /// Sıfır değilse ya çakışma var ya ağ kesildi; ekran bunu "bekleyen öğe"
  /// olarak gösteriyor (TR-M11-13).
  final int pendingAfter;

  /// Ulaşılan pull cursor'ı.
  final int cursor;

  bool get hasWork => pushed + pulled + conflicted + rejected > 0;

  SyncOutcome copyWith({
    int? pushed,
    int? conflicted,
    int? rejected,
    int? pulled,
    int? skipped,
    int? pendingAfter,
    int? cursor,
  }) => SyncOutcome(
    pushed: pushed ?? this.pushed,
    conflicted: conflicted ?? this.conflicted,
    rejected: rejected ?? this.rejected,
    pulled: pulled ?? this.pulled,
    skipped: skipped ?? this.skipped,
    pendingAfter: pendingAfter ?? this.pendingAfter,
    cursor: cursor ?? this.cursor,
  );

  /// Yalnız LOG için — kullanıcıya gösterilmiyor, o yüzden çeviriden
  /// geçmiyor ve İngilizce (`features/*/data` altındaki log satırlarıyla
  /// aynı kural).
  @override
  String toString() =>
      'SyncOutcome(pushed: $pushed, conflicted: $conflicted, '
      'rejected: $rejected, pulled: $pulled, skipped: $skipped, '
      'pending: $pendingAfter, cursor: $cursor)';
}
