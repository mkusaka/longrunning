#!/bin/bash
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 5 ]; then
  echo "usage: $0 <repo-path> <prompt-file> <run-root> [max-iterations] [model]" >&2
  exit 1
fi

repo="$1"
prompt_file="$2"
run_root="$3"
max_iterations="${4:-6}"
model="${5:-gpt-5.4}"

mkdir -p "$run_root"
"$(dirname "$0")/sync_prompt_into_repo.sh" "$repo" "$prompt_file"
printf '%s\n' "running" > "$run_root/watchdog_status.txt"

if [ -f "$repo/CODEX_IMPLEMENTATION_PROMPT.md" ]; then
  prompt_file="$repo/CODEX_IMPLEMENTATION_PROMPT.md"
fi

session_id=""
session_id_file="$run_root/session_id.txt"
todo_state_script="$(dirname "$0")/todo_state.py"
start_iteration=1

if [ -f "$session_id_file" ]; then
  session_id="$(cat "$session_id_file")"
fi

last_iter="$(
  find "$run_root" -maxdepth 1 -type d -name 'iter-*' -print \
    | sed 's#^.*/iter-##' \
    | sort \
    | tail -n 1
)"

if [ -n "$last_iter" ]; then
  start_iteration=$((10#$last_iter + 1))
fi

end_iteration=$((start_iteration + max_iterations - 1))

for iteration in $(seq "$start_iteration" "$end_iteration"); do
  iter_dir="$run_root/iter-$(printf '%02d' "$iteration")"
  mkdir -p "$iter_dir"

  if [ -z "$session_id" ]; then
    codex exec \
      -C "$repo" \
      --full-auto \
      --json \
      -m "$model" \
      -o "$iter_dir/last_message.txt" \
      - < "$prompt_file" \
      > "$iter_dir/run.jsonl"
    session_id="$("$(dirname "$0")/extract_session_id.sh" "$iter_dir/run.jsonl")"
    printf '%s\n' "$session_id" > "$session_id_file"
  else
    resume_prompt="$iter_dir/resume_prompt.txt"
    cat > "$resume_prompt" <<'EOF'
You returned control, but the main objective is not yet complete.

Read `CODEX_IMPLEMENTATION_PROMPT.md`, `TODO.md`, `investigate.md`, and `GOTCHA.md` again.
Before starting new work, reconcile `TODO.md` with already-landed code and tests so recently completed slices are marked done.
Then continue immediately from the highest-leverage unfinished frontier.

Do not stop because a local milestone is green.
Do not summarize and stop while objective-related unchecked tasks remain in `TODO.md`.
Only stop if the objective is truly complete or an external blocker is fully recorded in `TODO.md` and `investigate.md`.
EOF

    (
      cd "$repo"
      codex exec resume \
        --full-auto \
        --json \
        -m "$model" \
        -o "$iter_dir/last_message.txt" \
        "$session_id" \
        "$(cat "$resume_prompt")" \
        > "$iter_dir/run.jsonl"
    )
  fi

  todo_state_json="$(python3 "$todo_state_script" "$repo/TODO.md")"
  printf '%s\n' "$todo_state_json" > "$iter_dir/todo_state.json"
  open_todos="$(printf '%s\n' "$todo_state_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["objective_open"])')"
  blocked_todos="$(printf '%s\n' "$todo_state_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["blocked"])')"
  printf '%s\n' "$open_todos" > "$iter_dir/open_todos.txt"

  if [ "$open_todos" -eq 0 ] && [ "$blocked_todos" -eq 0 ]; then
    printf 'objective candidate complete after iteration %s\n' "$iteration" | tee "$run_root/watchdog_status.txt"
    exit 0
  fi

  if [ "$open_todos" -eq 0 ] && [ "$blocked_todos" -gt 0 ]; then
    printf 'watchdog observed explicit blockers after iteration %s\n' "$iteration" | tee "$run_root/watchdog_status.txt"
    exit 3
  fi
done

printf 'watchdog hit max iterations with unchecked TODO items remaining\n' | tee "$run_root/watchdog_status.txt"
exit 2
