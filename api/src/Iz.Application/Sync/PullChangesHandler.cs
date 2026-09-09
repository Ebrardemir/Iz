using Iz.Domain.Sync;

namespace Iz.Application.Sync;

/// <summary>
/// <c>GET /v1/sync/pull</c> — sunucudaki değişiklikleri cihaza indirir.
/// </summary>
/// <remarks>
/// SENKRONİZASYONUN OKUYAN YARISI. Push'un aynası ama simetrik değil, ve
/// asimetrinin sebebi <c>change_log</c>'un ne sakladığı:
///
///   GÜNLÜK **NEYİN** DEĞİŞTİĞİNİ SÖYLÜYOR, SATIR **NE OLDUĞUNU**.
///
/// Günlükte gövde yok — yalnız kimlik, işlem ve sıra. Gövdeyi tablodan
/// okuyoruz, yani gönderdiğimiz şey kaydın O ANKİ hâli, "o seq anındaki"
/// hâli değil. Bunun üç sonucu var ve üçü de bilerek seçildi:
///
/// 1. AYNI KAYIT SAYFA İÇİNDE BİRLEŞTİRİLİYOR. Bir anı beş kez düzenlenmişse
///    günlükte beş satır var ama gövde beşinde de aynı olurdu. Sayfada tek
///    satır olarak, en yüksek <c>seq</c>'iyle dönüyor. İstemci için sonuç
///    aynı, trafik beşte bir.
///
/// 2. `op` GÜNLÜKTEN DEĞİL SATIRDAN TÜRETİLİYOR. Günlükte "upsert" yazan bir
///    kayıt, sayfanın dışında kalan daha yeni bir <c>seq</c>'te silinmiş
///    olabilir. Günlüğe uysaydık silinmiş bir kaydı "güncellendi" diye
///    gönderir, istemci onu DİRİLTİRDİ — silme ancak bir sonraki sayfada
///    gelirdi ve kayıt o arada ekranda görünürdü. Gövdeyle işlemin aynı andan
///    gelmesi zorunlu.
///
/// 3. TABLODA OLMAYAN KAYIT SİLME SAYILIYOR. Çöp kutusu temizliği (FR-015)
///    satırı fiziksel olarak siliyor ama günlük satırı duruyor. "Bulamadım"
///    demek yerine "artık yok" demek doğru çeviri.
///
/// BOOTSTRAP AYRI BİR YOL DEĞİL (§4.3): yeni cihaz <c>cursor = 0</c> ile
/// başlıyor ve aynı kodu kullanıyor. Ayrı bir "full snapshot" ucu yazsaydık,
/// yılda birkaç kez çalışan o yol hiç test edilmemiş olurdu.
/// </remarks>
public sealed class PullChangesHandler(ISyncStore store)
{
    /// <summary>İstemci <c>limit</c> vermezse.</summary>
    public const int DefaultLimit = 200;

    /// <summary>
    /// Üst sınır — push'un batch sınırıyla AYNI.
    /// </summary>
    /// <remarks>
    /// İki yönün aynı büyüklükte olması istemcinin işini kolaylaştırıyor:
    /// tek bir sayfa boyutu var ve bellek hesabı tek.
    /// </remarks>
    public const int MaxLimit = 200;

    public async Task<SyncPullResult> HandleAsync(
        Guid userId,
        long cursor,
        int? limit,
        CancellationToken cancellationToken)
    {
        // NEGATİF CURSOR REDDEDİLMİYOR, SIFIRLANIYOR. Reddetmek istemciyi
        // eşitlemeden tamamen keserdi; sıfırlamak yalnız bir bootstrap
        // pahasına doğru sonucu veriyor. Pull idempotent olduğu için tekrar
        // inen veri zarar vermez.
        var basla = Math.Max(cursor, 0);
        var adet = Math.Clamp(limit ?? DefaultLimit, 1, MaxLimit);

        // BİR FAZLA İSTİYORUZ: `hasMore` için ikinci bir COUNT sorgusu
        // atmaya değmez ve o sorgu bu sorgudan sonra çalışacağı için
        // aradaki bir yazmayla tutarsız olabilirdi.
        var satirlar = await store.ChangesAfterAsync(userId, basla, adet + 1, cancellationToken);

        var devamiVar = satirlar.Count > adet;
        var sayfa = devamiVar ? satirlar.Take(adet).ToList() : satirlar;

        if (sayfa.Count == 0)
        {
            return new SyncPullResult([], basla, HasMore: false);
        }

        // CURSOR BİRLEŞTİRMEDEN ÖNCEKİ SON SATIRDAN: istemci TÜKETTİĞİ her
        // günlük satırının ötesine geçmeli. Birleştirilmiş listenin son
        // seq'ini verseydik, aradaki satırlar bir daha gelir ve her pull
        // aynı yerde dönüp dururdu.
        var sonrakiCursor = sayfa[^1].Seq;

        // Aynı kaydın birden çok satırı varsa SONUNCUSU kalıyor; sayfa
        // seq'e göre artan sırada geldiği için son yazma son satır.
        var sonHali = new Dictionary<string, ChangeLogEntry>(StringComparer.Ordinal);
        foreach (var satir in sayfa)
        {
            sonHali[Kimlik(satir)] = satir;
        }

        var govdeler = await GovdeleriYukleAsync(sonHali.Values, cancellationToken);

        var degisiklikler = sonHali.Values
            .OrderBy(e => e.Seq)
            .Select(e => Cevir(e, govdeler))
            .ToList();

        return new SyncPullResult(degisiklikler, sonrakiCursor, devamiVar);
    }

