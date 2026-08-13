/// `AsyncValue` → ekran dönüşümünü tek yerde toplayan widget.
///
/// NEDEN?
/// Her ekranda şunu yazmak istemezsin:
/// ```dart
/// state.when(
///   loading: () => const Center(child: CircularProgressIndicator()),
///   error: (e, s) => Center(child: Text('$e')),   // ← ham hata, kötü UX
///   data: (items) => ...,
/// )
/// ```
/// Bu widget yükleme/hata/boş durumlarını tutarlı ve erişilebilir biçimde
/// halleder; sen sadece `data` dalını yazarsın.
///
/// NFR-035: "Boş durum ekranları kullanıcıya ne yapacağını açıklamalıdır."
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/error/failure.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/l10n/failure_l10n.dart';
import 'package:iz/shared/widgets/app_error_view.dart';

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.onRetry,
    this.emptyBuilder,
    this.isEmpty,
    this.loading,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Hata ekranındaki "Tekrar dene" butonu. null ise buton gösterilmez.
  final VoidCallback? onRetry;

  /// Veri boşsa gösterilecek ekran (NFR-035).
  final Widget Function()? emptyBuilder;

  /// Verinin "boş" sayılma kuralı. Verilmezse liste uzunluğuna bakılır.
  final bool Function(T data)? isEmpty;

  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => loading ?? const _CenteredLoader(),
      error: (error, stackTrace) => AppErrorView(
        message: error is Failure
            ? error.localizedMessage(context.l10n)
            : context.l10n.errorGeneric,
        onRetry: (error is Failure && !error.isRetryable) ? null : onRetry,
      ),
      data: (value) {
        if (_resolveEmpty(value) && emptyBuilder != null) {
          return emptyBuilder!();
        }
        return data(value);
      },
    );
  }

  bool _resolveEmpty(T value) {
    final custom = isEmpty;
    if (custom != null) return custom(value);
    if (value is Iterable) return value.isEmpty;
    return false;
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) => Center(
    // Ekran okuyucu için etiket — NFR-032.
    // (`Semantics` const constructor'a sahip değil, bu yüzden const yok.)
    child: Semantics(
      label: context.l10n.commonLoading,
      child: const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    ),
  );
}

// SLIVER SÜRÜMÜ BİLEREK YOK.
//
// Burada bir `SliverAsyncValueView` vardı: hiçbir yerden çağrılmıyordu ve
// yukarıdakinin eksik bir kopyasıydı — `isRetryable` kontrolü yoktu (yani
// doğrulama hatasında da "Tekrar dene" gösteriyordu) ve boş durumda
// `AppEmptyState(title: '')` çiziyordu, yani NFR-035'in yasakladığı BOŞ
// ekranın kendisi.
//
// Sliver bir sürüm gerçekten gerekirse: `AsyncValueView`ı `SliverToBoxAdapter`
// içine koymak çoğu durumda yeter. Yetmiyorsa buraya yazılır — ama o gün
// `isEmpty`/`onRetry` kurallarını yukarıdakiyle PAYLAŞARAK, ikinci bir
// kopya üretmeden.
