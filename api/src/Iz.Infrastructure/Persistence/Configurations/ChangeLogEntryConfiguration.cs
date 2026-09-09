using Iz.Domain.Sync;
using Iz.Domain.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Iz.Infrastructure.Persistence.Configurations;

internal sealed class ChangeLogEntryConfiguration : IEntityTypeConfiguration<ChangeLogEntry>
{
    public void Configure(EntityTypeBuilder<ChangeLogEntry> builder)
    {
        builder.ToTable("change_log");
        builder.HasKey(e => e.Seq);

        // SIRAYI VERİTABANI ÜRETİYOR (bigserial). Uygulama üretseydi iki
        // eşzamanlı istek aynı numarayı alabilir ya da numara atlanabilirdi;
        // cursor'lı sayfalamada bunun bedeli sessizce atlanan bir değişiklik.
        builder.Property(e => e.Seq).UseIdentityAlwaysColumn();

        builder.Property(e => e.EntityType).HasMaxLength(64).IsRequired();

        // Bağların kimliği "uuid:uuid" — 73 karakter. 128 rahat yer bırakıyor.
        builder.Property(e => e.EntityId).HasMaxLength(128).IsRequired();

        // Metin olarak yazılıyor ("upsert"/"delete"), sayı olarak değil:
        // veritabanını elle okuyan biri 1 görüp tahmin etmek zorunda
        // kalmasın ve enum'a yeni değer eklemek eski satırların anlamını
        // kaydırmasın.
        builder.Property(e => e.Operation)
            .HasConversion(op => op.ToKey(), key => ChangeOperationKeys.FromKey(key))
            .HasMaxLength(16)
            .IsRequired();

        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(e => e.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // PULL'UN TEK SORGUSU: "şu kullanıcının şu seq'inden sonrası".
        // Bileşik indeks tam bu şekilde okunuyor — soldan `user_id`, sonra
        // `seq` üzerinde aralık taraması.
        builder.HasIndex(e => new { e.UserId, e.Seq })
            .HasDatabaseName("ix_change_log_user_seq");

        // ⚠️ QUERY FİLTRESİ YOK ve bu bilinçli.
        //
        // Diğer tablolarda global süzgeç IDOR'a karşı ikinci hat. Burada
        // koymuyoruz çünkü pull sorgusu zaten `user_id` ile süzüyor ve
        // günlüğü OKUYAN başka bir yol yok. Ayrıca kullanıcısız bağlamda
        // (arka plan işleri, bakım) günlüğü okuyabilmek gerekiyor; süzgeç
        // orada her şeyi gizlerdi.
        //
        // Bunun karşılığı bir sorumluluk: günlüğe erişen HER sorgu
        // `user_id`yi kendisi yazmak zorunda.
    }
}
