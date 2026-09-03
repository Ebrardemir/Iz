using Iz.Application.Devices;
using Iz.Domain.Devices;
using Microsoft.EntityFrameworkCore;

namespace Iz.Infrastructure.Persistence;

public sealed class DeviceRepository(IzDbContext dbContext) : IDeviceRepository
{
    public Task<Device?> FindAsync(Guid id, Guid userId, CancellationToken cancellationToken)
        // userId koşulu global süzgeçle ZATEN sağlanıyor; yine de açıkça
        // yazıyoruz. Süzgeç bir ağ, sorgunun kendi niyeti değil — sorguyu
        // okuyan kişi neyi kastettiğimizi süzgece bakmadan görebilmeli.
        => dbContext.Devices.SingleOrDefaultAsync(
            d => d.Id == id && d.UserId == userId, cancellationToken);

    public void Add(Device device) => dbContext.Devices.Add(device);
}
