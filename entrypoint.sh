#!/bin/sh
set -eu

DATA_DIR="${DATA_DIR:-/app/data}"
DB_PATH="${DATA_DIR}/db/data.sqlite"
CONFIG="${LITESTREAM_CONFIG:-/etc/litestream.yml}"

log() {
    printf '%s %s\n' '[9ROUTER-B2]' "$*"
}

fail() {
    log "ERRO: $*"
    exit 1
}

# Required runtime configuration.
: "${B2_KEY_ID:?B2_KEY_ID is required}"
: "${B2_APPLICATION_KEY:?B2_APPLICATION_KEY is required}"
: "${B2_BUCKET:?B2_BUCKET is required}"
: "${B2_ENDPOINT:?B2_ENDPOINT is required}"
: "${B2_REGION:?B2_REGION is required}"

mkdir -p "${DATA_DIR}/db" "${DATA_DIR}/.litestream"

log "Config: ${CONFIG}"
log "Database: ${DB_PATH}"
log "B2 bucket: ${B2_BUCKET}"

# Restore BEFORE starting Node/9Router. This guarantees that restoration and the
# application never open the SQLite database at the same time.
if [ ! -s "${DB_PATH}" ]; then
    if [ -f "${DB_PATH}" ]; then
        log "Banco vazio detectado; removendo arquivo para permitir a restauração."
        rm -f "${DB_PATH}" "${DB_PATH}-wal" "${DB_PATH}-shm"
    fi

    log "Banco local não encontrado. Procurando réplica no B2..."

    if litestream restore \
        -config "${CONFIG}" \
        -if-replica-exists \
        -integrity-check quick \
        "${DB_PATH}"; then
        if [ -s "${DB_PATH}" ]; then
            log "Banco restaurado do B2 com sucesso."
        else
            log "Nenhuma réplica encontrada. 9Router será inicializado com banco novo."
        fi
    else
        fail "Falha real ao restaurar o banco do B2. O 9Router não será iniciado para evitar sobrescrever a recuperação."
    fi
else
    log "Banco local encontrado. Restauração não necessária."
fi

# Run Litestream as PID 1 and let it supervise the Node process. Litestream
# handles child lifecycle/signals and keeps replication alive while 9Router runs.
log "Iniciando Litestream + 9Router..."
exec litestream replicate \
    -config "${CONFIG}" \
    -log-level info \
    -exec "node /app/server.js"
