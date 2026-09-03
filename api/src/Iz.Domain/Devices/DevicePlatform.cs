namespace Iz.Domain.Devices;

/// <summary>Cihazın platformu.</summary>
public enum DevicePlatform
{
    Unknown = 0,
    Ios = 1,
    Android = 2,
}

/// <summary>Platform ile tel üzerindeki anahtar arasındaki çeviri.</summary>
public static class DevicePlatformKeys
{
    public const string Unknown = "unknown";
    public const string Ios = "ios";
    public const string Android = "android";

    public static string ToKey(this DevicePlatform platform) => platform switch
    {
        DevicePlatform.Ios => Ios,
        DevicePlatform.Android => Android,
        _ => Unknown,
    };

    /// <summary>
    /// Tanınmayan platform <see cref="DevicePlatform.Unknown"/> olur.
    /// İstemcinin yazım hatası yüzünden cihaz kaydını reddetmek, kullanıcıyı
    /// çözemeyeceği bir hataya sokar; bilmediğimizi kaydetmek yeterli.
    /// </summary>
    public static DevicePlatform FromKey(string? key) => key?.ToLowerInvariant() switch
    {
        Ios => DevicePlatform.Ios,
        Android => DevicePlatform.Android,
        _ => DevicePlatform.Unknown,
    };
}
