/// Kişi deposu **sözleşmesi**.
///
/// Gerekçesi `MemoryRepository` ile aynı: domain "veriyi nasıl aldığımı
/// bilmem, ne aldığımı bilirim" der. Bugün Drift'ten geliyor; V1.5'te aynı
/// arayüzün arkasına senkronize eden bir sürüm konacak ve ViewModel'lerin
/// tek satırı değişmeyecek.
///
/// KURAL: hiçbir metot exception fırlatmaz — hepsi `Result` döner (TR-C-02).
library;

import 'package:iz/core/result/result.dart';
import 'package:iz/features/people/domain/entities/person.dart';

abstract interface class PersonRepository {
  /// FR-060 — kişi listesi. Veri değiştiğinde kendiliğinden yeniden yayınlar.
  ///
  /// Silinenler (tombstone) dahil DEĞİL.
  Stream<Result<List<Person>>> watchPeople();

  /// Kişi detayı. Kayıt yoksa `Ok(null)` — bu bir hata değil, silinmiş
  /// bir kişinin bağlantısına tıklamak olağan bir durum.
  Stream<Result<Person?>> watchPerson(String id);

  Future<Result<Person?>> findPerson(String id);

  /// Oluşturur veya günceller. Dönen değer kaydedilen kişinin kimliğidir.
  Future<Result<String>> save(PersonDraft draft);

  /// FR-060 — çöp kutusu yok, ama silme yine de TOMBSTONE.
  ///
  /// TR-C-32: fiziksel silme yapılmaz. Senkronizasyon geldiğinde "bu kişiyi
  /// sildim" olayının diğer cihaza taşınabilmesi buna bağlı.
  ///
  /// TR-M5-12: kişiyle etiketli ANILAR SİLİNMEZ, yalnız bağ kopar.
  Future<Result<Unit>> softDelete(String id);

  Future<Result<Unit>> setFavorite(String id, {required bool isFavorite});
}

/// Kişi formunun taşıdığı veri.
///
/// [Person]'dan AYRI bir tip: burada [id] boş olabilir (yeni kayıt) ve
/// [relationType] yok — o, [relationLabel]'dan türetiliyor
/// (bkz. `guessRelationType`). Entity'yi doğrudan taşısaydık çağıran tarafın
/// türü kendi hesaplaması gerekirdi ve iki yerde ayrışırdı.
final class PersonDraft {
  const PersonDraft({
    required this.name,
    this.id,
    this.kind = PersonKind.human,
    this.relationLabel,
    this.birthDate,
    this.avatarMediaId,
    this.note,
    this.isFavorite = false,
  });

  /// `null` → yeni kayıt; dolu → güncelleme.
  final String? id;

  final String name;
  final PersonKind kind;

  /// Kullanıcının kendi yazdığı ilişki adı ("Annem"). Tür bundan türetilir.
  final String? relationLabel;

  final DateTime? birthDate;
  final String? avatarMediaId;
  final String? note;
  final bool isFavorite;
}
