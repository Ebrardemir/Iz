/// Etiket–değer kartı: tek bir kart, içinde saç teli çizgilerle ayrılmış
/// satırlar.
///
/// İKİ EKRAN PAYLAŞIYOR ve bu bir tesadüf değil:
///   • anı OLUŞTURMA formu → sağ tarafta girdi (`_FormField`)
///   • anı DETAY ekranı     → sağ tarafta okunur değer ([MemoryInfoValue])
/// Kullanıcı aynı bilgiyi aynı yerde, aynı sırada, aynı hizada görüyor;
/// forma yazdığı satır detayda da aynı satır. İki ayrı kart yazmak bu
/// eşleşmeyi ilk küçük değişiklikte bozardı.
///
/// (Adı bir ara `MemoryFormCard`dı; detay ekranı da kullanmaya başlayınca
/// "form" yanıltıcı oldu.)
///
/// SATIRIN ANATOMİSİ:
///   [ikon]  [etiket]      [değer ─────────────────►]  [ek işaret]
///     20    sabit sütun    soldan sağa, kalan alan        20
///
/// DEĞER SOLDAN YAZILIR. Bir ara sağa yasladık (referans tasarımda öyle
/// görünüyor) ama yanlıştı: Türkçe soldan sağa okunur, bir formun değer
/// kolonunun sağdan başlaması gözü her satırda geri sardırıyor.
///
/// ETİKET SÜTUNU SABİT GENİŞLİKTE — soldan hizalamanın bedeli bu. Etikete
/// göre esneseydi her satırın değeri farklı bir yerden başlar, kart "form"
/// olmaktan çıkıp dağınık bir listeye dönerdi. Genişlik en uzun etikete
/// ("Koleksiyon") göre seçildi ve yazı ölçeğiyle birlikte büyüyor, böylece
/// erişilebilirlik ayarı açık kullanıcıda etiket kesilmiyor (NFR-032).
///
/// ETİKET DE DEĞER DE AYNI AĞIRLIK VE AYNI KOYULUKTA (w500, `onSurface`).
/// Etiketi soluklaştırmak "form alanı" hissi veriyordu; referansta satır bir
/// KAYIT gibi okunuyor — solda ne olduğu, sağda ne olduğu, ikisi de eşit
/// ağırlıkta.
///
/// SAF WIDGET: veri almaz, sağ tarafına ne konacağını çağıran belirler
/// (metin girdisi, seçili değer, tarih alanı). Böylece kart hiçbir iş kuralı
/// bilmiyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/shared/widgets/iz_divided_card.dart';

/// Satırların içinde durduğu kart.
///
/// KABUK ARTIK `shared/` ALTINDA ([IzDividedCard]): kişi listesi de aynı
/// kartı kullanıyor ve iki kopya zamanla ayrışırdı. Burada kalan tek şey
/// anıya ait olan: çizginin kenardan kenara gitmesi.
class MemoryInfoCard extends StatelessWidget {
  const MemoryInfoCard({required this.rows, super.key});

  /// Satırlar. Aralarındaki çizgileri kart çiziyor — her satırın kendi
  /// çizgisini taşıması SON satırda sahipsiz bir çizgi bırakırdı.
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => IzDividedCard(rows: rows);
}

/// Formdaki tek satır.
class MemoryInfoRow extends StatelessWidget {
  const MemoryInfoRow({
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Sağ taraf: metin girdisi ya da seçili değer.
  final Widget child;

  /// Değerin sağındaki ek işaret (takvim düğmesi, ok).
  final Widget? trailing;

  /// Satırın tamamı dokunulabilir olsun mu? Seçim satırlarında evet, metin
  /// girdisi olan satırlarda hayır — orada dokunuş girdinin kendisine gitmeli.
  final VoidCallback? onTap;

  /// Kartın yatay dolgusu.
  static const double kInset = AppSpacing.md;

  /// İkon–etiket ve etiket–değer araları.
  static const double _kGap = 12;

  /// Etiket sütununun genişliği — bkz. dosya başındaki not.
  ///
  /// En uzun etiket "Koleksiyon" ve ölçtüğümüzde 75.2 piksel çıkıyor
  /// (Poppins Medium 14). 80, kesilme riski olmadan en dar duran değer ve
  /// bu 5 piksel önemli: anı detayında kişiler satırı hem isim listesini
  /// hem avatarları taşıyor, orada her piksel değerin hanesine yazılıyor.
  /// Sütunun gerçekten yettiğini bir test doğruluyor.
  static const double kLabelWidth = 80;

  /// Satır yüksekliği.
  ///
  /// NFR-033 asgari dokunma hedefi 48; referans tasarım daha ferah duruyor
  /// (~56) ve sekiz satırlık bir kartta bu fark hissediliyor.
  static const double kMinHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kInset,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        // ÜSTTEN hizalı, ortadan değil: not satırı üç satıra çıkabiliyor ve
        // o zaman ikonun metnin ortasında asılı kalması yanlış görünüyor.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İkon ilk satırın hizasında kalsın diye küçük bir üst pay.
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: AppIconSize.md,
              // KOYU, soluk değil: referansta ikon etiketle aynı ağırlıkta.
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: _kGap),

          SizedBox(
            // Sütun YAZI ÖLÇEĞİYLE büyüyor: sabit 88 piksel, erişilebilirlik
            // ayarı açık bir kullanıcıda "Koleksiyon"u keserdi.
            width: MediaQuery.textScalerOf(context).scale(kLabelWidth),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: labelStyle(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: _kGap),

          Expanded(child: child),

          if (trailing != null) ...[
            // DAR bir boşluk (4, 8 değil): detaydaki kişiler satırında
            // avatarlar da burada duruyor ve isim listesiyle yarışıyor.
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinHeight),
      child: onTap == null
          ? content
          : Semantics(
              button: true,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }

  /// Etiket ve değerin PAYLAŞTIĞI stil.
  ///
  /// Tek yerde duruyor çünkü ikisinin aynı görünmesi bir tesadüf değil, bu
  /// tasarımın kararı. Girdi alanları da (bkz. `_FormField`) buradan okuyor;
  /// böylece yazılan metin, seçilen değer ve etiket tek bir ailedir.
  static TextStyle? labelStyle(BuildContext context) => context.text.bodyMedium
      ?.copyWith(color: context.colors.onSurface, fontWeight: FontWeight.w500);
}

/// Seçim satırlarının sağ tarafı: seçili değer ya da yer tutucu.
///
/// Değer YOKKEN soluk bir "Seç" yazıyor. Boş bırakmak satırı "bozuk" gibi
/// gösteriyordu; yer tutucu hem ne yapılacağını söylüyor hem de satırın
/// yüksekliğini sabit tutuyor.
class MemoryInfoValue extends StatelessWidget {
  const MemoryInfoValue({required this.value, super.key});

  /// Boş ya da null → yer tutucu.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value;
    final isEmpty = text == null || text.isEmpty;

    return Text(
      isEmpty ? context.l10n.memoryFieldEmpty : text,
      style: MemoryInfoRow.labelStyle(context)?.copyWith(
        // Yer tutucu SOLUK kalıyor: dolu bir değerle boş bir alan aynı
        // koyulukta olsa hangi satırların doldurulacağı görünmezdi.
        color: isEmpty
            ? context.colors.onSurfaceVariant.withValues(alpha: 0.6)
            : context.colors.onSurface,
      ),
      // İki satıra kadar: "Annem, Babam, Elif" gibi listeler sığsın ama
      // satır da kontrolden çıkmasın. Taşarsa üç nokta.
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
