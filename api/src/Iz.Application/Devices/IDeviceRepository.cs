using Iz.Domain.Devices;

namespace Iz.Application.Devices;

public interface IDeviceRepository
{
    /// <summary>
    /// Cihazı bulur. <paramref name="userId"/> ZORUNLU parametredir, isteğe
    /// bağlı bir filtre değil: yalnız kimlikle arayan bir aşırı yükleme
    /// eklersek bir gün biri onu çağırır ve IDOR açığı orada doğar
    /// (TR-M14-22). Sözleşme, yanlış kullanımı imkânsız kılacak biçimde yazılır.
    /// </summary>
    Task<Device?> FindAsync(Guid id, Guid userId, CancellationToken cancellationToken);

    void Add(Device device);
}
