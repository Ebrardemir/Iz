using Iz.Application.Abstractions;
using Iz.Domain.Sync;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Iz.Infrastructure.Persistence.Interceptors;

/// <summary>
/// Senkronize edilen her yazmayı <c>change_log</c>'a düşürür — AYNI
/// <c>SaveChanges</c> çağrısının içinde, yani aynı transaction'da.
/// </summary>
/// <remarks>
/// YOL HARİTASI §3.1'İN EN SERT KURALI BURADA UYGULANIYOR:
/// "change_log'a yazma, entity yazmasıyla aynı transaction içinde olur.
/// Aksi hâlde bir değişiklik kalıcı olur ama günlüğe düşmez → o kayıt hiçbir
/// cihaza gitmez, sessizce kaybolur."
///
/// NEDEN INTERCEPTOR, HER USE-CASE'DE ELLE DEĞİL?
/// Elle yazsaydık kural "hatırlanması gereken" olurdu. On dört varlık ve
/// önümüzdeki aylarda eklenecek her yeni yazma yolu için biri bir gün
/// unutur; sonucu da hata mesajı değil, ikinci cihazda hiç belirmeyen bir
/// anı olur. Kuralı buraya koyunca UNUTULAMIYOR: <see cref="ISyncable"/>
/// uygulayan bir kayıt yazıldığı anda günlük satırı da yazılıyor.
///
/// Aynı düşüncenin bir başka örneği <c>IzDbContext</c>'teki IDOR süzgeci:
/// "güvenlik kuralının hatırlanması gereken değil unutulamayan olması
/// gerekir".
///
/// SIRALAMA: <see cref="SavingChangesAsync"/> kaydetmeden ÖNCE çalışıyor ve
/// günlük satırlarını aynı <c>ChangeTracker</c>'a ekliyor. EF ikisini tek
/// komut kümesinde, tek transaction'da gönderiyor.
/// </remarks>
public sealed class ChangeLogInterceptor(IClock clock, ISyncOrigin origin) : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        if (eventData.Context is not null)
        {
            Append(eventData.Context);
        }

        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    /// <summary>
    /// Eşzamanlı (senkron) yol da kapalı olmak zorunda.
    /// </summary>
    /// <remarks>
    /// Uygulama her yerde <c>SaveChangesAsync</c> kullanıyor ama biri bir
    /// gün <c>SaveChanges</c> çağırırsa günlük sessizce boş kalırdı. İki
    /// kapıdan yalnız birini kilitlemek, kilitlememektir.
    /// </remarks>
    public override InterceptionResult<int> SavingChanges(
        DbContextEventData eventData,
        InterceptionResult<int> result)
    {
        if (eventData.Context is not null)
        {
            Append(eventData.Context);
        }

        return base.SavingChanges(eventData, result);
    }

    private void Append(DbContext context)
    {
        var now = clock.UtcNow;

        // ÖNCE LİSTEYE ALINIYOR: aşağıda yeni satırlar ekleniyor ve
        // ChangeTracker üzerinde gezerken ona eklemek istisna atardı.
        var changed = context.ChangeTracker
            .Entries<ISyncable>()
            .Where(entry => entry.State is EntityState.Added or EntityState.Modified)
            .ToList();

        foreach (var entry in changed)
        {
            context.Add(BuildEntry(entry, now));
        }
    }

    private ChangeLogEntry BuildEntry(EntityEntry<ISyncable> entry, DateTimeOffset now)
    {
        var entity = entry.Entity;

        return new ChangeLogEntry
        {
            UserId = entity.OwnerId,
            EntityType = entity.SyncEntityType,
            EntityId = entity.SyncId,

            // TOMBSTONE SİLMEDİR. `deletedAt` dolu bir kaydı "güncellendi"
            // diye bildirseydik, ikinci cihaz kaydı yazmaya devam eder ve
            // silme hiç uygulanmazdı.
            Operation = entity.DeletedAt is null
                ? ChangeOperation.Upsert
                : ChangeOperation.Delete,

            // DEĞİŞİMDEN SONRAKİ sürüm: istemci bunu kendi kaydına yazıyor ve
            // bir sonraki push'ta `baseVersion` olarak geri gönderiyor.
            Version = entity.Version,

            // Saat ENJEKTE (IClock): çakışma çözümü ve sıralama zamana bağlı
            // kararlar, testte sabitlenebilmeleri gerekiyor.
            ChangedAt = now,

            // Echo önleme. `null` = bir cihazdan gelmedi (arka plan işi);
            // o satır herkese gider.
            DeviceId = origin.DeviceId,
        };
    }
}
