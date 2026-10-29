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

# The OpenDots views: tasks, memories, settings, and the new bun path.
check 'the tasks page answers' "$(code $BASE/tasks)" "200"
has   'the tasks page lists schedules' "$(body $BASE/tasks)" 'Scheduled'
has   'the tasks page shows activity' "$(body $BASE/tasks)" 'Activity'
check 'the memories page answers' "$(code $BASE/memories)" "200"
has   'the memories page shows a seed memory' "$(body $BASE/memories)" 'Entity C splits freight'
check 'the settings page answers' "$(code $BASE/settings)" "200"
has   'the settings page admits what is not connected' "$(body $BASE/settings)" 'Not connected'
check 'a bun answers at /buns/' "$(code $BASE/buns/scout)" "200"
check 'the old /dots/ path still answers' "$(code $BASE/dots/scout)" "200"
check 'api state answers' "$(code $BASE/api/state)" "200"
has   'api state has memories' "$(body $BASE/api/state)" '"memories"'
has   'api state has schedules' "$(body $BASE/api/state)" '"schedules"'

# Tasks: create, fetch, act on.
TASK=$(json POST "$BASE/api/tasks" '{"dot":"relay","goal":"Book the reference call with Marcus"}')
has   'a task can be created' "$TASK" '"ok": true'
TASKID=$(printf '%s' "$TASK" | sed -e 's/.*"task": "//' -e 's/".*//')
check 'the task is fetchable' "$(code $BASE/api/tasks/$TASKID)" "200"
has   'the task recalls a memory first' "$(body $BASE/api/tasks/$TASKID)" 'memory.recall'
check 'a task without a goal is a 400' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"dot":"scout"}' $BASE/api/tasks)" "400"
check 'a task for a missing bun is a 404' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"dot":"nobody","goal":"x"}' $BASE/api/tasks)" "404"
check 'an unknown action is a 400' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"action":"nope"}' $BASE/api/tasks/r_seed_scout/actions)" "400"
check 'approving a task that is not waiting is a 409' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"action":"approve"}' $BASE/api/tasks/r_seed_scout/actions)" "409"
check 'a response is recorded' "$(curl -s -X POST -H 'content-type: application/json' -d '{"action":"respond","text":"Friday instead."}' $BASE/api/tasks/r_seed_post/actions)" '{"ok": true}'
check 'a response without text is a 400' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"action":"respond"}' $BASE/api/tasks/r_seed_post/actions)" "400"

# Schedules.
SCH=$(json POST "$BASE/api/tasks" '{"dot":"ledger","goal":"Review the pipeline","schedule":{"cadence":"daily"}}')
has   'a schedule can be created' "$SCH" '"cadence": "daily"'
SCHID=$(printf '%s' "$SCH" | sed -e 's/.*"id": "//' -e 's/".*//')
check 'a schedule can be removed' "$(curl -s -X DELETE $BASE/api/schedules/$SCHID)" '{"ok": true}'
check 'a missing schedule is a 404' "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE $BASE/api/schedules/sch_nope)" "404"
has   'PUT schedule on a task works' "$(curl -s -X PUT -H 'content-type: application/json' -d '{"cadence":"weekly"}' $BASE/api/tasks/r_seed_scout/schedule)" '"cadence": "weekly"'

# Memories: create, update, delete.
MEM=$(json POST "$BASE/api/memories" '{"dot":"scout","text":"Buyers read the pricing table longer."}')
has   'a memory can be created' "$MEM" '"source": "manual"'
MEMID=$(printf '%s' "$MEM" | sed -e 's/.*"id": "//' -e 's/".*//')
has   'a memory can be updated' "$(curl -s -X PUT -H 'content-type: application/json' -d '{"text":"revised"}' $BASE/api/memories/$MEMID)" '"text": "revised"'
check 'a memory can be deleted' "$(curl -s -X DELETE $BASE/api/memories/$MEMID)" '{"ok": true}'
check 'a missing memory is a 404' "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE $BASE/api/memories/mem_nope)" "404"
check 'an empty memory is a 400' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"dot":"scout","text":"  "}' $BASE/api/memories)" "400"

# Settings.
SET=$(curl -s -X PATCH -H 'content-type: application/json' -d '{"notify_gates":false,"tz_label":"IST"}' $BASE/api/settings)
has   'settings can be patched' "$SET" '"notify_gates": false'
check 'GET on settings is a 405' "$(code $BASE/api/settings)" "405"

printf '\n  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = "0" ]
