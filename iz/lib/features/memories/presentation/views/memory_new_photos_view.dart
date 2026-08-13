/// Yeni anı akışının **İLK adımı**: fotoğraf seçimi.
///
/// Ürünün tezi burada başlıyor. Rapor 3.2: *"Fotoğraf temel nesne değil; anı
/// temel nesnedir."* Ama bir anıyı hatırlatan ilk şey genelde bir kare — bu
/// yüzden akış fotoğrafla açılıyor, formla değil. Kullanıcı önce "hangi
/// kareler" diye düşünüyor, başlık ve not sonra geliyor.
///
/// AKIŞ: fotoğraf seçilir → BU SAYFA KAPANIR → detay adımı açılır.
/// `pushReplacement` kullanıyoruz, `push` değil: geri tuşuna basan kullanıcı
/// fotoğraf seçim ekranına DÖNMEMELİ, akıştan çıkmalı. Aksi hâlde seçimini
/// yaptıktan sonra aynı soruyu ikinci kez görürdü.
///
/// LİMİT SABİT DEĞİL. Hem alttaki uyarıdaki sayı hem de seçicinin izin
/// verdiği en fazla adet entitlement matrisinden geliyor (FR-041 / NFR-043):
/// ücretsiz planda 3, İZ+'ta 30.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz/app/router/app_routes.dart';
import 'package:iz/core/entitlement/entitlement.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/core/media/media_picker.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';
import 'package:iz/features/memories/presentation/widgets/photo_prompt_illustration.dart';

class MemoryNewPhotosView extends ConsumerWidget {
  const MemoryNewPhotosView({super.key});

  /// İçerik sütununun genişliği.
  ///
  /// Sayfa marjına kadar yaymıyoruz: başlık iki satıra bölünsün ve düğme
  /// ekranın tamamını kaplamasın. Referans tasarımda da başlık ile düğme
  /// AYNI ölçüyü paylaşıyor — ortalanmış tek bir sütun gibi okunuyor.
  static const double kContentWidth = 300;

  /// İçeriğin dikey hizası.
  ///
  /// Tam ortada DEĞİL, biraz yukarıda: illüstrasyon büyüdüğü için ortalanmış
  /// bir blok ekranın altına doğru sarkıyordu. −0.35 blok ile üst kenar
  /// arasındaki nefesi koruyup ağırlık merkezini yukarı alıyor.
  static const Alignment kContentAlignment = Alignment(0, -0.35);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // FR-041 — plana göre fotoğraf limiti.
    final photoLimit = ref
        .watch(entitlementsProvider)
        .limit(IzLimit.photosPerMemory);

    return Scaffold(
      // Zemin tema token'ından: açık temada krem (#FAF8F3), koyu temada
      // koyu yeşilimsi. Elle renk yazmıyoruz, iki tema kendiliğinden
      // doğru oluyor.
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        // Tasarımda başlık ORTADA; uygulamanın genel `appBarTheme`ı ise
        // sola yaslıyor (bkz. app_theme.dart). Bu ekran tam ekran bir
        // adım olduğu için ortalıyoruz.
        centerTitle: true,
        title: Text(l10n.memoryNew),
        // GERİ OKU DEĞİL ÇARPI: bu bir akışın adımı değil, üste açılan tam
        // ekran bir görev. Çarpı "vazgeç ve kapat" demek; geri oku
        // "önceki adıma dön" demek olurdu ve öncesi yok.
        leading: IconButton(
          icon: const Icon(AppIcons.clear),
          tooltip: l10n.commonClose,
          onPressed: () => context.pop(),
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment: kContentAlignment,
          child: SingleChildScrollView(
            // Küçük ekranda ve büyük yazı ölçeğinde içerik sığmayabilir;
            // kırpmak yerine kaydırılsın (NFR-032).
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: PhotoPromptIllustration()),
                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    l10n.memoryPhotosPrompt,
                    // Serif — markanın duygusal sesi. Bu bir form etiketi
                    // değil, bir soru.
                    style: context.text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  // Başlık ile düğme arası, illüstrasyon–başlık arasından
                  // DAHA GENİŞ.
                  //
                  // Amaç sırayı hissettirmek: illüstrasyon ve soru birlikte
                  // "burada ne oluyor"u anlatan tek bir blok; düğme ise ayrı
                  // bir şey, kullanıcının vereceği karar. Aralarındaki boşluk
                  // bu ayrımı taşıyor — eşit boşluklarda üçü de sıralı bir
                  // liste gibi okunuyordu.
                  const SizedBox(height: AppSpacing.xxl),

                  FilledButton.icon(
                    onPressed: () => _pickFromGallery(context, ref, photoLimit),
                    icon: const Icon(AppIcons.photoLibrary),
                    label: Text(l10n.memoryPickFromGallery),
                  ),
                  // Uyarı düğmeye YAPIŞMASIN: düğmenin bir parçası gibi
                  // değil, onu açıklayan ayrı bir not gibi okunmalı.
                  const SizedBox(height: AppSpacing.md),

                  Text(
                    l10n.memoryPhotoLimitHint(photoLimit),
                    style: context.textStyles.caption.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sistem galerisini açar; seçim yapıldıysa akışı detay adımına taşır.
  ///
  /// ÜÇ SONUÇ VAR ve üçü de farklı davranıyor:
  ///   • hata      → bildirim, sayfada kal
  ///   • vazgeçti  → hiçbir şey yapma (boş liste bir hata değil, bir karar)
  ///   • seçti     → bu sayfayı KAPAT, detay adımını aç
  ///
  /// Tek fotoğraf da yeter: kullanıcı üç tanesini seçmek zorunda değil.
  Future<void> _pickFromGallery(
    BuildContext context,
    WidgetRef ref,
    int limit,
  ) async {
    final result = await ref.read(mediaPickerProvider).pickImages(limit: limit);

    // Seçici uygulamanın DIŞINDA çalışıyor; dönüşte bu ekran hâlâ ayakta mı
    // diye bakmak zorundayız (use_build_context_synchronously).
    if (!context.mounted) return;

    final picked = result.fold(
      onOk: (images) => images,
      onErr: (failure) {
        context.showSnack(failure.localizedMessage(context.l10n));
        return const <PickedImage>[];
      },
    );

    if (picked.isEmpty) return;

    // Seçilen dosya yolları detay adımına `extra` ile taşınıyor.
    //
    // ⚠️ HENÜZ KALICI DEĞİL: medya hattı (dosyayı uygulama alanına kopyalama,
    // önizleme üretme, `MediaItems` tablosuna yazma) kurulmadı. Şimdilik
    // yalnızca yollar geçiyor; detay ekranı onları gösteriyor.
    context.pushReplacementNamed(
      AppRoute.memoryNewDetails.name,
      extra: [for (final image in picked) image.path],
    );
  }
}
