using Iz.Domain.Sync;

namespace Iz.Domain.Categories;

/// <summary>Anının genel teması (FR-070).</summary>
/// <remarks>
/// SİSTEM KATEGORİLERİ DE SENKRONİZE OLUYOR. İlk bakışta gereksiz görünüyor
/// — her cihaz onları kendi kurulumunda tohumluyor. Ama kullanıcı bir
/// sistem kategorisini gizleyebiliyor ya da sırasını değiştirebiliyor
/// (FR-070); o kararlar da onun verisi ve ikinci cihazda da geçerli olmalı.
/// </remarks>
public sealed class Category : ISyncable
{
    public required Guid Id { get; init; }

    /// <summary>
    /// ⚠️ [IsSystem] true ise burada AD DEĞİL, bir ÇEVİRİ ANAHTARI durur
    /// (<c>travel</c>, <c>family</c>…).
    /// </summary>
    /// <remarks>
    /// Sistem kategorilerinin adı dile göre değişiyor; veritabanına Türkçe
    /// yazsaydık İngilizce arayüzde de Türkçe görünürdü. Sunucu bu ayrımı
    /// bilmek zorunda DEĞİL — yalnız metni taşıyor — ama bir gün sunucuda
    /// arama yazan biri "neden 'travel' yazıyor" diye sormasın diye burada
    /// duruyor.
    /// </remarks>
    public required string Name { get; set; }

    public string IconKey { get; set; } = "daily";

    public int SortOrder { get; set; }

    public bool IsSystem { get; set; }

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.Category;

    public string SyncId => Id.ToString();
}
