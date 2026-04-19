#!/bin/bash
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 7 ]; then
  echo "usage: $0 <repo-path> <prompt-file> <run-root> [max-batches(0=unlimited)] [max-iterations-per-batch] [max-review-rounds] [model]" >&2
  exit 1
fi

repo="$1"
prompt_file="$2"
run_root="$3"
max_batches="${4:-0}"
max_iterations="${5:-8}"
max_review_rounds="${6:-3}"
model="${7:-gpt-5.4}"

watchdog_with_review_script="$(dirname "$0")/run_codex_watchdog_with_review.sh"
todo_state_script="$(dirname "$0")/todo_state.py"

mkdir -p "$run_root"
campaign_log="$run_root/campaign.log"
campaign_status="$run_root/campaign_status.txt"
watchdog_status="$run_root/watchdog_status.txt"
review_gate_status="$run_root/review_gate_status.txt"
final_todo_state="$run_root/final_todo_state.json"

printf '%s\n' "campaign started at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$campaign_log"
printf '%s\n' "running" > "$campaign_status"
rm -f "$watchdog_status" "$review_gate_status" "$final_todo_state"

batch=1
stalled_batches=0
previous_objective_open=""
while :; do
  if [ "$max_batches" -ne 0 ] && [ "$batch" -gt "$max_batches" ]; then
    echo "max_batches_exhausted" > "$campaign_status"
    exit 5
  fi

  printf '%s\n' "batch $batch start" | tee -a "$campaign_log"

  last_iter_before="$(
    find "$run_root" -maxdepth 1 -type d -name 'iter-*' -print \
      | sed 's#^.*/iter-##' \
      | sort \
      | tail -n 1
  )"

  set +e
  "$watchdog_with_review_script" "$repo" "$prompt_file" "$run_root" "$max_iterations" "$max_review_rounds" "$model" >> "$campaign_log" 2>&1
  status=$?
  set -e

  todo_state_json="$(python3 "$todo_state_script" "$repo/TODO.md")"
  printf '%s\n' "$todo_state_json" > "$run_root/final_todo_state.json"
  objective_open="$(printf '%s\n' "$todo_state_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["objective_open"])')"
  blocked="$(printf '%s\n' "$todo_state_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["blocked"])')"

  last_iter_after="$(
    find "$run_root" -maxdepth 1 -type d -name 'iter-*' -print \
      | sed 's#^.*/iter-##' \
      | sort \
      | tail -n 1
  )"

  if [ "$status" -eq 2 ] && [ "$previous_objective_open" = "$objective_open" ] && [ "$last_iter_before" = "$last_iter_after" ]; then
    stalled_batches=$((stalled_batches + 1))
  else
    stalled_batches=0
  fi
  previous_objective_open="$objective_open"

  printf '%s\n' "batch $batch end status=$status objective_open=$objective_open blocked=$blocked last_iter_before=${last_iter_before:-none} last_iter_after=${last_iter_after:-none} stalled_batches=$stalled_batches" | tee -a "$campaign_log"

  if [ "$stalled_batches" -ge 3 ]; then
    echo "stalled_no_new_iterations" > "$campaign_status"
    exit 6
  fi

  case "$status" in
    0)
      echo "completed" > "$campaign_status"
      exit 0
      ;;
    2)
      if [ "$objective_open" -gt 0 ]; then
        batch=$((batch + 1))
        continue
      fi
      echo "inconsistent_open_todo_state" > "$campaign_status"
      exit 2
      ;;
    3)
      batch=$((batch + 1))
      continue
      ;;
    4)
      echo "blocked" > "$campaign_status"
      exit 4
      ;;
    *)
      echo "failed_status_$status" > "$campaign_status"
      exit "$status"
      ;;
  esac
done
