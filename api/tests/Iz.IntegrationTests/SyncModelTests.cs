using Iz.Domain.Sync;
using Iz.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.IntegrationTests;

/// <summary>
/// Senkronize edilen modelin uyması gereken kurallar.
/// </summary>
/// <remarks>
/// Bu testler tek tek davranış sınamıyor; MODELİN TAMAMINI tarayıp bir
/// kuralın her tabloda tutulduğunu doğruluyor. Sebebi somut: yeni bir
/// senkronize tablo eklerken sorgu süzgecini yazmayı unutmak derlenir,
/// çalışır ve sonucu başka bir kullanıcının verisini döndürmektir (IDOR).
/// Böyle bir hatayı yakalayacak tek şey, kuralı tek tek değil TOPLUCA
/// denetleyen bir testtir.
/// </remarks>
[Collection(IzApiCollection.Name)]
public sealed class SyncModelTests(IzApiFactory factory)
{
    private IReadOnlyList<Microsoft.EntityFrameworkCore.Metadata.IEntityType> SyncableTypes()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var types = db.Model.GetEntityTypes()
            .Where(t => typeof(ISyncable).IsAssignableFrom(t.ClrType))
            .ToList();

        // BOS LISTE BUTUN KORUMA TESTLERINI BOSUNA GECIRIR. Bir yeniden
        // adlandirma ya da yanlis bir DbSet, taramayi sessizce sifir tabloya
        // dusurebilir ve asagidaki dort test yesil yanmaya devam ederdi.
        Assert.True(
            types.Count > 0,
            "Hicbir ISyncable tablo bulunamadi; model taramasi bos calisiyor.");

        return types;
    }

    [Fact]
    public void Senkronize_her_tablonun_SAHIPLIK_suzgeci_var()
    {
        // TR-M14-22 / §7.2 — IDOR'a karsi ikinci hat. Repository zaten
        // userId ile sorguluyor; bu suzgec onun YERINE degil USTUNE geciyor.
        var suzgecsiz = SyncableTypes()
            .Where(t => t.GetQueryFilter() is null)
            .Select(t => t.ClrType.Name)
            .ToList();

        Assert.True(
            suzgecsiz.Count == 0,
            "Sorgu suzgeci olmayan senkronize tablo(lar): " + string.Join(", ", suzgecsiz) +
            ". IzDbContext.OnModelCreating icinde HasQueryFilter ekle.");
    }

    [Fact]
    public void Senkronize_her_tablo_SAHIP_indeksi_tasiyor()
    {
        // Pull'un sicak yolu sahiple suzuyor; indekssiz bir tablo 2.000
        // kayitta tam tarama demek (NFR-003).
        var indekssiz = SyncableTypes()
            .Where(t => !t.GetIndexes().Any(i =>
                i.Properties.Any(p => p.Name == nameof(ISyncable.OwnerId))))
            .Select(t => t.ClrType.Name)
            .ToList();

        Assert.True(
            indekssiz.Count == 0,
            "Sahip indeksi olmayan tablo(lar): " + string.Join(", ", indekssiz));
    }

    [Fact]
    public void Hesaplanan_senkronizasyon_alanlari_SUTUN_DEGIL()
    {
        // `SyncEntityType` ve `SyncId` mevcut sutunlardan turetiliyor.
        // Saklansalardi ayni bilgi iki yerde durur ve bir gun ayrisirdi.
        var sizanlar = SyncableTypes()
            .SelectMany(t => t.GetProperties()
                .Where(p => p.Name is nameof(ISyncable.SyncEntityType) or nameof(ISyncable.SyncId))
                .Select(p => $"{t.ClrType.Name}.{p.Name}"))
            .ToList();

        Assert.True(
            sizanlar.Count == 0,
            "Sutun olarak eslenmis hesaplanan alan(lar): " + string.Join(", ", sizanlar));
    }

    [Fact]
    public void Tombstone_sutunu_suzgece_KONMAMIS()
    {
        // Bu testin ters yonu var: burada bir seyin OLMADIGINI doğruluyoruz.
        // `deletedAt` suzgece konsaydi pull silmeyi hic goremez, ikinci
        // cihazda kayit sonsuza kadar yasardi (bkz. ISyncable.DeletedAt).
        var suzgecler = SyncableTypes()
            .Select(t => t.GetQueryFilter()?.ToString() ?? string.Empty)
            .Where(f => f.Contains("DeletedAt", StringComparison.Ordinal))
            .ToList();

        Assert.True(
            suzgecler.Count == 0,
            "Tombstone suzgeci bulundu; senkronizasyon silmeyi tasiyamaz: " +
            string.Join(" | ", suzgecler));
    }

    [Fact]
    public void Butun_varliklar_kendi_TUR_ADINI_sozlukte_bildiriyor()
    {
        // Tur adlari sunucu ile istemci arasindaki sozlesme ve DEGISMEZ.
        // Yeni bir varlik sozlukte olmayan bir ad dondururse push onu
        // tanimaz ve degisiklik sessizce duser.
        var bilinmeyen = new List<string>();

        foreach (var type in SyncableTypes())
        {
            var ornek = (ISyncable)System.Runtime.CompilerServices
                .RuntimeHelpers.GetUninitializedObject(type.ClrType);

            if (!SyncEntityTypes.All.Contains(ornek.SyncEntityType))
            {
                bilinmeyen.Add($"{type.ClrType.Name} -> {ornek.SyncEntityType}");
            }
        }

        Assert.True(
            bilinmeyen.Count == 0,
            "SyncEntityTypes.All icinde olmayan tur(ler): " + string.Join(", ", bilinmeyen));
    }
}