    /// <summary>
    /// Sayfadaki kayıtları TÜR TÜR, toplu okur.
    /// </summary>
    /// <remarks>
    /// Tek tek okusaydık 200'lük bir sayfa 200 gidiş-dönüş ederdi; bootstrap
    /// binlerce kaydı sayfa sayfa indirdiği için orada fark dakikalarla
    /// ölçülürdü.
    ///
    /// Tanımadığımız bir tür ATLANIYOR: sözlükten bir tür kaldırılmış olsa
    /// bile eski günlük satırları duruyor ve tek bir eski satır yüzünden
    /// istemcinin bütün eşitlemesi durmamalı.
    /// </remarks>
    private async Task<Dictionary<string, ISyncable>> GovdeleriYukleAsync(
        IEnumerable<ChangeLogEntry> girdiler,
        CancellationToken cancellationToken)
    {
        var turBasinaAnahtarlar = new Dictionary<SyncEntityMapper, List<SyncEntityKey>>();

        foreach (var girdi in girdiler)
        {
            var mapper = SyncEntityMappers.Find(girdi.EntityType);
            if (mapper is null ||
                !SyncEntityKey.TryParse(girdi.EntityId, mapper.IsLink, out var key))
            {
                continue;
            }

            if (!turBasinaAnahtarlar.TryGetValue(mapper, out var liste))
            {
                liste = [];
                turBasinaAnahtarlar[mapper] = liste;
            }

            liste.Add(key);
        }

        var govdeler = new Dictionary<string, ISyncable>(StringComparer.Ordinal);

        foreach (var (mapper, anahtarlar) in turBasinaAnahtarlar)
        {
            var bulunanlar = await store.FindManyAsync(mapper, anahtarlar, cancellationToken);

            foreach (var (syncId, satir) in bulunanlar)
            {
                // Anahtar TÜRLE BİRLİKTE: bir bağın kimliği ("uuid:uuid")
                // başka bir bağ tablosunda da aynı olabilir.
                govdeler[$"{mapper.EntityType}/{syncId}"] = satir;
            }
        }

        return govdeler;
    }

    private static SyncPullChange Cevir(
        ChangeLogEntry girdi,
        IReadOnlyDictionary<string, ISyncable> govdeler)
    {
        var satir = govdeler.GetValueOrDefault(Kimlik(girdi));

        // Satır yoksa ya da tombstone'sa: SİLME. Gerekçe sınıfın başındaki
        // notta (2 ve 3 numaralı maddeler).
        var silindi = satir is null || satir.DeletedAt is not null;

        return new SyncPullChange(
            girdi.Seq,
            girdi.EntityType,
            girdi.EntityId,
            silindi ? ChangeOperationKeys.Delete : ChangeOperationKeys.Upsert,

            // SÜRÜM DE SATIRDAN: gövdeyle aynı andan gelmek zorunda. Günlükten
            // alsaydık istemci, gönderdiğimiz gövdeye ait olmayan bir sürüm
            // numarası yazar ve bir sonraki push'unda gereksiz çakışma alırdı.
            satir?.Version ?? girdi.Version,

            girdi.DeviceId,

            // Silmede gövde YOK: gerekmiyor, ve göndermek kullanıcının
            // sildiği veriyi kabloya geri koymak olurdu.
            silindi ? null : SyncRowWriter.Write(satir!));
    }

    private static string Kimlik(ChangeLogEntry girdi) =>
        $"{girdi.EntityType}/{girdi.EntityId}";
}
