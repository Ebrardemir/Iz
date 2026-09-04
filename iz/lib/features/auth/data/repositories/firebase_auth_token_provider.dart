/// [AuthTokenProvider]'ın Firebase karşılığı.
///
/// Ağ katmanı her isteğe kimlik eklemek için buraya soruyor. Token'ı
/// ÜRETMİYORUZ ve SAKLAMIYORUZ: ikisini de Firebase SDK'sı yapıyor
/// (TR-M1-02). Burada olan tek şey, elde varsa token'ı vermek.
library;

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:iz/core/logging/app_logger.dart';
import 'package:iz/core/network/auth_token_provider.dart';

final class FirebaseAuthTokenProvider implements AuthTokenProvider {
  FirebaseAuthTokenProvider({fb.FirebaseAuth? auth}) : _injected = auth;

  final fb.FirebaseAuth? _injected;
  final _log = appLogger('auth.token');

  fb.FirebaseAuth get _auth => _injected ?? fb.FirebaseAuth.instance;

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // Hesapsız kullanım normal durum (ADR-B12), hata değil.
        return null;
      }
      return await user.getIdToken(forceRefresh);
    } on Object catch (error, stackTrace) {
      // Token alınamadıysa isteği başlıksız göndeririz ve sunucu 401 döner.
      // Burada istisna fırlatmak, ağ katmanının her çağrısını try/catch'e
      // sarmayı gerektirirdi; oysa "token yok" zaten temsil edilebilen bir
      // durum. Yine de sessiz kalmıyoruz: sebep loga yazılıyor.
      //
      // MESAJ İNGİLİZCE — `firebase_auth_repository.dart`'taki 'no-app'
      // mesajıyla aynı gerekçe: loga gidiyor, kullanıcı görmüyor ve
      // `l10n_test` features/ altındaki Türkçe literalleri yakalıyor.
      _log.warning('Could not read Firebase ID token', error, stackTrace);
      return null;
    }
  }
}
