#!/bin/sh
set -eu

log() {
    printf '%s isipsafe: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

sync_once() {
    output="${BLOCKLIST_OUTPUT:-/data/blocklist.txt}"
    format="${BLOCKLIST_FORMAT:-txt}"
    tmp="${output}.tmp.$$"

    set -- blocklist --format "$format" -o "$tmp"
    [ -n "${BLOCKLIST_CONFIDENCE_MINIMUM:-}" ] && set -- "$@" --confidence-minimum "$BLOCKLIST_CONFIDENCE_MINIMUM"
    [ -n "${BLOCKLIST_LIMIT:-}" ] && set -- "$@" --limit "$BLOCKLIST_LIMIT"
    [ -n "${BLOCKLIST_DAYS:-}" ] && set -- "$@" --days "$BLOCKLIST_DAYS"
    [ -n "${BLOCKLIST_IP_VERSION:-}" ] && set -- "$@" --ip-version "$BLOCKLIST_IP_VERSION"
    [ -n "${BLOCKLIST_ONLY_COUNTRIES:-}" ] && set -- "$@" --only-countries "$BLOCKLIST_ONLY_COUNTRIES"
    [ -n "${BLOCKLIST_EXCEPT_COUNTRIES:-}" ] && set -- "$@" --except-countries "$BLOCKLIST_EXCEPT_COUNTRIES"
    [ -n "${ISIPSAFE_BASE_URL:-}" ] && set -- --base-url "$ISIPSAFE_BASE_URL" "$@"

    if ! isipsafe "$@"; then
        rm -f "$tmp"
        log "download failed; keeping the previous $output"
        return 1
    fi
    if [ ! -s "$tmp" ] && [ -s "$output" ]; then
        rm -f "$tmp"
        log "downloaded list is empty; keeping the previous $output"
        return 1
    fi
    mv -f "$tmp" "$output"
    log "updated $output ($(wc -l <"$output" | tr -d ' ') lines, format $format)"
    return 0
}

sync_blocklist() {
    if [ -z "${ISIPSAFE_API_KEY:-}" ]; then
        log "ISIPSAFE_API_KEY is not set; get a free key at https://isipsafe.com/login"
        exit 2
    fi
    interval="${BLOCKLIST_INTERVAL:-1800}"
    case "$interval" in
        '' | *[!0-9]*) log "BLOCKLIST_INTERVAL must be a number of seconds"; exit 2 ;;
    esac
    if [ "${1:-}" = "--once" ]; then
        sync_once
        exit $?
    fi
    if [ "$interval" -lt 300 ]; then
        log "BLOCKLIST_INTERVAL below 300 seconds; using 300"
        interval=300
    fi
    trap 'log "stopping"; exit 0' TERM INT
    while :; do
        sync_once || true
        sleep "$interval" &
        wait $!
    done
}

case "${1:-}" in
    sync-blocklist)
        shift
        sync_blocklist "$@"
        ;;
    isipsafe)
        shift
        exec isipsafe "$@"
        ;;
    sh | /bin/sh | ash)
        exec "$@"
        ;;
    *)
        exec isipsafe "$@"
        ;;
esac
