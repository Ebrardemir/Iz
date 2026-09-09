using Iz.Domain.Memories;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Iz.Infrastructure.Persistence.Configurations;

internal sealed class MemoryConfiguration : IEntityTypeConfiguration<Memory>
{
    public void Configure(EntityTypeBuilder<Memory> builder)
    {
        builder.ToTable("memories");
        builder.HasKey(m => m.Id);
        builder.ConfigureSyncable("ix_memories_owner_id");

        // Uzun metin sınırları İSTEMCİYLE AYNI olmak zorunda: sunucuda daha
        // dar olsaydı kullanıcının cihazında kabul edilen bir not push'ta
        // reddedilir ve kuyruk o satırda sonsuza kadar takılırdı.
        builder.Property(m => m.Title).HasMaxLength(200);
        builder.Property(m => m.Note).HasMaxLength(20_000);

        // YABANCI ANAHTAR YOK — kategori, konum ve kapak için.
        //
        // Nedeni sıralama: push tek transaction'da bir batch işliyor ve
        // batch'in içinde anı, referans verdiği kategoriden ÖNCE gelebilir.
        // Kısıt koysaydık geçerli bir kuyruk yalnız sırası yüzünden
        // reddedilirdi. Bütünlüğü istemci koruyor; sunucu ayna.
        //
        // Tutarsız bir referansın bedeli de düşük: ikinci cihaz o alanı
        // çözemez ve kategorisiz gösterir — veri kaybı değil.
    }
}
