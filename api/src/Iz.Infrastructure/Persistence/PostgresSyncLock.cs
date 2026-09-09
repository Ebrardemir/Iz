using Iz.Application.Sync;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Iz.Infrastructure.Persistence;

/// <inheritdoc cref="ISyncLock"/>
/// <remarks>
/// PostgreSQL'in <c>pg_advisory_xact_lock</c>'u kullanılıyor.
///
/// NEDEN TABLO ÜZERİNDE BİR SATIR KİLİDİ DEĞİL?
/// Kilitlenecek ortak bir satır yok: push on dört farklı tabloya yazıyor ve
/// bazen hiçbirine (hepsi çakışırsa). <c>users</c> satırını kilitlemek
/// işe yarardı ama o satırı push'la ilgisiz her istek de okuyor; oraya kilit
/// koymak profil güncellemesini push'un arkasında bekletirdi.
///
/// Advisory kilit VERİYE DEĞİL, BİR SAYIYA bağlı — tam da istediğimiz şey:
/// "bu kullanıcının push'u" diye soyut bir kaynağı kilitliyoruz.
///
/// <c>_xact_</c> EKİ ÖNEMLİ: kilit transaction bitince KENDİLİĞİNDEN
/// bırakılıyor. Elle bırakılan bir kilit (<c>pg_advisory_lock</c>) kullansaydık,
/// istisna yolunda bırakmayı unutan tek bir kod yolu o kullanıcının
/// senkronizasyonunu SONSUZA KADAR durdururdu — üstelik sunucu yeniden
/// başlatılana kadar.
/// </remarks>
internal sealed class PostgresSyncLock(IzDbContext context) : ISyncLock
{
    public async Task<ISyncLockHandle> AcquireAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var transaction = await context.Database.BeginTransactionAsync(cancellationToken);

        try
        {
            await context.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock({Anahtar(userId)})",
                cancellationToken);
        }
        catch
        {
            await transaction.DisposeAsync();
            throw;
        }

        return new Handle(transaction);
    }

    /// <summary>
    /// Kullanıcı kimliğini 64 bitlik kilit anahtarına indirger.
    /// </summary>
    /// <remarks>
    /// İKİ YARIM XOR'LANIYOR, ilk sekiz bayt DOĞRUDAN alınmıyor: kimlikler
    /// UUID v7 ve ilk baytları ZAMAN DAMGASI. Doğrudan alsaydık aynı saniyede
    /// açılan hesaplar aynı anahtara düşer ve birbirlerinin push'unu
    /// beklerlerdi.
    ///
    /// Çakışma yine de mümkün ama zararsız: iki ilgisiz kullanıcı sırayla
    /// işlenir, veri doğruluğu değişmez.
    /// </remarks>
    private static long Anahtar(Guid userId)
    {
        Span<byte> bytes = stackalloc byte[16];
        userId.TryWriteBytes(bytes);

        return BitConverter.ToInt64(bytes[..8]) ^ BitConverter.ToInt64(bytes[8..]);
    }

    private sealed class Handle(IDbContextTransaction transaction) : ISyncLockHandle
    {
        private bool _committed;

        public async Task CommitAsync(CancellationToken cancellationToken)
        {
            await transaction.CommitAsync(cancellationToken);
            _committed = true;
        }

        public async ValueTask DisposeAsync()
        {
            // COMMIT EDİLMEDİYSE GERİ AL. `DisposeAsync` zaten commit
            // edilmemiş bir transaction'ı geri sarıyor; yine de niyeti
            // açıkça yazıyoruz — bu satırın sessizce kaybolması, yarıda
            // kalan bir push'un yarım veri bırakması demek.
            if (!_committed)
            {
                await transaction.RollbackAsync();
            }

            await transaction.DisposeAsync();
        }
    }
}
