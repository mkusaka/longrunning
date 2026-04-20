#!/bin/bash
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 7 ]; then
  echo "usage: $0 <repo-path> <prompt-file> <run-root> [poll-seconds] [model] [stall-seconds] [max-iterations-per-batch]" >&2
  exit 1
fi

repo="$1"
prompt_file="$2"
run_root="$3"
poll_seconds="${4:-30}"
model="${5:-gpt-5.4}"
stall_seconds="${6:-3600}"
max_iterations="${7:-12}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
campaign_script="$script_dir/run_codex_campaign.sh"
supervisor_script="$script_dir/continue_until_complete.sh"

mkdir -p "$run_root"

bash "$campaign_script" "$repo" "$prompt_file" "$run_root" 0 "$max_iterations" 3 "$model" &
campaign_pid=$!
printf '%s\n' "$campaign_pid" > "$run_root/campaign.pid"

exec bash "$supervisor_script" "$campaign_pid" "$repo" "$prompt_file" "$run_root" "$poll_seconds" "$model" "$stall_seconds"
