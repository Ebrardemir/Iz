namespace Iz.Domain.Users;

/// <summary>
/// Abonelik planı. İstemcideki <c>IzPlan</c> ile AYNI anahtarları kullanır
/// (<c>core/entitlement/entitlement.dart</c>): <c>free</c> · <c>plus</c> · <c>family</c>.
/// </summary>
/// <remarks>
/// Bu değer sunucudaki <c>subscriptions</c> tablosundan türetilen bir
/// ÖNBELLEKTİR (ADR-B08: plan kararının tek kaynağı sunucudur). Faz 4'te
/// RevenueCat webhook'u burayı günceller; Faz 1'de herkes <c>Free</c>.
/// </remarks>
public enum IzPlan
{
    Free = 0,
    Plus = 1,
    Family = 2,
}

/// <summary>Plan ile tel üzerindeki/veritabanındaki anahtar arasındaki çeviri.</summary>
/// <remarks>
/// NEDEN <c>ToString()</c> YETMİYOR? <c>ToString()</c> "Free" üretir, oysa
/// istemcideki anahtar "free". Aradaki tek harflik fark, planı okuyan
/// istemcinin sessizce <c>IzPlan.free</c>'ye düşmesi demektir — yani ödeme
/// yapmış kullanıcı ücretsiz plana düşer ve kimse hata görmez.
/// Çeviriyi açıkça yazmak bu sınıf hataları imkânsız kılar.
///
/// Sayı olarak da saklamıyoruz: enum sırası değiştiği gün tüm kayıtlar
/// sessizce kayardı, ayrıca veritabanına bakan biri "1" değil "plus" görmeli.
/// </remarks>
public static class IzPlanKeys
{
    public const string Free = "free";
    public const string Plus = "plus";
    public const string Family = "family";

    public static string ToKey(this IzPlan plan) => plan switch
    {
        IzPlan.Free => Free,
        IzPlan.Plus => Plus,
        IzPlan.Family => Family,
        _ => throw new ArgumentOutOfRangeException(nameof(plan), plan, "Bilinmeyen plan."),
    };

    /// <summary>
    /// Anahtarı plana çevirir. Tanınmayan anahtar <see cref="IzPlan.Free"/>
    /// döner — yeni bir plan eklenip eski sunucu onu okuduğunda çökmek
    /// yerine en kısıtlı plana düşmek doğru davranıştır.
    /// </summary>
    public static IzPlan FromKey(string? key) => key switch
    {
        Plus => IzPlan.Plus,
        Family => IzPlan.Family,
        _ => IzPlan.Free,
    };
}
