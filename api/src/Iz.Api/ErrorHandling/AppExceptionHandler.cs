using Iz.Application.Abstractions;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;

namespace Iz.Api.ErrorHandling;

/// <summary>
/// Uygulama istisnalarını RFC 9457 ProblemDetails'e çevirir.
/// </summary>
/// <remarks>
/// İstemcinin <c>Failure</c> hiyerarşisi <c>errorCode</c> alanına bakarak
/// dallanır (TRD §1.2). Bu yüzden kod, metinden daha önemlidir: metin
/// çevrilir ve değişir, kod sözleşmedir.
///
/// Tanımadığımız istisnaları ELE ALMIYORUZ (<c>false</c> dönüyoruz) —
/// varsayılan işleyici devralır ve 500 üretir. Beklenmeyen bir hatayı
/// anlamlıymış gibi 400'e çevirmek, gerçek arızayı gizler.
/// </remarks>
public sealed class AppExceptionHandler(IProblemDetailsService problemDetails)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var (status, errorCode, field) = exception switch
        {
            AppValidationException validation =>
                (StatusCodes.Status400BadRequest, validation.Code, validation.Field),
            UniqueConstraintException =>
                (StatusCodes.Status409Conflict, "conflict", null),
            _ => (0, string.Empty, null),
        };

        if (status == 0)
        {
            return false;
        }

        httpContext.Response.StatusCode = status;

        var problem = new ProblemDetails
        {
            Status = status,
            // BAŞLIK KULLANICI İÇİN DEĞİL. Kullanıcının göreceği metni
            // istemci kendi diline göre seçer (TR-C-10); buradaki metin
            // geliştirici ve log içindir.
            Title = "İstek işlenemedi.",
        };

        problem.Extensions["errorCode"] = errorCode;
        if (field is not null)
        {
            problem.Extensions["field"] = field;
        }

        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = problem,
            Exception = exception,
        });
    }
}
