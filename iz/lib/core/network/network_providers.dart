/// Ağ katmanının DI bağlantıları.
///
/// `core/` altında provider tanımlamak alışılmadık görünebilir ama
/// `core/storage/app_preferences.dart` da aynısını yapıyor: kural "core
/// hiçbir FEATURE'ı bilmez", "core provider tanımlayamaz" değil.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/core/network/api_client.dart';
import 'package:iz/core/network/auth_token_provider.dart';

/// Uygulamanın tek Dio örneği.
///
/// TEK OLMASI ÖNEMLİ: bağlantı havuzu, zaman aşımı ayarları ve
/// interceptor'lar burada bir kez kuruluyor. Her çağrı yerinin kendi Dio'sunu
/// yaratması, kimlik başlığını eklemeyi unutan bir istek demekti.
final dioProvider = Provider<Dio>((ref) {
  return buildIzDio(tokens: ref.watch(authTokenProviderProvider));
});

final apiClientProvider = Provider<IzApiClient>((ref) {
  return IzApiClient(dio: ref.watch(dioProvider));
});
