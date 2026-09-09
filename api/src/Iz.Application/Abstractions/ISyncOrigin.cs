namespace Iz.Application.Abstractions;

/// <summary>
/// Bu isteğin yazmalarının hangi CİHAZDAN geldiği.
/// </summary>
/// <remarks>
/// <c>change_log.device_id</c> bunu okuyor ve echo önlemenin dayanağı o:
/// pull yanıtında istemci kendi gönderdiği değişiklikleri atlıyor
/// (yol haritası §4.2). Atlamasaydı az önce yazdığı şeyi geri alıp yeniden
/// uygular, o sırada kullanıcının yaptığı yeni düzenlemeyi ezerdi.
///
/// NEDEN <see cref="ICurrentUser"/>'A EKLENMEDİ?
/// O arayüz yalnız okuyor ve değerini kimlik doğrulama hattı belirliyor.
/// Cihaz ise token'dan gelmiyor — push GÖVDESİNDE bildiriliyor. İkisini
/// aynı arayüze koymak, "token'dan gelir" güvencesini cihaz için de veriyor
/// gibi görünürdü; oysa cihaz kimliği istemcinin söylediği bir şey.
///
/// <c>null</c> NORMALDİR: arka plan işleri ve yönetim işlemleri bir cihazdan
/// gelmiyor. O değişiklikler günlüğe cihazsız düşer ve HERKESE gider.
/// </remarks>
public interface ISyncOrigin
{
    Guid? DeviceId { get; }
}

/// <inheritdoc cref="ISyncOrigin"/>
/// <remarks>
/// İstek başına ömürlü. Cihazı push işleyicisi, gövdeyi doğruladıktan SONRA
/// yazıyor.
/// </remarks>
public sealed class SyncOrigin : ISyncOrigin
{
    public Guid? DeviceId { get; private set; }

    /// <summary>
    /// Cihazı bir kez belirler.
    /// </summary>
    /// <remarks>
    /// İKİNCİ ÇAĞRI HATA VERİR. Aynı istek içinde cihazın değişmesi bir
    /// programlama hatasıdır ve sessizce kabul edilseydi sonucu, günlüğün
    /// yarısının bir cihaza yarısının başkasına yazılması olurdu — echo
    /// önleme o kullanıcıda sessizce bozulurdu.
    /// </remarks>
    public void Attach(Guid deviceId)
    {
        if (DeviceId is not null)
        {
            throw new InvalidOperationException(
                "Cihaz bu istek için zaten belirlendi. Aynı istek içinde iki cihaz olamaz.");
        }

        DeviceId = deviceId;
    }
}
