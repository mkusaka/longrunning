#!/bin/bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "usage: $0 <repo-path> <run-dir> [model]" >&2
  exit 1
fi

repo="$1"
run_dir="$2"
model="${3:-gpt-5.4}"
schema="$(cd "$(dirname "$0")/.." && pwd)/schemas/review_findings.schema.json"

mkdir -p "$run_dir"

prompt_file="$run_dir/review_prompt.txt"
cat > "$prompt_file" <<'EOF'
Review the current uncommitted changes in this repository.

Focus on:
- correctness regressions
- missing implementation parity versus the stated objective
- missing test coverage
- unsafe assumptions
- architecture mismatches
- overlooked edge cases

Ignore markdown-only notes and temporary investigation artifacts.

Return JSON only, matching the provided schema.
- `summary`: short overall summary
- `findings`: array of actionable findings

Environment note:
- This repository may run in a sandbox where writing under `~/.cargo` is blocked.
- If you need to run Rust tests, prefer `CARGO_HOME=$PWD/tmp/cargo-home CARGO_TARGET_DIR=$PWD/tmp/target cargo test --offline`.
- Do not block the review on a failed attempt to use the default Cargo cache path; fall back to code-backed review if execution is constrained.
EOF

codex exec \
  -C "$repo" \
  --full-auto \
  --ephemeral \
  --json \
  --output-schema "$schema" \
  -m "$model" \
  -o "$run_dir/review.json" \
  - < "$prompt_file" \
  > "$run_dir/review_run.jsonl"
