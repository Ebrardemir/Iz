using Iz.Application.Abstractions;

namespace Iz.Infrastructure.Time;

/// <summary>Gerçek saat. Testler bunun yerine sabit bir saat enjekte eder.</summary>
public sealed class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
