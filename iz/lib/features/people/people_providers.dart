/// Kişiler feature'ının DIŞARI AÇILAN yüzü.
///
/// NEDEN AYRI DOSYA?
/// Anı formu "bu anıda kimler vardı?" diye soruyor, yani kişi listesine
/// ihtiyacı var — ama kişilerin İÇİNİ (DAO, uygulama sınıfı) görmemeli
/// (ARCHITECTURE.md §2 / TR-C-03: bir feature başka feature'ın yalnız
/// sözleşmesini tanır).
///
/// Sağlayıcıyı `data/repositories/...` içinde bırakmak, onu okumak isteyen
/// herkesi veri katmanını import etmeye zorluyordu. Medya tarafında
/// (`media_providers.dart`) aynı kapıyı açtık; desen bu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz/app/database/app_database.dart';
import 'package:iz/core/utils/id_generator.dart';
import 'package:iz/features/people/data/repositories/person_repository_impl.dart';
import 'package:iz/features/people/domain/repositories/person_repository.dart';

/// Domain arayüzü üzerinden veriyoruz: çağıranlar `PersonRepositoryImpl`i
/// değil `PersonRepository`yi görür.
final personRepositoryProvider = Provider<PersonRepository>((ref) {
  return PersonRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).personDao,
    idGenerator: ref.watch(idGeneratorProvider),
  );
});
