/// KOLEKSİYONLAR sekmesinin gövdesi: katlanır kartların listesi.
///
/// KATLAMA DURUMU NEDEN BURADA?
/// "Aynı anda yalnızca BİR kart açık" kuralını uyguluyoruz — referans
/// tasarımda da tek kart açık. Bu kural ancak durum LİSTEDE yaşarsa
/// mümkün: her kart kendi durumunu tutsaydı hiçbiri ötekinin açık
/// olduğunu bilemezdi.
///
/// Neden akordeon? Açık bir kart 370 px, yani ekranın yarısı. Üçü birden
/// açıkken liste gezilemez hâle geliyor ve kullanıcı hangi koleksiyonda
/// olduğunu kaybediyor. Çoklu açılım istenirse [_openId] bir `Set`e döner —
/// başka hiçbir yer değişmez.
///
/// SEKME İÇERİĞİ AMA AYRI WIDGET: `MyLifeView` zaten üç sekmeyi, seçili
/// günü ve görünen ayı yönetiyor. Koleksiyonların katlama durumunu da oraya
/// koymak o sınıfı iki ekranın karışımına çevirirdi.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/my_life/presentation/my_life_layout.dart';
import 'package:iz/features/my_life/presentation/widgets/collection_card.dart';
import 'package:iz/shared/widgets/app_empty_state.dart';

class CollectionsSection extends StatefulWidget {
  const CollectionsSection({
    required this.collections,
    required this.onOpenMemory,
    required this.onMemoryActions,
    super.key,
  });

  /// Boş liste → boş durum çizilir (NFR-035).
  final List<CollectionCardData> collections;

  final ValueChanged<CollectionMemoryData> onOpenMemory;

  /// İkinci parametre dokunulan üç nokta düğmesinin EKRAN koordinatlarındaki
  /// kutusu; menü ona çıpalanıyor (bkz. [CollectionCard.onMemoryActions]).
  final void Function(CollectionMemoryData memory, Rect anchor) onMemoryActions;

  /// Figma: kartlar arası boşluk. Tasarım çerçevesi `space-between` diyor
  /// ama o, sabit yüksekliğe (641) yayılmış üç kart için geçerliydi; liste
  /// dinamik olduğu için sabit bir aralık kullanıyoruz.
  static const double kCardGap = 12;

  @override
  State<CollectionsSection> createState() => _CollectionsSectionState();
}

class _CollectionsSectionState extends State<CollectionsSection> {
  /// Açık olan kartın kimliği; null → hepsi kapalı.
  ///
  /// Kimlikle tutuyoruz, indeksle DEĞİL: liste sıralanır ya da bir
  /// koleksiyon silinirse indeks başka bir kartı işaret etmeye başlar ve
  /// yanlış kart açık görünür.
  String? _openId;

  @override
  void initState() {
    super.initState();
    // Ekran açılınca İLK kart açık gelir — referans tasarımdaki hâl.
    // Boş bir liste karşılamak yerine kullanıcı ilk koleksiyonun içini
    // doğrudan görüyor.
    _openId = widget.collections.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(CollectionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Açık olan koleksiyon listeden kalktıysa (silindi/filtrelendi) durumu
    // temizle; yoksa hiçbir kart açık görünmezken `_openId` dolu kalır ve
    // o koleksiyon geri geldiğinde beklenmedik biçimde açılır.
    if (_openId != null &&
        !widget.collections.any((collection) => collection.id == _openId)) {
      _openId = widget.collections.firstOrNull?.id;
    }
  }

  void _toggle(String id) => setState(() {
    // Açık karta tekrar dokunmak onu kapatır.
    _openId = _openId == id ? null : id;
  });

  @override
  Widget build(BuildContext context) {
    if (widget.collections.isEmpty) {
      final l10n = context.l10n;
      return AppEmptyState(
        icon: AppIcons.collection,
        title: l10n.collectionsEmptyTitle,
        message: l10n.collectionsEmptyMessage,
      );
    }

    return Padding(
      // Tasarım bu bloğu 24'ten başlatıyor ama ekrandaki her şey (sekme
      // çubuğu, ay satırı, takvim) 20'de. 24 alsaydık sağ marj 16 kalır ve
      // kartlar üstteki sekme çubuğuyla hizasız görünürdü. 20'de bırakıyoruz
      // — aynı uzlaşmayı `calendar_week_header.dart` da yapıyor.
      padding: const EdgeInsets.symmetric(horizontal: MyLifeLayout.pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final collection in widget.collections) ...[
            if (collection != widget.collections.first)
              const SizedBox(height: CollectionsSection.kCardGap),
            CollectionCard(
              // `ValueKey` ŞART: kartlar açılıp kapandıkça ağaçtaki
              // yükseklikleri değişiyor. Anahtar olmadan Flutter durumu
              // konuma göre eşler ve yanlış kart açık görünebilir.
              key: ValueKey(collection.id),
              collection: collection,
              isExpanded: collection.id == _openId,
              onToggle: () => _toggle(collection.id),
              onOpenMemory: widget.onOpenMemory,
              onMemoryActions: widget.onMemoryActions,
            ),
          ],

          // Listenin dibinde nefes payı: son kart alt çubuğa yapışmasın.
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
