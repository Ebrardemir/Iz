using Iz.Domain.Sync;

namespace Iz.Application.Sync;

/// <summary>
/// Push'ta gelen <c>entityId</c>'nin çözülmüş hâli.
/// </summary>
/// <remarks>
/// İki biçim var ve ikisi de metin olarak geliyor: ana kayıtlarda tek bir
/// UUID, bağlarda <c>"uuid:uuid"</c> (bkz. <see cref="SyncEntityTypes.LinkId"/>).
///
/// NEDEN AYRI BİR TİP, DÜZ <c>string</c> DEĞİL?
/// Kimliği çözmek doğrulamanın kendisi: "memory_people" türüne tekil bir
/// UUID gelirse bu bir hatadır ve fark edilmezse sunucu bağı yanlış anahtarla
/// arar — bulamaz, YENİSİNİ AÇAR. Sonuç kullanıcıda ikinci bir bağ satırı
/// olurdu. Ayrıştırmayı tek bir yere toplamak, o kararın her çağrı yerinde
/// tekrar verilmesini engelliyor.
///
/// AYRIŞTIRMA SIKI, İÇERİK OKUMA GEVŞEK. Buradaki bir hata kaydı REDDEDİYOR
/// (bkz. <see cref="PushRejectionReasons"/>), oysa gövdedeki bir alan
/// okunamazsa varsayılanına düşülüyor. Ayrım bilinçli: kimliği yanlış olan
/// bir kaydı yazmak, yanlış satırı ezmek demek; bir alanı varsayılanla
/// yazmaksa yalnız o alanı kaybettirir.
/// </remarks>
public readonly record struct SyncEntityKey(Guid Primary, Guid? Secondary)
{
    /// <summary>
    /// <c>change_log.entity_id</c> biçimindeki kanonik metin.
    /// </summary>
    /// <remarks>
    /// İstemcinin gönderdiği metinle AYNI olmak zorunda değil: büyük harfli
    /// ya da süslü parantezli bir UUID de ayrıştırılır ve burada kanonik
    /// biçimde geri yazılır. Yanıtta ise istemcinin gönderdiği metin aynen
    /// yankılanıyor — outbox satırını onunla eşleştiriyor.
    /// </remarks>
    public string Value => Secondary is { } second
        ? SyncEntityTypes.LinkId(Primary, second)
        : Primary.ToString();

    /// <param name="composite">
    /// Bağ mı? Türden geliyor (<see cref="SyncEntityMapper.IsLink"/>), gövdeden
    /// değil: istemcinin "bu bir bağdır" demesine güvenseydik tür ile kimlik
    /// biçimi ayrışabilirdi.
    /// </param>
    public static bool TryParse(string? raw, bool composite, out SyncEntityKey key)
    {
        key = default;

        if (string.IsNullOrWhiteSpace(raw))
        {
            return false;
        }

        if (!composite)
        {
            if (!Guid.TryParse(raw, out var single))
            {
                return false;
            }

            key = new SyncEntityKey(single, null);
            return true;
        }

        // İKİ NOKTA ÜST ÜSTE İLK GEÇTİĞİ YERDEN bölünüyor. UUID'lerin kendisi
        // bu karakteri içermiyor, dolayısıyla ilk ayıraç doğru ayıraç.
        var separator = raw.IndexOf(':');
        if (separator <= 0)
        {
            return false;
        }

        if (!Guid.TryParse(raw.AsSpan(0, separator), out var parent) ||
            !Guid.TryParse(raw.AsSpan(separator + 1), out var child))
        {
            return false;
        }

        key = new SyncEntityKey(parent, child);
        return true;
    }
}
