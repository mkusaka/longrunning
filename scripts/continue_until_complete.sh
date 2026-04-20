#!/bin/bash
set -euo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 7 ]; then
  echo "usage: $0 <campaign-pid> <repo-path> <prompt-file> <run-root> [poll-seconds] [model] [stall-seconds]" >&2
  exit 1
fi

campaign_pid="$1"
repo="$2"
prompt_file="$3"
run_root="$4"
poll_seconds="${5:-30}"
model="${6:-gpt-5.4}"
stall_seconds="${7:-3600}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
campaign_script="$script_dir/run_codex_campaign.sh"
todo_state_script="$script_dir/todo_state.py"
run_state_script="$script_dir/check_run_state.py"
log_file="$run_root/continue_supervisor.log"

mkdir -p "$run_root"
printf '%s\n' "supervisor started at $(date -u +%Y-%m-%dT%H:%M:%SZ) for pid=$campaign_pid" >> "$log_file"

terminate_tree() {
  local pid="$1"
  local children
  children="$(pgrep -P "$pid" || true)"
  for child in $children; do
    terminate_tree "$child"
  done
  kill -TERM "$pid" 2>/dev/null || true
}

force_kill_tree() {
  local pid="$1"
  local children
  children="$(pgrep -P "$pid" || true)"
  for child in $children; do
    force_kill_tree "$child"
  done
  kill -KILL "$pid" 2>/dev/null || true
}

while :; do
  while kill -0 "$campaign_pid" >/dev/null 2>&1; do
    run_state_json="$(python3 "$run_state_script" "$run_root" "$stall_seconds")"
    stalled="$(printf '%s\n' "$run_state_json" | python3 -c 'import json, sys; print("1" if json.load(sys.stdin)["stalled"] else "0")')"
    latest_iter="$(printf '%s\n' "$run_state_json" | python3 -c 'import json, sys; data=json.load(sys.stdin); print(data["latest_iter"] or "")')"
    age_seconds="$(printf '%s\n' "$run_state_json" | python3 -c 'import json, sys; data=json.load(sys.stdin); print("" if data["run_jsonl_age_seconds"] is None else data["run_jsonl_age_seconds"])')"

    if [ "$stalled" -eq 1 ]; then
      printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) detected stalled run latest_iter=${latest_iter:-unknown} age_seconds=${age_seconds:-unknown}; terminating campaign tree rooted at pid=$campaign_pid" >> "$log_file"
      terminate_tree "$campaign_pid"
      sleep 5
      if kill -0 "$campaign_pid" >/dev/null 2>&1; then
        printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) campaign pid=$campaign_pid survived SIGTERM; escalating to SIGKILL" >> "$log_file"
        force_kill_tree "$campaign_pid"
        sleep 1
      fi
      break
    fi

    sleep "$poll_seconds"
  done

  todo_state_json="$(python3 "$todo_state_script" "$repo/TODO.md")"
  objective_open="$(printf '%s\n' "$todo_state_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["objective_open"])')"
  blocked="$(printf '%s\n' "$todo_state_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["blocked"])')"

  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) pid=$campaign_pid exited objective_open=$objective_open blocked=$blocked" >> "$log_file"

  if [ "$objective_open" -eq 0 ] && [ "$blocked" -eq 0 ]; then
    printf '%s\n' "objective complete; supervisor exiting" >> "$log_file"
    exit 0
  fi

  if [ "$blocked" -ne 0 ]; then
    printf '%s\n' "blocked TODOs present; supervisor exiting" >> "$log_file"
    exit 4
  fi

  printf '%s\n' "relaunching unlimited campaign" >> "$log_file"
  bash "$campaign_script" "$repo" "$prompt_file" "$run_root" 0 12 3 "$model" >> "$log_file" 2>&1 &
  campaign_pid=$!
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) relaunched pid=$campaign_pid" >> "$log_file"
done
