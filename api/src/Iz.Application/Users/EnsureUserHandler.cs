using Iz.Application.Abstractions;
using Iz.Domain.Users;

namespace Iz.Application.Users;

/// <summary>
/// Doğrulanmış bir kimlikten kullanıcı kaydını getirir; yoksa açar.
/// </summary>
/// <remarks>
/// AYRI BİR "KAYIT OL" UCU NEDEN YOK? Kayıt işini Firebase yapıyor (ADR-B15).
/// Bize ilk kez geçerli bir token geldiğinde kullanıcı zaten var demektir;
/// bizim tarafta eksik olan tek şey ona ait satırdır. Onu da ilk istekte
/// açıyoruz. Böylece "Firebase'de var ama bizde yok" diye bir ara durum
/// hiç oluşmuyor — o ara durum, kayıt akışının yarıda kesildiği her yerde
/// oluşurdu ve kullanıcı verisi sahipsiz kalırdı.
/// </remarks>
public sealed class EnsureUserHandler(
    IUserRepository users,
    IUnitOfWork unitOfWork,
    IClock clock)
{
    public async Task<User> HandleAsync(
        AuthenticatedIdentity identity,
        CancellationToken cancellationToken)
    {
        var existing = await users.FindByFirebaseUidAsync(identity.FirebaseUid, cancellationToken);
        if (existing is not null)
        {
            await RefreshEmailCopyAsync(existing, identity, cancellationToken);
            return existing;
        }

        var now = clock.UtcNow;
        var user = new User
        {
            // TR-C-40 ile aynı karar: UUID v7. Zaman sıralı olduğu için
            // birincil anahtar indeksi rastgele UUID'deki gibi parçalanmıyor.
            Id = Guid.CreateVersion7(now),
            FirebaseUid = identity.FirebaseUid,
            Email = identity.Email,
            DisplayName = identity.DisplayName,
            CreatedAt = now,
            UpdatedAt = now,
        };

        users.Add(user);

        try
        {
            await unitOfWork.SaveChangesAsync(cancellationToken);
            return user;
        }
        catch (UniqueConstraintException)
        {
            // Aynı kullanıcının iki isteği aynı anda geldi ve ikisi de
            // "yok, açayım" dedi. Kaybeden taraf kazananın açtığı satırı
            // okur. Bunu önce SELECT edip sonra INSERT ederek çözemeyiz:
            // iki sorgu arasında her zaman bir pencere kalır. Doğru çözüm
            // veritabanının benzersizlik kısıtına güvenip ihlali ele almaktır.
            var winner = await users.FindByFirebaseUidAsync(identity.FirebaseUid, cancellationToken);
            if (winner is null)
            {
                // Kısıt ihlali oldu ama kaydı bulamıyoruz: ihlal başka bir
                // kısıttan geliyor demektir. Yutmak yerine yükseltiyoruz.
                throw;
            }

            return winner;
        }
    }

    /// <summary>
    /// Firebase'deki e-posta değişmişse bizdeki kopyayı tazeler (TR-M1-06).
    /// </summary>
    private async Task RefreshEmailCopyAsync(
        User user,
        AuthenticatedIdentity identity,
        CancellationToken cancellationToken)
    {
        if (identity.Email is null || string.Equals(user.Email, identity.Email, StringComparison.Ordinal))
        {
            return;
        }

        user.Email = identity.Email;
        user.UpdatedAt = clock.UtcNow;
        await unitOfWork.SaveChangesAsync(cancellationToken);
    }
}
