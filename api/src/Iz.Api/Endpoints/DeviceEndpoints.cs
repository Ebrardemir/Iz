using Iz.Api.Authentication;
using Iz.Application.Devices;
using Iz.Domain.Devices;

namespace Iz.Api.Endpoints;

/// <summary>Cihaz kaydı — sync'in echo önlemesi ve sürüm uyumu için (TR-M13-20).</summary>
public static class DeviceEndpoints
{
    public static IEndpointRouteBuilder MapDeviceEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/v1/devices", async (
                RegisterDeviceRequest request,
                CurrentUserContext currentUser,
                RegisterDeviceHandler handler,
                CancellationToken cancellationToken) =>
            {
                var device = await handler.HandleAsync(
                    currentUser.Require().Id,
                    new DeviceRegistration(
                        request.Id,
                        DevicePlatformKeys.FromKey(request.Platform),
                        request.AppVersion,
                        request.SchemaVersion),
                    cancellationToken);

                return Results.Ok(DeviceResponse.From(device));
            })
            .RequireAuthorization()
            .WithName("RegisterDevice")
            .WithSummary("Cihazı kaydeder veya son görülme zamanını tazeler.")
            .WithTags("Devices");

        return app;
    }
}

/// <param name="Id">
/// İstemcinin daha önce aldığı cihaz kimliği; ilk kayıtta boş bırakılır.
/// Sunucu üretir — bkz. <see cref="Device.Id"/>.
/// </param>
/// <param name="Platform"><c>ios</c> · <c>android</c>.</param>
public sealed record RegisterDeviceRequest(
    Guid? Id,
    string? Platform,
    string? AppVersion,
    int? SchemaVersion);

public sealed record DeviceResponse(
    Guid Id,
    string Platform,
    string? AppVersion,
    int? SchemaVersion,
    DateTimeOffset LastSeenAt)
{
    public static DeviceResponse From(Device device) => new(
        device.Id,
        device.Platform.ToKey(),
        device.AppVersion,
        device.SchemaVersion,
        device.LastSeenAt);
}
