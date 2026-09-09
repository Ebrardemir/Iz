using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Nodes;
using Iz.Application.Sync;
using Iz.Domain.Sync;

namespace Iz.IntegrationTests;

/// <summary>
/// Gövde ↔ satır çevirisi: <see cref="SyncEntityMapper"/> ve
/// <see cref="SyncRowWriter"/>.
/// </summary>
/// <remarks>
/// Veritabanı GEREKMİYOR — bu testler saf çeviriyi ölçüyor. Yine de aynı
/// pakette duruyorlar: soru "sunucu istemcinin gönderdiğini eksiksiz
/// okuyabiliyor mu", ve cevabı yanlışsa kayıp veri sessiz olur.
/// </remarks>
public sealed class SyncPayloadTests
{
    /// <summary>Testin karşılaştırmadığı alanlar — hepsini SUNUCU belirliyor.</summary>
    /// <remarks>
    /// <c>version</c> ve <c>updated_at</c>'i <c>PushChangesHandler</c>,
    /// <c>deleted_at</c>'i ise <c>op</c> yazıyor; hiçbiri gövdeden
    /// okunmuyor ve okunmamalı. Geri kalan HER sütun gidiş-dönüşten aynen
    /// çıkmak zorunda.
    /// </remarks>
    private static readonly string[] SunucununBelirledigi =
    [
        "version",
        "updated_at",
        "deleted_at",
    ];

