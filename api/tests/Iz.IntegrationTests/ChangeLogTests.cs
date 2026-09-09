using Iz.Domain.Memories;
using Iz.Domain.Sync;
using Iz.Domain.Users;
using Iz.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Iz.IntegrationTests;

/// <summary>
/// <c>change_log</c> — senkronizasyonun kalbi (yol haritası §3.1).
/// </summary>
/// <remarks>
/// BURADAKİ TESTLER YAYIN DURDURUCUDUR. Günlüğe düşmeyen bir değişiklik
/// kalıcı olur ama hiçbir cihaza gitmez: kullanıcı anısını yazar, ikinci
/// cihazında hiç görmez ve bir hata mesajı da almaz. Sessiz veri kaybının
/// bu projedeki en olası biçimi bu.
///
/// GERÇEK PostgreSQL üzerinde koşuyor: <c>bigserial</c> sırası, bileşik
/// anahtarlar ve cascade davranışı bellek içi sağlayıcıda yok.
/// </remarks>
[Collection(IzApiCollection.Name)]
public sealed class ChangeLogTests(IzApiFactory factory)
{
    /// <summary>Testin kendi kullanıcısı — kayıtlar birbirine değmesin.</summary>
    private static async Task<Guid> YeniKullaniciAsync(IzDbContext db)
    {
        var user = new User
        {
            Id = Guid.CreateVersion7(),
            FirebaseUid = $"test-{Guid.NewGuid():N}",
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user.Id;
    }

    private static Memory YeniAni(Guid ownerId, string? title = "Kahve Molasi") => new()
    {
        Id = Guid.CreateVersion7(),
        OwnerId = ownerId,
        Title = title,
        OccurredAt = new DateTimeOffset(2026, 3, 12, 10, 0, 0, TimeSpan.Zero),
        OccurredYear = 2026,
        OccurredMonth = 3,
        OccurredDay = 12,
        CreatedAt = DateTimeOffset.UtcNow,
        UpdatedAt = DateTimeOffset.UtcNow,
        Version = 1,
    };

    private static async Task<List<ChangeLogEntry>> GunlukAsync(IzDbContext db, Guid userId) =>
        await db.ChangeLog
            .Where(e => e.UserId == userId)
            .OrderBy(e => e.Seq)
            .ToListAsync();

    [Fact]
    public async Task Yeni_kayit_gunluge_UPSERT_olarak_dusuyor()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var userId = await YeniKullaniciAsync(db);
        var ani = YeniAni(userId);

        db.Memories.Add(ani);
        await db.SaveChangesAsync();

        var gunluk = await GunlukAsync(db, userId);
        var satir = Assert.Single(gunluk);

        Assert.Equal(SyncEntityTypes.Memory, satir.EntityType);
        Assert.Equal(ani.Id.ToString(), satir.EntityId);
        Assert.Equal(ChangeOperation.Upsert, satir.Operation);
        Assert.Equal(1, satir.Version);
    }

    [Fact]
    public async Task Tombstone_gunluge_DELETE_olarak_dusuyor()
    {
        // Kritik ayrim: silinmis bir kaydi "guncellendi" diye bildirseydik
        // ikinci cihaz onu yazmaya devam eder, silme hic uygulanmazdi.
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var userId = await YeniKullaniciAsync(db);
        var ani = YeniAni(userId);
        db.Memories.Add(ani);
        await db.SaveChangesAsync();

        ani.DeletedAt = DateTimeOffset.UtcNow;
        ani.Version = 2;
        await db.SaveChangesAsync();

        var gunluk = await GunlukAsync(db, userId);
        Assert.Equal(2, gunluk.Count);
        Assert.Equal(ChangeOperation.Upsert, gunluk[0].Operation);
        Assert.Equal(ChangeOperation.Delete, gunluk[1].Operation);
        Assert.Equal(2, gunluk[1].Version);
    }

