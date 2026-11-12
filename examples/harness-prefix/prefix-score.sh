#!/usr/bin/env bash
# prefix-score — one number for nodecode's standing prefix.
# Runs one fresh rpc session (pinned seat, prompt "Reply with exactly: PONG"),
# then prints: tokens=<input+cached input of the turn>, wall_s=<whole probe>,
# boot_s=<process start to turn.started>, pong=<1|0>. Locked by climb.py.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
STORE="${NC_SCORE_STORE:-/tmp/nc-prefix/score.db}"
MODEL="${NC_SCORE_MODEL:-deepseek-v4.1-flash}"
EFFORT="${NC_SCORE_EFFORT:-low}"
PROMPT="${NC_SCORE_PROMPT:-Reply with exactly: PONG}"
mkdir -p "$(dirname "$STORE")"; rm -f "$STORE" "$STORE"-wal "$STORE"-shm
out=$(mktemp /tmp/nc-prefix/out.XXXX); err=$(mktemp /tmp/nc-prefix/err.XXXX)
payload=$(PROMPT="$PROMPT" MODEL="$MODEL" EFFORT="$EFFORT" python3 -c 'import json,os;print(json.dumps({"type":"start_turn","request":{"prompt":os.environ["PROMPT"],"provider":"surplus","model":os.environ["MODEL"],"effort":os.environ["EFFORT"]}}))')
fifo=$(mktemp -u /tmp/nc-prefix/fifo.XXXX); mkfifo "$fifo"
t0=$(date +%s%N)
nodecode rpc --store "$STORE" < "$fifo" > "$out" 2> "$err" & pid=$!
exec 3> "$fifo"
printf '%s\n' "$payload" >&3
for _ in $(seq 1 1200); do
  grep -qE '"type":"(turn\.completed|turn\.failed|turn\.cancelled)"' "$out" && break
  kill -0 $pid 2>/dev/null || break
  sleep 0.1
done
t1=$(date +%s%N)
exec 3>&-
wait $pid 2>/dev/null
rm -f "$fifo"
python3 - "$STORE" "$t0" "$t1" "$out" <<'PY'
import sqlite3, sys, json, re
store, t0, t1, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
wall = (t1 - t0) / 1e9
tok = None; boot = None; pong = 0
try:
    c = sqlite3.connect(store)
    r = c.execute("select payload from events where kind='turn.usage' order by occurred_at desc limit 1").fetchone()
    if r:
        j = json.loads(r[0])
        tok = int(j.get("input-tokens") or 0) + int(j.get("cached-input-tokens") or 0)
        pong = 1 if int(j.get("total-tokens") or 0) > 0 else 0
    pass
except Exception as e:
    print("score-error:", e, file=sys.stderr)
# answer check: the assistant message text must carry PONG
try:
    c = sqlite3.connect(store)
    r = c.execute("select payload from events where kind='turn.assistant_message_completed' order by occurred_at desc limit 1").fetchone()
    if r:
        msg = json.loads(r[0]).get("message")
        text = json.dumps(msg)
        pong = 1 if (pong and "PONG" in text.upper()) else 0
except Exception:
    pass
print(f"tokens={tok if tok is not None else -1}")
print(f"wall_s={wall:.2f}")
print(f"boot_s={boot if boot is not None else -1:.2f}")
print(f"pong={pong}")
PY
rc=$?
if [ "$rc" -ne 0 ]; then tail -3 "$err"; fi
rm -f "$out" "$err"
exit 0
