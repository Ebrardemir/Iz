using Iz.Domain.Sync;
using Iz.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.IntegrationTests;

/// <summary>
/// Sunucu, istemcinin senkronize ettiği HER ŞEYİ karşılayabiliyor mu?
/// </summary>
/// <remarks>
/// Bu testin sorusu tek tek tablolar hakkında değil, KAPSAM hakkında.
/// İstemci bir varlık için push gönderdiğinde sunucuda karşılığı yoksa
/// değişiklik reddedilir ve o kullanıcının kuyruğu o satırda takılır —
/// hiçbir şey eşitlenmez ve kullanıcı sebebini asla öğrenemez.
///
/// Sözlük (<see cref="SyncEntityTypes"/>) ile modelin ayrışması, bu hatanın
/// en olası biçimi: biri sözlüğe yeni bir tür ekler, tabloyu eklemeyi
/// unutur. Aşağıdaki test ikisini KARŞILIKLI denetliyor.
/// </remarks>
[Collection(IzApiCollection.Name)]
public sealed class SyncCoverageTests(IzApiFactory factory)
{
    private HashSet<string> ModeldekiTurler()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var turler = db.Model.GetEntityTypes()
            .Where(t => typeof(ISyncable).IsAssignableFrom(t.ClrType))
            .Select(t => ((ISyncable)System.Runtime.CompilerServices
                .RuntimeHelpers.GetUninitializedObject(t.ClrType)).SyncEntityType)
            .ToHashSet(StringComparer.Ordinal);

        // Bos tarama butun karsilastirmalari bosuna gecirir.
        Assert.NotEmpty(turler);
        return turler;
    }

    [Fact]
    public void Sozlukteki_her_turun_bir_TABLOSU_var()
    {
        // Sozluge eklenip tablosu unutulan tur: push onu tanir, yazamaz.
        var eksik = SyncEntityTypes.All.Except(ModeldekiTurler()).ToList();

        Assert.True(
            eksik.Count == 0,
            "SyncEntityTypes.All icinde olup tablosu olmayan tur(ler): " +
            string.Join(", ", eksik));
    }

    [Fact]
    public void Modeldeki_her_turun_SOZLUKTE_karsiligi_var()
    {
        // Ters yon: tablosu olup sozlukte olmayan tur, push dogrulamasindan
        // gecemez ve o varlik hicbir zaman senkronize olmaz.
        var fazla = ModeldekiTurler().Except(SyncEntityTypes.All).ToList();

        Assert.True(
            fazla.Count == 0,
            "Modelde olup SyncEntityTypes.All icinde olmayan tur(ler): " +
            string.Join(", ", fazla));
    }

    [Fact]
    public void Istemcinin_ondort_tablosunun_hepsi_karsilaniyor()
    {
        // ISTEMCIDEKI LISTE, ELLE YAZILI. Model taramasindan turetseydik
        // test kendi kendini onaylardi: sunucudan bir tablo dusse liste de
        // duser ve karsilastirma yine gecerdi.
        //
        // Kaynak: iz/lib/app/database/app_database.dart -> @DriftDatabase
        // (Users ve senkronize edilmeyen FTS tablolari haric).
        string[] istemcidekiler =
        [
            SyncEntityTypes.Memory,
            SyncEntityTypes.Location,
            SyncEntityTypes.MediaItem,
            SyncEntityTypes.Category,
            SyncEntityTypes.Collection,
            SyncEntityTypes.Ritual,
            SyncEntityTypes.Person,
            SyncEntityTypes.MemoryPeople,
            SyncEntityTypes.MemoryCollections,
            SyncEntityTypes.MemoryRituals,
            SyncEntityTypes.RitualPeople,
            SyncEntityTypes.MemoryMedia,
            SyncEntityTypes.JournalEntry,
            SyncEntityTypes.JournalMedia,
        ];

        var model = ModeldekiTurler();
        var eksik = istemcidekiler.Where(t => !model.Contains(t)).ToList();

        Assert.True(
            eksik.Count == 0,
            "Istemcide olup sunucuda karsiligi olmayan tablo(lar): " +
            string.Join(", ", eksik));

        // Sayi da tutmali: sunucuda FAZLA bir senkronize tablo, istemcinin
        // hic gondermeyecegi olu bir tablo demek.
        Assert.Equal(istemcidekiler.Length, model.Count);
    }
}
