namespace Iz.Application.Abstractions;

/// <summary>
/// Zamanın tek kaynağı. <c>DateTimeOffset.UtcNow</c> doğrudan çağrılmaz.
/// </summary>
/// <remarks>
/// İstemci tarafındaki TR-C-41 (<c>core/utils/clock.dart</c>) kuralının sunucu
/// karşılığı. Gerekçesi burada daha da güçlü: hesap silmenin 30 günü,
/// aboneliğin 90 günü ve çakışma çözümündeki saat karşılaştırması zamana
/// bağlı kararlar. Bunları "31 gün bekle" diye test edemeyiz.
/// </remarks>
public interface IClock
{
    DateTimeOffset UtcNow { get; }
}
