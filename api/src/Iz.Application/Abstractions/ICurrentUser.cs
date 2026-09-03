namespace Iz.Application.Abstractions;

/// <summary>
/// İsteği yapan kullanıcı — DOĞRULANMIŞ token'dan çözülmüş hâli.
/// </summary>
/// <remarks>
/// Bu arayüz yalnız okur. Değeri yazan tek yer kimlik doğrulama hattıdır;
/// use-case'lerin ve repository'lerin onu değiştirebilmesi için bir sebep yok
/// ve yazma yetkisi vermek, ileride birinin "test için" kullanıcıyı ortada
/// değiştirmesine kapı açardı.
///
/// <c>null</c> olması normaldir: kimlik istemeyen uçlar (<c>/health</c>) ve
/// arka plan işleri için kullanıcı yoktur. Bu durumda sahipli kayıtların
/// global sorgu süzgeci HİÇBİR satır döndürmez — güvenli varsayılan budur.
/// </remarks>
public interface ICurrentUser
{
    Guid? UserId { get; }
}
