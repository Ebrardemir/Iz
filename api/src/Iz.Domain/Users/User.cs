namespace Iz.Domain.Users;

/// <summary>
/// Hesabı olan kullanıcı. Uygulamayı hesapsız kullanan kişinin burada
/// karşılığı YOKTUR (ADR-B12) — hesap yalnız bulut isteyende açılır.
/// </summary>
public sealed class User
{
    /// <summary>
    /// BİZİM kimliğimiz (UUID v7). İstemcideki <c>ownerId</c> bu değeri alır.
    /// </summary>
    /// <remarks>
    /// NEDEN Firebase <c>uid</c>'sini birincil anahtar YAPMIYORUZ?
    /// Yapsaydık her satırın sahipliği bir kimlik sağlayıcısının iç
    /// kimliğine bağlanırdı; Firebase'den çıktığımız gün tüm veri
    /// taşınamaz hale gelirdi. Bugün maliyeti bir sütun, yarın kurtardığı
    /// şey göç edilebilirlik. ADR-B15'in duruşu da bu:
    /// "kimlik DOĞRULAMASI Google'da, kimlik KARARI bizde".
    /// </remarks>
    public required Guid Id { get; init; }

    /// <summary>
    /// Firebase Authentication kullanıcı kimliği — hesabın giriş anahtarı.
    /// </summary>
    /// <remarks>
    /// TR-M1-05: bu değer YALNIZ doğrulanmış ID token'ın <c>sub</c> alanından
    /// okunur. İstemcinin gövdede gönderdiği bir <c>uid</c> asla kabul edilmez.
    /// </remarks>
    public required string FirebaseUid { get; init; }

    /// <summary>
    /// E-posta. Tek gerçek kaynak Firebase'dir; burada hesap silme ve destek
    /// için bir kopyası tutulur (TR-M1-06).
    /// </summary>
    public string? Email { get; set; }

    public string? DisplayName { get; set; }

    /// <summary>BCP-47 dil etiketi (<c>tr-TR</c>, <c>en-US</c>).</summary>
    public string? Locale { get; set; }

    /// <summary>
    /// Plan önbelleği. Sync push'ta limit kontrolünü tek sorguda yapmak için
    /// <c>subscriptions</c> tablosundan denormalize edilir (Faz 4).
    /// </summary>
    public IzPlan PlanCache { get; set; } = IzPlan.Free;

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    /// <summary>
    /// Hesap silme talebinin alındığı an. Dolu olduğu 30 gün boyunca kullanıcı
    /// vazgeçebilir (TR-M1-15 / FR-007); süre dolunca kalıcı silme işi çalışır.
    /// </summary>
    public DateTimeOffset? DeletionRequestedAt { get; set; }

    /// <summary>
    /// Tombstone. Dolu olan kullanıcı hiçbir sorguda görünmez.
    /// </summary>
    public DateTimeOffset? DeletedAt { get; set; }
}
