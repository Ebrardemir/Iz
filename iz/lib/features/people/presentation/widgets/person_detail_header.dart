/// Kişi detayının başlık bloğu: solda yuvarlak fotoğraf, sağda ad, ilişki ve
/// doğum tarihi.
///
/// REFERANSTAKİ DAL/ÇİÇEK YOK — kullanıcı istemedi ve haklı: fotoğrafın
/// arkasındaki botanik doku boş durum ekranlarında (`PeopleEmptyIllustration`)
/// bir şeyin YOKLUĞUNU yumuşatmak için var. Burada bir kişi var; süs onu
/// çerçevelemek yerine gölgeliyordu.
///
/// DOĞUM TARİHİ BİR ÇİP, düz metin değil.
/// Referanstaki biçim bu ve doğru: ad ve ilişki kişinin KİM olduğunu söylüyor,
/// doğum tarihi ise bir veri parçası. Çip onu ayırıyor ve pasta ikonu ne
/// olduğunu tek bakışta anlatıyor. Tarih yoksa çip hiç çizilmiyor —
/// "—" göstermek boşluğu bilgi gibi sunmak olurdu.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/media/domain/entities/media_item.dart';
import 'package:iz/features/people/domain/entities/person.dart';
import 'package:iz/features/people/presentation/person_l10n.dart';
import 'package:iz/features/people/presentation/widgets/person_row.dart';

class PersonDetailHeader extends StatelessWidget {
  const PersonDetailHeader({required this.person, this.photo, super.key});

  final Person person;

  /// Kişinin fotoğrafı; null ise silüet ikonu (bkz. [PersonAvatar]).
  final MediaItem? photo;

  /// Avatarın çapı.
  ///
  /// Referansta ekran genişliğinin ~%25'i; 390 piksellik telefonda 96. Liste
  /// satırındaki 52'den belirgin biçimde büyük — burada kişi ekranın konusu,
  /// listede ise bir satır.
  static const double kAvatarSize = 96;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final birthDate = person.birthDate;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PersonAvatar(photo: photo, size: kAvatarSize),
        const SizedBox(width: AppSpacing.md),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                person.name,
                // Ekranın konusu bu: sayfadaki en ağır metin.
                style: context.textStyles.screenTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                // Kullanıcının yazdığı ilişki varsa o ("Annem"), yoksa türün
                // çevrilmiş adı ("Anne / Baba").
                relationDisplay(person, l10n),
                style: context.text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              if (birthDate != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _BirthDateChip(date: birthDate),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Doğum tarihi çipi: pasta ikonu + "18 Nisan".
class _BirthDateChip extends StatelessWidget {
  const _BirthDateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.forKey('birthday'),
              size: AppIconSize.sm,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              // YIL YOK, gün ve ay var: bu bir yaş bildirimi değil, "ne zaman
              // kutluyoruz" bilgisi. Yaş gerektiğinde `Person.ageAt` var.
              //
              // DİLİ AÇIKÇA GEÇİYORUZ: boş bırakılırsa `Intl.defaultLocale`
              // genel değişkenine düşüyor ve ekranı tek başına kurunca ay adı
              // İngilizce çıkıyor (anı detayında tam bunu yaşadık).
              DateFormat.MMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(date),
              style: context.text.bodySmall?.copyWith(color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
