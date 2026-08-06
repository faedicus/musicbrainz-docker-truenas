#!/usr/bin/env bash
set -euo pipefail

MARKER="/var/lib/musicbrainz/.init-complete"

if [[ -f "${MARKER}" ]]; then
  echo "Init marker ${MARKER} exists; skipping initialization."
  exit 0
fi

echo "=== MusicBrainz automated initialization ==="

wait_for_port() {
  local host="$1" port="$2" name="$3"
  echo "Waiting for ${name} at ${host}:${port}..."
  local i
  for i in $(seq 1 60); do
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" 2>/dev/null; then
      echo "${name} is ready."
      return 0
    fi
    sleep 5
  done
  echo "Timed out waiting for ${name}." >&2
  return 1
}

wait_for_pg_ready() {
  echo "Waiting for PostgreSQL to accept connections..."
  local i
  for i in $(seq 1 30); do
    if pg_isready -h "${MUSICBRAINZ_POSTGRES_SERVER:-db}" -U "${POSTGRES_USER:-musicbrainz}" -d "${POSTGRES_DB:-musicbrainz}" >/dev/null 2>&1; then
      echo "PostgreSQL is accepting connections."
      return 0
    fi
    sleep 5
  done
  echo "PostgreSQL never became ready." >&2
  return 1
}

# 0. Wait for dependencies
wait_for_port "${MUSICBRAINZ_POSTGRES_SERVER:-db}" 5432 "PostgreSQL"
wait_for_pg_ready
wait_for_port "${MUSICBRAINZ_VALKEY_SERVER:-valkey}" 6379 "Valkey"
wait_for_port "search" 8983 "Solr search"

# 1. Database creation and dump fetch/restore
echo "[1/6] Creating/fetching MusicBrainz database..."
createdb.sh -fetch

# 2. Search index download and load
echo "[2/6] Fetching Solr search backup archives..."
fetch-backup-archives
echo "[3/6] Loading Solr search backup archives..."
load-backup-archives

# 3. Cleanup
echo "[4/6] Removing downloaded archives..."
remove-backup-archives

# 4. Replication token setup
TOKEN_FILE="/run/secrets/metabrainz_access_token"
if [[ -n "${REPLICATION_TOKEN:-}" ]]; then
  echo "[5/6] Writing replication token from REPLICATION_TOKEN..."
  install -m 600 -D <(printf '%s' "${REPLICATION_TOKEN}") "${TOKEN_FILE}"
elif [[ -s "${TOKEN_FILE}" ]]; then
  echo "[5/6] Replication token already mounted at ${TOKEN_FILE}."
else
  echo "[5/6] WARNING: REPLICATION_TOKEN is not set and no token file is mounted. Replication will fail." >&2
fi

# 5. Replication cron activation
CRONTAB_PATH="${MUSICBRAINZ_CRONTAB_PATH:-/etc/cron.d/musicbrainz-replication}"
if [[ -f "${CRONTAB_PATH}" ]]; then
  echo "[6/6] Activating replication crontab..."
  chmod 644 "${CRONTAB_PATH}"
  # If the image runs cron as a non-root user, install the crontab for that user
  if id musicbrainz >/dev/null 2>&1; then
    crontab -u musicbrainz "${CRONTAB_PATH}" || true
  fi
else
  echo "[6/6] WARNING: crontab file not found at ${CRONTAB_PATH}" >&2
fi

# 6. Write idempotency marker
mkdir -p "$(dirname "${MARKER}")"
date > "${MARKER}"
echo "=== Initialization complete ==="
