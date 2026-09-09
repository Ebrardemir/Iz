using System.Text.Json;
using System.Text.Json.Nodes;
using Iz.Api.Authentication;
using Iz.Application.Sync;
using Microsoft.AspNetCore.Http.Features;

namespace Iz.Api.Endpoints;

/// <summary>Senkronizasyon uçları — yol haritası §4.</summary>
public static class SyncEndpoints
{
    /// <summary>
    /// Gövde üst sınırı (yol haritası §4.1).
    /// </summary>
    /// <remarks>
    /// DEĞİŞİKLİK SAYISINDAN AYRI BİR SINIR: 200 küçük satır ile 200 tane
    /// 20.000 karakterlik not aynı sayı ama çok farklı bellek. Sayı sınırı
    /// işleyicide, boyut sınırı burada — biri sunucunun işini, öteki
    /// sunucunun belleğini koruyor.
    ///
    /// Sınır AŞILIRSA 413 dönüyor. İstemcinin tepkisi batch'i küçültmek
    /// olmalı; kuyruğu düşürmek değil.
    /// </remarks>
    public const long MaxRequestBytes = 1024 * 1024;

    /// <summary>
    /// Gövde sınırını UYGULAYAN katman.
    /// </summary>
    /// <remarks>
    /// NEDEN MIDDLEWARE, <c>[RequestSizeLimit]</c> DEĞİL?
    /// Önce onu denedik ve testte 1,2 MB'lık bir gövde 200 OK aldı: öznitelik
    /// sessizce hiçbir şey yapmıyordu. "Sınır var" diye yazılmış ama
    /// çalışmayan bir kural, hiç olmayan kuraldan kötüdür — güvendeyiz sanır,
    /// değilizdir.
    ///
    /// NEDEN ENDPOINT FİLTRESİ DEĞİL? Minimal API'de filtre, gövde ZATEN
    /// okunup modele bağlandıktan sonra çalışıyor. Amacımız tam da onu
    /// okumamak.
    ///
    /// İKİ HAT: <c>Content-Length</c> bildirilmişse istek gövdeye hiç
    /// dokunmadan reddediliyor; bildirilmemişse (chunked) sunucunun kendi
    /// sınırı çekiliyor ve akış orada kesiliyor.
    ///
    /// Kimlik doğrulamadan ÖNCE duruyor: büyük bir gövdeyi kimin gönderdiğini
    /// öğrenmek için önce onu okumak gerekirdi.
    /// </remarks>
    public static IApplicationBuilder UseSyncRequestLimits(this IApplicationBuilder app) =>
        app.UseWhen(
            context => context.Request.Path.StartsWithSegments("/v1/sync"),
            branch => branch.Use(async (context, next) =>
            {
                var limit = context.Features.Get<IHttpMaxRequestBodySizeFeature>();
                if (limit is { IsReadOnly: false })
                {
                    limit.MaxRequestBodySize = MaxRequestBytes;
                }

                // UZUNLUK BİLDİRİLMEMİŞSE AKIŞ SAYILARAK OKUNUYOR.
                // `Content-Length` kontrolü tek başına yetmiyor: chunked
                // gönderen bir istemcide o başlık HİÇ GELMİYOR ve sınır
                // sessizce devre dışı kalıyor. Testte bunu birebir yaşadık —
                // istemci gövdeyi tamponlamayı bırakınca 1,2 MB'lık istek
                // sorunsuz geçti.
                context.Request.Body = new SinirliAkis(context.Request.Body, MaxRequestBytes);

                if (context.Request.ContentLength > MaxRequestBytes)
                {
                    await Results.Problem(
                            statusCode: StatusCodes.Status413PayloadTooLarge,
                            title: "İstek gövdesi çok büyük.",
                            extensions: new Dictionary<string, object?>
                            {
                                // İstemci METNE değil buna bakarak dallanıyor:
                                // doğru tepki batch'i küçültmek, kuyruğu
                                // düşürmek değil.
                                ["errorCode"] = "payload_too_large",
                                ["traceId"] = context.TraceIdentifier,
                            })
                        .ExecuteAsync(context);

                    return;
                }

                await next(context);
            }));

