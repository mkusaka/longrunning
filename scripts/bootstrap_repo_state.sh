#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <target-repo>" >&2
  exit 1
fi

target_repo="$1"
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

mkdir -p "$target_repo"

copy_if_missing() {
  local source="$1"
  local dest="$2"
  if [ ! -e "$dest" ]; then
    cp "$source" "$dest"
  fi
}

copy_if_missing "$repo_root/prompts/noninteractive_hybrid_prompt.md" "$target_repo/CODEX_IMPLEMENTATION_PROMPT.md"
copy_if_missing "$repo_root/templates/TODO.example.md" "$target_repo/TODO.md"
copy_if_missing "$repo_root/templates/investigate.example.md" "$target_repo/investigate.md"
copy_if_missing "$repo_root/templates/GOTCHA.example.md" "$target_repo/GOTCHA.md"
