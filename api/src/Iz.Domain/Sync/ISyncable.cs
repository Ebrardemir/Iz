namespace Iz.Domain.Sync;

/// <summary>
/// Cihazlarla senkronize edilen her kaydın taşıdığı ortak alanlar.
/// </summary>
/// <remarks>
/// İstemcideki <c>SyncableTable</c> mixin'inin (core/database/table_mixins.dart)
/// sunucu karşılığı. İki taraf AYNI modeli paylaşıyor (yol haritası §3);
/// ayrışırlarsa push/pull her seferinde çeviri yapmak zorunda kalır ve o
/// çeviri bir gün bir alanı sessizce düşürür.
///
/// NEDEN ARAYÜZ, ORTAK ATA SINIF DEĞİL?
/// EF Core ata sınıfları bir kalıtım hiyerarşisi sanıp TPH eşlemesi kurmaya
/// çalışıyor: tek tabloda ayırt edici sütun. Bizim istediğimiz bu değil —
/// on dört ayrı tablo. Arayüz EF'in eşleme kararlarına hiç karışmıyor,
/// ortak yapılandırma ise <c>SyncableConfiguration</c> ile veriliyor.
///
/// <see cref="ChangeLogInterceptor"/> bu arayüzü uygulayan HER kaydı
/// otomatik olarak <c>change_log</c>'a düşürür.
/// </remarks>
public interface ISyncable
{
    /// <summary>
    /// Bu kaydın <c>change_log</c>'daki tür adı. Bkz. <see cref="SyncEntityTypes"/>.
    /// </summary>
    /// <remarks>
    /// NEDEN HER VARLIK KENDİSİ SÖYLÜYOR, tip → ad eşlemesi bir sözlükte
    /// DEĞİL? Sözlük olsaydı yeni bir varlık eklemek DERLENİRDİ ve hata
    /// ancak çalışma anında, o varlık ilk kez yazıldığında ortaya çıkardı —
    /// üstelik sessizce: günlüğe düşmeyen değişiklik hiçbir cihaza gitmez.
    /// Arayüzün parçası olunca eklemeyi unutmak derleme hatası.
    /// </remarks>
    string SyncEntityType { get; }

    /// <summary>
    /// Bu kaydın <c>change_log.entity_id</c> değeri.
    /// </summary>
    /// <remarks>
    /// Ana kayıtlarda <c>Id</c>'nin metni; bağlarda iki kimliğin birleşimi
    /// (<see cref="SyncEntityTypes.LinkId"/>). Birincil anahtardan
    /// yansımayla türetmiyoruz: bileşik anahtarın SIRASI kimliği belirliyor
    /// ve o sıra yapılandırma dosyasında bir kez yanlış yazılırsa, kimlik
    /// sessizce ters döner.
    /// </remarks>
    string SyncId { get; }

    /// <summary>
    /// Kaydın sahibi. Her sorgunun süzgeci ve <c>change_log</c>'un kapsamı bu.
    /// </summary>
    /// <remarks>
    /// BAĞ TABLOLARINDA DA VAR — istemcide yok. Sunucuda gerekli çünkü
    /// (a) IDOR'a karşı global sorgu süzgeci bir sahip sütunu istiyor,
    /// (b) <c>change_log</c> kullanıcı başına sıralanıyor. Bağın sahibini
    /// her seferinde ana kayda join yaparak bulmak, güvenliğin en sıcak
    /// yolunu en pahalı yol yapardı.
    /// </remarks>
    Guid OwnerId { get; }

    /// <summary>
    /// Her yazmada +1 — çakışma tespitinin dayanağı (TR-C-31).
    /// </summary>
    /// <remarks>
    /// İstemci push'ta <c>baseVersion</c> gönderiyor: "ben şu sürümü
    /// biliyordum". Buradaki değer ondan büyükse araya biri girmiş demektir
    /// ve sunucu KENDİLİĞİNDEN EZMEZ (yol haritası §4.1).
    /// </remarks>
    int Version { get; set; }

    DateTimeOffset CreatedAt { get; }

    DateTimeOffset UpdatedAt { get; set; }

    /// <summary>
    /// Tombstone. Fiziksel silme yok (yol haritası §4.5).
    /// </summary>
    /// <remarks>
    /// ⚠️ Bu sütun sorgu süzgecine KONMUYOR — <c>users</c> tablosundakinin
    /// aksine. Sebep: senkronizasyonun asıl işlerinden biri "bu kayıt
    /// silindi" haberini taşımak. Silinmiş satırı sorgudan gizleseydik pull
    /// silmeyi hiç göremez, ikinci cihazda kayıt sonsuza kadar yaşardı.
    /// Silinmişi ayıklamak SORGUNUN işi, şemanın değil.
    /// </remarks>
    DateTimeOffset? DeletedAt { get; set; }
}
