using Iz.Api.Authentication;
using Iz.Application.Users;
using Iz.Domain.Users;

namespace Iz.Api.Endpoints;

/// <summary>Profil uçları — FR-003, TRD M1.</summary>
public static class MeEndpoints
{
    public static IEndpointRouteBuilder MapMeEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/v1/me", (CurrentUserContext currentUser) =>
                Results.Ok(MeResponse.From(currentUser.Require())))
            .RequireAuthorization()
            .WithName("GetMe")
            .WithSummary("Oturum açmış kullanıcının profili ve plan özeti.")
            .WithTags("Me");

        app.MapPatch("/v1/me", async (
                UpdateProfileRequest request,
                CurrentUserContext currentUser,
                UpdateProfileHandler handler,
                CancellationToken cancellationToken) =>
            {
                var updated = await handler.HandleAsync(
                    currentUser.Require().Id,
                    new ProfilePatch(request.DisplayName, request.Locale),
                    cancellationToken);

                return Results.Ok(MeResponse.From(updated));
            })
            .RequireAuthorization()
            .WithName("UpdateMe")
            .WithSummary("Profil alanlarını günceller. Boş bırakılan alan değişmez.")
            .WithTags("Me");

        return app;
    }
}

/// <param name="Plan">
/// <c>free</c> · <c>plus</c> · <c>family</c>. İstemcideki <c>IzPlan.fromKey</c>
/// bu değeri okur. ADR-B08 gereği planın tek kaynağı sunucudur; istemci
/// RevenueCat SDK'sından plan okumaz (TR-M12-16).
/// </param>
public sealed record MeResponse(
    Guid Id,
    string? Email,
    string? DisplayName,
    string? Locale,
    string Plan,
    DateTimeOffset CreatedAt)
{
    public static MeResponse From(User user) => new(
        user.Id,
        user.Email,
        user.DisplayName,
        user.Locale,
        user.PlanCache.ToKey(),
        user.CreatedAt);
}

/// <summary><c>null</c> alan "değiştirme" demektir (PATCH semantiği).</summary>
public sealed record UpdateProfileRequest(string? DisplayName, string? Locale);
