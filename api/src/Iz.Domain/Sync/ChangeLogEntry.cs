namespace Iz.Domain.Sync;

/// <summary>
/// Senkronizasyonun kalbi: kullanıcı başına monoton artan değişiklik günlüğü.
/// </summary>
/// <remarks>
/// NEDEN AYRI TABLO? (yol haritası §3.1)
/// Pull'daki "şu noktadan sonrasını ver" sorgusunu her tabloyu
/// <c>updated_at &gt; x</c> ile tarayarak yapmanın iki sorunu var:
///   (a) her varlık için ayrı indeks taraması,
///   (b) SIRALAMA GARANTİSİ YOK — iki tablodaki aynı milisaniyeli değişikliğin
///       hangi sırayla uygulanacağı belirsiz kalır.
///
/// <see cref="Seq"/> tek bir monoton sıra veriyor. Cursor = son görülen
/// <c>seq</c>. Sıra deterministik, sorgu tek indeks, sayfalama basit.
///
/// SİLMELERİ İFADE EDEBİLMESİ de en az bunun kadar önemli: tabloları tarayan
/// bir yaklaşımda silinmiş satır YOK ve "silindi" bilgisi hiçbir cihaza
/// gidemez. Günlük, silmeyi bir SATIR olarak saklıyor.
///
/// GÜNLÜĞE YAZMA, VERİ YAZMASIYLA AYNI TRANSACTION'DA olmak zorunda. Bu kural
/// hatırlanmaya bırakılmıyor: <c>ChangeLogInterceptor</c> satırları
/// <c>SaveChanges</c> sırasında kendisi üretiyor, yani unutulamıyor.
/// </remarks>
public sealed class ChangeLogEntry
{
    /// <summary>
    /// Sıra numarası — <c>bigserial</c>, VERİTABANI üretir.
    /// </summary>
    /// <remarks>
    /// Uygulama üretseydi iki eşzamanlı istek aynı numarayı alabilir, ya da
    /// numara atlanabilirdi; cursor'lı sayfalamada bunun bedeli sessizce
    /// atlanan bir değişikliktir.
    ///
    /// ⚠️ GLOBAL, kullanıcı başına DEĞİL. Kullanıcı başına ayrı sayaç
    /// tutmak her yazmada o kullanıcının satırını kilitlemek demekti.
    /// Cursor'ın anlamlı olması için numaraların ARDIŞIK olması gerekmiyor,
    /// yalnız ARTAN olması yeterli — sorgu zaten <c>user_id</c> ile
    /// süzülüyor.
    /// </remarks>
    public long Seq { get; init; }

    /// <summary>Günlüğün kapsamı. Pull bununla süzülüyor.</summary>
    public required Guid UserId { get; init; }

    /// <summary>Bkz. <see cref="SyncEntityTypes"/>.</summary>
    public required string EntityType { get; init; }

    /// <summary>
    /// Değişen kaydın kimliği. Bağlarda <see cref="SyncEntityTypes.LinkId"/>
    /// biçiminde bileşik bir metin.
    /// </summary>
    /// <remarks>
    /// <c>Guid</c> DEĞİL <c>string</c>: bağların kimliği iki UUID'nin
    /// birleşimi ve tek bir Guid'e sığmıyor. Türü daraltmak, tabloyu
    /// bağlar için kullanılamaz hale getirirdi.
    /// </remarks>
    public required string EntityId { get; init; }

    public required ChangeOperation Operation { get; init; }

    /// <summary>Değişimden SONRAKİ sürüm. İstemci bunu kendi kaydına yazar.</summary>
    public required int Version { get; init; }

    public required DateTimeOffset ChangedAt { get; init; }

    /// <summary>
    /// Değişikliği gönderen cihaz — echo önleme (yol haritası §4.2).
    /// </summary>
    /// <remarks>
    /// Pull yanıtında istemci kendi <c>deviceId</c>'sinden gelen satırları
    /// atlıyor: az önce kendi gönderdiği değişikliği geri alıp yeniden
    /// uygulaması hem gereksiz iş hem de kullanıcının o sırada yaptığı yeni
    /// düzenlemeyi ezme riski.
    ///
    /// <c>null</c> olabilir: arka plan işleri ve yönetim işlemleri bir
    /// cihazdan gelmiyor. O satırlar herkese gider — doğrusu da bu.
    /// </remarks>
    public Guid? DeviceId { get; init; }
}
