using Iz.Application.Abstractions;
using Iz.Application.Devices;
using Iz.Domain.Sync;

namespace Iz.Application.Sync;

/// <summary>
/// <c>POST /v1/sync/push</c> — kuyruğu sunucuya boşaltır.
/// </summary>
/// <remarks>
/// SENKRONİZASYONUN YAZAN YARISI. Sözleşme yol haritası §4.1'de; buradaki
/// üç kural onun taşıyıcısı:
///
/// 1. SUNUCU KENDİLİĞİNDEN EZMEZ. <c>baseVersion</c> sunucudaki sürümle
///    eşleşmiyorsa araya biri girmiştir; o değişiklik <c>conflict</c> döner
///    ve HİÇBİR ŞEY yazılmaz. Kararı kullanıcı verir (§4.4).
///
/// 2. BİR ÇAKIŞMA KUYRUĞU KİLİTLEMEZ. Batch tek transaction'da işleniyor
///    ama çakışan ve reddedilen satırlar "işlenmedi" sayılıp geri kalanı
///    uygulanıyor. Aksi hâlde tek bir çakışma, kullanıcının bütün
///    değişikliklerini süresiz durdururdu.
///
/// 3. DEĞİŞMEYEN KAYIT YAZILMAZ. İstemci bir anıyı her kaydettiğinde onun
///    TÜM bağlarını yeniden gönderiyor; hepsine günlük satırı düşürseydik
///    ikinci cihaz tek bir başlık düzeltmesi için on beş satır çekerdi.
///
/// TEK TRANSACTION: <see cref="IUnitOfWork.SaveChangesAsync"/> bir kez, en
/// sonda çağrılıyor. Değişiklikler ve onların <c>change_log</c> satırları
/// böylece birlikte kalıcı oluyor (§3.1).
///
/// ⏳ IDEMPOTENCY-KEY HENÜZ YOK (yol haritası §4.1, Faz 3 / adım 4).
/// Eksikliğin bedeli DUPLICATE DEĞİL — kimlikleri istemci üretiyor ve aynı
/// gövde ikinci kez geldiğinde hiçbir alan değişmiyor. Bedeli YANLIŞ
/// ÇAKIŞMA: yanıtı alamadan yeniden denenen bir push, ilk denemede artmış
/// sürüm yüzünden <c>conflict</c> alır ve kullanıcıya kendi değişikliği iki
/// sürüm hâlinde gösterilir. Bu yüzden anahtar, istemci motoru yayına
/// çıkmadan ÖNCE kapanmak zorunda.
/// </remarks>
public sealed class PushChangesHandler(
    ISyncStore store,
    ISyncLock syncLock,
    IDeviceRepository devices,
    IUnitOfWork unitOfWork,
    IClock clock,
    SyncOrigin origin)
{
    /// <summary>
    /// Bir istekteki üst sınır (yol haritası §4.1).
    /// </summary>
    /// <remarks>
    /// Gövde BOYUTU ayrıca uç noktada sınırlanıyor: 200 küçük satır ile 200
    /// tane 20.000 karakterlik not aynı sayı ama çok farklı bellek.
    /// </remarks>
    public const int MaxChangesPerBatch = 200;

    public async Task<SyncPushResult> HandleAsync(
        Guid userId,
        SyncPushCommand command,
        CancellationToken cancellationToken)
    {
        if (command.Changes.Count > MaxChangesPerBatch)
        {
            throw new AppValidationException("batch_too_large", field: "changes");
        }

        // CİHAZ BİZDE KAYITLI OLMAK ZORUNDA. Doğrulamasaydık istemci başka
        // bir cihazın kimliğini iddia edebilir ve echo kuralını kullanarak
        // kendi değişikliklerini o cihazdan gizleyebilirdi (Faz 1 notu).
        // Sorgu `userId` ile birlikte gidiyor: başkasının cihaz kimliği
        // burada "bulunamadı" alır.
        if (await devices.FindAsync(command.DeviceId, userId, cancellationToken) is null)
        {
            throw new AppValidationException("device_unknown", field: "deviceId");
        }

        origin.Attach(command.DeviceId);

        // KİLİT BURADAN İTİBAREN: "oku → karşılaştır → yaz" üçlüsü atomik
        // olmak zorunda. Aynı hesabın iki cihazı aynı anda aynı kaydı
        // gönderirse, kilit olmadan ikisi de aynı sürümü okur, ikisi de
        // kontrolü geçer ve sonraki öncekini SESSİZCE ezer (bkz. ISyncLock).
        //
        // Kilit aynı zamanda bu isteğin TRANSACTION'I: commit edilmezse
        // yazılan her şey geri sarılıyor.
        await using var kilit = await syncLock.AcquireAsync(userId, cancellationToken);

        var now = clock.UtcNow;

        // KAYDETMEDEN ÖNCEKİ BAŞ. Aşağıda "bu istekte hangi satırlar
        // yazıldı" sorusunu bununla soruyoruz; sırayı veritabanı ürettiği
        // için başka türlü öğrenemeyiz.
        var cursorBefore = await store.CurrentCursorAsync(userId, cancellationToken);

        var batch = new PushBatch();

        var applied = new List<AppliedChange>();
        var results = new List<SyncPushChangeResult>(command.Changes.Count);

        foreach (var change in command.Changes)
        {
            var outcome = await ApplyChangeAsync(userId, change, now, batch, cancellationToken);

            results.Add(outcome.Result);

            if (outcome.Result.Status == SyncPushStatus.Applied && outcome.Mapper is { } mapper)
            {
                applied.Add(new AppliedChange(results.Count - 1, mapper.EntityType, outcome.Key.Value));
            }
        }

        await unitOfWork.SaveChangesAsync(cancellationToken);

        await AttachSequencesAsync(userId, cursorBefore, applied, results, cancellationToken);

        var cursor = await store.CurrentCursorAsync(userId, cancellationToken);

        // COMMIT EN SONDA: buraya kadar bir istisna çıkarsa `kilit` commit
        // edilmeden kapanır ve yazılan HER ŞEY geri sarılır. Yarım uygulanmış
        // bir batch, hiç uygulanmamış bir batch'ten çok daha kötüdür —
        // istemci hangi satırın gittiğini bilemez.
        await kilit.CommitAsync(cancellationToken);

        return new SyncPushResult(results, cursor);
    }

    private async Task<ChangeOutcome> ApplyChangeAsync(
        Guid userId,
        SyncPushChange change,
        DateTimeOffset now,
        PushBatch batch,
        CancellationToken cancellationToken)
    {
        // Yanıtta İSTEMCİNİN GÖNDERDİĞİ metin dönüyor; outbox satırını
        // onunla eşleştiriyor.
        var echo = change.EntityId ?? string.Empty;

        var mapper = SyncEntityMappers.Find(change.EntityType);
        if (mapper is null)
        {
            return ChangeOutcome.Rejected(echo, PushRejectionReasons.UnknownEntityType);
        }

        if (!SyncEntityKey.TryParse(change.EntityId, mapper.IsLink, out var key))
        {
            return ChangeOutcome.Rejected(echo, PushRejectionReasons.EntityIdInvalid);
        }

        if (ParseOperation(change.Op) is not { } operation)
        {
            return ChangeOutcome.Rejected(echo, PushRejectionReasons.OperationInvalid);
        }

        // ⚠️ FAZ 4'ÜN KAPISI BURAYA TAKILACAK (ADR-B09, yol haritası §6).
        // Sync bir İZ+ özelliği: free plandaki hesap buradan
        // `entitlement_required` ile dönecek ve istemci onu paywall'a
        // çevirecek. Bugün açık, çünkü `cloudSync` bayrağı kapalı ve
        // `subscriptions` tablosu Faz 4'te geliyor. Kontrol İSTEMCİYE
        // BIRAKILMIYOR: plan sunucuda doğrulanacak.

        SyncPayload payload;
        if (operation == ChangeOperation.Upsert)
        {
            if (!SyncPayload.TryParse(change.Payload, out payload, out var rejection))
            {
                return ChangeOutcome.Rejected(echo, rejection!);
            }
        }
        else
        {
            // SİLMEK İÇİN GÖVDE GEREKMİYOR ve istemci de göndermiyor:
            // `deviceOnly`ye çevrilen bir günlük kaydının silme isteği yalnız
            // kimlik taşıyor — tam gövdeyi koymak, "bu cihazda kalsın" denen
            // metni silme isteğinin içinde buluta göndermek olurdu
            // (Faz 2, TR-M3-02).
            SyncPayload.TryParse(change.Payload, out payload, out _);
        }

        var existing = await FindAsync(mapper, key, batch, cancellationToken);

        var result = operation == ChangeOperation.Delete
            ? ApplyDelete(userId, mapper, key, change.BaseVersion, payload, now, batch, echo, existing)
            : ApplyUpsert(userId, mapper, key, change.BaseVersion, payload, now, batch, echo, existing);

        // BAĞLAR YALNIZ ANA KAYIT UYGULANDIYSA İŞLENİYOR. Çakışan bir
        // değişiklik için "hiçbir şey yazılmadı" diyorsak bağları da
        // yazmamalıyız: istemci o satırı çözüp yeniden gönderecek ve bağlar
        // onunla birlikte gelecek.
        if (result.Status == SyncPushStatus.Applied)
        {
            foreach (var group in payload.Links)
            {
                foreach (var row in group.Rows)
                {
                    await MergeLinkAsync(userId, group.Mapper, row, now, batch, cancellationToken);
                }
            }
        }

        return new ChangeOutcome(result, mapper, key);
    }

    private async Task<ISyncable?> FindAsync(
        SyncEntityMapper mapper,
        SyncEntityKey key,
        PushBatch batch,
        CancellationToken cancellationToken) =>
        batch.Find(mapper, key) ?? await store.FindAsync(mapper, key, cancellationToken);

    private SyncPushChangeResult ApplyUpsert(
        Guid userId,
        SyncEntityMapper mapper,
        SyncEntityKey key,
        int baseVersion,
        SyncPayload payload,
        DateTimeOffset now,
        PushBatch batch,
        string echo,
        ISyncable? existing)
    {
        if (existing is null)
        {
            // SUNUCUDA YOK. `baseVersion` sıfırdan farklı olabilir: istemci
            // kaydı gönderdiğini sanıyor ama bizde iz yok. Yine de ÇAKIŞMA
            // DEĞİL — gösterecek bir sunucu sürümü olmadığı için kullanıcının
            // seçebileceği bir şey yok. Kaydı açıyoruz, sürüm 1'den başlıyor
            // ve istemci onu yanıttan benimsiyor.
            var created = mapper.Create(key, userId, payload.Entity, now);
            mapper.Apply(created, payload.Entity);
            created.Version = 1;
            created.UpdatedAt = now;

            store.Add(created);
            batch.Remember(mapper, key, created);

            return new SyncPushChangeResult(echo, SyncPushStatus.Applied, created.Version);
        }

        if (baseVersion != existing.Version)
        {
            return Conflict(echo, existing);
        }

        mapper.Apply(existing, payload.Entity);

        // TOMBSTONE TEMİZLENİYOR: sürüm eşleşiyorsa istemci kaydın silinmiş
        // hâlini biliyor demektir ve yine de "bu kayıt var" diyor. Bu bir
        // GERİ ALMA (FR-015 çöp kutusundan geri yükleme) ve kasıtlı.
        existing.DeletedAt = null;

        BumpIfModified(existing, now);
        batch.Remember(mapper, key, existing);

        return new SyncPushChangeResult(echo, SyncPushStatus.Applied, existing.Version);
    }

    private SyncPushChangeResult ApplyDelete(
        Guid userId,
        SyncEntityMapper mapper,
        SyncEntityKey key,
        int baseVersion,
        SyncPayload payload,
        DateTimeOffset now,
        PushBatch batch,
        string echo,
        ISyncable? existing)
    {
        if (existing is null)
        {
            // SUNUCUDA HİÇ OLMAYAN BİR KAYDIN SİLİNMESİ — yine de TOMBSTONE
            // AÇIYORUZ. Hiçbir şey yapmasaydık, aynı kaydı henüz push
            // etmemiş İKİNCİ bir cihaz onu sonradan gönderir ve kullanıcının
            // sildiği kayıt diriltilirdi. Anonim → hesap yükseltmesinde iki
            // cihazın da aynı yerel kayıtları taşıması bunu gerçek bir
            // senaryo yapıyor.
            var tombstone = mapper.Create(key, userId, payload.Entity, now);
            tombstone.Version = 1;
            tombstone.UpdatedAt = now;
            tombstone.DeletedAt = now;

            store.Add(tombstone);
            batch.Remember(mapper, key, tombstone);

            return new SyncPushChangeResult(echo, SyncPushStatus.Applied, tombstone.Version);
        }

        if (existing.DeletedAt is not null)
        {
            // ZATEN SİLİNMİŞ. Sürümü artırmıyoruz: her tekrar denemede
            // yeniden silseydik sürüm sonsuza kadar büyür ve her seferinde
            // günlüğe yeni bir satır düşerdi.
            return new SyncPushChangeResult(echo, SyncPushStatus.Applied, existing.Version);
        }

        if (baseVersion != existing.Version)
        {
            return Conflict(echo, existing);
        }

        existing.DeletedAt = now;
        existing.UpdatedAt = now;
        existing.Version++;

        batch.Remember(mapper, key, existing);
        return new SyncPushChangeResult(echo, SyncPushStatus.Applied, existing.Version);
    }

    /// <summary>
    /// Bir bağ satırını birleştirir — SÜRÜM KONTROLÜ YOK.
    /// </summary>
    /// <remarks>
    /// Yol haritası §4.4: bağlar satır bazlı birleşiyor, SİLME KAZANIYOR.
    /// Gerekçe iki yönlü:
    ///   • İki cihazın aynı anıya FARKLI kişiler eklemesi bir çakışma değil,
    ///     ikisinin de olması gereken bir birleşme. Sürüm kontrolü koysaydık
    ///     kullanıcıya çözecek bir şeyi olmayan bir çakışma gösterirdik.
    ///   • Silme KASITLIDIR. "Bu kişiyi anıdan çıkardım" ile "bu kişiyi henüz
    ///     göndermedim" arasındaki farkı tombstone taşıyor; canlı bir satırın
    ///     silinmiş bir satırı ezmesine izin verseydik §1.1'deki hataya —
    ///     çıkarılan kişinin geri gelmesine — geri dönerdik.
    /// </remarks>
    private async Task MergeLinkAsync(
        Guid userId,
        SyncEntityMapper mapper,
        SyncRow row,
        DateTimeOffset now,
        PushBatch batch,
        CancellationToken cancellationToken)
    {
        if (!mapper.TryReadLinkKey(row, out var key))
        {
            return;
        }

        var incomingDeleted = row.NullableDateTime("deleted_at");
        var existing = await FindAsync(mapper, key, batch, cancellationToken);

        if (existing is null)
        {
            var created = mapper.Create(key, userId, row, now);
            mapper.Apply(created, row);
            created.Version = 1;
            created.UpdatedAt = now;

            // Gelen satır tombstone ise sunucuda da tombstone olarak doğuyor:
            // istemcinin "bu bağ koparıldı" bilgisi ikinci cihaza ancak bir
            // SATIR olarak gidebilir.
            created.DeletedAt = incomingDeleted is null ? null : now;

            store.Add(created);
            batch.Remember(mapper, key, created);
            return;
        }

        batch.Remember(mapper, key, existing);

        if (existing.DeletedAt is not null)
        {
            // SİLME KAZANIR — canlı bir satır onu diriltmiyor.
            return;
        }

        if (incomingDeleted is not null)
        {
            existing.DeletedAt = now;
            existing.UpdatedAt = now;
            existing.Version++;
            return;
        }

        mapper.Apply(existing, row);
        BumpIfModified(existing, now);
    }

    /// <summary>
    /// Kayıt gerçekten değiştiyse sürümü ve <c>updatedAt</c>'i ilerletir.
    /// </summary>
    /// <remarks>
    /// ÖNCE SORULUYOR, SONRA YAZILIYOR: atamanın kendisi kaydı "değişmiş"
    /// yapardı ve hiçbir şey değişmese bile her push günlüğe satır düşürürdü.
    ///
    /// <c>UpdatedAt</c> SUNUCUNUN SAATİ, istemcinin gönderdiği değil. Cihaz
    /// saatine güvenseydik, saati ileri kaymış tek bir cihaz alan bazlı "son
    /// yazma kazanır" karşılaştırmasını (§4.4) kalıcı olarak kazanırdı.
    /// </remarks>
    private void BumpIfModified(ISyncable entity, DateTimeOffset now)
    {
        if (!store.IsModified(entity))
        {
            return;
        }

        entity.UpdatedAt = now;
        entity.Version++;
    }

    private static SyncPushChangeResult Conflict(string echo, ISyncable existing) =>
        new(
            echo,
            SyncPushStatus.Conflict,
            Server: new SyncServerVersion(existing.Version, SyncRowWriter.Write(existing)));

    /// <summary>
    /// Uygulanan her sonuca <c>change_log</c> sırasını iliştirir.
    /// </summary>
    /// <remarks>
    /// Sırayı veritabanı üretiyor (<c>bigserial</c>), dolayısıyla ancak
    /// KAYDETTİKTEN SONRA öğrenilebiliyor. Aynı kayıt bu istekte birden çok
    /// kez yazılmışsa en YÜKSEK sıra alınıyor — istemcinin ilgilendiği,
    /// kaydın en son hâli.
    ///
    /// <c>seq</c>'i <c>null</c> kalan bir sonuç HATA DEĞİL: değişiklik
    /// hiçbir alanı değiştirmemiş, dolayısıyla günlüğe satır düşmemiş
    /// demektir.
    /// </remarks>
    private async Task AttachSequencesAsync(
        Guid userId,
        long cursorBefore,
        List<AppliedChange> applied,
        List<SyncPushChangeResult> results,
        CancellationToken cancellationToken)
    {
        if (applied.Count == 0)
        {
            return;
        }

        var written = await store.ChangesAfterAsync(userId, cursorBefore, limit: null, cancellationToken);
        if (written.Count == 0)
        {
            return;
        }

        var sequences = new Dictionary<(string, string), long>();
        foreach (var entry in written)
        {
            var identity = (entry.EntityType, entry.EntityId);
            if (!sequences.TryGetValue(identity, out var seen) || entry.Seq > seen)
            {
                sequences[identity] = entry.Seq;
            }
        }

        foreach (var change in applied)
        {
            if (sequences.TryGetValue((change.EntityType, change.EntityId), out var seq))
            {
                results[change.Index] = results[change.Index] with { Seq = seq };
            }
        }
    }

    /// <summary>
    /// Kabloda <c>create</c> ve <c>update</c> de kabul ediliyor.
    /// </summary>
    /// <remarks>
    /// Sunucunun <see cref="ChangeOperation"/>'ı bilerek daha dar: pull'u
    /// alan cihaz için fark yok, kayıt yoksa açar varsa günceller. Ama
    /// istemcinin outbox'ı <c>create</c>/<c>update</c>/<c>delete</c>
    /// saklıyor (<c>OutboxOperation</c>) ve o satırlar kullanıcının
    /// cihazında uygulama güncellemesinden SAĞ ÇIKIYOR. Üçünü de kabul
    /// etmek, bir çeviri hatasının kuyruğu kilitlemesini engelliyor.
    /// </remarks>
    private static ChangeOperation? ParseOperation(string? op) => op switch
    {
        ChangeOperationKeys.Upsert or "create" or "update" => ChangeOperation.Upsert,
        ChangeOperationKeys.Delete => ChangeOperation.Delete,
        _ => null,
    };

    /// <summary>
    /// Bu istekte dokunulmuş kayıtlar.
    /// </summary>
    /// <remarks>
    /// AYNI KAYIT BATCH'TE İKİ KEZ GELEBİLİR (önce oluştur, sonra düzenle).
    /// İkincisinde veritabanına sorsaydık henüz KAYDEDİLMEMİŞ olan ilkini
    /// bulamaz, aynı anahtarla ikinci bir satır açmaya çalışır ve EF "bu
    /// anahtar zaten izleniyor" diye patlardı — üstelik batch'in tamamı
    /// düşerdi.
    ///
    /// Bağlar da buraya giriyor: bir anının bağları hem kendi gövdesinde hem
    /// de aynı batch'teki bir serinin gövdesinde gelebilir
    /// (<c>memory_rituals</c> ikisinin de içinde).
    /// </remarks>
    private sealed class PushBatch
    {
        private readonly Dictionary<(string Type, string Id), ISyncable> _seen = [];

        public ISyncable? Find(SyncEntityMapper mapper, SyncEntityKey key) =>
            _seen.GetValueOrDefault((mapper.EntityType, key.Value));

        public void Remember(SyncEntityMapper mapper, SyncEntityKey key, ISyncable entity) =>
            _seen[(mapper.EntityType, key.Value)] = entity;
    }

    private readonly record struct ChangeOutcome(
        SyncPushChangeResult Result,
        SyncEntityMapper? Mapper,
        SyncEntityKey Key)
    {
        public static ChangeOutcome Rejected(string entityId, string reason) =>
            new(new SyncPushChangeResult(entityId, SyncPushStatus.Rejected, Reason: reason), null, default);
    }

    /// <summary>Sonuç listesindeki konumu ile kaydın kimliği.</summary>
    private readonly record struct AppliedChange(int Index, string EntityType, string EntityId);
}