    /// <summary>
    /// Belirli bir bayttan fazlasını OKUTMAYAN akış.
    /// </summary>
    /// <remarks>
    /// Sınırı gövde okunurken uyguluyor, dolayısıyla <c>Content-Length</c>
    /// bildirilmemiş (chunked) isteklerde de geçerli. Sınır aşıldığı anda
    /// okuma duruyor: 100 MB'lık bir gövdenin tamamı belleğe ALINMIYOR.
    ///
    /// <see cref="BadHttpRequestException"/> fırlatılıyor çünkü
    /// <c>AppExceptionHandler</c> onun kendi durum kodunu (413) kullanıyor.
    /// Düz bir istisna 500 üretirdi ve istemci 500'ü "sunucu bozuk" diye
    /// okuyup batch'i küçültmek yerine aynı isteği yeniden denerdi.
    /// </remarks>
    private sealed class SinirliAkis(Stream inner, long limit) : Stream
    {
        private long _okunan;

        public override bool CanRead => true;

        public override bool CanSeek => false;

        public override bool CanWrite => false;

        public override long Length => throw new NotSupportedException();

        public override long Position
        {
            get => _okunan;
            set => throw new NotSupportedException();
        }

        public override async ValueTask<int> ReadAsync(
            Memory<byte> buffer,
            CancellationToken cancellationToken = default) =>
            Say(await inner.ReadAsync(buffer, cancellationToken));

        public override Task<int> ReadAsync(
            byte[] buffer,
            int offset,
            int count,
            CancellationToken cancellationToken) =>
            ReadAsync(buffer.AsMemory(offset, count), cancellationToken).AsTask();

        public override int Read(byte[] buffer, int offset, int count) =>
            Say(inner.Read(buffer, offset, count));

        public override void Flush() => inner.Flush();

        public override long Seek(long offset, SeekOrigin origin) =>
            throw new NotSupportedException();

        public override void SetLength(long value) => throw new NotSupportedException();

        public override void Write(byte[] buffer, int offset, int count) =>
            throw new NotSupportedException();

        private int Say(int okunan)
        {
            _okunan += okunan;

            return _okunan > limit
                ? throw new BadHttpRequestException(
                    "İstek gövdesi çok büyük.", StatusCodes.Status413PayloadTooLarge)
                : okunan;
        }
    }

    public static IEndpointRouteBuilder MapSyncEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/v1/sync/push", async (
                SyncPushRequest request,
                HttpContext http,
                CurrentUserContext currentUser,
                PushChangesHandler handler,
                CancellationToken cancellationToken) =>
            {
                var result = await handler.HandleAsync(
                    currentUser.Require().Id,
                    new SyncPushCommand(
                        request.DeviceId,

                        // BAŞLIKTAN, gövdeden DEĞİL. Idempotency HTTP'nin
                        // kendi kavramı ve istemcinin retry katmanı gövdeye
                        // değil başlığa dokunur; gövdeye koysaydık her yeniden
                        // denemede anahtarın korunması gövdeyi yeniden kurmayı
                        // gerektirirdi.
                        http.Request.Headers["Idempotency-Key"].ToString(),
                        [.. (request.Changes ?? []).Select(c => new SyncPushChange(
                            c.EntityType,
                            c.EntityId,
                            c.Op,
                            c.BaseVersion,
                            c.Payload))]),
                    cancellationToken);

                return Results.Ok(SyncPushResponse.From(result));
            })
            .RequireAuthorization()
            .WithName("SyncPush")
            .WithSummary("Bir cihazın bekleyen değişikliklerini sunucuya yazar.")
            .WithTags("Sync");

        app.MapGet("/v1/sync/pull", async (
                long? cursor,
                int? limit,
                CurrentUserContext currentUser,
                PullChangesHandler handler,
                CancellationToken cancellationToken) =>
            {
                var result = await handler.HandleAsync(
                    currentUser.Require().Id,
                    cursor ?? 0,
                    limit,
                    cancellationToken);

                return Results.Ok(SyncPullResponse.From(result));
            })
            .RequireAuthorization()
            .WithName("SyncPull")
            .WithSummary("Cursor'dan sonraki değişiklikleri sayfa sayfa döndürür.")
            .WithTags("Sync");

        return app;
    }
}

