/// Senkronizasyon defterleri — M13.1.
///
/// ÜÇÜ DE YEREL VE ASLA SENKRONİZE EDİLMEZ. `SyncableTable` kullanmıyorlar:
/// bu tablolar senkronizasyonun KENDİSİNİ anlatıyor, senkronize edilecek
/// veriyi değil. Outbox'ı sunucuya göndermek özyineleme olurdu.
///
/// Faz 2'de tablolar KURULUYOR ama kimse okumuyor; motor Faz 3'te geliyor
/// (TR-M13-01). Şemayı erken açmanın sebebi rapor §12.2: sütun bugün 4
/// satır, sonra kurtarılmış bir migration.
library;

import 'package:drift/drift.dart';
import 'package:iz/features/sync/domain/entities/outbox_operation.dart';

/// TR-M13-01 — sunucuya gönderilmeyi bekleyen değişiklikler.
///
/// NEDEN KUYRUK? Kullanıcı çevrimdışıyken de yazabilmeli. Yazma anında
/// ağa çıkmayı denemek, uçakta yazılan bir anının kaybolması demekti.
@DataClassName('OutboxEntryRow')
@TableIndex(name: 'idx_outbox_created', columns: {#createdAt})
class OutboxEntries extends Table {
  /// UUID v7. Aynı zamanda `Idempotency-Key` olarak gidiyor (TR-M13-04):
  /// yeniden denemede AYNI anahtar kullanılınca sunucu tek kayıt oluşturur.
  TextColumn get id => text()();

  /// Hangi tablo — `memory`, `person`, `journal_entry`…
  ///
  /// Serbest metin, enum değil: yeni bir entity eklendiğinde eski
  /// kuyruktaki satırlar okunamaz hâle gelmesin. Kuyruk kullanıcının
  /// cihazında uygulama güncellemesinden SAĞ ÇIKAR.
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  TextColumn get op => textEnum<OutboxOperation>()();

  /// Değişikliğin gövdesi.
  ///
  /// ANLIK GÖRÜNTÜ, referans değil: kayıt kuyrukta beklerken üç kez daha
  /// düzenlenebilir. Gönderim anında tabloyu okusaydık, sunucuya giden şey
  /// kullanıcının o an yaptığı değişiklik değil en son hâli olurdu ve ara
  /// sürümler sessizce kaybolurdu.
  TextColumn get payloadJson => text()();

  /// Gönderim anındaki yerel `version`. Sunucu bununla çakışma tespit eder
  /// (TR-M13-10): sunucudaki sürüm daha yeniyse biri araya girmiş demektir.
  IntColumn get baseVersion => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// TR-M13-03 — üstel geri çekilmenin sayacı.
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  /// Son hata metni. Yedekleme Sağlığı ekranı bunu gösteriyor (FR-614).
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Eşitlemenin nerede kaldığı — rapor 12'deki `BackupState`.
///
/// TEK SATIRLIK TABLO: `id` her zaman [SyncState.singletonId]. Ayarlarda
/// tutulabilirdi ama cursor'ın veriyle AYNI transaction'da yazılması
/// gerekiyor (TR-M13-01), `SharedPreferences` bunu yapamaz.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  /// Sabit anahtar — değeri [singletonId].
  ///
  /// VARSAYILAN NEDEN DÜZ METİN? Drift üretilen koda bu ifadeyi OLDUĞU GİBİ
  /// kopyalıyor; `singletonId` yazsaydık üretilen dosyada niteliksiz bir ad
  /// olarak kalır ve derlenmezdi.
  TextColumn get id => text().withDefault(const Constant('local'))();

  /// Sunucudan nereye kadar çekildiği. `null` = hiç eşitlenmedi, bootstrap
  /// gerekiyor (TR-M13-23).
  TextColumn get cursor => text().nullable()();

  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  /// Kuyrukta bekleyen öğe sayısı. Outbox'tan `COUNT(*)` ile de bulunurdu;
  /// burada tutmamızın sebebi Yedekleme Sağlığı ekranının çevrimdışıyken de
  /// anında açılması.
  IntColumn get pendingCount => integer().withDefault(const Constant(0))();

  static const singletonId = 'local';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// TR-M13-10 — çakışmada KURTARILAN yerel sürüm.
///
/// Sunucu sürümü kaydın üzerine yazılır; kullanıcının kaybolacak olan metni
/// buraya alınır. Otomatik birleştirme YAPILMAZ ve kullanıcı seçmeden önce
/// hiçbir sürüm silinmez (TR-M13-11).
@DataClassName('SyncConflictRow')
@TableIndex(name: 'idx_sync_conflicts_unresolved', columns: {#resolvedAt})
class SyncConflicts extends Table {
  TextColumn get id => text()();

  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// Hangi alan çakıştı — `title`, `note`…
  TextColumn get field => text()();

  TextColumn get localValue => text().nullable()();
  TextColumn get serverValue => text().nullable()();

  DateTimeColumn get detectedAt => dateTime().withDefault(currentDateAndTime)();

  /// `null` iken çakışma AÇIK. Yedekleme Sağlığı ekranındaki sayaç bunu
  /// sayıyor (TR-M13-12).
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
