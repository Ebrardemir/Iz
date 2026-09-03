using Iz.Domain.Users;

namespace Iz.Application.Users;

public interface IUserRepository
{
    /// <summary>
    /// Silinmemiş kullanıcıyı Firebase kimliğiyle bulur.
    /// </summary>
    Task<User?> FindByFirebaseUidAsync(string firebaseUid, CancellationToken cancellationToken);

    Task<User?> FindByIdAsync(Guid id, CancellationToken cancellationToken);

    void Add(User user);
}