/// <param name="NextCursor">
/// Bir sonraki pull'da gönderilecek değer.
/// </param>
/// <remarks>
/// ⚠️ İstemci bunu ANCAK tüm değişiklikleri yerel transaction'a yazdıktan
/// sonra kaydeder (yol haritası §4.2). Önce kaydederse ve araya bir çökme
/// girerse o sayfa bir daha gelmez.
/// </remarks>
public sealed record SyncPullResponse(
    IReadOnlyList<SyncPullChangeResponse> Changes,
    long NextCursor,
    bool HasMore)
{
    public static SyncPullResponse From(SyncPullResult result) => new(
        [.. result.Changes.Select(SyncPullChangeResponse.From)],
        result.NextCursor,
        result.HasMore);
}

/// <param name="DeviceId">
/// Değişikliği gönderen cihaz. İstemci KENDİ kimliğiyle eşleşen satırları
/// atlıyor — echo önleme (yol haritası §4.2). Arka plan işlerinden gelen
/// satırlarda <c>null</c>: onlar herkese gider.
/// </param>
public sealed record SyncPullChangeResponse(
    long Seq,
    string EntityType,
    string EntityId,
    string Op,
    int Version,
    Guid? DeviceId,
    JsonNode? Payload)
{
    public static SyncPullChangeResponse From(SyncPullChange change) => new(
        change.Seq,
        change.EntityType,
        change.EntityId,
        change.Op,
        change.Version,
        change.DeviceId,
        change.Payload);
}

/// <param name="DeviceId">
/// Değişiklikleri gönderen cihaz — <c>POST /v1/devices</c>'tan alınmış
/// kimlik. Kayıtlı değilse istek <c>device_unknown</c> ile reddedilir.
/// </param>
public sealed record SyncPushRequest(Guid DeviceId, IReadOnlyList<SyncPushChangeRequest>? Changes);

/// <param name="Payload">
/// İstemcinin <c>encodeOutboxPayload</c> ile ürettiği zarf:
/// <c>{ "v", "entity", "links" }</c>. Ham <see cref="JsonElement"/> olarak
/// alınıyor — sunucu onu tipli bir modele çevirmiyor.
/// </param>
/// <remarks>
/// GÖVDE NEDEN TİPLENMİYOR? On dört tablo için on dört DTO yazmak, aynı
/// alan listesini üçüncü kez tekrarlamak olurdu (istemcide, varlıkta ve
/// burada). Daha kötüsü: tipli bir model tanımadığı bir alanı BAĞLAMA
/// SIRASINDA reddederdi ve sunucudan yeni bir istemcinin tek bir yeni alanı,
/// o kullanıcının bütün kuyruğunu kilitlerdi.
/// </remarks>
public sealed record SyncPushChangeRequest(
    string? EntityType,
    string? EntityId,
    string? Op,
    int BaseVersion,
    JsonElement? Payload);

/// <param name="Cursor">
/// Sunucunun O ANKİ günlük başı — bir İPUCU, pull cursor'ı DEĞİL.
/// Gerekçesi <see cref="SyncPushResult"/> notunda.
/// </param>
public sealed record SyncPushResponse(
    IReadOnlyList<SyncPushChangeResponse> Results,
    long Cursor)
{
    public static SyncPushResponse From(SyncPushResult result) => new(
        [.. result.Results.Select(SyncPushChangeResponse.From)],
        result.Cursor);
}

/// <param name="Status"><c>applied</c> · <c>conflict</c> · <c>rejected</c>.</param>
/// <remarks>
/// KABLODA METİN, SAYI DEĞİL. Enum'un sayısal değerini yazsaydık, listeye
/// ileride bir durum eklemek eski istemcilerde her durumun anlamını
/// kaydırırdı — üstelik sessizce.
/// </remarks>
public sealed record SyncPushChangeResponse(
    string EntityId,
    string Status,
    int? Version,
    long? Seq,
    SyncServerVersionResponse? Server,
    string? Reason)
{
    public static SyncPushChangeResponse From(SyncPushChangeResult result) => new(
        result.EntityId,
        result.Status switch
        {
            SyncPushStatus.Applied => "applied",
            SyncPushStatus.Conflict => "conflict",
            SyncPushStatus.Rejected => "rejected",
            _ => throw new ArgumentOutOfRangeException(nameof(result)),
        },
        result.Version,
        result.Seq,
        result.Server is { } server
            ? new SyncServerVersionResponse(server.Version, server.Payload)
            : null,
        result.Reason);
}

/// <summary>Çakışmada sunucudaki hâl — kullanıcıya iki sürüm gösterilebilsin diye.</summary>
public sealed record SyncServerVersionResponse(int Version, JsonNode Payload);
