using Iz.Domain.Sync;

namespace Iz.Domain.Locations;

/// <summary>Anının geçtiği yer (FR-016).</summary>
/// <remarks>
/// KULLANICININ YAZDIĞI METİN bir satıra çevriliyor; koordinat OPSİYONEL.
/// Konum servisi izni olmadan da yer yazılabilmeli — kullanıcı "Anneannemin
/// bahçesi" diyebiliyor ve o, hiçbir haritada olmayan gerçek bir yer.
/// </remarks>
public sealed class Location : ISyncable
{
    public required Guid Id { get; init; }

    public required string Label { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    public string? City { get; set; }

    public string? Country { get; set; }

    public required Guid OwnerId { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int Version { get; set; }

    public string SyncEntityType => SyncEntityTypes.Location;

    public string SyncId => Id.ToString();
}
