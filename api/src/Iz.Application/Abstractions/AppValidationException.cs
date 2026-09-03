namespace Iz.Application.Abstractions;

/// <summary>
/// İş kuralı ihlali. HTTP karşılığı 400 + ProblemDetails.
/// </summary>
/// <remarks>
/// <see cref="Code"/> istemcideki <c>ValidationCode</c> ile aynı sözlükten
/// gelir ve ProblemDetails'in <c>errorCode</c> alanına yazılır. İstemci
/// METNE değil bu koda bakarak dallanır (TR-C-10: kullanıcıya sunucunun
/// yazdığı cümle değil, uygulamanın kendi çevirisi gösterilir).
///
/// <see cref="Field"/> doluysa istemci hatayı ilgili form alanının ALTINDA
/// gösterir — genel bir hata balonu değil (TRD §1.2).
/// </remarks>
public sealed class AppValidationException(string code, string? field = null)
    : Exception($"Doğrulama hatası: {code}")
{
    public string Code { get; } = code;

    public string? Field { get; } = field;
}
