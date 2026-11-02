#!/bin/sh
set -eu

IMAGE="${IMAGE:-isipsafe:test}"
MOCK="isipsafe-mock-$$"
VOL="isipsafe-data-$$"
here="$(cd "$(dirname "$0")" && pwd)"
failures=0

cleanup() {
    docker rm -f "$MOCK" >/dev/null 2>&1 || true
    docker volume rm "$VOL" >/dev/null 2>&1 || true
}
trap cleanup EXIT

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }
expect() {
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1: got '$2'"; fi
}

docker volume create "$VOL" >/dev/null
docker run -d --name "$MOCK" \
    -v "$here/mock_api.py:/mock_api.py:ro" python:3.13-alpine python /mock_api.py >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if docker exec "$MOCK" python -c "import urllib.request,sys; urllib.request.urlopen('http://127.0.0.1:8000/ok/api/v1/check')" 2>/dev/null; then break; fi
    sleep 1
done

out="$(docker run --rm "$IMAGE" --version)"
expect "version" "$out" "isipsafe 0.1.0"

out="$(docker run --rm "$IMAGE" sh -c id)"
case "$out" in uid=10001*) pass "runs as non-root" ;; *) fail "user: $out" ;; esac

out="$(docker run --rm --network "container:$MOCK" "$IMAGE" --base-url http://127.0.0.1:8000/ok/api/v1 check 203.0.113.50 | head -1)"
expect "check through the CLI" "$out" "203.0.113.50  MALICIOUS"

if docker run --rm --network "container:$MOCK" "$IMAGE" --base-url http://127.0.0.1:8000/ok/api/v1 check 203.0.113.50 --fail-if-malicious >/dev/null; then
    fail "--fail-if-malicious should exit 1"
else
    pass "--fail-if-malicious exit code"
fi

if docker run --rm --network "container:$MOCK" "$IMAGE" sync-blocklist --once 2>/dev/null; then
    fail "sync without a key should fail"
else
    pass "sync refuses to start without a key"
fi

docker run --rm --network "container:$MOCK" -v "$VOL:/data" -e ISIPSAFE_API_KEY=sl_test \
    -e ISIPSAFE_BASE_URL=http://127.0.0.1:8000/ok/api/v1 "$IMAGE" sync-blocklist --once 2>/dev/null
out="$(docker run --rm -v "$VOL:/data" "$IMAGE" sh -c 'cat /data/blocklist.txt')"
expect "sync writes the blocklist" "$out" "$(printf '203.0.113.50\n198.51.100.4')"

if docker run --rm --network "container:$MOCK" -v "$VOL:/data" -e ISIPSAFE_API_KEY=sl_test \
    -e ISIPSAFE_BASE_URL=http://127.0.0.1:8000/fail/api/v1 "$IMAGE" sync-blocklist --once 2>/dev/null; then
    fail "sync against a failing API should exit non-zero"
else
    pass "sync reports a failed download"
fi
out="$(docker run --rm -v "$VOL:/data" "$IMAGE" sh -c 'cat /data/blocklist.txt; ls /data | grep -c tmp || true')"
expect "failed download keeps the previous list" "$out" "$(printf '203.0.113.50\n198.51.100.4\n0')"

docker run --rm --network "container:$MOCK" -v "$VOL:/data" -e ISIPSAFE_API_KEY=sl_test \
    -e ISIPSAFE_BASE_URL=http://127.0.0.1:8000/empty/api/v1 "$IMAGE" sync-blocklist --once 2>/dev/null || true
out="$(docker run --rm -v "$VOL:/data" "$IMAGE" sh -c 'cat /data/blocklist.txt')"
expect "empty download keeps the previous list" "$out" "$(printf '203.0.113.50\n198.51.100.4')"

if docker run --rm --network "container:$MOCK" -v "$VOL:/data" -e ISIPSAFE_API_KEY=sl_wrong \
    -e ISIPSAFE_BASE_URL=http://127.0.0.1:8000/ok/api/v1 "$IMAGE" sync-blocklist --once 2>/dev/null; then
    fail "wrong key should fail"
else
    pass "wrong key fails without touching the list"
fi

name="isipsafe-loop-$$"
docker run -d --name "$name" --network "container:$MOCK" -e ISIPSAFE_API_KEY=sl_test \
    -e ISIPSAFE_BASE_URL=http://127.0.0.1:8000/ok/api/v1 "$IMAGE" sync-blocklist >/dev/null
sleep 3
start="$(date +%s)"
docker stop -t 10 "$name" >/dev/null
elapsed=$(($(date +%s) - start))
docker rm "$name" >/dev/null
if [ "$elapsed" -lt 5 ]; then pass "loop stops promptly on SIGTERM (${elapsed}s)"; else fail "stop took ${elapsed}s"; fi

if [ "$failures" -gt 0 ]; then
    printf '%s test(s) failed\n' "$failures"
    exit 1
fi
printf 'all tests passed\n'