    private static readonly DateTimeOffset Simdi =
        new(2026, 9, 9, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Sozlukteki_her_turun_bir_ESLEYICISI_var()
    {
        // Esleyicisi olmayan tur push'ta TANINIR ama yazilamaz: o
        // kullanicinin kuyrugu o satirda takilir.
        var eksik = SyncEntityTypes.All
            .Except(SyncEntityMappers.All.Select(m => m.EntityType))
            .ToList();

        Assert.True(
            eksik.Count == 0,
            "SyncEntityTypes.All icinde olup esleyicisi olmayan tur(ler): " +
            string.Join(", ", eksik));
    }

    [Fact]
    public void Esleyicilerin_hepsi_SOZLUKTE_var()
    {
        var fazla = SyncEntityMappers.All
            .Select(m => m.EntityType)
            .Except(SyncEntityTypes.All)
            .ToList();

        Assert.True(
            fazla.Count == 0,
            "Esleyicisi olup sozlukte olmayan tur(ler): " + string.Join(", ", fazla));
    }

    /// <summary>
    /// SUNUCUDAKİ HER SÜTUN GÖVDEDEN OKUNUYOR mu?
    /// </summary>
    /// <remarks>
    /// BU TESTİN YAKALADIĞI HATA: birinin varlığa yeni bir sütun ekleyip
    /// <c>Apply</c>'a eklemeyi unutması. Derlenir, bütün öteki testler
    /// geçer — ve o alan hiçbir zaman senkronize olmaz. Kullanıcı ikinci
    /// cihazında alanı boş bulur, hata mesajı almaz.
    ///
    /// Yöntem: varlığı yansımayla TAMAMEN doldur → gövdeye yaz → BOŞ bir
    /// varlığa geri oku → tekrar gövdeye yaz. İki gövde, sunucunun belirlediği
    /// üç alan dışında birebir aynı olmalı.
    ///
    /// Yansımayı burada kullanmak güvenli çünkü test kendi kendini
    /// onaylamıyor: doldurmayı yansıma, okumayı ELLE YAZILMIŞ eşleyici
    /// yapıyor. Eşleyici eksikse iki taraf ayrışır.
    /// </remarks>
    [Fact]
    public void Her_esleyici_TUM_sutunlari_govdeden_okuyor()
    {
        foreach (var mapper in SyncEntityMappers.All)
        {
            var kaynak = Doldur(VarlikTipi(mapper));

            Assert.True(
                SyncEntityKey.TryParse(kaynak.SyncId, mapper.IsLink, out var key),
                $"{mapper.EntityType}: SyncId ayristirilamadi ({kaynak.SyncId}).");

            var govde = Oku(SyncRowWriter.Write(kaynak));

            var hedef = mapper.Create(key, kaynak.OwnerId, govde.Row, Simdi);
            mapper.Apply(hedef, govde.Row);

            var geriYazilan = SyncRowWriter.Write(hedef).AsObject();

            foreach (var alan in govde.Node.AsObject())
            {
                if (SunucununBelirledigi.Contains(alan.Key, StringComparer.Ordinal))
                {
                    continue;
                }

                Assert.True(
                    geriYazilan.ContainsKey(alan.Key),
                    $"{mapper.EntityType}: `{alan.Key}` geri yazilan govdede yok.");

                Assert.Equal(
                    alan.Value?.ToJsonString(),
                    geriYazilan[alan.Key]?.ToJsonString());
            }

            // Ters yon: geri yazilan govdede kaynakta olmayan bir alan
            // birikmemeli.
            Assert.Equal(govde.Node.AsObject().Count, geriYazilan.Count);
        }
    }

    [Fact]
    public void Hesaplanan_alanlar_govdeye_GIRMIYOR()
    {
        // `sync_entity_type` ve `sync_id` mevcut sutunlardan turetiliyor ve
        // sunucuda bile sutunlari yok. Govdeye koysaydik istemci onlari kendi
        // satirina yazmaya calisir ve karsiligi olmayan iki alan bulurdu.
        var govde = SyncRowWriter.Write(Doldur(typeof(Domain.Memories.Memory))).AsObject();

        Assert.False(govde.ContainsKey("sync_entity_type"));
        Assert.False(govde.ContainsKey("sync_id"));
        Assert.True(govde.ContainsKey("occurred_year"));
    }

    [Theory]
    [InlineData("bos-degil-ama-uuid-degil", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void Gecersiz_tekil_kimlik_ayristirilamiyor(string? ham, bool beklenen) =>
        Assert.Equal(beklenen, SyncEntityKey.TryParse(ham, composite: false, out _));

    [Fact]
    public void Bag_kimligi_CIFT_olmak_zorunda()
    {
        var tekil = Guid.CreateVersion7();

        // Tekil bir UUID bag olarak ayristirilamaz: kabul etseydik sunucu
        // bagi yanlis anahtarla arar, bulamaz ve YENISINI acardi.
        Assert.False(SyncEntityKey.TryParse(tekil.ToString(), composite: true, out _));

        var cocuk = Guid.CreateVersion7();
        Assert.True(SyncEntityKey.TryParse($"{tekil}:{cocuk}", composite: true, out var key));
        Assert.Equal(tekil, key.Primary);
        Assert.Equal(cocuk, key.Secondary);
        Assert.Equal($"{tekil}:{cocuk}", key.Value);
    }

    [Fact]
    public void Buyuk_harfli_kimlik_KANONIK_bicime_donuyor()
    {
        // Ayni kayit iki farkli metinle gelirse gunlukte iki ayri satir
        // olurdu; kanoniklestirme bunu engelliyor.
        var id = Guid.CreateVersion7();

        Assert.True(SyncEntityKey.TryParse(id.ToString().ToUpperInvariant(), false, out var key));
        Assert.Equal(id.ToString(), key.Value);
    }

    [Fact]
    public void Okuyucu_BAGISLAYICI_bozuk_alan_istisna_atmiyor()
    {
        // Kati bir okuyucu, tek bir bozuk alan yuzunden o kullanicinin TUM
        // kuyrugunu kilitlerdi (TR-M13-22'nin sunucu karsiligi).
        var row = Oku(JsonNode.Parse(
            """
            {
              "title": 42,
              "occurred_year": "iki bin yirmi alti",
              "is_favorite": 1,
              "category_id": "uuid degil",
              "created_at": "tarih degil"
            }
            """)!).Row;

        Assert.Null(row.Text("title"));
        Assert.Equal(-1, row.Int32("occurred_year", -1));
        Assert.True(row.Bool("is_favorite"));
        Assert.Null(row.NullableGuid("category_id"));
        Assert.Equal(Simdi, row.DateTime("created_at", Simdi));
        Assert.Null(row.Text("hic-olmayan-alan"));
    }

    // --- Yardimcilar -------------------------------------------------------

    private static Type VarlikTipi(SyncEntityMapper mapper)
    {
        // SyncEntityMapper<T> -> T
        var taban = mapper.GetType().BaseType;
        Assert.NotNull(taban);
        return taban.GetGenericArguments()[0];
    }

    /// <summary>
    /// Varlığın YAZILABİLİR her alanını ayırt edici bir değerle doldurur.
    /// </summary>
    /// <remarks>
    /// <c>GetUninitializedObject</c>: <c>required</c> kısıtını atlamanın tek
    /// yolu ve testte doğru olan da bu — burada bir varlık kurmuyoruz, sütun
    /// listesini geziyoruz. <c>init</c> ayarlayıcıları yansımayla
    /// çağrılabiliyor.
    /// </remarks>
    private static ISyncable Doldur(Type tip)
    {
        var varlik = (ISyncable)RuntimeHelpers.GetUninitializedObject(tip);
        var tohum = 0;

        foreach (var alan in tip.GetProperties(BindingFlags.Public | BindingFlags.Instance))
        {
            if (!alan.CanWrite)
            {
                continue;
            }

            alan.SetValue(varlik, Deger(alan.PropertyType, ++tohum));
        }

        return varlik;
    }

    private static object Deger(Type tip, int tohum)
    {
        var asil = Nullable.GetUnderlyingType(tip) ?? tip;

        if (asil == typeof(string))
        {
            return $"deger-{tohum}";
        }

        if (asil == typeof(int))
        {
            return tohum;
        }

        if (asil == typeof(long))
        {
            return (long)tohum * 1_000;
        }

        if (asil == typeof(double))
        {
            return tohum + 0.5;
        }

        if (asil == typeof(bool))
        {
            return true;
        }

        if (asil == typeof(Guid))
        {
            return new Guid($"0000000{tohum % 10}-0000-4000-8000-000000000001");
        }

        if (asil == typeof(DateTimeOffset))
        {
            return Simdi.AddDays(tohum);
        }

        throw new NotSupportedException(
            $"Test doldurucusu {asil.Name} tipini tanimiyor — yeni bir sutun tipi mi eklendi?");
    }

    /// <summary>JSON düğümünü hem <see cref="SyncRow"/> hem düğüm olarak verir.</summary>
    /// <remarks>
    /// <see cref="SyncRow"/> bir <see cref="JsonElement"/> sarmalıyor;
    /// <see cref="JsonDocument"/>'ın ömrü boyunca geçerli olduğu için düğümü
    /// de birlikte tutuyoruz.
    /// </remarks>
    private static (SyncRow Row, JsonNode Node) Oku(JsonNode node)
    {
        var element = JsonSerializer.Deserialize<JsonElement>(node.ToJsonString());
        return (new SyncRow(element), node);
    }
}
