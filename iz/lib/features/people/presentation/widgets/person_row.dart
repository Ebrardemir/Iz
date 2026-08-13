/// Kişi listesinin tek satırı: yuvarlak avatar, ad, altında ilişki türü ve
/// sonda detaya götüren ok.
///
/// REFERANSTAKİ SAYAÇLAR ("26 anı · 3 ritüel") BİLEREK YOK.
/// Kullanıcı istemedi ve haklı: bu ekranın işi kişiyi BULMAK. Sayılar satırın
/// sağını doldurup adı ve ilişkiyi ikinci plana atıyordu; ayrıca her satır için
/// iki ayrı sayım demek — kişi detayında bir kez göstermek daha doğru yer.
///
/// SAF WIDGET: `Person` alıyor ama dokunuşu yukarı bildiriyor; nereye
/// gidileceğine ekran karar veriyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/people/presentation/person_l10n.dart';
import 'package:iz/shared/widgets/media_thumbnail.dart';

class PersonRow extends StatelessWidget {
  const PersonRow({
    required this.person,
    required this.onTap,
    this.photo,
    super.key,
  });

  final Person person;

  /// Kişinin fotoğrafı.
  ///
  /// AYRI PARAMETRE, `person.avatarMediaId` DEĞİL: entity yalnızca kimliği
  /// taşıyor, o kimliği bir `MediaItem`a çevirmek veri katmanının işi. Satır
  /// hazır medyayı alıyor; null ise ikon çiziliyor.
  final MediaItem? photo;

  final VoidCallback onTap;

  /// Avatarın çapı.
  ///
  /// Referansta satır yüksekliğinin ~%70'i. 48 küçük, 56 satırı şişiriyordu;
  /// 52 ikisinin arası ve iki satırlık metin bloğuyla (ad + ilişki) aynı
  /// yükseklikte duruyor.
  static const double kAvatarSize = 52;

  /// Satırın yatay dolgusu — çizgiler de bu hizadan başlıyor.
  static const double kInset = AppSpacing.md;

  /// Avatar–metin arası.
  static const double _kGap = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Semantics(
      button: true,
      label: l10n.peopleOpenDetail(person.name),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kInset,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              PersonAvatar(photo: photo, size: kAvatarSize),
              const SizedBox(width: _kGap),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.name,
                      // Ad satırın ASIL bilgisi: ilişkiden belirgin şekilde
                      // ağır. Referansta da fark bu kadar keskin.
                      style: context.text.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // Kullanıcının yazdığı ilişki varsa o görünüyor
                      // ("Annem"), yoksa türün çevrilmiş adı ("Anne / Baba").
                      relationDisplay(person, l10n),
                      style: context.text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),
              Icon(
                AppIcons.forward,
                size: AppIconSize.md,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kişinin yuvarlak görseli; fotoğraf yoksa ikon.
///
/// NEDEN BAŞ HARF DEĞİL? Anı detayındaki avatar yığınında baş harf
/// kullanıyoruz çünkü orada daireler 24 piksel ve üst üste biniyor — küçük bir
/// harf orada okunuyor, bir ikon okunmuyor. Burada daire 52 piksel ve tek
/// başına; kullanıcının isteği de "klasik bir kişi ikonu" oldu.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({required this.size, this.photo, super.key});

  final MediaItem? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = photo;

    if (item != null) {
      return MediaThumbnail(
        media: item,
        size: size,
        // YUVARLAK: yarıçap kenarın yarısı. `MediaThumbnail` kare bir
        // önizleme çiziyor; ayrı bir avatar bileşeni yazmak yerine ona
        // daire yarıçapı veriyoruz — kayıp medya ve bulut durumlarını o
        // zaten doğru gösteriyor (BR-007).
        borderRadius: Radius.circular(size / 2),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        AppIcons.person,
        // Dairenin içinde nefes payı kalsın.
        size: size * 0.5,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}
