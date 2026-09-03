namespace Iz.Application.Abstractions;

/// <summary>
/// Bir benzersizlik kısıtı ihlal edildi.
/// </summary>
/// <remarks>
/// NEDEN AYRI TİP? Application katmanı EF Core'u tanımaz, dolayısıyla
/// <c>DbUpdateException</c>'ı da tanıyamaz. Altyapı katmanı veritabanının
/// benzersizlik hatasını yakalayıp bu tipe çevirir; use-case yalnız bunu
/// bilir. Böylece "aynı anda iki istek geldi" durumunu, veritabanı
/// sağlayıcısına bağımlı olmadan ele alabiliyoruz.
/// </remarks>
public sealed class UniqueConstraintException(string constraintName, Exception innerException)
    : Exception($"Benzersizlik kısıtı ihlal edildi: {constraintName}", innerException)
{
    public string ConstraintName { get; } = constraintName;
}
