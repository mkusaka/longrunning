#!/bin/bash
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 6 ]; then
  echo "usage: $0 <repo-path> <prompt-file> <run-root> [max-iterations] [max-review-rounds] [model]" >&2
  exit 1
fi

repo="$1"
prompt_file="$2"
run_root="$3"
max_iterations="${4:-6}"
max_review_rounds="${5:-3}"
model="${6:-gpt-5.4}"

watchdog_script="$(dirname "$0")/run_codex_watchdog.sh"
review_script="$(dirname "$0")/run_structured_review.sh"
todo_state_script="$(dirname "$0")/todo_state.py"

printf '%s\n' "running" > "$run_root/review_gate_status.txt"

"$watchdog_script" "$repo" "$prompt_file" "$run_root" "$max_iterations" "$model" || true

session_id_file="$run_root/session_id.txt"
if [ ! -f "$session_id_file" ]; then
  echo "missing session_id.txt after watchdog run" >&2
  exit 1
fi
session_id="$(cat "$session_id_file")"

todo_state_json="$(python3 "$todo_state_script" "$repo/TODO.md")"
printf '%s\n' "$todo_state_json" > "$run_root/final_todo_state.json"
open_todos="$(printf '%s\n' "$todo_state_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["objective_open"])')"
blocked_todos="$(printf '%s\n' "$todo_state_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["blocked"])')"

if [ "$open_todos" -ne 0 ]; then
  echo "watchdog ended with open TODO items; skipping review gate" > "$run_root/review_gate_status.txt"
  exit 2
fi

if [ "$blocked_todos" -ne 0 ]; then
  echo "watchdog ended with explicit blockers; skipping review gate" > "$run_root/review_gate_status.txt"
  exit 4
fi

for round in $(seq 1 "$max_review_rounds"); do
  review_dir="$run_root/review-round-$(printf '%02d' "$round")"
  mkdir -p "$review_dir"
  "$review_script" "$repo" "$review_dir" "$model"

  findings_count="$(python3 - "$review_dir/review.json" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
print(len(payload.get("findings", [])))
PY
)"

  printf '%s\n' "$findings_count" > "$review_dir/findings_count.txt"
  if [ "$findings_count" -eq 0 ]; then
    echo "review gate passed" > "$run_root/review_gate_status.txt"
    exit 0
  fi

  resume_prompt="$review_dir/review_resume_prompt.txt"
  cat > "$resume_prompt" <<EOF
You believed the main objective was complete, but an independent review found actionable issues.

Read these files before doing anything else:
- CODEX_IMPLEMENTATION_PROMPT.md
- TODO.md
- investigate.md
- GOTCHA.md
- $review_dir/review.json

Add each actionable finding to TODO.md, fix the issues, rerun relevant tests, update investigate.md with the reasoning, and continue.
Do not stop until TODO.md is clear again and the independent review passes.
EOF

  (
    cd "$repo"
    codex exec resume \
      --full-auto \
      --json \
      -m "$model" \
      -o "$review_dir/review_resume_last_message.txt" \
      "$session_id" \
      "$(cat "$resume_prompt")" \
      > "$review_dir/review_resume_run.jsonl"
  )

  todo_state_json="$(python3 "$todo_state_script" "$repo/TODO.md")"
  printf '%s\n' "$todo_state_json" > "$review_dir/todo_state_after_resume.json"
done

echo "review gate exhausted max rounds" > "$run_root/review_gate_status.txt"
exit 3
