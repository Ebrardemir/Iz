using Iz.Application.Abstractions;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Iz.Infrastructure.Persistence;

/// <inheritdoc cref="IUnitOfWork"/>
public sealed class EfUnitOfWork(IzDbContext dbContext) : IUnitOfWork
{
    /// <summary>PostgreSQL "unique_violation" hata kodu.</summary>
    private const string UniqueViolation = "23505";

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken)
    {
        try
        {
            return await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException
        {
            SqlState: UniqueViolation,
        } postgres)
        {
            // Sağlayıcıya özgü hatayı burada, sınırda çeviriyoruz.
            // Application katmanı Npgsql'i tanımıyor ve tanımamalı —
            // veritabanını değiştirmek use-case'lere dokunmamalı.
            throw new UniqueConstraintException(postgres.ConstraintName ?? "bilinmeyen", ex);
        }
    }
}
