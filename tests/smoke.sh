#!/usr/bin/env sh
# The checks the gateway must pass. Usage: ./tests/smoke.sh http://localhost:8000
set -u
BASE="${1:-http://localhost:8000}"
fail=0

check() {  # description, expected status, curl arguments...
  desc="$1"; want="$2"; shift 2
  got=$(curl -s -o /dev/null -w '%{http_code}' "$@")
  if [ "$got" = "$want" ]; then echo "  ok    $desc ($got)"; else echo "  FAIL  $desc: want $want, got $got"; fail=1; fi
}

contains() {  # description, expected text, curl arguments...
  desc="$1"; want="$2"; shift 2
  if curl -s -i "$@" | grep -qi -- "$want"; then echo "  ok    $desc"; else echo "  FAIL  $desc: missing $want"; fail=1; fi
}

absent() {  # description, forbidden text, curl arguments...
  desc="$1"; bad="$2"; shift 2
  if curl -s -i "$@" | grep -qi -- "$bad"; then echo "  FAIL  $desc: found $bad"; fail=1; else echo "  ok    $desc"; fi
}

check    "health answers"                          200 "$BASE/health"
check    "unknown route is 404"                    404 "$BASE/nope"
contains "404 uses the error envelope"             '"error":"NOT_FOUND"' "$BASE/nope"
check    "protected route without token is 401"    401 "$BASE/api/v1/users"
contains "401 uses the error envelope"             '"error":"UNAUTHORIZED"' "$BASE/api/v1/users"
contains "a correlation id is generated"           'X-Correlation-Id:' "$BASE/api/v1/users"
contains "the client's correlation id is kept"     'X-Correlation-Id: smoke-1' -H 'X-Correlation-Id: smoke-1' "$BASE/api/v1/users"
check    "preflight is allowed"                    204 -X OPTIONS -H 'Origin: http://localhost:3000' "$BASE/api/v1/users"
contains "CORS allows Idempotency-Key"             'Idempotency-Key' -X OPTIONS -H 'Origin: http://localhost:3000' "$BASE/api/v1/users"
contains "CORS exposes X-Correlation-Id"           'Access-Control-Expose-Headers: X-Correlation-Id' -H 'Origin: http://localhost:3000' "$BASE/api/v1/users"
absent   "an unknown origin gets no CORS grant"    'Access-Control-Allow-Origin' -H 'Origin: http://evil.example' "$BASE/api/v1/users"

exit $fail
