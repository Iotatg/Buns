#!/bin/sh
# A smoke test that starts its own server and its own state file, so it never
# touches the workspace you are looking at.
#
#   sh scripts/smoke.sh

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8802}"
STATE="${TMPDIR:-/tmp}/buns-smoke.json"
LOG="${TMPDIR:-/tmp}/buns-smoke.log"
BASE="http://127.0.0.1:$PORT"

cd "$ROOT"
rm -f "$STATE"
BUNS_STATE="$STATE" PORT="$PORT" ./bin/buns app.bun > "$LOG" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
sleep 4

pass=0
fail=0

check() {
  if [ "$2" = "$3" ]; then
    printf '  ok    %s\n' "$1"
    pass=$((pass + 1))
  else
    printf '  FAIL  %s (expected %s, got %s)\n' "$1" "$3" "$2"
    fail=$((fail + 1))
  fi
}

has() {
  if printf '%s' "$2" | grep -q "$3"; then
    printf '  ok    %s\n' "$1"
    pass=$((pass + 1))
  else
    printf '  FAIL  %s (missing %s)\n' "$1" "$3"
    fail=$((fail + 1))
  fi
}

code() { curl -s -o /dev/null -w '%{http_code}' "$1"; }
body() { curl -s "$1"; }
json() { curl -s -X "$1" -H 'content-type: application/json' -d "$3" "$2"; }

printf 'buns — smoke test against %s\n' "$BASE"

check 'the health endpoint answers' "$(code $BASE/health)" "200"
has   'health names the service' "$(body $BASE/health)" '"service": "buns"'
check 'today answers' "$(code $BASE/)" "200"
has   'today shows the open gate' "$(body $BASE/)" 'Waiting on you'
has   'today names the coworker' "$(body $BASE/)" 'Post'
check 'a coworker thread answers' "$(code $BASE/dots/scout)" "200"
has   'the thread has the seeded run' "$(body $BASE/dots/scout)" 'data-run='
check 'the library answers' "$(code $BASE/spaces)" "200"
has   'the library lists spaces' "$(body $BASE/spaces)" 'Aurelia launch'
check 'a space answers' "$(code $BASE/spaces/launch)" "200"
check 'a page answers' "$(code $BASE/spaces/launch/p/p_brief)" "200"
has   'the page renders markdown' "$(body $BASE/spaces/launch/p/p_brief)" '<h2>What we heard</h2>'
has   'the page has a revision' "$(body $BASE/spaces/launch/p/p_brief)" 'revision 4'
check 'search answers' "$(code "$BASE/search?q=pricing")" "200"
has   'search finds a source' "$(body "$BASE/search?q=pricing")" 'Pricing pages that convert'
check 'the about page answers' "$(code $BASE/about)" "200"
check 'the stylesheet is served' "$(code $BASE/assets/app.css)" "200"
has   'the stylesheet has a CSS type' "$(curl -s -D - -o /dev/null $BASE/assets/app.css)" 'text/css'
check 'the script is served' "$(code $BASE/assets/app.js)" "200"
check 'an unknown path is a 404' "$(code $BASE/nope)" "404"

# A message starts a run.
MSG=$(json POST "$BASE/api/messages" '{"dot":"scout","text":"Brief me on freight costs"}')
has   'a message starts a run' "$MSG" '"ok": true'
RUN=$(printf '%s' "$MSG" | sed -e 's/.*"run": "//' -e 's/".*//')
check 'the run page answers' "$(code "$BASE/dots/scout?run=$RUN")" "200"
has   'the run is in the thread' "$(body "$BASE/dots/scout")" "$RUN"

# A finished run cannot be decided again.
check 'deciding a finished run is a 409' "$(json POST "$BASE/api/runs/$RUN/decide" '{"approve":true}' -o /dev/null -w '' >/dev/null 2>&1; curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"approve":true}' "$BASE/api/runs/$RUN/decide")" "409"

check 'an empty message is a 400' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"dot":"scout","text":"  "}' $BASE/api/messages)" "400"
check 'a message without a coworker is a 400' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"text":"hello"}' $BASE/api/messages)" "400"

# Pages: create, conflict, save.
NEW=$(json POST "$BASE/api/pages" '{"space":"launch"}')
has   'a page can be created' "$NEW" '"ok": true'
PAGE=$(printf '%s' "$NEW" | sed -e 's/.*"id": "//' -e 's/".*//')
check 'the new page answers' "$(code "$BASE/spaces/launch/p/$PAGE")" "200"
STALE=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH -H 'content-type: application/json' -d '{"body":"x","rev":99}' "$BASE/api/pages/$PAGE")
check 'a stale revision is a 409' "$STALE" "409"
SAVED=$(curl -s -X PATCH -H 'content-type: application/json' -d '{"body":"## Edited","rev":1}' "$BASE/api/pages/$PAGE")
has   'a current revision saves' "$SAVED" '"rev": 2'
check 'GET on a page endpoint is a 405' "$(code "$BASE/api/pages/$PAGE")" "405"

printf '\n  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = "0" ]
