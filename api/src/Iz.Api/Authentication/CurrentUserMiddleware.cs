using Iz.Application.Users;

namespace Iz.Api.Authentication;

/// <summary>
/// Doğrulanmış token'ı kendi kullanıcı kaydımıza bağlar.
/// </summary>
/// <remarks>
/// Kimlik doğrulamadan SONRA, uç noktadan ÖNCE çalışır. İşi tek cümleyle:
/// "bu token'ın sahibi bizde hangi satır?" — yoksa açar (bkz.
/// <see cref="EnsureUserHandler"/>).
///
/// Bunu her uç noktanın kendi içinde yapmıyoruz. Yapsaydık yeni bir uç
/// noktayı yazan kişi bir gün unuturdu ve o uç <c>ICurrentUser.UserId</c>'yi
/// boş görürdü — global sorgu süzgeci de sessizce hiçbir şey döndürmezdi.
/// Sessizce boş dönen bir uç, hata veren bir uçtan çok daha zor bulunur.
/// </remarks>
public sealed class CurrentUserMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, CurrentUserContext currentUser)
    {
        if (context.User.Identity?.IsAuthenticated != true)
        {
            // Kimlik istemeyen uçlar (/health, /openapi) buradan geçer.
            await next(context);
            return;
        }

        // TR-M1-05: uid YALNIZ doğrulanmış token'ın içinden okunur.
        // İstek gövdesinden veya sorgu dizesinden gelen bir uid asla
        // bu noktaya ulaşamaz.
        var firebaseUid = context.User.FindFirst("sub")?.Value;
        if (string.IsNullOrWhiteSpace(firebaseUid))
        {
            // Doğrulanmış ama "sub" taşımayan token: normalde imkânsız.
            // Yine de varsayımı koda gömmüyoruz.
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

        var identity = new AuthenticatedIdentity(
            FirebaseUid: firebaseUid,
            Email: context.User.FindFirst("email")?.Value,
            EmailVerified: string.Equals(
                context.User.FindFirst("email_verified")?.Value, "true", StringComparison.OrdinalIgnoreCase),
            DisplayName: context.User.FindFirst("name")?.Value);

        var ensureUser = context.RequestServices.GetRequiredService<EnsureUserHandler>();
        var user = await ensureUser.HandleAsync(identity, context.RequestAborted);

        currentUser.Set(user);

        await next(context);
    }
}
