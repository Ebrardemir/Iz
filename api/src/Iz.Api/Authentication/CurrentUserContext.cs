using Iz.Application.Abstractions;
using Iz.Domain.Users;

namespace Iz.Api.Authentication;

/// <summary>
/// İstek boyunca yaşayan kullanıcı bağlamı. <see cref="CurrentUserMiddleware"/>
/// doldurur; use-case'ler ve repository'ler onu yalnız <see cref="ICurrentUser"/>
/// olarak, yani sadece kimlik olarak görür.
/// </summary>
public sealed class CurrentUserContext : ICurrentUser
{
    /// <summary>
    /// Çözülmüş kullanıcı kaydı. Kimlik istemeyen uçlarda <c>null</c>.
    /// </summary>
    /// <remarks>
    /// Kaydı burada tutmamızın sebebi tasarruf: middleware zaten veritabanından
    /// okudu. Uç noktaların aynı satırı bir kez daha sorgulaması, her istekte
    /// gereksiz bir gidiş-dönüş demekti.
    /// </remarks>
    public User? User { get; private set; }

    public Guid? UserId => User?.Id;

    public void Set(User user) => User = user;

    /// <summary>
    /// Kimlik gerektiren uç noktalar için kullanıcıyı döndürür.
    /// </summary>
    /// <exception cref="InvalidOperationException">
    /// Uç nokta <c>RequireAuthorization()</c> ile korunmuyorsa atılır.
    /// Bu bir programlama hatasıdır, kullanıcı hatası değil — 401 değil 500
    /// üretmesi doğrudur: sessizce boş yanıt dönmektense gürültü çıkarsın.
    /// </exception>
    public User Require() => User
        ?? throw new InvalidOperationException(
            "Kullanıcı bağlamı boş. Uç nokta RequireAuthorization() ile korunuyor mu?");
}
