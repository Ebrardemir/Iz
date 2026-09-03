using Iz.Application.Abstractions;
using Iz.Domain.Devices;

namespace Iz.Application.Devices;

/// <summary>
/// Cihazı kaydeder veya var olanın "son görülme"sini tazeler.
/// </summary>
/// <remarks>
/// Tek uç nokta, çünkü istemci açısından soru tek: "ben bu cihazım, beni tanı".
/// İlk çağrıda kimlik üretilir ve döner; sonraki her çağrı aynı kimliği
/// gönderir. İstemci kimliği <c>SecureStore</c>'da saklar.
/// </remarks>
public sealed class RegisterDeviceHandler(
    IDeviceRepository devices,
    IUnitOfWork unitOfWork,
    IClock clock)
{
    public const int AppVersionMaxLength = 32;

    public async Task<Device> HandleAsync(
        Guid userId,
        DeviceRegistration registration,
        CancellationToken cancellationToken)
    {
        if (registration.AppVersion is { Length: > AppVersionMaxLength })
        {
            throw new AppValidationException("app_version_invalid", field: "appVersion");
        }

        if (registration.SchemaVersion is < 1)
        {
            throw new AppValidationException("schema_version_invalid", field: "schemaVersion");
        }

        var now = clock.UtcNow;

        if (registration.DeviceId is { } deviceId)
        {
            // DİKKAT: userId ile birlikte aranıyor. Başkasının cihaz kimliğini
            // gönderen bir istek burada "bulunamadı" alır ve YENİ bir cihaz
            // açar — kurbanın kaydına dokunamaz (TR-M14-22).
            var existing = await devices.FindAsync(deviceId, userId, cancellationToken);
            if (existing is not null)
            {
                // Platform GÜNCELLENMİYOR: bir cihaz iOS'tan Android'e dönmez.
                // Değişmiş görünüyorsa istemci yanlış kimliği göndermiştir;
                // sessizce üzerine yazmak yerine kayıt olduğu gibi kalır.
                existing.AppVersion = registration.AppVersion;
                existing.SchemaVersion = registration.SchemaVersion;
                existing.LastSeenAt = now;

                await unitOfWork.SaveChangesAsync(cancellationToken);
                return existing;
            }
        }

        var device = new Device
        {
            Id = Guid.CreateVersion7(now),
            UserId = userId,
            Platform = registration.Platform,
            AppVersion = registration.AppVersion,
            SchemaVersion = registration.SchemaVersion,
            CreatedAt = now,
            LastSeenAt = now,
        };

        devices.Add(device);
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return device;
    }
}

/// <param name="DeviceId">
/// İstemcinin daha önce aldığı kimlik. İlk kayıtta <c>null</c>.
/// </param>
public sealed record DeviceRegistration(
    Guid? DeviceId,
    DevicePlatform Platform,
    string? AppVersion,
    int? SchemaVersion);
