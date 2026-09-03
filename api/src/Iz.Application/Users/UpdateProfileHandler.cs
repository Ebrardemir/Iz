using Iz.Application.Abstractions;
using Iz.Domain.Users;

namespace Iz.Application.Users;

/// <summary>Profil alanlarını günceller (FR-003).</summary>
public sealed class UpdateProfileHandler(
    IUserRepository users,
    IUnitOfWork unitOfWork,
    IClock clock)
{
    /// <summary>Görünen ad üst sınırı. İstemcideki form doğrulamasıyla aynı olmalı.</summary>
    public const int DisplayNameMaxLength = 100;

    /// <summary>BCP-47 etiketi için makul üst sınır (<c>zh-Hant-TW</c> = 11).</summary>
    public const int LocaleMaxLength = 16;

    /// <param name="patch">
    /// Yalnız DOLU alanlar uygulanır. <c>null</c> "değiştirme" demektir,
    /// "boşalt" demek değil — PATCH semantiği budur.
    /// </param>
    public async Task<User> HandleAsync(
        Guid userId,
        ProfilePatch patch,
        CancellationToken cancellationToken)
    {
        var user = await users.FindByIdAsync(userId, cancellationToken)
            ?? throw new AppValidationException("user_not_found");

        if (patch.DisplayName is { } displayName)
        {
            var trimmed = displayName.Trim();
            if (trimmed.Length > DisplayNameMaxLength)
            {
                throw new AppValidationException("display_name_too_long", field: "displayName");
            }

            // Boş dize "adımı kaldır" demektir; veritabanında "" değil null durur.
            user.DisplayName = trimmed.Length == 0 ? null : trimmed;
        }

        if (patch.Locale is { } locale)
        {
            var trimmed = locale.Trim();
            if (trimmed.Length > LocaleMaxLength)
            {
                throw new AppValidationException("locale_invalid", field: "locale");
            }

            user.Locale = trimmed.Length == 0 ? null : trimmed;
        }

        user.UpdatedAt = clock.UtcNow;
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return user;
    }
}

/// <summary>Profil güncelleme isteği. <c>null</c> alan = dokunma.</summary>
public sealed record ProfilePatch(string? DisplayName, string? Locale);
