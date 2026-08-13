/// Günlük ana sayfasının karşılama kartı: fotoğraf zemin, üstünde "Hoş
/// geldin", bir davet cümlesi ve "Yazmaya Başla" düğmesi.
///
/// ZEMİN BİR ÇİZİM (`JournalHeroIllustration`): masa, açık defter, kalem ve
/// kahve. Önce anı önizlemesinden ödünç bir fotoğraf duruyordu; kalabalıktı ve
/// günlükle ilgisi yoktu.
///
/// METNİN OKUNURLUĞU ZEMİNE EMANET EDİLMİYOR: çizimin üstüne yüzey renginden
/// soldan sağa açılan bir geçiş var. Metin sol tarafta, ÇİZİM sağ tarafta;
/// ikisi üst üste binmiyor ve karşıtlık her temada korunuyor (NFR-031).
///
/// METİN KARTIN ÜSTÜNDE, ortasında değil: kullanıcı önce selamı okuyor, sonra
/// gözü aşağıya, düğmeye iniyor.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/journal/presentation/widgets/journal_hero_illustration.dart';

class JournalHeroCard extends StatelessWidget {
  const JournalHeroCard({required this.onStartWriting, this.name, super.key});

  /// Kullanıcının adı — "Hoş geldin, Ebrar".
  ///
  /// null ise yalnızca "Hoş geldin" yazıyor. Profil verisi henüz yok
  /// (`InstantAuthRepository` bir taslak); ad geldiğinde tek satır değişecek.
  final String? name;

  final VoidCallback onStartWriting;

  /// Referanstaki oran — geniş ve alçak değil, içinde metin duran bir kart.
  static const double kAspectRatio = 1.28;

  /// Metin sütununun kartа oranı.
  ///
  /// Sağ taraf çizime bırakılıyor. Aynı zamanda davet cümlesinin İKİ SATIRA
  /// düşmesini sağlayan şey bu: cümleyi elle bölmek (`\n`) çeviri değişince
  /// ya da yazı ölçeği büyüyünce tuhaf kırılmalar üretirdi.
  static const double kTextWidthRatio = 0.62;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final personName = name?.trim();

    return Semantics(
      label: l10n.journalHeroSemantics,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(AppRadius.xl),
        child: AspectRatio(
          aspectRatio: kAspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const JournalHeroIllustration(),

              // GEÇİŞ: solda yüzey rengi, sağda saydam. Metnin arkası her
              // zaman düz kalıyor, çizim sağda görünüyor.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colors.surfaceContainerHigh,
                      colors.surfaceContainerHigh.withValues(alpha: 0),
                    ],
                    stops: const [0.34, 0.66],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // ÜSTTEN başlıyor: selam kartın tepesinde duruyor.
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      personName == null || personName.isEmpty
                          ? l10n.journalHeroGreeting
                          : l10n.journalHeroGreetingNamed(personName),
                      // POPPINS, Cormorant DEĞİL.
                      //
                      // Serif denendi ve altındaki Poppins cümleyle aynı
                      // aileden görünmüyordu: küçücük bir kartta iki yazı
                      // ailesi, tasarımı "iki sesli" yapıyor. Serifi
                      // uygulamanın gerçekten duygusal konuştuğu yerlere
                      // (onboarding, boş durum başlıkları) bırakıyoruz.
                      style: context.textStyles.screenTitle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // GENİŞLİK SINIRLI: cümle iki satıra düşüyor ve sağdaki
                    // çizimin üstüne taşmıyor.
                    FractionallySizedBox(
                      widthFactor: kTextWidthRatio,
                      child: Text(
                        l10n.journalHeroBody,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),

                    // Metinle düğme arası GENİŞ: ikisi birbirine yapışıkken
                    // düğme cümlenin devamı gibi okunuyordu.
                    const Spacer(),

                    FilledButton.icon(
                      onPressed: onStartWriting,
                      icon: const Icon(AppIcons.edit, size: AppIconSize.sm),
                      label: Text(l10n.journalHeroAction),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Köşedeki yaprak rozeti — referansın imzası. Dekoratif olduğu
              // için ekran okuyucudan gizli (kartın kendi etiketi var).
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Icon(
                        // Yaprak: referanstaki rozetin içindeki motif ve
                        // markanın kendi filizi.
                        AppIcons.leaf,
                        size: AppIconSize.md,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
