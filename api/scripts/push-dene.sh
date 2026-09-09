#!/usr/bin/env bash
#
# /v1/sync/push'u GERÇEK bir hesapla, GERÇEK bir sunucuya karşı dener.
#
# NEDEN VAR? İstemcide kuyruğu gönderen motor (`SyncEngine`) henüz yazılmadı;
# uygulamadan push tetiklenemiyor. Bu betik o boşluğu dolduruyor ve aynı
# zamanda kablodaki gövde biçiminin ÇALIŞAN belgesi: yol haritası §4.1'de
# yazan şeyin gerçekten öyle olduğunu her koşuşta kanıtlıyor.
#
# Entegrasyon testleri aynı senaryoları zaten koşuyor (`SyncPushTests`).
# Bunun farkı: Docker'daki asıl imaj, asıl Postgres ve Firebase'in ASIL
# token'ı. Testlerin göremediği şeyler burada görünüyor — nitekim ilk
# koşuşta geçersiz UTF-8'in bütün batch'i 500'e düşürdüğü ortaya çıktı.
#
# KULLANIM
#   cd api && docker compose up -d
#   IZ_EMAIL=... IZ_PAROLA=... bash scripts/push-dene.sh
#
# ⚠️ ŞEMAYI BİR KEZ KURMAK GEREKİYOR — API açılışta migration UYGULAMIYOR:
#   IZ_Iz__DatabaseConnection="Host=localhost;Port=5432;Database=iz;Username=iz;Password=gelistirme" \
#     dotnet ef database update --project src/Iz.Infrastructure --startup-project src/Iz.Infrastructure
set -euo pipefail

API="${IZ_API:-http://localhost:8080}"
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${IZ_EMAIL:?IZ_EMAIL gerekli — Firebase test hesabının e-postası}"
: "${IZ_PAROLA:?IZ_PAROLA gerekli}"

# Firebase Web API anahtarı — SIR DEĞİL. Her mobil uygulamanın içine gömülü
# dağıtılıyor, herkes görebilir. Gizli olan şey servis hesabı dosyasıdır ve
# bizim sunucumuzun ona ihtiyacı yok: token'ı Google'ın AÇIK anahtarlarıyla
# doğruluyor (ADR-B15).
#
# Değeri istemcinin dosyasından OKUNUYOR, buraya kopyalanmıyor: iki yerde
# duran bir değer bir gün ayrışır ve betik sessizce yanlış projeye bağlanır.
ANAHTAR="${IZ_FIREBASE_KEY:-$(
  sed -n 's/.*"current_key": *"\([^"]*\)".*/\1/p' \
    "$KOK/../iz/android/app/google-services.json" | head -1
)}"
[ -n "$ANAHTAR" ] || { echo "Firebase anahtarı bulunamadı."; exit 1; }

# Windows'ta python stdin'i sistemin ANSI kod sayfasıyla okuyor ve sunucunun
# UTF-8 yanıtını bozuk gösteriyor ("molası" → "molasÄ±"). Veri doğru, gösterim
# yanlış — ama bu fark hata avlarken saatler yakar.
export PYTHONIOENCODING=utf-8

# Süsleme isteğe bağlı: python yoksa ham JSON basılır, betik yine çalışır.
if command -v python >/dev/null 2>&1; then
  guzel() { python -m json.tool 2>/dev/null || cat; }
else
  guzel() { cat; }
fi

bolum() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# UUID v4 — python'a bağımlı olmadan. Git Bash'te de /dev/urandom var.
uuid() {
  local h
  h=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
  printf '%s-%s-4%s-a%s-%s\n' \
    "${h:0:8}" "${h:8:4}" "${h:13:3}" "${h:17:3}" "${h:20:12}"
}

