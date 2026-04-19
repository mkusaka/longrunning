#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <run-jsonl>" >&2
  exit 1
fi

jsonl="$1"
python3 - "$jsonl" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        event = json.loads(line)
        if event.get("type") == "session_meta":
            print(event["payload"]["id"])
            break
        if event.get("type") == "thread.started":
            print(event["thread_id"])
            break
PY
