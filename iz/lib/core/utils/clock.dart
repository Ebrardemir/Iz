/// Zaman kaynağı soyutlaması.
///
/// NEDEN?
/// Kodun içinde doğrudan `DateTime.now()` çağırırsan "Bugünün İzi" (FR-080),
/// ritüel hatırlatmaları (FR-152) ve yıl sonu özeti (FR-084) gibi zamana bağlı
/// mantıkları TEST EDEMEZSİN — testin sonucu çalıştırdığın güne göre değişir.
///
/// Bunun yerine `ref.read(clockProvider).now()` kullan; testte
/// `clockProvider.overrideWithValue(FixedClock(DateTime(2026, 7, 26)))` de.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class Clock {
  DateTime now();
  DateTime today();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}

/// Testlerde kullan.
final class FixedClock implements Clock {
  const FixedClock(this._fixed);
  final DateTime _fixed;

  @override
  DateTime now() => _fixed;

  @override
  DateTime today() => DateTime(_fixed.year, _fixed.month, _fixed.day);
}

final clockProvider = Provider<Clock>((ref) => const SystemClock());
