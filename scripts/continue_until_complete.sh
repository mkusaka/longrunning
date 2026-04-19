#!/bin/bash
set -euo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 6 ]; then
  echo "usage: $0 <campaign-pid> <repo-path> <prompt-file> <run-root> [poll-seconds] [model]" >&2
  exit 1
fi

campaign_pid="$1"
repo="$2"
prompt_file="$3"
run_root="$4"
poll_seconds="${5:-30}"
model="${6:-gpt-5.4}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
campaign_script="$script_dir/run_codex_campaign.sh"
todo_state_script="$script_dir/todo_state.py"
log_file="$run_root/continue_supervisor.log"

mkdir -p "$run_root"
printf '%s\n' "supervisor started at $(date -u +%Y-%m-%dT%H:%M:%SZ) for pid=$campaign_pid" >> "$log_file"

while :; do
  while kill -0 "$campaign_pid" >/dev/null 2>&1; do
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