# Tek bir JSON alanını çeker. Gövdeler küçük ve alan adları benzersiz;
# tam bir ayrıştırıcı gerekmiyor.
alan() { sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p" | head -1; }

bolum "1) Firebase'den ID token alınıyor"
TOKEN=$(
  curl -s -X POST \
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$ANAHTAR" \
    -H 'Content-Type: application/json' \
    --data-binary @- <<< "{\"email\":\"$IZ_EMAIL\",\"password\":\"$IZ_PAROLA\",\"returnSecureToken\":true}" \
  | tr ',' '\n' | alan idToken
)
[ -n "$TOKEN" ] || { echo "Token alınamadı — e-posta/parola doğru mu?"; exit 1; }
echo "Token alındı (${#TOKEN} karakter)."

# GÖVDE STDIN'DEN GİDİYOR, komut satırından DEĞİL.
# Git Bash yerli bir Windows programına (curl.exe) argüman geçerken metni
# sistemin ANSI kod sayfasına çeviriyor: UTF-8 "ş" (c5 9f) tek bayt 0xFE olur
# ve gövde geçersiz UTF-8 hâline gelir. Sunucu bunu artık `rejected` ile
# karşılıyor ama gönderdiğimiz şeyin bozuk olmaması gerekiyor.
cagir() {  # cagir <METOT> <yol> [gövde]
  local metot=$1 yol=$2 govde=${3:-}
  if [ -n "$govde" ]; then
    curl -s -X "$metot" "$API$yol" \
      -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
      --data-binary @- <<< "$govde"
  else
    curl -s -X "$metot" "$API$yol" -H "Authorization: Bearer $TOKEN"
  fi
}

bolum "2) Profil — ilk çağrı users kaydını token'daki uid ile açar"
cagir GET /v1/me | guzel

bolum "3) Cihaz kaydı — kimliği SUNUCU üretiyor"
CIHAZ=$(cagir POST /v1/devices \
  '{"platform":"android","appVersion":"1.5.0","schemaVersion":8}' | alan id)
[ -n "$CIHAZ" ] || { echo "Cihaz kaydedilemedi."; exit 1; }
echo "deviceId = $CIHAZ"

ANI=$(uuid); KISI=$(uuid)
echo "memoryId = $ANI"
echo "personId = $KISI"

# Alan adları SQL SÜTUN ADI (snake_case) ve gövde zarflı — istemcinin
# ürettiği biçimin aynısı (iz/lib/features/sync/data/outbox_payload.dart).
govde() {  # govde <baslik> <bag_silindi_mi: evet|hayir>
  local silinme=null
  [ "$2" = "evet" ] && silinme='"2026-03-13T08:00:00.000Z"'
  cat <<JSON
{ "v": 1,
  "entity": {
    "id": "$ANI", "title": "$1", "note": null,
    "occurred_at": "2026-03-12T10:00:00.000Z",
    "occurred_year": 2026, "occurred_month": 3, "occurred_day": 12,
    "is_favorite": false, "is_archived": false,
    "created_at": "2026-03-12T10:00:00.000Z",
    "updated_at": "2026-03-12T10:00:00.000Z",
    "version": 1, "owner_id": "local"
  },
  "links": { "memory_people": [
    { "memory_id": "$ANI", "person_id": "$KISI", "role": "kardeşim",
      "created_at": "2026-03-12T10:00:00.000Z",
      "updated_at": "2026-03-12T10:00:00.000Z",
      "deleted_at": $silinme, "version": 1 }
  ] } }
JSON
}

push() {  # push <op> <baseVersion> <payload>
  cagir POST /v1/sync/push "{\"deviceId\":\"$CIHAZ\",\"changes\":[
    {\"entityType\":\"memory\",\"entityId\":\"$ANI\",\"op\":\"$1\",
     \"baseVersion\":$2,\"payload\":$3}]}" | guzel
}

bolum "4) Yeni anı + kişi bağı  ->  applied, version 1, seq DOLU"
push upsert 0 "$(govde 'Kahve molası' hayir)"

bolum "5) AYNI gövde yeniden  ->  applied ama seq NULL (hiçbir alan değişmedi)"
push upsert 1 "$(govde 'Kahve molası' hayir)"

bolum "6) Başlık değişti  ->  version 2, yeni seq"
push upsert 1 "$(govde 'Kahve molası — düzenlendi' hayir)"

bolum "7) ESKİ sürümle gönderim  ->  conflict + SUNUCUNUN gövdesi"
push upsert 1 "$(govde 'Eski cihazın başlığı' hayir)"

bolum "8) Kişi çıkarıldı (bağ tombstone geldi)  ->  bağ siliniyor"
push upsert 2 "$(govde 'Kahve molası — düzenlendi' evet)"

bolum "9) Bağ CANLI olarak yeniden gönderiliyor  ->  SİLME KAZANIR, dirilmiyor"
push upsert 2 "$(govde 'Kahve molası — düzenlendi' hayir)"

bolum "10) Tanınmayan tür + sağlam kayıt aynı batch'te  ->  biri rejected, öteki applied"
cagir POST /v1/sync/push "{\"deviceId\":\"$CIHAZ\",\"changes\":[
  {\"entityType\":\"bilinmeyen\",\"entityId\":\"$ANI\",\"op\":\"upsert\",
   \"baseVersion\":0,\"payload\":$(govde 'gecmemeli' hayir)},
  {\"entityType\":\"memory\",\"entityId\":\"$ANI\",\"op\":\"upsert\",
   \"baseVersion\":2,\"payload\":$(govde 'Kuyruk kilitlenmedi' hayir)}]}" | guzel

psql() { docker compose --project-directory "$KOK" exec -T postgres psql -U iz -d iz -c "$1"; }

bolum "SUNUCUDA NE VAR?"
psql "SELECT title, version, deleted_at IS NOT NULL AS silindi
      FROM memories WHERE id = '$ANI';"
psql "SELECT role, version, deleted_at IS NOT NULL AS silindi
      FROM memory_people WHERE memory_id = '$ANI';"

bolum "DEĞİŞİKLİK GÜNLÜĞÜ — ikinci cihaza gidecek satırlar"
psql "SELECT seq, entity_type, operation, version FROM change_log
      WHERE entity_id IN ('$ANI', '$ANI:$KISI') ORDER BY seq;"
