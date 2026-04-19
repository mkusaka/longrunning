#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ] && [ "$#" -ne 4 ]; then
  echo "usage: $0 <repo-path> <prompt-file> [replace-from replace-to]" >&2
  exit 1
fi

repo="$1"
prompt_file="$2"
dest="$repo/CODEX_IMPLEMENTATION_PROMPT.md"

source_real="$(python3 - "$prompt_file" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
)"

dest_real="$(python3 - "$dest" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
)"

if [ "$source_real" != "$dest_real" ]; then
  cp "$prompt_file" "$dest"
fi

if [ "$#" -eq 4 ]; then
  python3 - "$dest" "$3" "$4" <<'PY'
import sys

path = sys.argv[1]
replace_from = sys.argv[2]
replace_to = sys.argv[3]

with open(path, "r", encoding="utf-8") as handle:
    text = handle.read()

text = text.replace(replace_from, replace_to)

with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
PY
fi
