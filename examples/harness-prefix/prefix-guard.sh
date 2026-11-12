#!/usr/bin/env bash
# prefix-guard — the probe must have completed its turn and answered PONG.
set -uo pipefail
STORE="${NC_SCORE_STORE:-/tmp/nc-prefix/score.db}"
python3 - "$STORE" <<'PY'
import sqlite3, sys, json
try:
    c = sqlite3.connect(sys.argv[1])
except Exception as e:
    print("guard: no store:", e); sys.exit(1)
rows = c.execute("select payload from events where kind='turn.assistant_message_completed' order by occurred_at desc limit 1").fetchone()
completed = c.execute("select count(*) from events where kind='turn.completed'").fetchone()[0]
said = bool(rows) and "PONG" in json.dumps(json.loads(rows[0]).get("message")).upper()
print(f"guard: completed={completed} said_pong={said}")
sys.exit(0 if (completed and said) else 1)
PY