    [Fact]
    public async Task Silinen_kayit_SORGUDA_DURUYOR_gizlenmiyor()
    {
        // `users` tablosunun aksine tombstone suzgeci YOK ve bu bilincli:
        // pull'un isi silmeyi TASIMAK. Gizleseydik ikinci cihaz silmeyi hic
        // ogrenemez, kayit orada sonsuza kadar yasardi.
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var userId = await YeniKullaniciAsync(db);
        var ani = YeniAni(userId);
        db.Memories.Add(ani);
        await db.SaveChangesAsync();

        ani.DeletedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync();

        // Sahiplik suzgeci kullanicisiz baglamda hicbir sey gecirmiyor;
        // testin sorusu tombstone hakkinda, o yuzden atliyoruz.
        var okunan = await db.Memories
            .IgnoreQueryFilters()
            .SingleOrDefaultAsync(m => m.Id == ani.Id);

        Assert.NotNull(okunan);
        Assert.NotNull(okunan.DeletedAt);
    }

    [Fact]
    public async Task Baglar_da_gunluge_dusuyor_ve_kimlikleri_BILESIK()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var userId = await YeniKullaniciAsync(db);
        var ani = YeniAni(userId);
        db.Memories.Add(ani);
        await db.SaveChangesAsync();

        var kisiId = Guid.CreateVersion7();
        db.MemoryPeople.Add(new MemoryPerson
        {
            MemoryId = ani.Id,
            PersonId = kisiId,
            OwnerId = userId,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
            Version = 1,
        });
        await db.SaveChangesAsync();

        var gunluk = await GunlukAsync(db, userId);
        var bag = gunluk.Last();

        Assert.Equal(SyncEntityTypes.MemoryPeople, bag.EntityType);
        // Bagin kendi UUID'si yok; kimligi cift.
        Assert.Equal($"{ani.Id}:{kisiId}", bag.EntityId);
    }

    [Fact]
    public async Task Seq_ARTIYOR_ve_cursor_sayfalamasi_calisiyor()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var userId = await YeniKullaniciAsync(db);

        for (var i = 0; i < 3; i++)
        {
            db.Memories.Add(YeniAni(userId, $"Ani {i}"));
            await db.SaveChangesAsync();
        }

        var gunluk = await GunlukAsync(db, userId);
        Assert.Equal(3, gunluk.Count);
        Assert.True(gunluk[0].Seq < gunluk[1].Seq);
        Assert.True(gunluk[1].Seq < gunluk[2].Seq);

        // Pull'un tek sorgusu: "su seq'ten sonrasi".
        var sonrasi = await db.ChangeLog
            .Where(e => e.UserId == userId && e.Seq > gunluk[0].Seq)
            .ToListAsync();

        Assert.Equal(2, sonrasi.Count);
    }

    [Fact]
    public async Task Gunluk_BASKA_kullanicinin_degisikligini_ICERMIYOR()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var birinci = await YeniKullaniciAsync(db);
        var ikinci = await YeniKullaniciAsync(db);

        db.Memories.Add(YeniAni(birinci));
        db.Memories.Add(YeniAni(ikinci));
        await db.SaveChangesAsync();

        var gunluk = await GunlukAsync(db, birinci);
        var satir = Assert.Single(gunluk);
        Assert.Equal(birinci, satir.UserId);
    }

    [Fact]
    public async Task Tek_SaveChanges_hem_veriyi_hem_gunlugu_yaziyor()
    {
        // YOL HARITASI §3.1'IN KURALI. Ikisi ayri transaction'da olsaydi
        // aradaki bir cokme degisikligi kalici yapar ama gunluge dusurmezdi:
        // kayit hicbir cihaza gitmez, sessizce kaybolurdu.
        //
        // Testin olctugu sey: interceptor gunluk satirini AYNI
        // ChangeTracker'a ekliyor, yani EF ikisini tek komut kumesinde
        // gonderiyor.
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var userId = await YeniKullaniciAsync(db);
        db.Memories.Add(YeniAni(userId));

        var yazilanSatirSayisi = await db.SaveChangesAsync();

        // 1 ani + 1 gunluk satiri.
        Assert.Equal(2, yazilanSatirSayisi);
    }

    [Fact]
    public async Task Gunluk_satiri_ELLE_yazilmiyor_interceptor_uretiyor()
    {
        // Kod hicbir yerde `db.ChangeLog.Add(...)` cagirmiyor. Bu test o
        // sozu koruyor: interceptor kaldirilirsa buradaki gunluk bos kalir
        // ve uc harflik bir duzenleme sessizce senkronizasyonu olduremez.
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IzDbContext>();

        var userId = await YeniKullaniciAsync(db);
        db.Memories.Add(YeniAni(userId));
        await db.SaveChangesAsync();

        Assert.NotEmpty(await GunlukAsync(db, userId));
    }
}
