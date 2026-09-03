using Iz.Application.Users;
using Iz.Domain.Users;
using Microsoft.EntityFrameworkCore;

namespace Iz.Infrastructure.Persistence;

public sealed class UserRepository(IzDbContext dbContext) : IUserRepository
{
    public Task<User?> FindByFirebaseUidAsync(string firebaseUid, CancellationToken cancellationToken)
        => dbContext.Users.SingleOrDefaultAsync(u => u.FirebaseUid == firebaseUid, cancellationToken);

    public Task<User?> FindByIdAsync(Guid id, CancellationToken cancellationToken)
        => dbContext.Users.SingleOrDefaultAsync(u => u.Id == id, cancellationToken);

    public void Add(User user) => dbContext.Users.Add(user);
}
