namespace Iz.Application.Abstractions;

/// <summary>
/// Bir isteğin tüm yazmalarını tek transaction'da kalıcılaştırır.
/// </summary>
/// <remarks>
/// Faz 3'ün en sert kuralı buna dayanacak: entity yazması ile
/// <c>change_log</c> yazması AYNI transaction'da olmak zorunda
/// (BACKEND_YOL_HARITASI §3.1). Ayrı olurlarsa bir değişiklik kalıcı olur
/// ama günlüğe düşmez — o kayıt hiçbir cihaza gitmez, sessizce kaybolur.
/// Kaydetme yetkisini repository'lere değil tek bir yere vermemizin sebebi bu.
/// </remarks>
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken cancellationToken);
}
